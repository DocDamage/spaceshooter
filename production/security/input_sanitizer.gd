class_name InputSanitizer
extends RefCounted

const BIDI_CONTROL_RANGES := [Vector2i(0x202A, 0x202E), Vector2i(0x2066, 0x2069)]
const PATH_UNSAFE := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]

static func sanitize_display_name(value: String, maximum_characters := 32) -> String:
	var result := ""
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint < 32 or codepoint == 127 or _is_bidi_control(codepoint):
			continue
		var character := value.substr(index, 1)
		result += "_" if character in PATH_UNSAFE else character
		if result.length() >= maximum_characters:
			break
	result = " ".join(result.strip_edges().split(" ", false))
	return result

static func sanitize_network_text(value: String, maximum_characters := 256) -> String:
	return sanitize_display_name(value, maximum_characters).replace("\n", " ").replace("\r", " ")

static func safe_storage_key(value: String, maximum_characters := 96) -> String:
	if value.is_empty() or value.length() > maximum_characters or value.contains(".."):
		return ""
	var result := ""
	for index in value.length():
		var character := value.substr(index, 1)
		if character.to_lower() not in "abcdefghijklmnopqrstuvwxyz0123456789._-":
			return ""
		result += character.to_lower()
	return result

static func _is_bidi_control(codepoint: int) -> bool:
	for range_value in BIDI_CONTROL_RANGES:
		if codepoint >= range_value.x and codepoint <= range_value.y:
			return true
	return false
