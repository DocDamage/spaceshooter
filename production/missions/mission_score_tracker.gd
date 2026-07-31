class_name MissionScoreTracker
extends Node

signal score_changed(score: int, chain: int, multiplier: float)
signal chain_broken(final_chain: int, reason: StringName)

var score := 0
var chain := 0
var maximum_chain := 0
var defeats := 0
var objectives_completed := 0
var segments_completed := 0
var elapsed := 0.0
var last_defeat_time := -99.0
var chain_window := 4.0
var score_by_player: Dictionary = {}

func _process(delta: float) -> void:
	elapsed += delta
	if chain > 0 and elapsed - last_defeat_time > chain_window: break_chain(&"timeout")

func record_defeat(player_id: StringName, base_score: int) -> int:
	if elapsed - last_defeat_time <= chain_window: chain += 1
	else:
		if chain > 0: break_chain(&"timeout")
		chain = 1
	last_defeat_time = elapsed
	maximum_chain = maxi(maximum_chain, chain)
	defeats += 1
	var awarded := int(round(float(maxi(0, base_score)) * multiplier()))
	score += awarded
	score_by_player[player_id] = int(score_by_player.get(player_id, 0)) + awarded
	score_changed.emit(score, chain, multiplier())
	return awarded

func record_objective(reward: Dictionary) -> int:
	objectives_completed += 1
	var awarded := int(reward.get("score", int(reward.get("credits", 0)) * 10))
	score += maxi(0, awarded)
	score_changed.emit(score, chain, multiplier())
	return awarded

func record_segment() -> void:
	segments_completed += 1

func record_bonus(amount: int) -> int:
	var awarded := maxi(0, amount)
	score += awarded
	score_changed.emit(score, chain, multiplier())
	return awarded

func break_chain(reason: StringName) -> void:
	if chain <= 0: return
	var final_chain := chain
	chain = 0
	chain_broken.emit(final_chain, reason)
	score_changed.emit(score, chain, multiplier())

func multiplier() -> float:
	return 1.0 + minf(2.0, float(chain / 5) * 0.25)

func rank() -> StringName:
	var performance := score + maximum_chain * 250 + objectives_completed * 3000
	if performance >= 50000: return &"S"
	if performance >= 30000: return &"A"
	if performance >= 18000: return &"B"
	if performance >= 9000: return &"C"
	return &"D"

func result() -> Dictionary:
	return {"score": score, "max_chain": maximum_chain, "defeats": defeats, "objectives_completed": objectives_completed, "segments_completed": segments_completed, "rank": rank(), "elapsed_seconds": elapsed, "score_by_player": score_by_player.duplicate(true)}

func snapshot() -> Dictionary:
	return result().merged({"chain": chain, "last_defeat_time": last_defeat_time}, true)

func restore(data: Dictionary) -> void:
	score = maxi(0, int(data.get("score", 0))); chain = maxi(0, int(data.get("chain", 0))); maximum_chain = maxi(chain, int(data.get("max_chain", 0)))
	defeats = maxi(0, int(data.get("defeats", 0))); objectives_completed = maxi(0, int(data.get("objectives_completed", 0))); segments_completed = maxi(0, int(data.get("segments_completed", 0)))
	elapsed = maxf(0.0, float(data.get("elapsed_seconds", 0.0))); last_defeat_time = float(data.get("last_defeat_time", -99.0)); score_by_player = data.get("score_by_player", {}).duplicate(true)
