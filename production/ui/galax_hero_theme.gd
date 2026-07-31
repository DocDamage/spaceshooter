class_name GalaxHeroTheme
extends RefCounted

const PANEL_PRIMARY := "res://assets_runtime/ui/ui_panel_primary.png"
const PANEL_SECONDARY := "res://assets_runtime/ui/ui_panel_secondary.png"
const BUTTON_FRAME := "res://assets_runtime/ui/ui_button_frame.png"
const SEPARATOR := "res://assets_runtime/ui/ui_separator_horizontal.png"

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color("d8efff"))
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.08, 0.18, 0.85))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	var panel := _texture_box(PANEL_PRIMARY, 8.0, Color("9edbff"))
	var panel_secondary := _texture_box(PANEL_SECONDARY, 8.0, Color("b4e7ff"))
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel_secondary)
	var normal := _texture_box(BUTTON_FRAME, 6.0, Color("9edbff"))
	var hover := _texture_box(BUTTON_FRAME, 6.0, Color("fff09a"))
	var pressed := _texture_box(BUTTON_FRAME, 6.0, Color("6be6ff"))
	var disabled := _texture_box(BUTTON_FRAME, 6.0, Color(0.35, 0.46, 0.58, 0.7))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.1, 0.5, 0.8, 0.16)
	focus.border_color = Color("fff09a")
	focus.set_border_width_all(2)
	focus.corner_radius_top_left = 4; focus.corner_radius_top_right = 4
	focus.corner_radius_bottom_left = 4; focus.corner_radius_bottom_right = 4
	for type_name in ["Button", "OptionButton", "CheckBox"]:
		theme.set_stylebox("normal", type_name, normal)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("disabled", type_name, disabled)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_color", type_name, Color("d8efff"))
		theme.set_color("font_hover_color", type_name, Color("fff6bd"))
		theme.set_color("font_pressed_color", type_name, Color.WHITE)
		theme.set_color("font_disabled_color", type_name, Color("74879c"))
		theme.set_font_size("font_size", type_name, 17)
	var separator := _texture_box(SEPARATOR, 1.0, Color("74d9ff"))
	theme.set_stylebox("separator", "HSeparator", separator)
	var line_edit := StyleBoxFlat.new()
	line_edit.bg_color = Color(0.015, 0.08, 0.16, 0.94)
	line_edit.border_color = Color("399bc7")
	line_edit.set_border_width_all(2)
	line_edit.set_corner_radius_all(4)
	line_edit.set_content_margin_all(8.0)
	theme.set_stylebox("normal", "LineEdit", line_edit)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", Color("e6f6ff"))
	return theme

static func _texture_box(path: String, margin: float, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.set_content_margin_all(margin + 4.0)
	style.modulate_color = tint
	return style
