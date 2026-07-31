class_name HurtboxComponent
extends Node

var enabled := true
var radius := 0.0
var damage_multiplier := 1.0

func configure(hurt_radius: float, multiplier := 1.0) -> void:
	radius = maxf(0.0, hurt_radius)
	damage_multiplier = maxf(0.0, multiplier)
