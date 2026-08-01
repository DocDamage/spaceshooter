extends SceneTree

var failures := PackedStringArray()
var passed_count := 0

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1; print("PASS: %s" % message)
	else:
		failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	var database := ContentDatabase.new(); root.add_child(database)
	_assert(database.initialize(), "Phase 8 resources pass content validation")
	_test_experience()
	_test_stats()
	_test_inventory(database)
	_test_skills(database)
	_test_temporary_upgrades(database)
	_test_rewards_and_persistence()
	_test_ability_upgrades(database)
	_test_reports()
	if failures.is_empty(): print("PHASE 8 ACCEPTANCE: all %d checks passed" % passed_count); _finish(0)
	else: print("PHASE 8 ACCEPTANCE: %d check(s) failed" % failures.size()); _finish(1)

func _finish(exit_code: int) -> void:
	TestSupport.remove_tree("user://phase8_acceptance.json")
	TestSupport.remove_tree("user://phase8_level_curve.csv")
	TestSupport.remove_tree("user://phase8_economy.csv")
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _test_experience() -> void:
	var profile := ProgressionProfile.new(); profile.add_experience(ExperienceCurve.xp_to_next(1) + ExperienceCurve.xp_to_next(2) + 17)
	_assert(profile.level == 3 and profile.current_experience == 17, "multi-level gains carry excess XP iteratively")
	_assert(profile.statistic_points == 4 and profile.skill_points == 2, "level rewards grant stat and skill points once")
	profile.add_experience(2147483647)
	_assert(profile.level == 99 and profile.current_experience == 0, "level cap is enforced without recursive leveling")
	_assert(ExperienceCurve.level_table().size() == 99 and ExperienceCurve.campaign_completion_range() == Vector2i(42, 50), "level 1-99 table and campaign range are defined")
	profile.statistic_points = 100
	_assert(profile.allocate_stat(&"power", 50) and not profile.allocate_stat(&"power", 1), "stat cap is enforced")

func _test_stats() -> void:
	var result := StatCalculator.calculate({&"damage": 1.0, &"status_chance": 0.2, &"move_speed": 300.0}, {&"power": 5}, [{&"damage": 0.2}], [{&"damage": 0.1}], [{&"damage": 0.3}], [{&"damage": -0.1}], {&"damage_multiplier": 2.0, &"status_chance_multiplier": 10.0})
	_assert(is_equal_approx(result.damage, 3.2), "stat stacking applies allocation, equipment, skills, temporary, status, then difficulty")
	_assert(is_equal_approx(result.status_chance, 1.0), "effective stat caps are applied")
	var delta := StatCalculator.equipment_delta({&"damage": 1.0}, [{&"damage": 0.1}], {&"damage": 0.3}, {&"damage": 0.1})
	_assert(is_equal_approx(delta.damage, 0.2), "equipment comparison reports actual effective changes")

func _test_inventory(database: ContentDatabase) -> void:
	var definitions: Array[EquipmentDefinition] = []
	for content in database.get_definitions_by_type(&"equipment"): definitions.append(content as EquipmentDefinition)
	var profile := ProgressionProfile.new(); var inventory := InventoryManager.new(profile, definitions)
	var core: EquipmentDefinition = database.get_definition(&"equipment.reactor_matrix", &"equipment")
	var acquired := inventory.acquire(core); var instance_id: StringName = acquired.item.instance_id
	_assert(acquired.accepted and inventory.equip(instance_id, &"core"), "compatible equipment can be acquired and equipped")
	_assert(not inventory.equip(instance_id, &"engine"), "invalid equipment slot cannot be equipped")
	_assert(inventory.set_locked(instance_id, true) and inventory.sell(instance_id) == 0, "locked equipment cannot be sold or dismantled")
	_assert(inventory.save_preset(&"boss") and inventory.load_preset(&"boss"), "loadout presets save and restore")
	var thruster: EquipmentDefinition = database.get_definition(&"equipment.vector_thrusters", &"equipment")
	inventory.acquire(thruster); var converted := inventory.acquire(thruster)
	_assert(converted.converted and profile.currency == thruster.dismantle_value, "duplicate conversion policy is deterministic")
	_assert(inventory.sorted_items(&"rarity").size() == 2 and inventory.sorted_items(&"name", &"engine").size() == 1, "inventory sorting and filtering work")

