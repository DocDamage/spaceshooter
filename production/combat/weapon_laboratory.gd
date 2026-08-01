class_name WeaponLaboratory
extends Node2D

var pool_manager: ProjectilePoolManager
var registry: ActorRegistry
var event_bus: TypedEventBus
var test_actor: BaseActor2D
var weapon_runtime: WeaponRuntime
var status_label: Label

func _ready() -> void:
	registry = ActorRegistry.new()
	add_child(registry)
	event_bus = TypedEventBus.new()
	pool_manager = ProjectilePoolManager.new()
	pool_manager.position = Vector2.ZERO
	add_child(pool_manager)
	for category in ProjectilePoolManager.CATEGORIES:
		pool_manager.prewarm(category, 16)
	test_actor = BaseActor2D.new()
	test_actor.configure_actor(&"player.weapon_lab", &"player", &"players", registry, event_bus)
	test_actor.position = Vector2(270, 780)
	add_child(test_actor)
	weapon_runtime = WeaponRuntime.new()
	add_child(weapon_runtime)
	weapon_runtime.configure(test_actor, pool_manager, registry, event_bus)
	var weapons: Array[WeaponDefinition] = []
	for path in _weapon_paths():
		var weapon := load(path) as WeaponDefinition
		if weapon != null:
			weapons.append(weapon)
	weapon_runtime.equip(weapons)
	status_label = Label.new()
	status_label.position = Vector2(16, 16)
	status_label.add_theme_font_size_override("font_size", 18)
	add_child(status_label)
	queue_redraw()

func _process(delta: float) -> void:
	weapon_runtime.set_trigger(Input.is_action_pressed(&"primary_fire"), Vector2.UP)
	weapon_runtime.tick(delta)
	if Input.is_action_just_pressed(&"next_weapon"):
		weapon_runtime.cycle(1)
	if Input.is_action_just_pressed(&"previous_weapon"):
		weapon_runtime.cycle(-1)
	var weapon := weapon_runtime.current_weapon()
	status_label.text = "PHASE 6 WEAPON LAB\nWeapon: %s\nActive / pooled: %d / %d\nFire: primary_fire  Switch: [ / ]" % [weapon.display_name if weapon else "None", pool_manager.get_active_count(), _total_pooled()]

func _total_pooled() -> int:
	var total := 0
	for category in ProjectilePoolManager.CATEGORIES:
		total += pool_manager.get_total_count(category)
	return total

func _weapon_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://production/content/data/weapon/pulse_cannon.tres", "res://production/content/data/weapon/spread_cannon.tres",
		"res://production/content/data/weapon/beam_weapon.tres", "res://production/content/data/weapon/missile_launcher.tres",
		"res://production/content/data/weapon/mine_layer.tres", "res://production/content/data/weapon/rail_weapon.tres",
		"res://production/content/data/weapon/drone_launcher.tres", "res://production/content/data/weapon/scatter_weapon.tres",
		"res://production/content/data/weapon/homing_laser.tres", "res://production/content/data/weapon/chain_lightning.tres"])

func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("071328"))
	draw_line(Vector2(20, 700), Vector2(520, 700), Color("405070"), 2.0)
