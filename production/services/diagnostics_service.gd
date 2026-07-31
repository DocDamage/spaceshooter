class_name DiagnosticsService
extends BaseGameService

signal warning_added(message: String)

var _session: GameSession
var _warnings := PackedStringArray()
var active_effect_count := 0
var pool_occupancy := 0
var network_diagnostics: NetworkDiagnostics

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
