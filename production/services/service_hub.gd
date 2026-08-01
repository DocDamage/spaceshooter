class_name ServiceHub
extends Node

signal services_ready
signal service_failed(service_id: StringName, message: String)

const INITIALIZATION_ORDER := [
	&"settings", &"platform", &"localization", &"input", &"audio",
	&"saves", &"profiles", &"story", &"achievements", &"scene_router", &"game_flow", &"diagnostics"
]

var content_database: ContentDatabase
var game_flow: GameFlowService
var scene_router: SceneRouterService
var settings: SettingsService
var input: GameInputService
var profiles: ProfileService
var saves: SaveService
var audio: GameAudioService
var localization: LocalizationService
var achievements: AchievementService
var platform: PlatformService
var diagnostics: DiagnosticsService
var story: StoryService
var _services: Dictionary = {}
var is_ready := false

func _ready() -> void:
	initialize_services()

func initialize_services() -> bool:
	if is_ready:
		return true
	content_database = ContentDatabase.new()
	content_database.name = "ContentDatabase"
	add_child(content_database)
	content_database.validation_failed.connect(_on_content_validation_failed)
	if not content_database.initialize():
		service_failed.emit(&"content_database", "Content validation failed")
		return false
	game_flow = _add_service(GameFlowService.new())
	scene_router = _add_service(SceneRouterService.new())
	settings = _add_service(SettingsService.new())
	input = _add_service(GameInputService.new())
	profiles = _add_service(ProfileService.new())
	story = _add_service(StoryService.new())
	saves = _add_service(SaveService.new())
	audio = _add_service(GameAudioService.new())
	localization = _add_service(LocalizationService.new())
	achievements = _add_service(AchievementService.new())
	platform = _add_service(PlatformService.new())
	diagnostics = _add_service(DiagnosticsService.new())
	for service_id in INITIALIZATION_ORDER:
		var service: BaseGameService = _services[service_id]
		if not service.initialize({"hub": self}):
			service_failed.emit(service_id, "Initialization failed")
			return false
	is_ready = true
	services_ready.emit()
	return true

func _add_service(service: BaseGameService) -> BaseGameService:
	_services[service.service_id] = service
	service.name = String(service.service_id).to_pascal_case()
	service.service_error.connect(_on_service_error)
	add_child(service)
	return service

func get_service(service_id: StringName) -> BaseGameService:
	return _services.get(service_id)

func get_initialization_order() -> Array:
	return INITIALIZATION_ORDER.duplicate()

func _on_service_error(service_id: StringName, message: String) -> void:
	service_failed.emit(service_id, message)

func _on_content_validation_failed(errors: PackedStringArray) -> void:
	for message in errors:
		push_error("[content_database] %s" % message)
