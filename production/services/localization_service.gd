class_name LocalizationService
extends BaseGameService

var locale := "en"
var settings: SettingsService

const PSEUDO_ACCENTS := {
	"a": "à", "A": "À", "e": "ë", "E": "Ë", "i": "ï", "I": "Ï", "o": "ô", "O": "Ô",
	"u": "ü", "U": "Ü", "c": "ç", "C": "Ç", "n": "ñ", "N": "Ñ", "y": "ÿ", "Y": "Ÿ"
}

func _init() -> void:
	service_id = &"localization"

func initialize(context: Dictionary = {}) -> bool:
	settings = context.get("hub").settings if context.has("hub") else null
	if settings != null:
		set_locale(String(settings.get_setting(&"locale", "en")))
		settings.setting_changed.connect(_on_setting_changed)
	is_initialized = true
	return true

func set_locale(next_locale: String) -> void:
	locale = next_locale if next_locale in ["en", "qps_ploc", "qps_rtl"] else "en"
	TranslationServer.set_locale("en" if locale.begins_with("qps_") else locale)

func text(key: StringName) -> String:
	return render(String(key))

func render(source: String) -> String:
	var translated := tr(source)
	if locale == "qps_ploc": return _pseudo(translated, false)
	if locale == "qps_rtl": return _pseudo(translated, true)
	return translated

func localize_tree(node: Node) -> void:
	if node is Label or node is Button or node is CheckBox:
		var control := node as Control
		if not control.has_meta(&"localization_source"): control.set_meta(&"localization_source", String(control.get("text")))
		control.set("text", render(String(control.get_meta(&"localization_source"))))
		control.layout_direction = Control.LAYOUT_DIRECTION_RTL if locale == "qps_rtl" else Control.LAYOUT_DIRECTION_LTR
	for child in node.get_children(): localize_tree(child)

func _pseudo(source: String, mirrored: bool) -> String:
	var transformed := ""
	for character in source:
		transformed += PSEUDO_ACCENTS.get(character, character)
	var padding := " " + "~".repeat(maxi(2, int(ceil(source.length() * 0.35))))
	if mirrored:
		var reversed := ""
		for index in range(transformed.length() - 1, -1, -1): reversed += transformed[index]
		return "⟧%s%s⟦" % [reversed, padding]
	return "⟦%s%s⟧" % [transformed, padding]

func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"locale": set_locale(String(value))
