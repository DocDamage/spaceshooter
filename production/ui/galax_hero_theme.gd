class_name GalaxHeroTheme
extends RefCounted

static func create(scale_factor := 1.0) -> Theme:
	var scale := clampf(scale_factor, 0.75, 1.5)
	var theme := Theme.new()
	theme.default_font_size = maxi(13, int(round(17.0 * scale)))
	theme.set_color("font_color", "Label", Color("d8efff"))
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.04, 0.11, 0.9))
	theme.set_constant("shadow_offset_x", "Label", maxi(1, int(round(scale))))
	theme.set_constant("shadow_offset_y", "Label", maxi(1, int(round(2.0 * scale))))
	theme.set_constant("separation", "VBoxContainer", int(round(8.0 * scale)))
	theme.set_constant("separation", "HBoxContainer", int(round(10.0 * scale)))

	var panel := _flat_box(Color(0.018, 0.055, 0.115, 0.94), Color("28769d"), 1, 10, 16.0, scale)
	var panel_secondary := _flat_box(Color(0.012, 0.035, 0.075, 0.97), Color("4aa9cd"), 2, 10, 16.0, scale)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel_secondary)

	var normal := _flat_box(Color(0.018, 0.09, 0.16, 0.94), Color("2b708f"), 1, 6, 12.0, scale)
	var hover := _flat_box(Color(0.025, 0.16, 0.25, 0.98), Color("62d5ff"), 2, 6, 12.0, scale)
	var pressed := _flat_box(Color(0.04, 0.22, 0.31, 1.0), Color("fff09a"), 2, 6, 12.0, scale)
	var disabled := _flat_box(Color(0.025, 0.045, 0.075, 0.82), Color(0.22, 0.31, 0.39, 0.75), 1, 6, 12.0, scale)
	var focus := _flat_box(Color(0.0, 0.0, 0.0, 0.0), Color("fff09a"), 2, 6, 2.0, scale)
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
		theme.set_font_size("font_size", type_name, maxi(13, int(round(17.0 * scale))))

	var separator := StyleBoxFlat.new()
	separator.bg_color = Color("2a86ad")
	separator.content_margin_top = maxf(1.0, scale)
	separator.content_margin_bottom = maxf(1.0, scale)
	theme.set_stylebox("separator", "HSeparator", separator)
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.015, 0.045, 0.08, 0.72)
	scroll_track.set_corner_radius_all(maxi(2, int(round(3.0 * scale))))
	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.2, 0.62, 0.78, 0.82)
	scroll_grabber.set_corner_radius_all(maxi(2, int(round(3.0 * scale))))
	scroll_grabber.set_content_margin_all(3.0 * scale)
	var scroll_grabber_hover := scroll_grabber.duplicate() as StyleBoxFlat
	scroll_grabber_hover.bg_color = Color("72d8ff")
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hover)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber_hover)

	var line_edit := _flat_box(Color(0.01, 0.055, 0.11, 0.98), Color("399bc7"), 2, 5, 9.0, scale)
	theme.set_stylebox("normal", "LineEdit", line_edit)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", Color("e6f6ff"))
	return theme

static func _flat_box(background: Color, border: Color, border_width: int, corner_radius: int, margin: float, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, int(round(float(border_width) * scale))))
	style.set_corner_radius_all(maxi(2, int(round(float(corner_radius) * scale))))
	style.set_content_margin_all(margin * scale)
	return style
