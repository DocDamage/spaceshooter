param(
    [ValidateSet("import", "test", "boot", "soak", "assets", "artifacts", "metadata", "verify", "export-debug", "export-release", "all")]
    [string]$Task = "verify",
    [string]$GodotPath = ""
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
        [switch]$AllowEngineDiagnostics
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
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
    if ($null -eq $python) { throw "Python 3.10+ is required for asset validation." }
    $pipeline = Join-Path $ProjectRoot "tools/asset_catalog/asset_pipeline.py"
    Invoke-Checked -Label "Runtime asset release validation" -Command $python.Source -Arguments @($pipeline, "validate", "--release")
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
	Invoke-Checked -Label "30-minute simulated Stage 1 replay soak" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, "--script", "res://tests/phase20/phase20_stage1_soak.gd")
}

function Export-Project {
    param([Parameter(Mandatory = $true)][ValidateSet("debug", "release")][string]$Kind)
    Assert-GodotVersion
    $buildDirectory = Join-Path $ProjectRoot "builds/$Kind"
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    $preset = if ($Kind -eq "debug") { "Windows Desktop (Debug)" } else { "Windows Desktop (Release)" }
    $output = if ($Kind -eq "debug") { Join-Path $buildDirectory "galax-hero-debug.exe" } else { Join-Path $buildDirectory "galax-hero-release.exe" }
    $flag = if ($Kind -eq "debug") { "--export-debug" } else { "--export-release" }
    Invoke-Checked -Label "$preset export" -Command $Godot -Arguments @("--headless", "--path", $ProjectRoot, $flag, $preset, $output)
    if (-not (Test-Path -LiteralPath $output)) { throw "$preset did not create '$output'." }
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText("$output.sha256", "$hash  $([System.IO.Path]::GetFileName($output))`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "$output`nsha256=$hash" -ForegroundColor Green
}

Push-Location $ProjectRoot
try {
    switch ($Task) {
        "import" { Invoke-ImportValidation }
        "test" { Invoke-AllTests }
        "boot" { Invoke-BootSmoke }
		"soak" { Invoke-StageOneSoak }
        "assets" { Invoke-AssetValidation }
        "artifacts" { Test-RepositoryArtifacts }
        "metadata" { Test-Metadata }
        "export-debug" { Export-Project -Kind "debug" }
        "export-release" { Export-Project -Kind "release" }
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
            Export-Project -Kind "debug"
            Export-Project -Kind "release"
        }
    }
}
finally {
    Pop-Location
}
