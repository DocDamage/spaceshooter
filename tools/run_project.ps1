param(
    [ValidateSet("import", "test", "boot", "soak", "assets", "assets-source", "artifacts", "metadata", "verify", "export-debug", "export-development", "export-qa", "export-demo", "export-rc", "export-release", "export-smoke", "rc-repro", "package-release", "installer", "installer-smoke", "all")]
    [string]$Task = "verify",
    [string]$GodotPath = "",
    [switch]$RequireSignature
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$ExpectedGodotVersion = "4.7.1.stable"
$FailurePattern = '^(SCRIPT ERROR:|ERROR:)|FAIL:|WARNING:.*(?:RID|ObjectDB instances?).*leaked|ERROR:.*resources? still in use'

function Resolve-GodotCommand {
	if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
		return (Resolve-Path -LiteralPath $GodotPath).Path
	}
	$firstCandidate = ""
	foreach ($name in @("godot.cmd", "godot", "godot.exe")) {
		$command = Get-Command $name -ErrorAction SilentlyContinue
		if ($null -eq $command) { continue }
		if ([string]::IsNullOrWhiteSpace($firstCandidate)) { $firstCandidate = $command.Source }
		$version = (& $command.Source --version 2>&1 | Select-Object -First 1).ToString().Trim()
		if ($version.StartsWith($ExpectedGodotVersion, [System.StringComparison]::Ordinal)) { return $command.Source }
	}
	if (-not [string]::IsNullOrWhiteSpace($firstCandidate)) { return $firstCandidate }
	throw "Godot was not found. Install Godot $ExpectedGodotVersion or pass -GodotPath."
}

$Godot = Resolve-GodotCommand

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowEngineDiagnostics,
        [string[]]$ForbiddenPatterns = @()
	)
	Write-Host "`n== $Label ==" -ForegroundColor Cyan
	$previousErrorPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try {
		$output = @(& $Command @Arguments 2>&1 | ForEach-Object { $_.ToString() })
		$exitCode = $LASTEXITCODE
	}
	finally {
		$ErrorActionPreference = $previousErrorPreference
	}
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0) { throw "$Label exited with code $exitCode." }
    if (-not $AllowEngineDiagnostics) {
        $bad = @($output | Where-Object { $_ -match $FailurePattern })
        if ($bad.Count -gt 0) {
            throw "$Label emitted release-blocking diagnostics: $($bad -join ' | ')"
        }
    }
	foreach ($pattern in $ForbiddenPatterns) {
		$forbidden = @($output | Where-Object { $_ -match $pattern })
		if ($forbidden.Count -gt 0) { throw "$Label packed forbidden release content matching '$pattern': $($forbidden -join ' | ')" }
	}
}

function Assert-GodotVersion {
    $actual = (& $Godot --version 2>&1 | Select-Object -First 1).ToString().Trim()
    if (-not $actual.StartsWith($ExpectedGodotVersion, [System.StringComparison]::Ordinal)) {
        throw "Expected Godot $ExpectedGodotVersion, found '$actual'."
    }
    Write-Host "Godot $actual" -ForegroundColor Green
}

function Test-Metadata {
    Write-Host "`n== Version metadata ==" -ForegroundColor Cyan
    $version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
    $contentRevision = (Get-Content -LiteralPath (Join-Path $ProjectRoot "CONTENT_REVISION") -Raw).Trim()
    $projectText = Get-Content -LiteralPath (Join-Path $ProjectRoot "project.godot") -Raw
    if ($projectText -notmatch ('config/version="' + [regex]::Escape($version) + '"')) {
        throw "VERSION '$version' does not match project.godot."
    }
    if ($projectText -notmatch ('config/content_revision="' + [regex]::Escape($contentRevision) + '"')) {
        throw "CONTENT_REVISION '$contentRevision' does not match project.godot."
    }
    $exactTag = (git -C $ProjectRoot describe --tags --exact-match 2>$null | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($exactTag) -and $exactTag -match '^v(.+)$' -and $Matches[1] -ne $version) {
        throw "Release tag '$exactTag' does not match VERSION '$version'."
    }
    Write-Host "version=$version content_revision=$contentRevision" -ForegroundColor Green
}

