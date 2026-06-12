# Host / Join / Solo — three buttons and an IP box.
extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(490, 200)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	var title := Label.new()
	title.text = "LAST CIRCLE"
	title.add_theme_font_size_override("font_size", 52)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a battle-royale slice · task-23"
	subtitle.modulate.a = 0.7
	panel.add_child(subtitle)

	panel.add_child(_button("Solo vs 5 bots",
		func(): Net.solo_match(5)))
	panel.add_child(_button("Host match (3 bots)",
		func(): Net.host_match(3)))

	var row := HBoxContainer.new()
	var ip := LineEdit.new()
	ip.text = "127.0.0.1"
	ip.custom_minimum_size = Vector2(190, 0)
	row.add_child(ip)
	row.add_child(_button("Join", func(): Net.join_match(ip.text)))
	panel.add_child(row)

	panel.add_child(_button("Quit", func(): get_tree().quit()))

	# headless CI hooks: boot straight into a match without clicking
	var args := OS.get_cmdline_user_args()
	if "--menu-smoke" in args:
		print("MENU OK")
		get_tree().quit(0)
	elif "--mp-host" in args:
		Net.host_match(1)
	elif "--mp-join" in args:
		Net.join_match("127.0.0.1")

func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	return button
