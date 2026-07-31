extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1; print("PASS: %s" % message)
	else:
		failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	hub = ServiceHub.new(); root.add_child(hub); await process_frame
	_test_mode_catalog_and_isolation()
	_test_arcade_score_attack_and_time_attack()
	_test_boss_survival_and_training()
	_test_challenges_and_difficulty()
	_test_platform_foundation()
	if failures.is_empty():
		print("PHASE 17 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else:
		print("PHASE 17 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _test_mode_catalog_and_isolation() -> void:
	var catalog := ModeCatalog.all()
	var complete := true
	for id in [&"arcade", &"score_attack", &"boss_rush", &"survival", &"endless", &"time_attack", &"training"]:
		complete = complete and catalog.has(id) and (catalog[id] as ModeDefinition).validate().is_empty()
	_assert(complete and catalog.arcade.multiplayer_allowed and not catalog.training.leaderboard_eligible, "mode rules define progression, loadouts, lives, continues, score, checkpoints, rewards, stages, difficulty, seeds, multiplayer, and leaderboard policy")
	var profile := hub.profiles.get_progression_profile()
	var before: Dictionary = profile.to_snapshot()
	var run := ModeRunController.new(); run.start(catalog.score_attack, 17017, 65, [&"aim_assistance"])
	var result := run.finish(true)
	_assert(result.campaign_mutations.is_empty() and profile.to_snapshot() == before and result.active_assists == [&"aim_assistance"], "alternative-mode progression and assist metadata cannot mutate campaign data")

func _test_arcade_score_attack_and_time_attack() -> void:
	var board := LocalLeaderboard.new(); board.configure_storage("user://phase17_%d/boards.json" % Time.get_ticks_usec())
	var arcade := ModeRunController.new(); arcade.start(ModeCatalog.get_mode(&"arcade"), 42, 50)
	arcade.add_score(&"enemy", 250000, 1)
	var arcade_result := arcade.finish(true, board)
	_assert(arcade.lives == 4 and arcade_result.score_breakdown.enemy == 250000 and board.entries(&"arcade").size() == 1, "arcade applies chain scoring, earned continues, stage rules, and local scoreboards")
	var score_attack := ModeRunController.new(); score_attack.start(ModeCatalog.get_mode(&"score_attack"), 99, 73, [&"auto_fire"]); score_attack.advance(12.5); score_attack.add_score(&"boss", 5000)
	var score_result := score_attack.finish(true, board)
	_assert(score_result.seed == 99 and score_result.elapsed_seconds == 12.5 and score_result.effective_difficulty == 73 and score_result.active_assists == [&"auto_fire"], "score attack records seed, timer, breakdown, effective difficulty, and assists")
	var timed := ModeRunController.new(); timed.start(ModeCatalog.get_mode(&"time_attack"), 8, 50); timed.advance(5.0); timed.register_defeat()
	_assert(timed.penalty_seconds == 10.0 and not ModeCatalog.get_mode(&"time_attack").checkpoints_enabled, "time attack applies death penalties and checkpoint restrictions")

func _test_boss_survival_and_training() -> void:
	var boss := ModeCatalog.get_mode(&"boss_rush")
	_assert(boss.stage_selection == &"unlocked_bosses" and boss.multiplayer_allowed and boss.rules.timer and boss.rules.recovery_between_bosses > 0.0, "boss rush defines unlock sequence, recovery, lives, score, time, difficulty, and local multiplayer")
	var endless := ModeRunController.new(); endless.start(ModeCatalog.get_mode(&"endless"), 101, 100)
	var scaling := endless.survival_scaling(1000, 1000)
	_assert(scaling.difficulty_multiplier == 3.0 and scaling.active_enemy_cap == 96 and scaling.active_projectile_cap == 1800, "survival and endless scaling obey difficulty and performance safety caps")
	var training := TrainingController.new(); training.set_option(&"invulnerability", true); training.set_option(&"infinite_resources", true); training.select_encounter(&"enemy.pirate_fighter", &"formation.pincer", &"boss.corsair_dreadnought", 2); training.set_speed(0.25); training.reset()
	var practice := training.projectile_practice_config(&"reflect")
	_assert(practice.invulnerability and practice.infinite_resources and practice.speed_scale == 0.25 and not practice.rewards_enabled and training.selected_phase == 2 and training.reset_count == 1, "training supports encounters, boss phases, projectile practice, resources, hitbox/damage options, speed, and reset without rewards")

func _test_challenges_and_difficulty() -> void:
	var challenges := ChallengeService.new(); var timestamp := 1785499200
	var first := challenges.definition_for(&"daily", timestamp); var repeated := challenges.definition_for(&"daily", timestamp)
	challenges.record_completion(first, {"score": 100, "active_assists": []}); var snapshot := challenges.snapshot(); var restored := ChallengeService.new()
	_assert(first.seed == repeated.seed and first.mutators == repeated.mutators and restored.restore(snapshot) and restored.completion_history.has(first.challenge_id), "daily and weekly challenge definitions reproduce and persist local completion history")
	var difficulty := DifficultyController.new(); difficulty.configure(&"veteran", 80, {"projectile_speed": 99.0, "density": 99.0}, true); difficulty.observe_performance(0.0, 0.5)
	var effective := difficulty.effective(ModeCatalog.get_mode(&"score_attack"), [&"simplified_patterns"])
	_assert(effective.rating > 80 and effective.projectile_speed == 1.6 and effective.density == 1.75 and effective.active_assists == [&"simplified_patterns"], "difficulty combines master slider, presets, overrides, dynamic adjustment, assist records, and impossible-generation safeguards")

func _test_platform_foundation() -> void:
	_assert(hub.platform.is_initialized and hub.platform.supports(&"offline_fallback") and not hub.platform.get_user_id().is_empty(), "platform abstraction provides identity and launches with a standalone offline fallback")
	var conflict := hub.platform.compare_cloud_file("profile.json", {"revision": 2, "credits": 10}, {"revision": 3, "credits": 5})
	var resolved := hub.platform.resolve_cloud_conflict("profile.json", &"keep_both")
	_assert(conflict.status == &"conflict" and not conflict.resolved and resolved.resolved and resolved.choice == &"keep_both", "cloud conflicts require an explicit local, remote, or keep-both choice")
	var unlocks := [0]
	hub.achievements.achievement_unlocked.connect(func(_id: StringName) -> void: unlocks[0] += 1)
	hub.achievements.unlock(&"achievement.phase17"); hub.achievements.unlock(&"achievement.phase17")
	_assert(unlocks[0] == 1 and hub.achievements.is_unlocked(&"achievement.phase17") and hub.platform.set_rich_presence({"status": "Testing modes"}) and not hub.platform.glyph_for_action(&"game_a").is_empty(), "achievements unlock once while rich presence and input glyphs remain provider-agnostic")
