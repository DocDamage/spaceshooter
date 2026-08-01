class_name BaseActor2D
extends Area2D

signal spawned(actor_id: StringName)
signal despawned(actor_id: StringName)
signal damage_resolved(packet: DamagePacket, result: DamageResult)
signal destroyed(actor_id: StringName, source_actor_id: StringName)

var actor_id: StringName
var faction: StringName = &"neutral"
var actor_category: StringName = &"hazard"
var active := false
var pooled := false
var registry: ActorRegistry
var event_bus: TypedEventBus
var health_component: HealthComponent
var shield_component: ShieldComponent
var armor_component: ArmorComponent
var status_component: StatusComponent
var hitbox_component: HitboxComponent
var hurtbox_component: HurtboxComponent
var invulnerability_time := 0.0
var _registered := false

func _init() -> void:
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	add_child(health_component)
	shield_component = ShieldComponent.new()
	shield_component.name = "ShieldComponent"
	add_child(shield_component)
	armor_component = ArmorComponent.new()
	armor_component.name = "ArmorComponent"
	add_child(armor_component)
	status_component = StatusComponent.new()
	status_component.name = "StatusComponent"
	status_component.periodic_damage_requested.connect(_on_periodic_damage_requested)
	add_child(status_component)
	hitbox_component = HitboxComponent.new()
	hitbox_component.name = "HitboxComponent"
	add_child(hitbox_component)
	hurtbox_component = HurtboxComponent.new()
	hurtbox_component.name = "HurtboxComponent"
	add_child(hurtbox_component)

func configure_actor(id: StringName, category: StringName, actor_faction: StringName, session_registry: ActorRegistry, session_events: TypedEventBus, use_pool := false) -> void:
	actor_id = id
	actor_category = category
	faction = actor_faction
	registry = session_registry
	event_bus = session_events
	pooled = use_pool

func _ready() -> void:
	spawn_actor()

func _physics_process(delta: float) -> void:
	if not active:
		return
	invulnerability_time = maxf(0.0, invulnerability_time - delta)
	status_component.tick(delta)
	var generator_multiplier := 0.5 if armor_component.get_condition(&"shield_generator") < 0.5 else 1.0
	shield_component.tick(delta, generator_multiplier * status_component.shield_recharge_multiplier())
	if status_component.has(&"regeneration"):
		health_component.heal(status_component.strength(&"regeneration") * delta)

func spawn_actor() -> bool:
	if actor_id.is_empty() or registry == null:
		return false
	if not _registered:
		_registered = registry.register_actor(actor_id, actor_category, self)
	if not _registered:
		return false
	active = true
	visible = true
	monitoring = true
	process_mode = Node.PROCESS_MODE_INHERIT
	health_component.reset()
	shield_component.reset()
	status_component.clear()
	spawned.emit(actor_id)
	return true

func despawn_actor() -> void:
	if not active and not _registered:
		return
	active = false
	# Destruction is commonly reached from Area2D overlap signals. Collision state
	# must change after the physics query flush to avoid unsafe callback mutation.
	if is_inside_tree(): set_deferred("monitoring", false)
	else: monitoring = false
	if _registered and registry != null:
		registry.unregister_actor(actor_id)
	_registered = false
	despawned.emit(actor_id)
	if pooled:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		queue_free()

func receive_damage(packet: DamagePacket) -> DamageResult:
	return DamageResolver.resolve(self, packet)

func take_damage(amount: int, source_id: StringName) -> void:
	receive_damage(DamagePacket.new(amount, source_id))

func is_damageable() -> bool:
	return active and hurtbox_component.enabled and not health_component.is_depleted()

func is_invulnerable() -> bool:
	return invulnerability_time > 0.0 or status_component.has(&"invulnerable")

func grant_invulnerability(seconds: float) -> void:
	invulnerability_time = maxf(invulnerability_time, maxf(0.0, seconds))

func _on_periodic_damage_requested(source_actor_id: StringName, amount: float) -> void:
	if active and amount > 0.0:
		var packet := DamagePacket.new(amount, source_actor_id)
		packet.source_ability_id = &"status.burn"
		packet.damage_type = DamagePacket.DamageType.FIRE
		receive_damage(packet)

func on_damage_resolved(packet: DamagePacket, result: DamageResult) -> void:
	damage_resolved.emit(packet, result)
	if event_bus != null and result.health_damage + result.shield_damage > 0.0:
		event_bus.publish(ActorDamagedEvent.new(packet.source_actor_id, actor_id, result.health_damage, result.shield_damage, packet.damage_type, packet.network_sequence_id))

func destroy_actor(source_actor_id: StringName) -> void:
	if not active:
		return
	active = false
	destroyed.emit(actor_id, source_actor_id)
	if event_bus != null:
		event_bus.publish(ActorDestroyedEvent.new(source_actor_id, actor_id))
	despawn_actor()
