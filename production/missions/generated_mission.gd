class_name GeneratedMission
extends Node2D

const STAGE_ONE_MUSIC := preload("res://assets_runtime/audio/music_stage1_frontier_theme.mp3")
const SFX_PLAYER_SHOT := preload("res://assets_runtime/audio/sfx_shot_player.wav")
const SFX_ENEMY_SHOT := preload("res://assets_runtime/audio/sfx_shot_enemy.wav")
const SFX_HIT := preload("res://assets_runtime/audio/sfx_hit_primary.wav")
const SFX_EXPLOSION := preload("res://assets_runtime/audio/sfx_explosion_primary.wav")
const EXPLOSION_SHEET := preload("res://assets_runtime/effects/effect_explosion_small_01_sheet.png")

var session: GameSession
var database: ContentDatabase
var stage_runtime: StageRuntime
var projectile_pool: ProjectilePoolManager
var enemy_pool: EnemyPoolManager
var projectile_sequence := 0
var enemy_sequence := 0
var pickup_sequence := 0
var difficulty_definition: DifficultyProfileDefinition
var camera_rig: PresentationCameraRig
var effects_pool: EffectsPoolManager
var screen_effects: ScreenEffectsController
var player_actors: Array[Node2D] = []
var wingman_actors: Array[WingmanRuntime] = []
var active_boss: BossActor
var active_boss_arena: BossArenaController
var cooperative_hud: CooperativeHUD
var story_layer: CanvasLayer
var radio_presenter: RadioPresenter
var briefing_presenter: BriefingPresenter
var score_tracker: MissionScoreTracker
var mission_hud: MissionHUD
var mission_backdrop: MissionBackdrop
var _finished_enemy_ids: Dictionary = {}
var _retarget_elapsed := 0.0
var _mode_lives_remaining := 0
var _mode_continues_used := 0
var _stage_music: AudioStream

func configure(game_session: GameSession, content_database: ContentDatabase) -> void:
	session = game_session
	database = content_database