function Test-RepositoryArtifacts {
    Write-Host "`n== Repository artifact policy ==" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
        throw "The project root is not initialized as a Git repository."
    }
    $tracked = @(git -C $ProjectRoot ls-files)
    $forbidden = @($tracked | Where-Object {
        $_ -match '(^|/)\.godot/' -or
        $_ -match '(^|/)builds/.+\.(exe|pck|zip)$' -or
        $_ -match '\.(exe|pck|tpz)$'
    })
    if ($forbidden.Count -gt 0) {
        throw "Committed build/cache artifacts: $($forbidden -join ', ')"
    }
    $runtimeFiles = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "assets_runtime") -File -Recurse | Where-Object { $_.Extension -ne ".import" })
    if ($runtimeFiles.Count -eq 0) { throw "assets_runtime contains no approved derivatives." }
    Write-Host "$($runtimeFiles.Count) runtime derivatives; no committed executable/cache artifacts" -ForegroundColor Green
}

function Invoke-ImportValidation {
    Assert-GodotVersion
    Invoke-Checked -Label "Godot import and parse validation" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "--editor", "--quit")
}

function Invoke-AssetValidation {
    param([switch]$RequireSource)
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
    if ($null -eq $python) { throw "Python 3.10+ is required for asset validation." }
    $pipeline = Join-Path $ProjectRoot "tools/asset_catalog/asset_pipeline.py"
    $arguments = @($pipeline, "validate", "--release")
    if ($RequireSource) { $arguments += "--require-source" }
    Invoke-Checked -Label "Runtime asset release validation" -Command $python.Source -Arguments $arguments
	Invoke-Checked -Label "Asset pipeline unit tests" -Command $python.Source -Arguments @((Join-Path $ProjectRoot "tests/phase3/test_asset_pipeline.py")) -AllowEngineDiagnostics
}

function Invoke-AllTests {
	Assert-GodotVersion
	$tests = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "tests") -Recurse -Filter "*acceptance.gd" | Sort-Object FullName)
	foreach ($test in $tests) {
		$relative = $test.FullName.Substring($ProjectRoot.Length + 1).Replace("\", "/")
		Invoke-Checked -Label $relative -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "--script", "res://$relative")
	}
	$smoke = Join-Path $ProjectRoot "tests/smoke/phase1_smoke.tscn"
	if (Test-Path -LiteralPath $smoke) {
		Invoke-Checked -Label "tests/smoke/phase1_smoke.tscn" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "res://tests/smoke/phase1_smoke.tscn")
	}
	Write-Host "`n$($tests.Count) acceptance suites plus legacy smoke passed without leak diagnostics." -ForegroundColor Green
}

function Invoke-BootSmoke {
    Assert-GodotVersion
    Invoke-Checked -Label "Shipping main-scene headless boot" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "--quit-after", "180")
}

function Invoke-StageOneSoak {
	Assert-GodotVersion
	Invoke-Checked -Label "4-hour simulated Stage 1 replay soak" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "--script", "res://tests/phase20/phase20_stage1_soak.gd")
}

function Get-BuildDefinition {
    param([Parameter(Mandatory = $true)][ValidateSet("development", "qa", "demo", "rc", "release")][string]$Kind)
    switch ($Kind) {
        "development" { return @{ Preset = "Windows Desktop (Development)"; Directory = "development"; File = "galax-hero-development.exe"; Flag = "--export-debug" } }
        "qa" { return @{ Preset = "Windows Desktop (QA)"; Directory = "qa"; File = "galax-hero-qa.exe"; Flag = "--export-debug" } }
        "demo" { return @{ Preset = "Windows Desktop (Demo)"; Directory = "demo"; File = "galax-hero-demo.exe"; Flag = "--export-release" } }
        "rc" { return @{ Preset = "Windows Desktop (Release Candidate)"; Directory = "rc"; File = "galax-hero-rc.exe"; Flag = "--export-release" } }
        "release" { return @{ Preset = "Windows Desktop (Release)"; Directory = "release"; File = "galax-hero-release.exe"; Flag = "--export-release" } }
    }
}

