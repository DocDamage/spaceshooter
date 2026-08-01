class_name ProductionPickup
extends PooledCombatObject

signal collected(drop: Dictionary, collector_id: StringName)

const PICKUP_TEXTURE := preload("res://assets_runtime/pickups/pickup_credits_01_sheet.png")
const ENERGY_TEXTURE := preload("res://assets_runtime/pickups/pickup_energy_container.png")
const HEALTH_TEXTURE := preload("res://assets_runtime/pickups/pickup_health_container.png")

var actor_id: StringName
var drop: Dictionary = {}
var players: Array[Node2D] = []
var registry: ActorRegistry
var lifetime := 10.0
var velocity := Vector2(0, 38)
var collected_once := false

func _ready() -> void:
	var collision := CollisionShape2D.new(); var shape := CircleShape2D.new(); shape.radius = 12.0; collision.shape = shape; add_child(collision)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func configure_from_pool(configuration: Dictionary) -> void:
	actor_id = configuration.get("actor_id", StringName("pickup.%d" % pool_generation))
	drop = configuration.get("drop", {}).duplicate(true)
	players.clear(); players.assign(configuration.get("players", []))
	registry = configuration.get("registry") as ActorRegistry
	lifetime = maxf(1.0, float(configuration.get("lifetime", 10.0)))
	velocity = configuration.get("initial_velocity", Vector2(0, 38))
	collected_once = false
	collision_layer = 16; collision_mask = 1

func activate_from_pool(spawn_transform := Transform2D.IDENTITY) -> bool:
	var activated := super.activate_from_pool(spawn_transform)
	if activated and registry != null: registry.register_actor(actor_id, &"pickup", self)
	return activated

func reset_pool_object() -> void:
	if registry != null and not actor_id.is_empty(): registry.unregister_actor(actor_id)
	super.reset_pool_object()
	actor_id = &""; drop.clear(); players.clear(); registry = null; lifetime = 0.0; velocity = Vector2.ZERO; collected_once = false
	collision_layer = 0; collision_mask = 0

func _physics_process(delta: float) -> void:
	if not pool_active: return
	lifetime -= delta
	var target := _nearest_authorized_player()
	if target != null and global_position.distance_to(target.global_position) <= 145.0:
		velocity = velocity.lerp(global_position.direction_to(target.global_position) * 330.0, minf(1.0, delta * 7.0))
	position += velocity * delta
	rotation += delta * 1.8
	if target != null and global_position.distance_to(target.global_position) <= 18.0: _collect(target.actor_id)
	elif lifetime <= 0.0 or position.y > 1020.0:
		_collect(target.actor_id if target != null else StringName(drop.get("owner_id", "")))

func _on_area_entered(area: Area2D) -> void:
	if area is ProductionPlayer and _authorized(area.actor_id): _collect(area.actor_id)

func _collect(collector_id: StringName) -> void:
	if collected_once or not pool_active: return
	collected_once = true
	collected.emit(drop.duplicate(true), collector_id)
	call_deferred("deactivate_to_pool")

func _nearest_authorized_player() -> ProductionPlayer:
	var best: ProductionPlayer
	var best_distance := INF
	for candidate in players:
		if candidate is ProductionPlayer and candidate.active and _authorized(candidate.actor_id):
			var distance := global_position.distance_squared_to(candidate.global_position)
			if distance < best_distance: best = candidate; best_distance = distance
	return best

func _authorized(player_id: StringName) -> bool:
	var owner := StringName(drop.get("owner_id", &"shared"))
	return owner.is_empty() or owner == &"shared" or owner == player_id or String(owner).begins_with("wingman")

func _draw() -> void:
	var tint := Color("78f5ff")
	var texture: Texture2D = PICKUP_TEXTURE
	var source := Rect2(0, 0, 16, 16)
	match StringName(drop.get("category", &"currency")):
		&"healing": tint = Color("71ff8b"); texture = HEALTH_TEXTURE; source = Rect2(Vector2.ZERO, HEALTH_TEXTURE.get_size())
		&"experience": tint = Color("c792ff"); texture = ENERGY_TEXTURE; source = Rect2(Vector2.ZERO, ENERGY_TEXTURE.get_size())
		&"temporary_weapon_power": tint = Color("ffd36d"); texture = ENERGY_TEXTURE; source = Rect2(Vector2.ZERO, ENERGY_TEXTURE.get_size())
		&"flux": tint = Color("f4ff82"); texture = ENERGY_TEXTURE; source = Rect2(Vector2.ZERO, ENERGY_TEXTURE.get_size())
	draw_circle(Vector2.ZERO, 13.0, Color(tint, 0.22))
	draw_texture_rect_region(texture, Rect2(-10, -10, 20, 20), source, tint)
