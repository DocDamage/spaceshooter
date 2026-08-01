class_name SceneRouterService
extends BaseGameService

func _init() -> void:
	service_id = &"scene_router"

func route_to(scene_path: String) -> Error:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		report_error("Scene does not exist: %s" % scene_path)
		return ERR_FILE_NOT_FOUND
	return get_tree().change_scene_to_file(scene_path)
