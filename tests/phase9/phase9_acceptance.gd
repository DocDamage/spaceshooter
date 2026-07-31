extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var test_root := "user://phase9_acceptance_%d" % Time.get_ticks_usec()

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1; print("PASS: %s" % message)
	else:
		failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	_test_atomic_and_recovery()
	_test_migration()
	_test_profiles()
	_test_content_reconciliation()
	_test_checkpoint_and_rewards()
	if failures.is_empty(): print("PHASE 9 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else: print("PHASE 9 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _service(folder: String) -> SaveService:
	var service := SaveService.new()
	service.configure_storage("%s/%s" % [test_root, folder])
	return service

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(text); file.close()

func _test_atomic_and_recovery() -> void:
	var saves := _service("atomic")
	var path := "%s/state.json" % saves.storage_root
	var first := {"schema_version": 9, "value": 1}
	var first_error := saves.save_snapshot_atomic(first, path)
	_assert(first_error == OK, "normal save writes a checksum-verified atomic document (error %d: %s)" % [first_error, saves.last_error_message])
	_write("%s.tmp" % path, "{interrupted")
	_assert(saves.load_snapshot(path).get("value") == 1, "interrupted temporary write preserves the valid primary")
	_assert(saves.save_snapshot_atomic({"schema_version": 9, "value": 2}, path) == OK, "second generation rotates the primary to previous backup")
	_assert(saves.save_snapshot_atomic({"schema_version": 9, "value": 3}, path) == OK, "third generation rotates a recovery backup")
	_write(path, "{corrupt-primary")
	_assert(saves.load_snapshot(path).get("value") == 2 and saves.status == &"recovered", "corrupt primary restores from previous backup")
	_write("%s.previous" % path, "{corrupt-backup")
	_assert(saves.load_snapshot(path).get("value") == 1, "corrupt primary and previous backup restore from recovery generation")
	_write("%s.recovery" % path, "{also-corrupt")
	_assert(saves.load_snapshot(path).is_empty() and saves.status == &"corrupt", "all corrupt generations fail safely without resetting data")
	_assert(saves.export_diagnostics("%s/diagnostics.json" % saves.storage_root) == OK, "recovery diagnostics export with actionable attempt details")

func _test_migration() -> void:
	var saves := _service("migration")
	var path := "%s/profile.json" % saves.storage_root
	var old := ProgressionProfile.new().to_snapshot()
	old.schema_version = 8; old.erase("display_name"); old.weapon_levels = {"weapon.pulse": 3}; old.future_extension = {"keep": true}
	_assert(saves.save_snapshot_atomic(old, path) == OK, "released schema fixture is written")
	var migrated := saves.load_snapshot_recovering(path, true)
	_assert(migrated.schema_version == 9 and migrated.weapon_levels.has("weapon.pulse_cannon"), "schema 8 migrates through the registered path and content rename map")
	_assert(migrated.get("future_extension", {}).get("keep", false), "unknown profile data is retained where safe")
	_assert(FileAccess.file_exists("%s.pre_migration_v8" % path) and not saves.migration_log.is_empty(), "migration creates a pre-migration backup and audit log")
	var unsupported := SaveSchemaMigrator.migrate({"schema_version": 7})
	_assert(not unsupported.success and String(unsupported.message).contains("No migration path"), "unsupported old schemas fail with a clear recovery reason")

func _test_profiles() -> void:
	var saves := _service("profiles")
	var profiles := ProfileService.new(); profiles.save_service = saves
	var first := profiles.create_profile("Ace", &"profile.ace")
	first.playtime_seconds = 3720; first.campaign_progress = {"percent": 25}; first.last_played_stage = &"mission.3"; first.new_game_plus_cycle = 2
	profiles.persist_profile(first.profile_id)
	var copy := profiles.duplicate_profile(first.profile_id)
	_assert(copy != null and copy.profile_id != first.profile_id and copy.playtime_seconds == 3720, "profiles can be created and duplicated with campaign metadata")
	_assert(profiles.rename_profile(copy.profile_id, "Wing Ace") and profiles.select_profiles([copy.profile_id]), "profiles can be renamed and selected")
	var summaries := profiles.profile_summaries()
	_assert(summaries.size() == 2 and summaries[0].has("last_played_stage") and summaries[0].has("new_game_plus_cycle"), "slot summaries expose playtime, campaign, last stage, and New Game Plus")
	_assert(profiles.delete_profile(first.profile_id) and profiles.get_progression_profile(first.profile_id, false) == null, "profiles can be explicitly deleted without silently replacing them")

func _test_content_reconciliation() -> void:
	var database := ContentDatabase.new(); root.add_child(database); _assert(database.initialize(), "content database is available for save reconciliation")
	var optional := ProgressionProfile.new().to_snapshot(); optional.unlocked_content = ["optional.removed_pack"]
	var optional_result := ProfileContentValidator.validate(optional, database)
	_assert(optional_result.valid and optional_result.unresolved_optional.has("optional.removed_pack"), "missing optional content is retained and does not destroy the profile")
	var required := optional.duplicate(true); required.inventory = [{"instance_id": "item.1", "definition_id": "equipment.removed"}]; required.equipped = {"core": "item.1"}
	var required_result := ProfileContentValidator.validate(required, database)
	_assert(not required_result.valid and not required_result.missing_required.is_empty(), "missing required equipped content produces an explicit recovery path")

func _test_checkpoint_and_rewards() -> void:
	var saves := _service("checkpoint")
	var checkpoint := {"checkpoint_id": "midpoint", "mission_id": "mission.1", "seed": 918273, "route": ["entry", "secret_left"], "segment": 4, "session_run_id": "run.fixed", "participants": ["profile.1", "profile.2"], "selected_ships": ["ship.1", "ship.2"], "loadouts": [{"weapon": "pulse"}, {"weapon": "rail"}], "objective_state": {"rescued": 2}, "temporary_upgrades": {"upgrade.barrier": 1}, "pending_rewards": {"credits": 450}}
	_assert(saves.save_checkpoint(&"profile.1", checkpoint) == OK, "checkpoint saves required multiplayer, objective, upgrade, and pending-reward state")
	var restored := saves.load_checkpoint(&"profile.1")
	_assert(restored.seed == checkpoint.seed and restored.route == checkpoint.route and restored.participants == checkpoint.participants, "checkpoint restores the exact stage seed, route, and local participants")
	_assert(int(restored.objective_state.get("rescued", 0)) == 2 and int(restored.temporary_upgrades.get("upgrade.barrier", 0)) == 1, "checkpoint restores objective and temporary upgrade state")
	var profile := ProgressionProfile.new(); var reward := {"xp": 100, "currency": 50}
	_assert(RewardCalculator.claim(profile, &"reward.run.fixed", reward) and not RewardCalculator.claim(profile, &"reward.run.fixed", reward) and profile.currency == 50, "checkpoint reload cannot duplicate a reward transaction")
	profile.new_game_plus_cycle = 3
	var round_trip := ProgressionProfile.from_snapshot(profile.to_snapshot())
	_assert(round_trip.new_game_plus_cycle == 3, "New Game Plus cycle survives profile serialization")