func _ready() -> void:
	if session == null or database == null or session.config.mission_definition.recipe == null:
		push_error("GeneratedMission requires a configured Phase 10 mission")
		return
	_mode_lives_remaining = int(session.config.mode_rules.get("starting_lives", 0))
	projectile_pool = ProjectilePoolManager.new()
	projectile_pool.name = "ProjectilePoolManager"
	add_child(projectile_pool)
	projectile_pool.register_factory(&"pickup", _create_pickup)
	projectile_pool.prewarm(&"player_bullet", 96)
	projectile_pool.prewarm(&"enemy_bullet", 160)
	projectile_pool.prewarm(&"missile", 48)
	projectile_pool.prewarm(&"mine", 32)
	projectile_pool.prewarm(&"pickup", 32)
	projectile_pool.prewarm(&"impact", 48)
	projectile_pool.prewarm(&"explosion", 24)
	enemy_pool = EnemyPoolManager.new()
	enemy_pool.name = "EnemyPoolManager"
	add_child(enemy_pool)
	enemy_pool.prewarm(48)
	enemy_pool.enemy_defeated.connect(_on_pooled_enemy_defeated)
	enemy_pool.enemy_rewards.connect(_on_pooled_enemy_rewards)
	enemy_pool.enemy_escaped.connect(_on_pooled_enemy_escaped)
	enemy_pool.enemy_fired.connect(_on_pooled_enemy_fired)
	enemy_pool.enemy_damaged.connect(_on_pooled_enemy_damaged)
	difficulty_definition = database.get_definition(session.difficulty_profile, &"difficulty_profile") as DifficultyProfileDefinition
	if difficulty_definition == null: difficulty_definition = database.get_definition(StringName("difficulty.%s" % session.difficulty_profile), &"difficulty_profile") as DifficultyProfileDefinition
	if difficulty_definition != null and float(session.config.mode_rules.get("projectile_speed_multiplier", 1.0)) != 1.0:
		difficulty_definition = difficulty_definition.duplicate(true) as DifficultyProfileDefinition
		difficulty_definition.projectile_speed_multiplier *= float(session.config.mode_rules.projectile_speed_multiplier)
	effects_pool = EffectsPoolManager.new(); effects_pool.name = "EffectsPoolManager"; add_child(effects_pool)
	screen_effects = ScreenEffectsController.new(); screen_effects.name = "ScreenEffects"; screen_effects.configure(session.services.settings); add_child(screen_effects)
	var mission_definition := session.config.mission_definition
	var operation_index := clampi(int(ceil(float(mission_definition.stage_number) / 10.0)), 1, 6)
	var background_path := mission_definition.background_asset_path
	if background_path.is_empty() and operation_index == 1: background_path = "res://assets_runtime/backgrounds/background_frontier_planets_final.png"
	mission_backdrop = MissionBackdrop.new()
	mission_backdrop.name = "MissionBackdrop"
	mission_backdrop.configure(background_path, operation_index, session.services.settings)
	add_child(mission_backdrop)
	_stage_music = STAGE_ONE_MUSIC
	if not mission_definition.music_asset_path.is_empty() and ResourceLoader.exists(mission_definition.music_asset_path):
		_stage_music = load(mission_definition.music_asset_path) as AudioStream
	var music_state := mission_definition.music_state if not mission_definition.music_state.is_empty() else StringName("operation_%d_stage" % operation_index)
	session.services.audio.transition_music(_stage_music, music_state, session.services.audio.music_crossfade_seconds, true)
	_spawn_players()
	_spawn_selected_wingman()
	score_tracker = MissionScoreTracker.new(); score_tracker.name = "MissionScoreTracker"; add_child(score_tracker)
	score_tracker.score_changed.connect(_on_score_changed)
	if session.mission_state.has("score_snapshot"): score_tracker.restore(session.mission_state.score_snapshot)
	if session.local_coop != null:
		cooperative_hud = CooperativeHUD.new(); cooperative_hud.name = "CooperativeHUD"; cooperative_hud.configure(session.local_coop); add_child(cooperative_hud)
		session.local_coop.team_defeated.connect(func(): session.complete_session(false, &"team_defeated"))
	story_layer = CanvasLayer.new(); story_layer.layer = 35; add_child(story_layer)
	radio_presenter = RadioPresenter.new(); radio_presenter.name = "CampaignRadio"; radio_presenter.bind(session.services.story.radio_queue); story_layer.add_child(radio_presenter)
	briefing_presenter = BriefingPresenter.new(); briefing_presenter.name = "MissionBriefing"; briefing_presenter.bind(session.services.story.adapter); story_layer.add_child(briefing_presenter)
	if not session.services.story.gameplay_pause_requested.is_connected(_on_story_pause_requested): session.services.story.gameplay_pause_requested.connect(_on_story_pause_requested)
	var briefing_id := StringName(session.config.mission_definition.dialogue_hooks.get("briefing", ""))
	var entry_id := StringName(session.config.mission_definition.dialogue_hooks.get("stage_entry", ""))
	if not briefing_id.is_empty() and session.services.story.start_dialogue(briefing_id, {"stage": session.config.mission_definition.stage_number}):
		if not entry_id.is_empty():
			session.services.story.adapter.dialogue_finished.connect(func(finished_id: StringName):
				if finished_id == briefing_id: session.services.story.start_dialogue(entry_id, {"stage": session.config.mission_definition.stage_number}), CONNECT_ONE_SHOT)
	elif not entry_id.is_empty():
		session.services.story.start_dialogue(entry_id, {"stage": session.config.mission_definition.stage_number})
	camera_rig = PresentationCameraRig.new(); camera_rig.name = "PresentationCameraRig"; camera_rig.configure(session.services.settings); camera_rig.set_targets(player_actors); camera_rig.enabled = true; add_child(camera_rig)
	var plan := StageGraphGenerator.new().generate(session.config.mission_definition, session.stage_seed, int(session.config.mode_rules.get("difficulty_rating", difficulty_definition.rating if difficulty_definition != null else 50)))
	if plan != null: plan = ModeStagePlanAdapter.adapt(plan, StringName(session.config.mode_rules.get("mode_id", "")))
	stage_runtime = StageRuntime.new()
	stage_runtime.name = "StageRuntime"
	var runtime_context := {"projectile_pool": projectile_pool, "enemy_pool": enemy_pool, "players": player_actors, "difficulty": difficulty_definition, "registry": session.actor_registry, "event_bus": session.event_bus, "stage_seed": session.stage_seed, "score_tracker": score_tracker, "session": session}
	if plan == null or not stage_runtime.configure(session, database, plan, runtime_context):
		push_error("Generated stage failed validation")
		return
	stage_runtime.enemy_spawn_requested.connect(_spawn_enemy)
	stage_runtime.segment_changed.connect(_on_segment_changed)
	stage_runtime.segment_cleared.connect(func(_segment_id): score_tracker.record_segment())
	stage_runtime.objective_resolved.connect(_on_objective_resolved)
	stage_runtime.stage_completed.connect(_on_stage_completed)
	mission_hud = MissionHUD.new(); mission_hud.name = "MissionHUD"; mission_hud.configure(session, player_actors, score_tracker); add_child(mission_hud); mission_hud.bind_stage(stage_runtime)
	add_child(stage_runtime)
	if not session.checkpoint_snapshot.is_empty(): stage_runtime.call_deferred("restore_from_checkpoint", session.checkpoint_snapshot)