function Invoke-CodeSigning {
    param([Parameter(Mandatory = $true)][string]$Executable)
    $thumbprint = [Environment]::GetEnvironmentVariable("GALAX_HERO_SIGNING_THUMBPRINT")
    if ([string]::IsNullOrWhiteSpace($thumbprint)) {
        if ($RequireSignature) { throw "A release signature is required, but GALAX_HERO_SIGNING_THUMBPRINT is not configured." }
        Write-Warning "No signing identity configured; this output is an unsigned test artifact, not a public release."
        return $false
    }
    $configuredTool = [Environment]::GetEnvironmentVariable("GALAX_HERO_SIGNTOOL")
    $signTool = if ([string]::IsNullOrWhiteSpace($configuredTool)) { Get-Command "signtool.exe" -ErrorAction SilentlyContinue } else { Get-Item -LiteralPath $configuredTool -ErrorAction SilentlyContinue }
    if ($null -eq $signTool) { throw "signtool.exe was not found. Set GALAX_HERO_SIGNTOOL to the Windows SDK signing tool." }
    $signToolPath = if ($signTool.PSObject.Properties.Name -contains "Source") { $signTool.Source } else { $signTool.FullName }
    Invoke-Checked -Label "Authenticode signing" -Command $signToolPath -Arguments @("sign", "/sha1", $thumbprint, "/fd", "SHA256", "/tr", "http://timestamp.digicert.com", "/td", "SHA256", $Executable)
    $signature = Get-AuthenticodeSignature -LiteralPath $Executable
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) { throw "Signature verification failed: $($signature.Status) $($signature.StatusMessage)" }
    Write-Host "Authenticode signature verified: $($signature.SignerCertificate.Subject)" -ForegroundColor Green
    return $true
}

function Export-Project {
    param([Parameter(Mandatory = $true)][ValidateSet("development", "qa", "demo", "rc", "release")][string]$Kind)
    Assert-GodotVersion
    $definition = Get-BuildDefinition -Kind $Kind
    $buildDirectory = Join-Path $ProjectRoot ("builds/" + $definition.Directory)
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    $output = Join-Path $buildDirectory $definition.File
    $forbiddenPatterns = if ($Kind -in @("demo", "rc", "release")) { @("res://(?:legacy|tests|tools|docs)/", "(?:weapon_laboratory|enemy_laboratory|online_test_lab|stage_preview|mission_editor|full_campaign_qa_runner|test_mission)") } else { @() }
    Invoke-Checked -Label "$($definition.Preset) export" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, $definition.Flag, $definition.Preset, $output) -ForbiddenPatterns $forbiddenPatterns
    if (-not (Test-Path -LiteralPath $output)) { throw "$($definition.Preset) did not create '$output'." }
    $signed = if ($Kind -in @("rc", "release")) { Invoke-CodeSigning -Executable $output } else { $false }
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$output.sha256", "$hash  $([System.IO.Path]::GetFileName($output))`n", [System.Text.UTF8Encoding]::new($false))
    $buildRecord = [ordered]@{
        schema_version = 1
        channel = $Kind
        version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
        content_revision = (Get-Content -LiteralPath (Join-Path $ProjectRoot "CONTENT_REVISION") -Raw).Trim()
        godot_version = $ExpectedGodotVersion
        executable = [System.IO.Path]::GetFileName($output)
        sha256 = $hash
        signature = if ($signed) { "valid" } else { "unsigned_test_artifact" }
    }
    [System.IO.File]::WriteAllText("$output.build.json", ($buildRecord | ConvertTo-Json -Depth 4) + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "$output`nsha256=$hash" -ForegroundColor Green
}

function Invoke-ExportSmoke {
    param([Parameter(Mandatory = $true)][ValidateSet("development", "qa", "demo", "rc", "release")][string]$Kind)
    $definition = Get-BuildDefinition -Kind $Kind
    $executable = Join-Path $ProjectRoot ("builds/$($definition.Directory)/$($definition.File)")
    if (-not (Test-Path -LiteralPath $executable)) { throw "Exported $Kind executable does not exist: $executable" }
	$log = Join-Path (Split-Path -Parent $executable) "export-smoke.log"
	if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
	Write-Host "`n== $Kind exported-build profile/load/mission smoke ==" -ForegroundColor Cyan
	$arguments = @("--headless", "--log-file", ('"' + $log + '"'), "--", "--export-smoke")
	$process = Start-Process -FilePath $executable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
	$output = if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log) } else { @() }
	$output | ForEach-Object { Write-Host $_ }
	if ($process.ExitCode -ne 0) { throw "$Kind exported smoke exited with code $($process.ExitCode)." }
	$bad = @($output | Where-Object { $_ -match $FailurePattern })
	if ($bad.Count -gt 0) { throw "$Kind exported smoke emitted release-blocking diagnostics: $($bad -join ' | ')" }
	if (-not ($output | Where-Object { $_ -match '^EXPORT_SMOKE: PASS' })) { throw "$Kind exported smoke did not emit its explicit pass marker." }
}

