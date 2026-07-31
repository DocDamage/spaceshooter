class_name GeneratedMission
extends Node2D

var session: GameSession
var database: ContentDatabase
var stage_runtime: StageRuntime
var projectile_pool: ProjectilePoolManager
var projectile_sequence := 0
var camera_rig: PresentationCameraRig
var effects_pool: EffectsPoolManager
var screen_effects: ScreenEffectsController
var player_actors: Array[Node2D] = []
var active_boss: BossActor
var active_boss_arena: BossArenaController
var cooperative_hud: CooperativeHUD
var story_layer: CanvasLayer
var radio_presenter: RadioPresenter

func configure(game_session: GameSession, content_database: ContentDatabase) -> void:
	session = game_session
	database = content_database

func _ready() -> void:
	if session == null or database == null or session.config.mission_definition.recipe == null:
		push_error("GeneratedMission requires a configured Phase 10 mission")
		return
	projectile_pool = ProjectilePoolManager.new()
	projectile_pool.name = "ProjectilePoolManager"
	add_child(projectile_pool)
	projectile_pool.prewarm(&"player_bullet", 96)
	effects_pool = EffectsPoolManager.new(); effects_pool.name = "EffectsPoolManager"; add_child(effects_pool)
	screen_effects = ScreenEffectsController.new(); screen_effects.name = "ScreenEffects"; screen_effects.configure(session.services.settings); add_child(screen_effects)
	_spawn_players()
	if session.local_coop != null:
		cooperative_hud = CooperativeHUD.new(); cooperative_hud.name = "CooperativeHUD"; cooperative_hud.configure(session.local_coop); add_child(cooperative_hud)
	story_layer = CanvasLayer.new(); story_layer.layer = 35; add_child(story_layer)
	radio_presenter = RadioPresenter.new(); radio_presenter.name = "CampaignRadio"; radio_presenter.bind(session.services.story.radio_queue); story_layer.add_child(radio_presenter)
	var briefing_id := StringName(session.config.mission_definition.dialogue_hooks.get("briefing", ""))
	if not briefing_id.is_empty(): session.services.story.start_dialogue(briefing_id, {"stage": session.config.mission_definition.stage_number})
	camera_rig = PresentationCameraRig.new(); camera_rig.name = "PresentationCameraRig"; camera_rig.configure(session.services.settings); camera_rig.set_targets(player_actors); camera_rig.enabled = true; add_child(camera_rig)
	var plan := StageGraphGenerator.new().generate(session.config.mission_definition, session.stage_seed, 50)
	stage_runtime = StageRuntime.new()
	stage_runtime.name = "StageRuntime"
	if plan == null or not stage_runtime.configure(session, database, plan):
		push_error("Generated stage failed validation")
		return
	stage_runtime.enemy_spawn_requested.connect(_spawn_enemy)
	stage_runtime.segment_changed.connect(_on_segment_changed)
	stage_runtime.stage_completed.connect(func(): session.complete_session(true))
	add_child(stage_runtime)
	queue_redraw()

func _spawn_players() -> void:
	var online := session.online_coop != null
	var spawn_count := session.config.effective_player_count()
	var local_online_index := int(session.config.multiplayer_configuration.get("local_peer_id", 1)) - 1
	for player_index in spawn_count:
		var ship_id := session.config.selected_ships[mini(player_index, session.config.selected_ships.size() - 1)]
		var ship := database.get_definition(ship_id, &"ship") as ShipDefinition
		var weapon := database.get_definition(ship.default_weapon_id, &"weapon") as WeaponDefinition
		var player := ProductionPlayer.new()
		var actor_id := StringName("player.online_%d" % (player_index + 1)) if online else StringName("player.local_%d" % (player_index + 1))
		var input_index := 0 if online else player_index
		player.configure(actor_id, input_index, ship, weapon, session.actor_registry, session.event_bus, session.services.input)
		player.position = Vector2(270.0 + (float(player_index) - 0.5) * 60.0, 820.0)
		if session.local_coop != null:
			var participant: Dictionary = session.local_coop.roster.participants[player_index]
			player.actor_id = StringName(participant.actor_id)
			player.player_color = participant.color
		add_child(player)
		player_actors.append(player)
		if online:
			session.online_coop.register_player(player_index + 1, player.position, ship.move_speed)
			if player_index != local_online_index: player.set_physics_process(false)
		if session.local_coop != null: session.local_coop.attach_actor(StringName(session.local_coop.roster.participants[player_index].slot_id), player)
		player.configure_combat(projectile_pool, [weapon])
		if session.local_coop != null:
			var profile_id := StringName(session.local_coop.roster.participants[player_index].profile_id)
			if not bool(session.local_coop.roster.participants[player_index].guest): player.apply_progression(session.services.profiles.get_progression_profile(profile_id, false))

func _physics_process(_delta: float) -> void:
	if session == null or session.online_coop == null: return
	var local_index := int(session.config.multiplayer_configuration.get("local_peer_id", 1)) - 1
	for index in player_actors.size():
		var actor := player_actors[index]
		var actor_id := StringName("player.online_%d" % (index + 1))
		if index == local_index and session.online_coop.is_host and session.online_coop.world_state.actors.has(actor_id):
			session.online_coop.world_state.actors[actor_id].position = actor.position
		elif index != local_index and session.online_coop.world_state.actors.has(actor_id):
			actor.position = session.online_coop.world_state.actors[actor_id].get("position", actor.position)

