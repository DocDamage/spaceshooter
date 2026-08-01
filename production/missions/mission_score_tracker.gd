class_name MissionScoreTracker
extends Node

signal score_changed(score: int, chain: int, multiplier: float)
signal chain_broken(final_chain: int, reason: StringName)
signal loop_changed(chain_fill: float, rate: float, rank_pips: int)

var score := 0
var chain := 0
var maximum_chain := 0
var defeats := 0
var objectives_completed := 0
var segments_completed := 0
var elapsed := 0.0
var last_defeat_time := -99.0
var last_chain_source: StringName = &"none"
var chain_window := 4.0
var chain_fill := 0.0
var rate := 1.0
var beam_holding := false
var overdrive_active := false
var grazes := 0
var flux_collected := 0
var element_score := 0
var bombs_used := 0
var overdrives_used := 0
var score_by_player: Dictionary = {}
var reason_totals: Dictionary = {}

func _process(delta: float) -> void:
	elapsed += delta
	if chain <= 0: return
	var drain := 1.0 / maxf(0.1, chain_window)
	if beam_holding: drain *= 0.18
	if overdrive_active: drain *= 0.1
	chain_fill = maxf(0.0, chain_fill - drain * delta)
	if chain_fill <= 0.0: break_chain(&"drain")
	else: _emit_loop()

func record_defeat(player_id: StringName, base_score: int) -> int:
	if elapsed - last_defeat_time <= chain_window and chain_fill > 0.0: chain += 1
	else:
		if chain > 0: break_chain(&"timeout")
		chain = 1
	last_defeat_time = elapsed; chain_fill = 1.0; last_chain_source = player_id; maximum_chain = maxi(maximum_chain, chain); defeats += 1
	return _award(player_id, base_score, &"defeat", true)

func record_graze(player_id: StringName, value := 1) -> int:
	grazes += 1; last_chain_source = player_id
	chain_fill = minf(1.0, chain_fill + 0.025 * maxi(1, value))
	return _award(player_id, maxi(1, value) * 5, &"graze", false)

func record_flux(player_id: StringName, value := 1) -> int:
	flux_collected += maxi(1, value); last_chain_source = player_id; rate = minf(4.0, rate + 0.025 * value)
	chain_fill = minf(1.0, chain_fill + 0.04 * value)
	return _award(player_id, value * 25, &"flux", false)

func record_element_damage(player_id: StringName, damage: float) -> int:
	var awarded := maxi(0, roundi(damage * 3.0)); element_score += awarded
	return _award(player_id, awarded, &"element", false)

func record_bomb(player_id: StringName) -> void:
	bombs_used += 1; rate = maxf(1.0, rate - 0.5); chain_fill *= 0.45
	_reason(&"bomb", 0); _emit_loop()

func set_beam_hold(held: bool) -> void:
	beam_holding = held

func set_overdrive(active: bool, player_id: StringName = &"") -> void:
	if active and not overdrive_active: overdrives_used += 1; _reason(&"overdrive", 0)
	overdrive_active = active
	if not player_id.is_empty(): _emit_loop()

func record_objective(reward: Dictionary) -> int:
	objectives_completed += 1
	return _award(&"", int(reward.get("score", int(reward.get("credits", 0)) * 10)), &"objective", false)

func record_segment() -> void:
	segments_completed += 1

func record_bonus(amount: int) -> int:
	return _award(&"", amount, &"bonus", false)

func break_chain(reason: StringName) -> void:
	if chain <= 0: return
	var final_chain := chain; chain = 0; chain_fill = 0.0; beam_holding = false
	chain_broken.emit(final_chain, reason); _reason(reason, 0); score_changed.emit(score, chain, multiplier()); _emit_loop()

func multiplier() -> float:
	return (1.0 + minf(2.0, float(chain) * 0.05)) * rate

func rank_pips() -> int:
	return clampi(int((rate - 1.0) * 1.25) + int(chain >= 25), 0, 3)

func rank() -> StringName:
	var performance := score + maximum_chain * 250 + objectives_completed * 3000
	if performance >= 50000: return &"S"
	if performance >= 30000: return &"A"
	if performance >= 18000: return &"B"
	if performance >= 9000: return &"C"
	return &"D"

func result() -> Dictionary:
	return {&"score": score, &"max_chain": maximum_chain, &"defeats": defeats, &"objectives_completed": objectives_completed, &"segments_completed": segments_completed, &"rank": rank(), &"elapsed_seconds": elapsed, &"score_by_player": score_by_player.duplicate(true), &"graze": grazes, &"flux": flux_collected, &"element_score": element_score, &"bombs": bombs_used, &"overdrives": overdrives_used, &"rate": rate, &"reasons": reason_totals.duplicate(true)}

func snapshot() -> Dictionary:
	return result().merged({&"chain": chain, &"chain_fill": chain_fill, &"last_defeat_time": last_defeat_time, &"last_chain_source": last_chain_source, &"beam_holding": beam_holding, &"overdrive_active": overdrive_active}, true)

func restore(data: Dictionary) -> void:
	score = maxi(0, int(data.get("score", 0))); chain = maxi(0, int(data.get("chain", 0))); maximum_chain = maxi(chain, int(data.get("max_chain", 0))); chain_fill = clampf(float(data.get("chain_fill", 0.0)), 0.0, 1.0)
	defeats = maxi(0, int(data.get("defeats", 0))); objectives_completed = maxi(0, int(data.get("objectives_completed", 0))); segments_completed = maxi(0, int(data.get("segments_completed", 0)))
	elapsed = maxf(0.0, float(data.get("elapsed_seconds", 0.0))); last_defeat_time = float(data.get("last_defeat_time", -99.0)); last_chain_source = StringName(data.get("last_chain_source", "none")); rate = clampf(float(data.get("rate", 1.0)), 1.0, 4.0)
	grazes = maxi(0, int(data.get("graze", 0))); flux_collected = maxi(0, int(data.get("flux", 0))); element_score = maxi(0, int(data.get("element_score", 0))); bombs_used = maxi(0, int(data.get("bombs", 0))); overdrives_used = maxi(0, int(data.get("overdrives", 0)))
	score_by_player = data.get("score_by_player", {}).duplicate(true); reason_totals = data.get("reasons", {}).duplicate(true); beam_holding = bool(data.get("beam_holding", false)); overdrive_active = bool(data.get("overdrive_active", false)); _emit_loop()

func _award(player_id: StringName, amount: int, reason: StringName, use_multiplier: bool) -> int:
	var awarded := maxi(0, roundi(float(amount) * (multiplier() if use_multiplier else rate)))
	score += awarded
	if not player_id.is_empty(): score_by_player[player_id] = int(score_by_player.get(player_id, 0)) + awarded
	_reason(reason, awarded); score_changed.emit(score, chain, multiplier()); _emit_loop()
	return awarded

func _reason(reason: StringName, amount: int) -> void:
	reason_totals[reason] = int(reason_totals.get(reason, 0)) + amount

func _emit_loop() -> void:
	loop_changed.emit(chain_fill, rate, rank_pips())