func _spawn_players() -> void:
	var online := session.online_coop != null
	var spawn_count := session.config.effective_player_count()
	var local_online_index := int(session.config.multiplayer_configuration.get("local_peer_id", 1)) - 1
	for player_index in spawn_count:
		var ship_id := session.config.selected_ships[mini(player_index, session.config.selected_ships.size() - 1)]
		var ship := database.get_definition(ship_id, &"ship") as ShipDefinition
		var loadout: Dictionary = session.config.loadouts[player_index] if player_index < session.config.loadouts.size() else {}
		var primary := _weapon_from_loadout(loadout, [&"weapon_id", &"primary"], ship.default_weapon_id)
		var secondary := _weapon_from_loadout(loadout, [&"secondary_id", &"secondary"], &"weapon.spread_cannon")
		var heavy := _weapon_from_loadout(loadout, [&"heavy_id", &"heavy_weapon", &"heavy"], &"weapon.missile_launcher")
		var spell := database.get_definition(_id_from_loadout(loadout, [&"spell_id", &"spell"], &"spell.aegis"), &"spell") as SpellDefinition
		if bool(session.config.mode_rules.get("limited_spells", false)): spell = null
		var melee := database.get_definition(_id_from_loadout(loadout, [&"melee_id", &"melee"], &"melee.energy_blade"), &"melee") as MeleeDefinition
		var super_mode := database.get_definition(_id_from_loadout(loadout, [&"super_id", &"super"], &"super.overdrive"), &"super_mode") as SuperModeDefinition
		var player := ProductionPlayer.new()
		var actor_id := StringName("player.online_%d" % (player_index + 1)) if online else StringName("player.local_%d" % (player_index + 1))
		var input_index := 0 if online else player_index
		player.configure(actor_id, input_index, ship, primary, session.actor_registry, session.event_bus, session.services.input)
		if not bool(session.config.mode_rules.get("campaign", true)): player.pooled = true
		player.position = Vector2(270.0 + (float(player_index) - 0.5) * 60.0, 820.0)
		if session.local_coop != null:
			var participant: Dictionary = session.local_coop.roster.participants[player_index]
			player.actor_id = StringName(participant.actor_id)
			player.player_color = participant.color
		add_child(player)
		player_actors.append(player)
		player.damage_resolved.connect(_on_player_damaged)
		player.destroyed.connect(_on_player_destroyed.bind(player))
		if online:
			session.online_coop.register_player(player_index + 1, player.position, ship.move_speed)
			if player_index != local_online_index: player.set_physics_process(false)
		if session.local_coop != null: session.local_coop.attach_actor(StringName(session.local_coop.roster.participants[player_index].slot_id), player)
		var weapons: Array[WeaponDefinition] = []
		for weapon in [primary, secondary, heavy]:
			if weapon != null: weapons.append(weapon)
		var spells: Array[SpellDefinition] = []
		if spell != null: spells.append(spell)
		player.configure_combat(projectile_pool, weapons, spells, melee, super_mode)
		player.weapon_runtime.fired.connect(func(_weapon_id: StringName, projectile_count: int):
			if projectile_count > 0: session.services.audio.play(SFX_PLAYER_SHOT, &"Weapons", 2, 0.045, player.global_position))
		var profile_id := session.config.selected_profiles[mini(player_index, session.config.selected_profiles.size() - 1)]
		var guest := false
		if session.local_coop != null:
			profile_id = StringName(session.local_coop.roster.participants[player_index].profile_id)
			guest = bool(session.local_coop.roster.participants[player_index].guest)
		if not guest:
			var profile := session.services.profiles.get_progression_profile(profile_id, false)
			if profile != null: player.apply_progression(profile, _equipment_modifiers(profile), _skill_modifiers(profile), [], [], session.config.mode_rules.get("player_stat_modifiers", {}))
		var restored_power_stacks := int(session.temporary_upgrade_state.get("weapon_power_stacks", 0))
		if restored_power_stacks > 0: player.grant_temporary_drop(&"temporary_weapon_power", restored_power_stacks)
		if StringName(session.config.mode_rules.get("mode_id", "")) == &"training":
			var training: Dictionary = session.config.mode_rules.get("training_options", {})
			if bool(training.get(&"invulnerability", false)): player.grant_invulnerability(INF)
			if bool(training.get(&"infinite_resources", false)) and player.weapon_runtime != null: player.weapon_runtime.energy_recharge = 9999.0

