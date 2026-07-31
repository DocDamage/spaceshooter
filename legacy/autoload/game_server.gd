extends Node

enum GameState { SPLASH, MENU, PLAYING, COMPLETE, GAME_OVER }

signal state_changed(state: GameState)
var state := GameState.SPLASH

func set_state(value: GameState) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(state)

func reset_session() -> void:
	BattleServer.reset_battle()
	Currency.reset()
	set_state(GameState.MENU)

