class_name VerticalSliceMetrics
extends RefCounted

const TARGETS := {"minimum_average_fps": 60.0, "maximum_worst_frame_ms": 16.8, "maximum_projectiles": 2000, "maximum_enemies": 150, "maximum_effects": 200, "maximum_generation_ms": 100.0, "maximum_checkpoint_save_ms": 100.0, "maximum_results_save_ms": 250.0}

var samples := {"frame_count": 0, "elapsed_seconds": 0.0, "worst_frame_ms": 0.0, "projectile_peak": 0, "enemy_peak": 0, "effect_peak": 0, "memory_before": 0, "memory_after": 0, "generation_ms": 0.0, "checkpoint_save_ms": 0.0, "results_save_ms": 0.0}

func sample_frame(delta: float, projectiles: int, enemies: int, effects: int) -> void:
	samples.frame_count += 1
	samples.elapsed_seconds += maxf(0.0, delta)
	samples.worst_frame_ms = maxf(float(samples.worst_frame_ms), delta * 1000.0)
	samples.projectile_peak = maxi(int(samples.projectile_peak), projectiles)
	samples.enemy_peak = maxi(int(samples.enemy_peak), enemies)
	samples.effect_peak = maxi(int(samples.effect_peak), effects)

func average_fps() -> float:
	return float(samples.frame_count) / float(samples.elapsed_seconds) if float(samples.elapsed_seconds) > 0.0 else 0.0

func report() -> Dictionary:
	var result := samples.duplicate(true)
	result.average_fps = average_fps()
	result.memory_delta = int(samples.memory_after) - int(samples.memory_before)
	result.targets = TARGETS.duplicate(true)
	result.target_met = (result.average_fps >= TARGETS.minimum_average_fps or is_equal_approx(result.average_fps, TARGETS.minimum_average_fps)) and float(result.worst_frame_ms) <= TARGETS.maximum_worst_frame_ms and int(result.projectile_peak) <= TARGETS.maximum_projectiles and int(result.enemy_peak) <= TARGETS.maximum_enemies and int(result.effect_peak) <= TARGETS.maximum_effects and float(result.generation_ms) <= TARGETS.maximum_generation_ms and float(result.checkpoint_save_ms) <= TARGETS.maximum_checkpoint_save_ms and float(result.results_save_ms) <= TARGETS.maximum_results_save_ms
	return result
