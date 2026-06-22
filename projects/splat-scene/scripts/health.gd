# A character's hit points. Single-player: damage is applied directly, no
# referee RPC (unlike ../fps-game which routes damage through the host).
class_name Health
extends Node

signal changed(hp: int)
signal died

const MAX_HP := 100

var hp := MAX_HP

func is_dead() -> bool:
	return hp <= 0

func apply_damage(amount: int) -> void:
	if is_dead():
		return
	_set_hp(maxi(hp - amount, 0))

func _set_hp(value: int) -> void:
	var was_alive := not is_dead()
	hp = value
	changed.emit(hp)
	if was_alive and is_dead():
		died.emit()