func _id_from_loadout(loadout: Dictionary, keys: Array, fallback: StringName) -> StringName:
	for key in keys:
		var candidate := StringName(loadout.get(key, ""))
		if not candidate.is_empty() and database.has_id(candidate): return candidate
	return fallback

func _spawn_selected_wingman() -> void:
	if session.config.effective_player_count() != 1 or player_actors.is_empty(): return
	var loadout: Dictionary = session.config.loadouts[0] if not session.config.loadouts.is_empty() else {}
	var profile := session.services.profiles.get_progression_profile(session.config.selected_profiles[0], false)
	var wingman_id := StringName(loadout.get("wingman", loadout.get("wingman_id", "")))
	if wingman_id.is_empty() and profile != null and profile.unlocked_content.has(&"wingman.rook"): wingman_id = &"wingman.rook"
	var definition := database.get_definition(wingman_id, &"wingman") as WingmanDefinition
	if definition == null: return
	var ship := database.get_definition(definition.ship_id, &"ship") as ShipDefinition
	var weapon := database.get_definition(definition.basic_attack_id, &"weapon") as WeaponDefinition
	if ship == null or weapon == null: return
	var slot := ActorSlot.new().configure(&"wingman.slot.1", ship.stable_id, &"ai")
	var wingman := WingmanRuntime.new(); wingman.name = "Wingman_%s" % definition.stable_id
	if not wingman.configure_wingman(definition, slot, session.actor_registry, session.event_bus): return
	wingman.position = player_actors[0].position + Vector2(90, 50)
	wingman.configure_combat_context(player_actors[0] as ProductionPlayer, ship, weapon, projectile_pool)
	add_child(wingman); wingman_actors.append(wingman)

func _weapon_from_loadout(loadout: Dictionary, keys: Array, fallback: StringName) -> WeaponDefinition:
	return database.get_definition(_id_from_loadout(loadout, keys, fallback), &"weapon") as WeaponDefinition

func _equipment_modifiers(profile: ProgressionProfile) -> Array[Dictionary]:
	var definitions: Array[EquipmentDefinition] = []
	for content in database.get_definitions_by_type(&"equipment"):
		if content is EquipmentDefinition: definitions.append(content)
	return InventoryManager.new(profile, definitions).equipped_modifiers()

func _skill_modifiers(profile: ProgressionProfile) -> Array[Dictionary]:
	var definitions: Array[SkillNodeDefinition] = []
	for content in database.get_definitions_by_type(&"skill_node"):
		if content is SkillNodeDefinition: definitions.append(content)
	return SkillTreeManager.new(profile, definitions).effect_modifiers()

func _physics_process(delta: float) -> void:
	if session == null: return
	_retarget_elapsed += delta
	if _retarget_elapsed >= 0.5:
		_retarget_elapsed = 0.0
		if enemy_pool != null:
			for enemy in enemy_pool.active_enemies():
				if not is_instance_valid(enemy.attack_controller.target) or not enemy.attack_controller.target.active: enemy.retarget(_target_player(enemy.formation_slot))
	_advance_local_revives(delta)
	if session.online_coop == null: return
	var local_index := int(session.config.multiplayer_configuration.get("local_peer_id", 1)) - 1
	for index in player_actors.size():
		var actor := player_actors[index]
		var actor_id := StringName("player.online_%d" % (index + 1))
		if index == local_index and session.online_coop.is_host and session.online_coop.world_state.actors.has(actor_id):
			session.online_coop.world_state.actors[actor_id].position = actor.position
		elif index != local_index and session.online_coop.world_state.actors.has(actor_id):
			actor.position = session.online_coop.world_state.actors[actor_id].get("position", actor.position)

