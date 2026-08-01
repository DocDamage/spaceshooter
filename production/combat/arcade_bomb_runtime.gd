class_name ArcadeBombRuntime
extends Node

signal detonated(owner_id: StringName, remaining_stock: int, converted: int)

var stock := 2
var invulnerability_seconds := 1.0
var conversion_service: BulletConversionService

func configure(converter: BulletConversionService, starting_stock := 2) -> void:
	conversion_service = converter
	stock = maxi(0, starting_stock)

func activate(owner: BaseActor2D) -> bool:
	if owner == null or stock <= 0: return false
	stock -= 1
	owner.grant_invulnerability(invulnerability_seconds)
	var converted := conversion_service.convert_active(owner.actor_id) if conversion_service != null else 0
	detonated.emit(owner.actor_id, stock, converted)
	return true

func snapshot() -> Dictionary:
	return {&"stock": stock}
