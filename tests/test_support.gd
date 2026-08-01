class_name TestSupport
extends RefCounted

static func free_root_nodes(tree: SceneTree) -> void:
	for child in tree.root.get_children():
		tree.root.remove_child(child)
		child.free()

static func remove_tree(user_path: String) -> void:
	if user_path.is_empty() or not user_path.begins_with("user://"):
		push_error("TestSupport.remove_tree only accepts an explicit user:// path")
		return
	_remove_absolute(ProjectSettings.globalize_path(user_path))

static func _remove_absolute(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child_path := path.path_join(entry)
			if directory.current_is_dir():
				_remove_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