func _spawn_enemy(enemy_id: StringName, spawn_position: Vector2, formation: FormationRuntime, slot: int) -> void:
	var definition := database.get_definition(enemy_id, &"enemy") as EnemyDefinition
	if definition == null:
		session.services.diagnostics.add_warning("Generated wave references missing enemy %s" % enemy_id)
		if stage_runtime.current_segment != null: stage_runtime.current_segment.wave_scheduler.notify_enemy_finished()
		return
	enemy_sequence += 1
	var actor_id := StringName("enemy.segment_%d.%d.%d" % [session.current_segment, slot, enemy_sequence])
	var source_ids: Array[StringName] = []
	for player in player_actors:
		if is_instance_valid(player): source_ids.append(player.actor_id)
	var enemy := enemy_pool.acquire({"actor_id": actor_id, "definition": definition, "registry": session.actor_registry, "event_bus": session.event_bus, "target": _target_player(slot), "projectile_pool": projectile_pool, "difficulty": difficulty_definition, "source_player_ids": source_ids, "stage_seed": session.stage_seed, "player_count": player_actors.size()}, spawn_position)
	if enemy == null:
		session.services.diagnostics.add_warning("Enemy pool exhausted while spawning %s" % enemy_id)
		_notify_enemy_finished(actor_id)
		return
	if formation != null:
		formation.player_count = maxi(1, player_actors.size())
		formation.add_member(enemy, slot)

func _on_pooled_enemy_defeated(_enemy: ProductionEnemy, actor_id: StringName, credits: int) -> void:
	session.services.audio.play(SFX_EXPLOSION, &"Explosions", 3, 0.08, _enemy.global_position)
	_spawn_explosion(_enemy.global_position, 0.72)
	if camera_rig != null: camera_rig.add_shake(&"enemy_destroyed", 1.8, 0.12, 29.0)
	session.reward_state.credits = int(session.reward_state.get("credits", 0)) + credits
	_notify_enemy_finished(actor_id)

func _on_pooled_enemy_rewards(_enemy: ProductionEnemy, source_player_id: StringName, score: int, experience: int, drops: Array[Dictionary]) -> void:
	if source_player_id in wingman_actors.map(func(wingman): return wingman.actor_id) and not player_actors.is_empty(): source_player_id = player_actors[0].actor_id
	if not session.reward_state.has("score_by_player"): session.reward_state.score_by_player = {}
	if not session.reward_state.has("experience_by_player"): session.reward_state.experience_by_player = {}
	session.reward_state.score_by_player[source_player_id] = int(session.reward_state.score_by_player.get(source_player_id, 0)) + score
	session.reward_state.experience_by_player[source_player_id] = int(session.reward_state.experience_by_player.get(source_player_id, 0)) + experience
	if score_tracker != null: score_tracker.record_defeat(source_player_id, score)
	for player in player_actors:
		if player is ProductionPlayer and player.actor_id == source_player_id: player.grant_super_charge(minf(25.0, float(score) * 0.02 + float(experience) * 0.01))
	for drop in drops:
		pickup_sequence += 1
		var pickup := projectile_pool.acquire(&"pickup", {"actor_id": StringName("pickup.%d" % pickup_sequence), "drop": drop, "players": player_actors, "registry": session.actor_registry}, Transform2D(0.0, _enemy.global_position))
		if pickup == null: _apply_collected_drop(drop, source_player_id)

func _create_pickup() -> PooledCombatObject:
	var pickup := ProductionPickup.new()
	pickup.collected.connect(_apply_collected_drop)
	return pickup

