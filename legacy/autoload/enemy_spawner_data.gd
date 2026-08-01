extends Node

const MIGRATION_WAVE := [
	Vector2(90, -40), Vector2(200, -100), Vector2(340, -160),
	Vector2(450, -220), Vector2(270, -300)
]

func get_legacy_wave() -> Array[Vector2]:
	var wave: Array[Vector2] = []
	wave.assign(MIGRATION_WAVE)
	return wave
