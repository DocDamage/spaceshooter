class_name ContentDatabase
extends Node

signal validation_failed(errors: PackedStringArray)
signal reloaded(content_count: int)

const DEFAULT_DIRECTORIES := ["res://production/content/data"]

var _by_id: Dictionary = {}
var _ids_by_type: Dictionary = {}
var _source_paths: Dictionary = {}
var _validation_errors := PackedStringArray()
var _content_version := "unloaded"

func initialize(directories: PackedStringArray = PackedStringArray()) -> bool:
	return reload(PackedStringArray(DEFAULT_DIRECTORIES) if directories.is_empty() else directories)

func reload(directories: PackedStringArray = PackedStringArray()) -> bool:
	if directories.is_empty():
		directories = PackedStringArray(DEFAULT_DIRECTORIES)
	var definitions: Array[ContentDefinition] = []
	var source_paths: Dictionary = {}
	for directory in directories:
		_scan_directory(directory, definitions, source_paths)
	# Operations 2-6 are a large, regular content set.  They are authored in one
	# declarative catalog and expanded into the same definitions used by disk
	# resources, which keeps the campaign data-driven without 160 copy/paste files.
	if directories == PackedStringArray(DEFAULT_DIRECTORIES):
		for definition in FullCampaignContentFactory.build():
			definitions.append(definition)
			source_paths[definition] = "res://production/content/full_campaign_content_factory.gd"
	return _build_index(definitions, source_paths)

func build_index_for_test(definitions: Array[ContentDefinition]) -> bool:
	return _build_index(definitions, {})

func _scan_directory(path: String, definitions: Array[ContentDefinition], source_paths: Dictionary) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_validation_errors.append("Content directory is unavailable: %s" % path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_scan_directory(child_path, definitions, source_paths)
		elif entry.get_extension() in ["tres", "res"]:
			var resource := ResourceLoader.load(child_path)
			if resource is ContentDefinition:
				definitions.append(resource)
				source_paths[resource] = child_path
		entry = directory.get_next()
	directory.list_dir_end()

func _build_index(definitions: Array[ContentDefinition], source_paths: Dictionary) -> bool:
	_by_id.clear()
	_ids_by_type.clear()
	_source_paths.clear()
	_validation_errors.clear()
	var versions := PackedStringArray()
	for definition in definitions:
		if definition == null:
			_validation_errors.append("Null content definition encountered")
			continue
		_validation_errors.append_array(definition.validate_definition())
		if definition.stable_id.is_empty():
			continue
		if _by_id.has(definition.stable_id):
			_validation_errors.append("Duplicate content ID: %s" % definition.stable_id)
			continue
		_by_id[definition.stable_id] = definition
		_source_paths[definition.stable_id] = source_paths.get(definition, "<memory>")
		var content_type := definition.get_content_type()
		if not _ids_by_type.has(content_type):
			_ids_by_type[content_type] = []
		_ids_by_type[content_type].append(definition.stable_id)
		versions.append("%s:%s" % [definition.stable_id, definition.content_version])
	for definition in _by_id.values():
		for dependency_id in definition.dependency_ids:
			if not _by_id.has(dependency_id):
				_validation_errors.append("%s requires missing content ID: %s" % [definition.stable_id, dependency_id])
	_content_version = "|".join(versions)
	if not _validation_errors.is_empty():
		validation_failed.emit(_validation_errors)
		return false
	reloaded.emit(_by_id.size())
	return true

func get_definition(stable_id: StringName, expected_type: StringName = &"") -> ContentDefinition:
	var definition: ContentDefinition = _by_id.get(stable_id)
	if definition != null and (expected_type.is_empty() or definition.get_content_type() == expected_type):
		return definition
	return null

func get_definitions_by_type(content_type: StringName) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for stable_id in _ids_by_type.get(content_type, []):
		result.append(_by_id[stable_id])
	return result

func has_id(stable_id: StringName) -> bool:
	return _by_id.has(stable_id)

func get_content_count() -> int:
	return _by_id.size()

func get_content_version() -> String:
	return _content_version

func get_validation_errors() -> PackedStringArray:
	return _validation_errors.duplicate()