func _apply_collected_drop(drop: Dictionary, collector_id: StringName) -> void:
	if collector_id.is_empty() and not player_actors.is_empty(): collector_id = player_actors[0].actor_id
	var category := StringName(drop.get("category", &"item")); var amount := maxi(1, int(drop.get("amount", 1)))
	match category:
		&"currency": session.reward_state.credits = int(session.reward_state.get("credits", 0)) + amount
		&"experience":
			if not session.reward_state.has("experience_by_player"): session.reward_state.experience_by_player = {}
			session.reward_state.experience_by_player[collector_id] = int(session.reward_state.experience_by_player.get(collector_id, 0)) + amount
		&"healing", &"temporary_weapon_power":
			for player in player_actors:
				if player is ProductionPlayer and player.actor_id == collector_id:
					player.grant_temporary_drop(category, amount)
					if category == &"temporary_weapon_power": session.temporary_upgrade_state.weapon_power_stacks = int(session.temporary_upgrade_state.get("weapon_power_stacks", 0)) + amount
		_: session.reward_state.items.append(drop.duplicate(true))
	session.services.audio.play(SFX_HIT, &"Player", 1, 0.08)

func _on_player_damaged(_packet: DamagePacket, result: DamageResult) -> void:
	if result.health_damage + result.shield_damage <= 0.0: return
	if score_tracker != null: score_tracker.break_chain(&"player_hit")
	session.services.audio.play(SFX_HIT, &"Player", 3, 0.035)
	if camera_rig != null: camera_rig.add_shake(&"player_hit", 4.5, 0.2, 34.0)
	_pulse_screen_effect(&"damage", clampf((result.health_damage + result.shield_damage) / 35.0, 0.16, 0.65), 0.14)

func _on_score_changed(_score: int, chain: int, _multiplier: float) -> void:
	if stage_runtime == null or stage_runtime.current_segment == null: return
	for objective in stage_runtime.current_segment.definition.objectives:
		if objective.objective_type == "chain": stage_runtime.objectives.set_progress(objective.stable_id, chain)

func _on_pooled_enemy_fired(enemy: ProductionEnemy, _pattern_id: StringName, projectile_count: int) -> void:
	if projectile_count > 0: session.services.audio.play(SFX_ENEMY_SHOT, &"Enemies", 1, 0.055, enemy.global_position)

func _on_pooled_enemy_damaged(enemy: ProductionEnemy, _packet: DamagePacket, result: DamageResult) -> void:
	if result.health_damage + result.shield_damage <= 0.0: return
	session.services.audio.play(SFX_HIT, &"Enemies", 1, 0.045, enemy.global_position)

func _on_player_destroyed(_actor_id: StringName, _source_actor_id: StringName, player_actor: ProductionPlayer = null) -> void:
	if session.local_coop == null:
		if not bool(session.config.mode_rules.get("campaign", true)) and is_instance_valid(player_actor):
			_handle_mode_defeat(player_actor)
			return
		var any_active := player_actors.any(func(player): return is_instance_valid(player) and player.active)
		if not any_active: session.complete_session(false, &"all_players_destroyed")

func _handle_mode_defeat(player_actor: ProductionPlayer) -> void:
	var starting_lives := int(session.config.mode_rules.get("starting_lives", 0))
	var continue_limit := int(session.config.mode_rules.get("continue_limit", 0))
	if not session.mission_state.has("deaths"): session.mission_state.deaths = 0
	session.mission_state.deaths = int(session.mission_state.deaths) + 1
	if float(session.config.mode_rules.get("death_penalty_seconds", 0.0)) > 0.0:
		session.mission_state.time_penalty = float(session.mission_state.get("time_penalty", 0.0)) + float(session.config.mode_rules.death_penalty_seconds)
	if starting_lives == 0:
		call_deferred("_respawn_mode_player", player_actor)
		return
	_mode_lives_remaining -= 1
	if _mode_lives_remaining > 0:
		call_deferred("_respawn_mode_player", player_actor)
		return
	if continue_limit < 0 or _mode_continues_used < continue_limit:
		_mode_continues_used += 1
		_mode_lives_remaining = starting_lives
		if score_tracker != null: score_tracker.break_chain(&"continue")
		call_deferred("_respawn_mode_player", player_actor)
		return
	session.complete_session(false, &"out_of_lives")

func _respawn_mode_player(player_actor: ProductionPlayer) -> void:
	if not is_instance_valid(player_actor) or session.mission_state.get("status") != &"active": return
	player_actor.position = session.safe_spawn
	player_actor.spawn_actor()
	player_actor.grant_invulnerability(2.0)