function Test-ReleaseCandidateReproducibility {
	$hashes = @()
	$commit = (git -C $ProjectRoot rev-parse HEAD).Trim()
	$dirtyBefore = -not [string]::IsNullOrWhiteSpace((git -C $ProjectRoot status --porcelain | Out-String).Trim())
	for ($candidate = 1; $candidate -le 3; $candidate++) {
		Export-Project -Kind "rc"
		Invoke-ExportSmoke -Kind "rc"
		$definition = Get-BuildDefinition -Kind "rc"
		$executable = Join-Path $ProjectRoot ("builds/$($definition.Directory)/$($definition.File)")
		$hashes += (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
	}
	if (@($hashes | Select-Object -Unique).Count -ne 1) {
		throw "Three consecutive RC exports were not byte-for-byte reproducible: $($hashes -join ', ')"
	}
	$report = [ordered]@{
		schema_version = 1
		git_commit = $commit
		git_worktree_dirty = $dirtyBefore
		candidate_count = $hashes.Count
		sha256 = $hashes[0]
		exported_smoke = "pass"
		byte_reproducible = $true
	}
	$reportPath = Join-Path $ProjectRoot "builds/rc/reproducibility-report.json"
	[System.IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 5) + "`n", [System.Text.UTF8Encoding]::new($false))
	Write-Host "Three consecutive RC exports and exported-build smokes passed with identical SHA-256 $($hashes[0])." -ForegroundColor Green
}

function Get-GDScriptConstant {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Name)
    $text = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($text, ("const\s+" + [regex]::Escape($Name) + "\s*:=\s*(\d+)"))
    if (-not $match.Success) { throw "Could not read $Name from $Path." }
    return [int]$match.Groups[1].Value
}

