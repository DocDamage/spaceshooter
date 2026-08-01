class_name AccessibilityPreview
extends Control

var settings: SettingsService
var player_color := Color("62dcff")
var hostile_color := Color("ff566d")
var friendly_color := Color("62dcff")
var motion_phase := 0.0
var metadata_label: Label

func configure(service: SettingsService) -> void:
	settings = service
	settings.setting_changed.connect(_on_setting_changed)
	_apply_all()

func _ready() -> void:
	custom_minimum_size = Vector2(430, 230)
	metadata_label = Label.new()
	metadata_label.position = Vector2(16, 178)
	metadata_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metadata_label.size = Vector2(398, 48)
	add_child(metadata_label)
	_apply_all()

func _process(delta: float) -> void:
	if settings:
		motion_phase += delta * (1.0 - float(settings.get_setting(&"background_motion_reduction", 0.0)))
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("081329"), true)
	for index in 18:
		var x := fposmod(index * 71.0 + motion_phase * 30.0, maxf(size.x, 1.0))
		draw_circle(Vector2(x, 24.0 + (index * 47) % 135), 1.5, Color(0.7, 0.8, 1.0, 0.55))
	var player := Vector2(size.x * 0.5, 145)
	if settings and bool(settings.get_setting(&"player_outline", true)):
		draw_circle(player, 18, Color.WHITE)
	draw_circle(player, 14, player_color)
	for index in 5:
		var hostile := Vector2(90 + index * 62, 55 + (index % 2) * 24)
		if settings and bool(settings.get_setting(&"projectile_outline", true)):
			draw_circle(hostile, 7, Color.WHITE)
		draw_circle(hostile, 4, hostile_color)
	for index in 3:
		draw_circle(Vector2(180 + index * 36, 115), 4, friendly_color)

func active_assists() -> PackedStringArray:
	var assists := PackedStringArray()
	if settings == null:
		return assists
	for key in [&"auto_fire", &"simplified_patterns", &"invulnerability_assist"]:
		if bool(settings.get_setting(key, false)):
			assists.append(String(key))
	if float(settings.get_setting(&"aim_assistance", 0.0)) > 0.0:
		assists.append("aim_assistance")
	if float(settings.get_setting(&"game_speed_assistance", 1.0)) < 1.0:
		assists.append("game_speed_assistance")
	return assists

func run_metadata() -> Dictionary:
	return {"active_assists": Array(active_assists()), "accessibility_allowed": true}

func _on_setting_changed(_key: StringName, _value: Variant) -> void:
	_apply_all()

func _apply_all() -> void:
	if settings == null:
		return
	hostile_color = Color(String(settings.get_setting(&"hostile_bullet_color", "ff566d")))
	friendly_color = Color(String(settings.get_setting(&"friendly_bullet_color", "62dcff")))
	player_color = _filtered_color(friendly_color, String(settings.get_setting(&"colorblind_filter", "off")))
	if metadata_label:
		var assists := active_assists()
		metadata_label.text = "Live preview • Active assists: %s" % ("None" if assists.is_empty() else ", ".join(assists))
	queue_redraw()

func _filtered_color(color: Color, mode: String) -> Color:
	match mode:
		"protanopia": return Color(color.g * 0.55 + color.r * 0.45, color.g, color.b)
		"deuteranopia": return Color(color.r, color.r * 0.35 + color.g * 0.65, color.b)
		"tritanopia": return Color(color.r, color.g * 0.65 + color.b * 0.35, color.g * 0.35 + color.b * 0.65)
	return color
