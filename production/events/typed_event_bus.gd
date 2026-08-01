class_name TypedEventBus
extends RefCounted

signal event_published(event: GameEvent)

var _subscribers: Dictionary = {}

func subscribe(event_type: StringName, callable: Callable) -> void:
	if not _subscribers.has(event_type):
		_subscribers[event_type] = []
	if callable not in _subscribers[event_type]:
		_subscribers[event_type].append(callable)

func unsubscribe(event_type: StringName, callable: Callable) -> void:
	if _subscribers.has(event_type):
		_subscribers[event_type].erase(callable)

func publish(event: GameEvent) -> void:
	if event == null or event.source_id.is_empty():
		push_error("Typed events require a stable source_id")
		return
	event_published.emit(event)
	for callable in _subscribers.get(event.get_event_type(), []):
		if callable.is_valid():
			callable.call(event)