function New-ReleasePackage {
    $definition = Get-BuildDefinition -Kind "release"
    $buildDirectory = Join-Path $ProjectRoot "builds/release"
    $executable = Join-Path $buildDirectory $definition.File
    if (-not (Test-Path -LiteralPath $executable)) { throw "Export the release executable before packaging." }
    $version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
    $contentRevision = (Get-Content -LiteralPath (Join-Path $ProjectRoot "CONTENT_REVISION") -Raw).Trim()
    $protocol = Get-GDScriptConstant -Path (Join-Path $ProjectRoot "production/network/network_protocol.gd") -Name "PROTOCOL_VERSION"
    $saveSchema = Get-GDScriptConstant -Path (Join-Path $ProjectRoot "production/services/save_service.gd") -Name "SCHEMA_VERSION"
    $commit = (git -C $ProjectRoot rev-parse HEAD).Trim()
    $dirty = -not [string]::IsNullOrWhiteSpace((git -C $ProjectRoot status --porcelain | Out-String).Trim())
    $signature = Get-AuthenticodeSignature -LiteralPath $executable
    $exeHash = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLowerInvariant()
    $assetManifestPath = Join-Path $ProjectRoot "tools/asset_catalog/generated/manifest.json"
    $assetManifestHash = (Get-FileHash -LiteralPath $assetManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestPath = Join-Path $buildDirectory "release-manifest.json"
    $manifest = [ordered]@{
        schema_version = 1
        product = "Galax Hero"
        version = $version
        channel = "release"
        content_revision = $contentRevision
        protocol_version = $protocol
        save_schema_version = $saveSchema
        godot_version = $ExpectedGodotVersion
        architecture = "windows-x86_64"
        git_commit = $commit
        git_worktree_dirty = $dirty
        signature_status = $signature.Status.ToString()
        asset_manifest_sha256 = $assetManifestHash
        artifacts = @(@{ path = $definition.File; sha256 = $exeHash; bytes = (Get-Item -LiteralPath $executable).Length })
    }
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8) + "`n", [System.Text.UTF8Encoding]::new($false))
    $sbomPath = Join-Path $buildDirectory "sbom.spdx.json"
    $sbom = [ordered]@{
        spdxVersion = "SPDX-2.3"
        dataLicense = "CC0-1.0"
        SPDXID = "SPDXRef-DOCUMENT"
        name = "Galax-Hero-$version-Windows"
        documentNamespace = "https://galax-hero.invalid/spdx/$version/$commit"
        creationInfo = @{ created = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"); creators = @("Tool: tools/run_project.ps1", "Organization: Galax Hero") }
        packages = @(
            @{ name = "Galax Hero"; SPDXID = "SPDXRef-Package-GalaxHero"; versionInfo = $version; downloadLocation = "NOASSERTION"; filesAnalyzed = $true; licenseConcluded = "NOASSERTION"; licenseDeclared = "NOASSERTION"; checksums = @(@{ algorithm = "SHA256"; checksumValue = $exeHash }) },
            @{ name = "Godot Engine"; SPDXID = "SPDXRef-Package-Godot"; versionInfo = $ExpectedGodotVersion; downloadLocation = "https://github.com/godotengine/godot"; filesAnalyzed = $false; licenseConcluded = "MIT"; licenseDeclared = "MIT" }
        )
        relationships = @(@{ spdxElementId = "SPDXRef-Package-GalaxHero"; relationshipType = "DEPENDS_ON"; relatedSpdxElement = "SPDXRef-Package-Godot" })
    }
    [System.IO.File]::WriteAllText($sbomPath, ($sbom | ConvertTo-Json -Depth 10) + "`n", [System.Text.UTF8Encoding]::new($false))
    $archive = Join-Path $buildDirectory "galax-hero-$version-windows-x86_64.zip"
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    $packageFiles = @($executable, "$executable.sha256", "$executable.build.json", $manifestPath, $sbomPath, (Join-Path $ProjectRoot "LICENSE"), (Join-Path $ProjectRoot "CHANGELOG.md"), (Join-Path $ProjectRoot "THIRD_PARTY_NOTICES.md"), (Join-Path $ProjectRoot "KNOWN_ISSUES.md"), (Join-Path $ProjectRoot "docs/PLAYER_MANUAL.md"), (Join-Path $ProjectRoot "docs/TROUBLESHOOTING_AND_RECOVERY.md"), (Join-Path $ProjectRoot "docs/SUPPORT_PRIVACY_AND_DIAGNOSTICS.md"), (Join-Path $ProjectRoot "docs/RELEASE_ROLLBACK_HOTFIX_AND_LAUNCH.md"), (Join-Path $ProjectRoot "docs/PLAN_COMPLETION_AUDIT.md"), (Join-Path $ProjectRoot "tools/asset_catalog/generated/runtime_asset_report.json"), (Join-Path $ProjectRoot "tools/asset_catalog/generated/runtime_asset_credits.md"))
    Compress-Archive -LiteralPath $packageFiles -DestinationPath $archive -CompressionLevel Optimal
    $archiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$archive.sha256", "$archiveHash  $([System.IO.Path]::GetFileName($archive))`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "Release package: $archive`nsha256=$archiveHash" -ForegroundColor Green
}

function Resolve-InnoSetupCompiler {
    $command = Get-Command "iscc.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6/ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6/ISCC.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs/Inno Setup 6/ISCC.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    throw "Inno Setup 6 was not found. Install JRSoftware.InnoSetup with winget."
}