func _on_objective_resolved(_objective_id: StringName, succeeded: bool, reward: Dictionary, _dialogue_hook: StringName) -> void:
	if succeeded and score_tracker != null: score_tracker.record_objective(reward)

func _on_stage_completed() -> void:
	if score_tracker != null:
		session.mission_state.metrics = score_tracker.result()
		session.mission_state.metrics.deaths = int(session.mission_state.get("deaths", 0))
		session.mission_state.metrics.penalty_seconds = float(session.mission_state.get("time_penalty", 0.0))
		session.mission_state.metrics.elapsed_seconds = float(session.mission_state.metrics.get("elapsed_seconds", 0.0)) + float(session.mission_state.metrics.penalty_seconds)
		session.reward_state.score = score_tracker.score
	session.complete_session(true)

func _advance_local_revives(delta: float) -> void:
	if session.local_coop == null: return
	for target_slot in session.local_coop.player_states:
		var target_state: CoopPlayerState = session.local_coop.player_states[target_slot]
		if not target_state.downed: continue
		var target_actor: ProductionPlayer = session.local_coop.actors.get(target_slot)
		for reviver_slot in session.local_coop.player_states:
			if reviver_slot == target_slot: continue
			var reviver_actor: ProductionPlayer = session.local_coop.actors.get(reviver_slot)
			if is_instance_valid(reviver_actor) and reviver_actor.active and is_instance_valid(target_actor) and reviver_actor.global_position.distance_to(target_actor.global_position) <= 100.0 and session.services.input.is_action_pressed_for_player(&"shield", reviver_actor.player_index):
				session.local_coop.advance_revive(reviver_slot, target_slot, delta)

func _on_pooled_enemy_escaped(_enemy: ProductionEnemy, actor_id: StringName) -> void:
	_notify_enemy_finished(actor_id)

func _notify_enemy_finished(actor_id: StringName) -> void:
	if _finished_enemy_ids.has(actor_id): return
	_finished_enemy_ids[actor_id] = true
	if stage_runtime != null and stage_runtime.current_segment != null and stage_runtime.current_segment.wave_scheduler != null:
		stage_runtime.current_segment.wave_scheduler.notify_enemy_finished()

func _target_player(seed_offset := 0) -> ProductionPlayer:
	var valid_players: Array[ProductionPlayer] = []
	for candidate in player_actors:
		if candidate is ProductionPlayer and candidate.active: valid_players.append(candidate)
	if valid_players.is_empty(): return null
	return valid_players[posmod(seed_offset + enemy_sequence, valid_players.size())]

func _on_segment_changed(_node_id: StringName, _segment_id: StringName) -> void:
	if stage_runtime.current_segment == null: return
	var category := StringName(stage_runtime.current_segment.definition.category)
	if category not in [&"miniboss", &"boss"]: return
	var boss_id := session.config.mission_definition.miniboss_id if category == &"miniboss" else session.config.mission_definition.boss_id
	_spawn_boss(boss_id, category)

