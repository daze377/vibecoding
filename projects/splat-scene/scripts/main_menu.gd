# Start / Quit — a single Play button loads the splat scene. No host/join
# (single-player). Adapted from ../fps-game/scripts/main_menu.gd.
extends Control

const NAVY := Color("0f1d33")
const NAVY_CARD := Color("1b2e4d")
const ORANGE := Color("f97316")
const TEAL := Color("2dd4bf")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_constant_override("separation", 12)
	center.add_child(panel)

	var title := Label.new()
	title.text = "SPLAT SCENE"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a real-world 3DGS environment · light shooter"
	subtitle.add_theme_color_override("font_color", TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(subtitle)

	panel.add_child(_spacer(18))
	panel.add_child(_button("Play",
		func(): get_tree().change_scene_to_file("res://scenes/game.tscn"), true))
	panel.add_child(_spacer(6))
	panel.add_child(_button("Quit", func(): get_tree().quit()))

	var controls := Label.new()
	controls.text = "WASD move · mouse aim · LMB shoot · R reload · Shift sprint · Space jump · Esc free mouse"
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.anchor_right = 1.0
	controls.offset_top = -44
	controls.offset_bottom = -18
	add_child(controls)

	# headless CI hook: confirm the menu builds without errors.
	var args := OS.get_cmdline_user_args()
	if "--menu-smoke" in args:
		print("MENU OK")
		get_tree().quit(0)

func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# faint orange rings echoing the fps-game "zone" motif
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for index in 3:
		var ring := _ring(220.0 + index * 130.0, Color(ORANGE, 0.10 - index * 0.03))
		add_child(ring)

func _ring(radius: float, color: Color) -> Control:
	var ring := Control.new()
	ring.set_anchors_preset(Control.PRESET_CENTER)
	ring.draw.connect(func(): ring.draw_arc(
		Vector2.ZERO, radius, 0.0, TAU, 96, color, 3.0, true))
	return ring

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _style_box(control: Control, state: String, fill: Color,
		border := Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	if border.a > 0:
		style.set_border_width_all(1)
		style.border_color = border
	control.add_theme_stylebox_override(state, style)

func _button(text: String, on_press: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var base := ORANGE if accent else NAVY_CARD
	_style_box(button, "normal", base)
	_style_box(button, "hover", base.lightened(0.12))
	_style_box(button, "pressed", base.darkened(0.18))
	button.pressed.connect(on_press)
	return button