function New-WindowsInstaller {
    $releaseExecutable = Join-Path $ProjectRoot "builds/release/galax-hero-release.exe"
    if (-not (Test-Path -LiteralPath $releaseExecutable)) { throw "Export the release executable before building the installer." }
    foreach ($required in @("docs/PLAYER_MANUAL.md", "docs/TROUBLESHOOTING_AND_RECOVERY.md")) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $required))) { throw "Installer input is missing: $required" }
    }
    $version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
    $compiler = Resolve-InnoSetupCompiler
    $script = Join-Path $ProjectRoot "packaging/windows/GalaxHero.iss"
    Invoke-Checked -Label "Versioned Windows installer" -Command $compiler -Arguments @("/Qp", "/DMyAppVersion=$version", $script)
    $installer = Join-Path $ProjectRoot "builds/installer/galax-hero-$version-windows-x86_64-setup.exe"
    if (-not (Test-Path -LiteralPath $installer)) { throw "Inno Setup did not create the expected installer: $installer" }
    $signed = Invoke-CodeSigning -Executable $installer
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$installer.sha256", "$hash  $([System.IO.Path]::GetFileName($installer))`n", [System.Text.UTF8Encoding]::new($false))
    $record = [ordered]@{ schema_version = 1; product = "Galax Hero"; version = $version; artifact = [System.IO.Path]::GetFileName($installer); sha256 = $hash; signature = if ($signed) { "valid" } else { "unsigned_test_artifact" }; installer = "Inno Setup 6" }
    [System.IO.File]::WriteAllText("$installer.build.json", ($record | ConvertTo-Json -Depth 5) + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "Windows installer: $installer`nsha256=$hash" -ForegroundColor Green
}

function Test-WindowsInstaller {
    $version = (Get-Content -LiteralPath (Join-Path $ProjectRoot "VERSION") -Raw).Trim()
    $installer = Join-Path $ProjectRoot "builds/installer/galax-hero-$version-windows-x86_64-setup.exe"
    if (-not (Test-Path -LiteralPath $installer)) { throw "Build the Windows installer before running its smoke test." }
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $installDirectory = [System.IO.Path]::GetFullPath((Join-Path $tempRoot ("GalaxHeroInstallerSmoke_" + [Guid]::NewGuid().ToString("N"))))
    if (-not $installDirectory.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or [System.IO.Path]::GetFileName($installDirectory) -notlike "GalaxHeroInstallerSmoke_*") {
        throw "Refusing installer smoke outside the validated temporary directory: $installDirectory"
    }
    $installLog = Join-Path $ProjectRoot "builds/installer/install-smoke.log"
    $gameLog = Join-Path $ProjectRoot "builds/installer/installed-game-smoke.log"
    $repairLog = Join-Path $ProjectRoot "builds/installer/repair-smoke.log"
    $uninstallLog = Join-Path $ProjectRoot "builds/installer/uninstall-smoke.log"
    $reinstallLog = Join-Path $ProjectRoot "builds/installer/reinstall-smoke.log"
    $secondUninstallLog = Join-Path $ProjectRoot "builds/installer/reinstall-uninstall-smoke.log"
    $installProcess = Start-Process -FilePath $installer -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=`"$installDirectory`"", "/LOG=`"$installLog`"") -WindowStyle Hidden -Wait -PassThru
    if ($installProcess.ExitCode -ne 0) { throw "Silent installer exited with code $($installProcess.ExitCode)." }
    $installedExecutable = Join-Path $installDirectory "galax-hero-release.exe"
    if (-not (Test-Path -LiteralPath $installedExecutable)) { throw "Installed executable is missing: $installedExecutable" }
    $expectedHash = (Get-FileHash -LiteralPath (Join-Path $ProjectRoot "builds/release/galax-hero-release.exe") -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $installedExecutable -Algorithm SHA256).Hash -ne $expectedHash) { throw "Clean install executable hash does not match the packaged release." }
    $repairProcess = Start-Process -FilePath $installer -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=`"$installDirectory`"", "/LOG=`"$repairLog`"") -WindowStyle Hidden -Wait -PassThru
    if ($repairProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $installedExecutable)) { throw "Same-version repair install failed." }
    if ((Get-FileHash -LiteralPath $installedExecutable -Algorithm SHA256).Hash -ne $expectedHash) { throw "Repair install executable hash does not match the packaged release." }
    $gameProcess = Start-Process -FilePath $installedExecutable -ArgumentList @("--headless", "--log-file", "`"$gameLog`"", "--", "--export-smoke") -WindowStyle Hidden -Wait -PassThru
    $gameOutput = if (Test-Path -LiteralPath $gameLog) { @(Get-Content -LiteralPath $gameLog) } else { @() }
    if ($gameProcess.ExitCode -ne 0 -or -not ($gameOutput | Where-Object { $_ -match '^EXPORT_SMOKE: PASS' })) { throw "Installed game smoke did not pass." }
    $uninstaller = Join-Path $installDirectory "unins000.exe"
    if (-not (Test-Path -LiteralPath $uninstaller)) { throw "Uninstaller is missing from the clean install." }
    $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/LOG=`"$uninstallLog`"") -WindowStyle Hidden -Wait -PassThru
    if ($uninstallProcess.ExitCode -ne 0) { throw "Silent uninstaller exited with code $($uninstallProcess.ExitCode)." }
    if (Test-Path -LiteralPath $installedExecutable) { throw "Uninstall left the game executable behind." }
    $reinstallProcess = Start-Process -FilePath $installer -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/DIR=`"$installDirectory`"", "/LOG=`"$reinstallLog`"") -WindowStyle Hidden -Wait -PassThru
    if ($reinstallProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $installedExecutable)) { throw "Uninstall/reinstall cycle failed." }
    if ((Get-FileHash -LiteralPath $installedExecutable -Algorithm SHA256).Hash -ne $expectedHash) { throw "Reinstalled executable hash does not match the packaged release." }
    $secondUninstaller = Join-Path $installDirectory "unins000.exe"
    $secondUninstallProcess = Start-Process -FilePath $secondUninstaller -ArgumentList @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/LOG=`"$secondUninstallLog`"") -WindowStyle Hidden -Wait -PassThru
    if ($secondUninstallProcess.ExitCode -ne 0) { throw "Reinstall cleanup uninstaller exited with code $($secondUninstallProcess.ExitCode)." }
    if (Test-Path -LiteralPath $installedExecutable) { throw "Reinstall cleanup left the game executable behind." }
    if (Test-Path -LiteralPath $installDirectory) { Remove-Item -LiteralPath $installDirectory -Recurse -Force }
    Write-Host "Installer clean install, hash verification, same-version repair, exported-game smoke, uninstall, reinstall, and final uninstall passed." -ForegroundColor Green
}

