class_name GrazeComponent
extends Node

signal grazed(projectile_id: StringName, player_id: StringName, value: int)

var owner_player: ProductionPlayer
var score_tracker: MissionScoreTracker
var graze_area: Area2D

func configure(player: ProductionPlayer, tracker: MissionScoreTracker) -> void:
	owner_player = player
	score_tracker = tracker
	graze_area = player.graze_area if player != null else null
	if graze_area == null: return
	graze_area.monitoring = true
	graze_area.area_entered.connect(_on_area_entered)
	graze_area.area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if owner_player == null or not owner_player.active or not area is ProductionProjectile: return
	var projectile := area as ProductionProjectile
	if projectile.try_graze(owner_player.actor_id):
		var value := projectile.graze_value()
		if score_tracker != null: score_tracker.record_graze(owner_player.actor_id, value)
		grazed.emit(projectile.actor_id, owner_player.actor_id, value)

func _on_area_exited(area: Area2D) -> void:
	if owner_player != null and area is ProductionProjectile:
		(area as ProductionProjectile).clear_graze_player(owner_player.actor_id)