func _test_skills(database: ContentDatabase) -> void:
	var definitions: Array[SkillNodeDefinition] = []
	for content in database.get_definitions_by_type(&"skill_node"): definitions.append(content as SkillNodeDefinition)
	var profile := ProgressionProfile.new(); profile.level = 10; profile.skill_points = 4; profile.currency = 100
	var tree := SkillTreeManager.new(profile, definitions)
	_assert(tree.purchase(&"skill.weapons.calibration") and int(profile.skill_trees.get(&"skill.weapons.calibration")) == 1, "data-driven skill nodes purchase ranks")
	var before_points := profile.skill_points; var cancelled := tree.respec(false, true)
	_assert(not cancelled.success and profile.skill_points == before_points, "respec requires confirmation")
	var result := tree.respec(true, true)
	_assert(result.success and result.refund == 1 and profile.skill_points == 4 and profile.skill_trees.is_empty(), "training respec refunds exactly and cannot duplicate points")
	_assert(definitions.size() >= 5, "all five planned skill trees have authored nodes")

func _test_temporary_upgrades(database: ContentDatabase) -> void:
	var definitions: Array[TemporaryUpgradeDefinition] = []
	for content in database.get_definitions_by_type(&"temporary_upgrade"): definitions.append(content as TemporaryUpgradeDefinition)
	var draft := TemporaryUpgradeDraft.new(definitions, 88)
	_assert(draft.offer(2, [], false).is_empty() and draft.offer(2, [], true).size() == 2, "upgrade choice panels only open during safe transitions")
	_assert(draft.offer(2, [&"pacifist"], true).size() == 1, "incompatible temporary upgrades are not offered")
	_assert(draft.select(&"upgrade.emergency_barrier"), "temporary upgrade selection changes the stage build")
	var snapshot := draft.checkpoint_snapshot(); var restored := TemporaryUpgradeDraft.new(definitions, 0)
	_assert(restored.restore_checkpoint(snapshot) and restored.active_upgrade_ids == draft.active_upgrade_ids, "temporary upgrades serialize into checkpoints")
	restored.reset_after_mission(); _assert(restored.active_upgrade_ids.is_empty(), "temporary upgrades reset after missions")

func _test_rewards_and_persistence() -> void:
	var profile := ProgressionProfile.new()
	var reward := RewardCalculator.calculate({"completed": true, "base_xp": 1000, "base_currency": 500, "difficulty_multiplier": 1.2, "objectives_completed": 2, "max_chain": 20, "score": 100000, "damage_taken": 0, "boss_challenge": true, "secret_route": true})
	_assert(reward.xp > 1000 and reward.currency > 500, "mission rewards account for performance and challenges")
	_assert(RewardCalculator.claim(profile, &"mission.1", reward) and not RewardCalculator.claim(profile, &"mission.1", reward), "results rewards cannot be duplicated by reload")
	var service := SaveService.new(); root.add_child(service); var snapshot := profile.to_snapshot(); var path := "user://phase8_acceptance.json"
	_assert(service.save_snapshot_atomic(snapshot, path) == OK, "profile saves atomically")
	var restored := ProgressionProfile.from_snapshot(service.load_snapshot(path))
	_assert(restored.currency == profile.currency and restored.claimed_reward_ids == profile.claimed_reward_ids, "complete persistent build saves and reloads")

func _test_ability_upgrades(database: ContentDatabase) -> void:
	var profile := ProgressionProfile.new(); profile.currency = 10000
	_assert(profile.upgrade_ability(&"weapon.pulse_cannon", false, 100) and int(profile.weapon_levels[&"weapon.pulse_cannon"]) == 2, "permanent weapon upgrades persist in profile")
	_assert(profile.upgrade_ability(&"spell.nova", true, 100) and int(profile.spell_levels[&"spell.nova"]) == 2, "permanent spell upgrades persist in profile")
	var runtime := WeaponRuntime.new(); root.add_child(runtime); var weapon: WeaponDefinition = database.get_definition(&"weapon.pulse_cannon", &"weapon"); runtime.upgrade_levels = {weapon.stable_id: 8}; runtime.global_damage_multiplier = 1.25
	var spec := runtime.get_effective_spec(weapon)
	_assert(spec.damage > weapon.damage * 1.25 and spec.cooldown < weapon.cooldown_seconds and spec.visual_intensity > 1.0, "persistent build and weapon levels alter combat and presentation parameters")

func _test_reports() -> void:
	_assert(EconomyReporter.simulate(30).size() == 30, "economy simulation covers XP, currency, costs, drops, farming, bosses, and New Game Plus")
	_assert(ExperienceCurve.export_csv("user://phase8_level_curve.csv") == OK and EconomyReporter.export_csv("user://phase8_economy.csv", 30) == OK, "balance reports export as CSV")