func _spawn_enemy(enemy_id: StringName, spawn_position: Vector2, _formation: FormationRuntime, slot: int) -> void:
	var definition := database.get_definition(enemy_id, &"enemy") as EnemyDefinition
	if definition == null:
		session.services.diagnostics.add_warning("Generated wave references missing enemy %s" % enemy_id)
		if stage_runtime.current_segment != null: stage_runtime.current_segment.wave_scheduler.notify_enemy_finished()
		return
	var enemy := ProductionEnemy.new()
	enemy.configure(StringName("enemy.segment_%d.%d.%d" % [session.current_segment, slot, Time.get_ticks_usec()]), definition, session.actor_registry, session.event_bus)
	enemy.position = spawn_position
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)

func _on_enemy_defeated(_actor_id: StringName, credits: int) -> void:
	session.reward_state.credits = int(session.reward_state.get("credits", 0)) + credits
	if stage_runtime.current_segment != null:
		stage_runtime.current_segment.wave_scheduler.notify_enemy_finished()
		for objective in stage_runtime.current_segment.definition.objectives:
			if objective.objective_type == "destroy_marked": stage_runtime.objectives.progress(objective.stable_id)

func _on_segment_changed(_node_id: StringName, _segment_id: StringName) -> void:
	if stage_runtime.current_segment == null: return
	var category := StringName(stage_runtime.current_segment.definition.category)
	if category not in [&"miniboss", &"boss"]: return
	var boss_id := session.config.mission_definition.miniboss_id if category == &"miniboss" else session.config.mission_definition.boss_id
	_spawn_boss(boss_id, category)

func _spawn_boss(boss_id: StringName, category: StringName) -> void:
	var definition := database.get_definition(boss_id, &"boss") as BossDefinition
	if definition == null or stage_runtime.current_segment == null: return
	var gate_id := StringName("encounter.%s" % category)
	if not stage_runtime.current_segment.acquire_external_gate(gate_id): return
	active_boss_arena = BossArenaController.new(); active_boss_arena.name = "BossArena"; active_boss_arena.configure(definition.arena_profile, player_actors.size()); add_child(active_boss_arena)
	active_boss = BossActor.new(); active_boss.name = "Boss_%s" % definition.stable_id; active_boss.configure_boss(definition, session.actor_registry, session.event_bus, active_boss_arena, null, session.services.profiles.get_progression_profile().new_game_plus_cycle)
	if session.local_coop != null: active_boss.health_component.maximum *= float(session.local_coop.difficulty_profile().boss_health_multiplier); active_boss.health_component.current = active_boss.health_component.maximum
	elif session.online_coop != null: active_boss.health_component.maximum *= float(CoopDifficultyScaler.profile(2).boss_health_multiplier); active_boss.health_component.current = active_boss.health_component.maximum
	active_boss.position = Vector2(270, 220); active_boss.configure_combat_context(player_actors[0] if not player_actors.is_empty() else null, projectile_pool, database.get_definition(&"difficulty.normal", &"difficulty") as DifficultyProfileDefinition)
	active_boss.summon_requested.connect(func(enemy_id, summon_index): _spawn_enemy(enemy_id, Vector2(180 + summon_index * 60, 260), null, summon_index))
	active_boss.rewards_ready.connect(func(rewards, _challenges):
		session.reward_state.credits = int(session.reward_state.get("credits", 0)) + int(rewards.get("credits", 0))
		if rewards.has("equipment_id"): session.reward_state.items.append(rewards.equipment_id)
		if stage_runtime.current_segment != null: stage_runtime.current_segment.release_external_gate(gate_id))
	add_child(active_boss)
	if camera_rig != null: camera_rig.frame_boss(active_boss, player_actors)

func _draw() -> void:
	var operation := int(session.config.mode_rules.get("operation", 1)) if session != null and session.config != null else 1
	var palette := [Color("071328"), Color("071328"), Color("071d36"), Color("1b0d32"), Color("33170c"), Color("300914"), Color("29240a")]
	var background: Color = palette[clampi(operation, 0, palette.size() - 1)]
	draw_rect(Rect2(0, 0, 540, 960), background)
	for index in 90:
		var star := Vector2(float((index * 97) % 532 + 4), float((index * 173) % 940 + 10))
		var star_color: Color = [Color("9dd8ff"), Color("9dd8ff"), Color("8edcff"), Color("d4a6ff"), Color("ffc18c"), Color("ff8fa3"), Color("fff38a")][clampi(operation, 0, 6)]
		draw_circle(star, 1.0 + float(index % 3) * 0.45, Color(star_color, 0.6))
	if operation >= 3:
		for index in range(operation - 2):
			draw_arc(Vector2(90 + index * 105, 250 + (index % 2) * 260), 70.0 + index * 12.0, 0.0, TAU, 48, Color(0.7, 0.45, 1.0, 0.16), 3.0)
