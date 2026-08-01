extends Node

signal enemy_defeated(experience: int, credits: int)
signal player_damaged(amount: int, absorbed: int)

var kills := 0
var damage_dealt := 0

func reset_battle() -> void:
	kills = 0
	damage_dealt = 0

func register_enemy_defeat(experience: int, credits: int) -> void:
	kills += 1
	enemy_defeated.emit(experience, credits)

func register_player_damage(amount: int, absorbed: int) -> void:
	player_damaged.emit(amount, absorbed)

