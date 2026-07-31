class_name LocalizationService
extends BaseGameService

var locale := "en"

func _init() -> void:
	service_id = &"localization"

func set_locale(next_locale: String) -> void:
	locale = next_locale
	TranslationServer.set_locale(next_locale)

func text(key: StringName) -> String:
	return tr(String(key))