func _spawn_boss(boss_id: StringName, category: StringName) -> void:
	var definition := database.get_definition(boss_id, &"boss") as BossDefinition
	if definition == null or stage_runtime.current_segment == null: return
	session.services.audio.transition_music(_stage_music if _stage_music != null else STAGE_ONE_MUSIC, &"boss", session.services.audio.music_crossfade_seconds, true)
	var gate_id := StringName("encounter.%s" % category)
	if not stage_runtime.current_segment.acquire_external_gate(gate_id): return
	var arena := BossArenaController.new(); arena.name = "BossArena"; arena.configure(definition.arena_profile, player_actors.size()); add_child(arena); active_boss_arena = arena
	var practice: BossPracticeSession
	if StringName(session.config.mode_rules.get("mode_id", "")) == &"boss_practice":
		practice = BossPracticeSession.new(); practice.configure(definition.stable_id, int(session.config.mode_rules.get("boss_practice_phase", 0)), int(session.config.mode_rules.get("difficulty_rating", 50)), session.config.loadouts[0] if not session.config.loadouts.is_empty() else {}, definition.phases.size())
	var spawned_boss := BossActor.new(); spawned_boss.name = "Boss_%s" % definition.stable_id; spawned_boss.configure_boss(definition, session.actor_registry, session.event_bus, arena, practice, session.services.profiles.get_progression_profile().new_game_plus_cycle); active_boss = spawned_boss
	if session.local_coop != null: active_boss.health_component.maximum *= float(session.local_coop.difficulty_profile().boss_health_multiplier); active_boss.health_component.current = active_boss.health_component.maximum
	elif session.online_coop != null: active_boss.health_component.maximum *= float(CoopDifficultyScaler.profile(2).boss_health_multiplier); active_boss.health_component.current = active_boss.health_component.maximum
	active_boss.position = Vector2(270, 220); active_boss.configure_combat_context(_target_player(), projectile_pool, difficulty_definition)
	active_boss.damage_resolved.connect(func(_packet: DamagePacket, result: DamageResult):
		if result.health_damage + result.shield_damage > 0.0: session.services.audio.play(SFX_HIT, &"Enemies", 2, 0.03, active_boss.global_position))
	active_boss.destroyed.connect(func(_actor_id: StringName, _source_id: StringName):
		session.services.audio.play(SFX_EXPLOSION, &"Explosions", 5, 0.04, active_boss.global_position)
		_spawn_explosion(active_boss.global_position, 1.25))
	if active_boss.attack_controller != null:
		active_boss.attack_controller.pattern_fired.connect(func(_pattern_id: StringName, projectile_count: int):
			if projectile_count > 0: session.services.audio.play(SFX_ENEMY_SHOT, &"Enemies", 2, 0.035, active_boss.global_position))
	active_boss.summon_requested.connect(func(enemy_id, summon_index): _spawn_enemy(enemy_id, Vector2(180 + summon_index * 60, 260), null, summon_index))
	active_boss.dialogue_requested.connect(func(dialogue_id: StringName): session.services.story.start_dialogue(dialogue_id, {"boss_id": definition.stable_id}))
	active_boss.rewards_ready.connect(func(rewards, _challenges):
		session.reward_state.credits = int(session.reward_state.get("credits", 0)) + int(rewards.get("credits", 0))
		if rewards.has("equipment_id"): session.reward_state.items.append(rewards.equipment_id)
		if stage_runtime.current_segment != null: stage_runtime.current_segment.release_external_gate(gate_id)
		if is_instance_valid(arena): arena.queue_free()
		if active_boss_arena == arena: active_boss_arena = null)
	add_child(active_boss)
	if camera_rig != null:
		camera_rig.frame_boss(active_boss, player_actors)
		camera_rig.add_shake(&"boss_arrival", 5.0, 0.45, 18.0)
	_pulse_screen_effect(&"boss_warning", 0.58, 0.42)

func _on_story_pause_requested(paused: bool) -> void:
	session.services.audio.set_music_paused(paused)
	if DisplayServer.get_name() != "headless": get_tree().paused = paused

func _spawn_explosion(at: Vector2, scale_factor: float) -> void:
	if effects_pool == null: return
	var effect := effects_pool.spawn_effect(&"explosion", &"gameplay", at)
	if effect == null: return
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", 22.0)
	frames.set_animation_loop(&"default", false)
	for frame_index in 5:
		var frame := AtlasTexture.new()
		frame.atlas = EXPLOSION_SHEET
		frame.region = Rect2(frame_index * 32, 0, 32, 32)
		frames.add_frame(&"default", frame)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * 2.15
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.add_child(sprite)
	sprite.play(&"default")
	var ring := Line2D.new()
	for point_index in 25:
		ring.add_point(Vector2.RIGHT.rotated(TAU * float(point_index) / 24.0) * 18.0)
	ring.width = 2.5
	ring.default_color = Color(0.55, 0.9, 1.0, 0.85)
	ring.antialiased = true
	effect.add_child(ring)
	effect.modulate = Color.WHITE
	effect.scale = Vector2.ONE * 0.45
	var tween := effect.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector2.ONE * scale_factor, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * 2.4, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.28).set_delay(0.04)
	tween.tween_property(effect, "modulate:a", 0.0, 0.34).set_delay(0.12)
	tween.chain().tween_callback(func(): effects_pool.release_effect(effect))

func _pulse_screen_effect(effect_id: StringName, intensity: float, duration: float) -> void:
	if screen_effects == null: return
	screen_effects.trigger(effect_id, intensity)
	var timer := get_tree().create_timer(duration, false)
	timer.timeout.connect(func():
		if screen_effects != null: screen_effects.clear(effect_id))
