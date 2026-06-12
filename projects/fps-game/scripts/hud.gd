# Health, ammo, alive count, zone timer, crosshair, and the win screen.
# Everything talks to the HUD through the "hud" group — no hard wiring.
extends CanvasLayer

var _hp_fill: ColorRect
var _ammo: Label
var _alive: Label
var _zone: Label
var _message: Label
var _hit_marker: Label

func _ready() -> void:
	add_to_group("hud")
	_hp_fill = _bar()
	_ammo = _label(Vector2(-180, -56), "30 / 30", 26, HORIZONTAL_ALIGNMENT_RIGHT)
	_alive = _label(Vector2(-180, 24), "", 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_zone = _label(Vector2(-150, 24), "", 20, HORIZONTAL_ALIGNMENT_CENTER, true)
	_message = _label(Vector2(-300, -40), "", 40, HORIZONTAL_ALIGNMENT_CENTER, true)
	_message.position.y = 220
	_hit_marker = _label(Vector2(-20, -64), "✕", 30, HORIZONTAL_ALIGNMENT_CENTER, true)
	_hit_marker.modulate.a = 0.0
	_crosshair()

func _process(_delta: float) -> void:
	_hit_marker.modulate.a = maxf(_hit_marker.modulate.a - _delta * 3.0, 0.0)
	var zone := get_node_or_null("/root/Game/Zone")
	if zone:
		var seconds: int = zone.seconds_to_next_phase()
		_zone.text = ("Zone closed" if seconds == 0
			else "Zone %d shrinks in %ds" % [zone.phase + 1, seconds])
	var alive := 0
	for body in get_tree().get_nodes_in_group("characters"):
		if not body.is_dead():
			alive += 1
	_alive.text = "%d alive" % alive

# --- group API (called from anywhere via call_group) ---------------------------

func set_hp(hp: int) -> void:
	_hp_fill.size.x = 2.4 * hp
	_hp_fill.color = Color(0.9, 0.25, 0.2) if hp < 35 else Color(0.3, 0.8, 0.35)

func set_ammo(ammo: int, reloading: bool) -> void:
	_ammo.text = "Reloading…" if reloading else "%d / 30" % ammo

func show_hit_marker() -> void:
	_hit_marker.modulate.a = 1.0

func flash_message(text: String) -> void:
	_message.text = text
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): if _message.text == text: _message.text = "")

func show_death() -> void:
	_message.text = "You are down — spectating"

func show_winner(winner: String) -> void:
	_message.text = "🏆  WINNER:  %s" % winner

# --- widget builders ------------------------------------------------------------

func _bar() -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.45)
	back.position = Vector2(24, -56)
	back.size = Vector2(248, 22)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	add_child(back)
	var fill := ColorRect.new()
	fill.color = Color(0.3, 0.8, 0.35)
	fill.position = Vector2(4, 4)
	fill.size = Vector2(240, 14)
	back.add_child(fill)
	return fill

func _label(offset: Vector2, text: String, size: int,
		alignment: int, center_x := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = alignment
	label.size = Vector2(300, 40)
	if center_x:
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.position = Vector2(offset.x + 640 - 150, maxf(offset.y, 16))
	elif offset.x < 0:
		label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		label.position = Vector2(1280 + offset.x, maxf(offset.y, 16))
		if offset.y < 0:
			label.position.y = 720 + offset.y
	add_child(label)
	return label

func _crosshair() -> void:
	for delta in [Vector2(-9, 0), Vector2(9, 0), Vector2(0, -9), Vector2(0, 9)]:
		var dot := ColorRect.new()
		dot.color = Color(1, 1, 1, 0.9)
		dot.size = Vector2(4, 4) if delta.x == 0 else Vector2(4, 4)
		dot.position = Vector2(640, 360) + delta - Vector2(2, 2)
		add_child(dot)
