class_name DiagnosticsService
extends BaseGameService

signal warning_added(message: String)

var _session: GameSession
var _warnings := PackedStringArray()
var active_effect_count := 0
var pool_occupancy := 0
var network_diagnostics: NetworkDiagnostics
var last_export_path := ""

func _init() -> void:
	service_id = &"diagnostics"

func attach_session(session: GameSession) -> void:
	_session = session

func add_warning(message: String) -> void:
	_warnings.append(message)
	warning_added.emit(message)

func attach_network(diagnostics: NetworkDiagnostics) -> void:
	network_diagnostics = diagnostics
	if diagnostics != null: diagnostics.desync_detected.connect(func(details): add_warning("Network desync at tick %d" % int(details.get("tick", 0))))

func get_snapshot() -> Dictionary:
	var counts := {}
	if is_instance_valid(_session) and _session.actor_registry != null:
		counts = _session.actor_registry.get_counts()
	var snapshot := {
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": 1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		"players": counts.get(&"player", 0),
		"wingmen": counts.get(&"wingman", 0),
		"enemies": counts.get(&"enemy", 0),
		"bosses": counts.get(&"boss", 0),
		"projectiles": counts.get(&"projectile", 0),
		"pickups": counts.get(&"pickup", 0),
		"hazards": counts.get(&"hazard", 0),
		"effects": active_effect_count,
		"pool_occupancy": pool_occupancy,
		"mission_seed": _session.stage_seed if is_instance_valid(_session) else 0,
		"segment": _session.current_segment if is_instance_valid(_session) else 0,
		"active_waves": _session.active_waves if is_instance_valid(_session) else 0,
		"difficulty": _session.difficulty_profile if is_instance_valid(_session) else &"none",
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"warnings": _warnings.duplicate()
	}
	snapshot["network"] = network_diagnostics.snapshot() if network_diagnostics != null else {}
	return snapshot

func export_privacy_safe_report(save_status: StringName = &"unknown", report_directory := "user://diagnostics") -> String:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_directory)) != OK:
		add_warning("Could not create the diagnostics export directory")
		return ""
	var runtime := get_snapshot()
	var safe_warnings := PackedStringArray()
	for warning in runtime.get("warnings", []):
		safe_warnings.append(_redact_local_paths(String(warning)))
	runtime.warnings = safe_warnings
	var report := {
		"schema_version": 1,
		"privacy": "Created only after a player action. Contains no profile name, save contents, account token, IP address, or automatic upload destination.",
		"generated_unix": int(Time.get_unix_time_from_system()),
		"build": {
			"version": ProjectSettings.get_setting("application/config/version", "dev"),
			"content_revision": ProjectSettings.get_setting("application/config/content_revision", "dev"),
			"protocol_version": NetworkProtocol.PROTOCOL_VERSION,
			"debug_build": OS.is_debug_build(),
		},
		"environment": {
			"os": OS.get_name(),
			"os_version": OS.get_version(),
			"processor_count": OS.get_processor_count(),
			"renderer": RenderingServer.get_current_rendering_method(),
		},
		"save_status": String(save_status),
		"runtime": runtime,
	}
	last_export_path = "%s/galax_hero_diagnostics_%d.json" % [report_directory, int(report.generated_unix)]
	var file := FileAccess.open(last_export_path, FileAccess.WRITE)
	if file == null:
		add_warning("Could not write the diagnostics report")
		last_export_path = ""
		return ""
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return last_export_path

func _redact_local_paths(value: String) -> String:
	var sanitized := value
	for virtual_path in ["user://", "res://"]:
		var absolute := ProjectSettings.globalize_path(virtual_path)
		if not absolute.is_empty(): sanitized = sanitized.replace(absolute, virtual_path)
	return sanitized
