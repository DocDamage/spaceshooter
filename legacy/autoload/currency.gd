extends Node

signal changed(total: int)

var main_currency := 0

func reset() -> void:
	main_currency = 0
	changed.emit(main_currency)

func add(amount: int) -> void:
	main_currency = maxi(0, main_currency + amount)
	changed.emit(main_currency)

func get_main_currency() -> int:
	return main_currency