Push-Location $ProjectRoot
try {
    switch ($Task) {
        "import" { Invoke-ImportValidation }
        "test" { Invoke-AllTests }
        "boot" { Invoke-BootSmoke }
        "soak" { Invoke-StageOneSoak }
        "assets" { Invoke-AssetValidation }
        "assets-source" { Invoke-AssetValidation -RequireSource }
        "artifacts" { Test-RepositoryArtifacts }
        "metadata" { Test-Metadata }
        "export-debug" { Export-Project -Kind "development" }
        "export-development" { Export-Project -Kind "development" }
        "export-qa" { Export-Project -Kind "qa" }
        "export-demo" { Export-Project -Kind "demo" }
        "export-rc" { Export-Project -Kind "rc" }
        "export-release" { Export-Project -Kind "release" }
        "export-smoke" {
            Invoke-ExportSmoke -Kind "development"
            foreach ($optionalKind in @("qa", "demo", "rc")) {
                $optionalDefinition = Get-BuildDefinition -Kind $optionalKind
                $optionalExecutable = Join-Path $ProjectRoot ("builds/$($optionalDefinition.Directory)/$($optionalDefinition.File)")
                if (Test-Path -LiteralPath $optionalExecutable) {
                    Invoke-ExportSmoke -Kind $optionalKind
                }
            }
            Invoke-ExportSmoke -Kind "release"
        }
        "rc-repro" { Test-ReleaseCandidateReproducibility }
        "package-release" { New-ReleasePackage }
        "installer" { New-WindowsInstaller }
        "installer-smoke" { Test-WindowsInstaller }
        "verify" {
            Invoke-ImportValidation
            Test-Metadata
            Test-RepositoryArtifacts
            Invoke-AssetValidation
            Invoke-AllTests
            Invoke-BootSmoke
        }
        "all" {
            Invoke-ImportValidation
            Test-Metadata
            Test-RepositoryArtifacts
            Invoke-AssetValidation
            Invoke-AllTests
            Invoke-BootSmoke
			Invoke-StageOneSoak
            Export-Project -Kind "development"
            Export-Project -Kind "release"
            Invoke-ExportSmoke -Kind "development"
            Invoke-ExportSmoke -Kind "release"
            New-ReleasePackage
            New-WindowsInstaller
            Test-WindowsInstaller
        }
    }
}
finally {
    Pop-Location
}
