class_name MovementProfile
extends Resource

@export var maximum_speed := 320.0
@export var acceleration := 1800.0
@export var deceleration := 2200.0
@export var focus_speed := 150.0
@export var regulation_direct := false
@export var boost_speed := 480.0
@export var dash_distance := 150.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.75
@export var dash_invulnerability := 0.18
@export var roll_time := 0.45
@export var roll_cooldown := 1.0
@export var roll_invulnerability := 0.3
@export var teleport_distance := 180.0
@export var teleport_cooldown := 2.0
@export var teleport_invulnerability := 0.15
@export var boundary := Rect2(28.0, 70.0, 484.0, 850.0)
@export var wrap_boundaries := false
