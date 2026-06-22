# Headless test: the shooting logic. Runs the Weapon + Health state machines
# directly (no scene needed) and verifies:
#   1. a hit reduces target health by Weapon.DAMAGE,
#   2. a target dies after enough hits,
#   3. cooldown blocks rapid fire (one shot per COOLDOWN),
#   4. the magazine empties after MAG_SIZE shots and then refuses to fire.
extends Node

var _passed := 0
var _failed := 0

func _ready() -> void:
	_test_weapon_fire_reduces_ammo()
	_test_hit_reduces_health()
	_test_target_dies_after_enough_hits()
	_test_cooldown_blocks_rapid_fire()
	_test_magazine_empties_then_refuses()
	_report()

func _test_weapon_fire_reduces_ammo() -> void:
	var w := Weapon.new()
	var before := w.ammo
	if w.fire(0.0):
		_pass("first shot fired")
	else:
		_fail("first shot did not fire")
	if w.ammo == before - 1:
		_pass("ammo decremented to %d" % w.ammo)
	else:
		_fail("ammo not decremented (got %d)" % w.ammo)

func _test_hit_reduces_health() -> void:
	var h := Health.new()
	var before := h.hp
	h.apply_damage(Weapon.DAMAGE)
	if h.hp == before - Weapon.DAMAGE:
		_pass("health reduced to %d after a hit" % h.hp)
	else:
		_fail("health not reduced (got %d)" % h.hp)

func _test_target_dies_after_enough_hits() -> void:
	var h := Health.new()
	var hits_to_kill := ceili(float(Health.MAX_HP) / float(Weapon.DAMAGE))
	for _i in hits_to_kill:
		h.apply_damage(Weapon.DAMAGE)
	if h.is_dead():
		_pass("target died after %d hits" % hits_to_kill)
	else:
		_fail("target not dead after %d hits (hp=%d)" % [hits_to_kill, h.hp])

func _test_cooldown_blocks_rapid_fire() -> void:
	var w := Weapon.new()
	var first := w.fire(0.0)
	var second := w.fire(0.01)        # well within cooldown
	if first and not second:
		_pass("cooldown blocked the second shot")
	else:
		_fail("cooldown did not block rapid fire (first=%s second=%s)" % [first, second])
	# After cooldown elapses, the next shot should fire again.
	var third := w.fire(Weapon.COOLDOWN + 0.01)
	if third:
		_pass("next shot fired after cooldown elapsed")
	else:
		_fail("no shot after cooldown elapsed")

func _test_magazine_empties_then_refuses() -> void:
	var w := Weapon.new()
	var fired := 0
	var t := 0.0
	# Fire as fast as cooldown allows until the magazine is empty.
	while t < 30.0:
		if w.fire(t):
			fired += 1
		w.update(t)
		t += Weapon.COOLDOWN
	if fired == Weapon.MAG_SIZE:
		_pass("fired exactly MAG_SIZE (%d) rounds before empty" % fired)
	else:
		_fail("fired %d rounds, expected %d" % [fired, Weapon.MAG_SIZE])
	# Empty weapon refuses to fire.
	if w.fire(t + 1.0):
		_fail("weapon fired on an empty magazine")
	else:
		_pass("empty magazine refused to fire")
	# Reload restores the magazine.
	w.start_reload(t + 2.0)
	w.update(t + 2.0 + Weapon.RELOAD_TIME + 0.01)
	if w.ammo == Weapon.MAG_SIZE and w.fire(t + 3.0):
		_pass("reload refilled the magazine and allowed firing again")
	else:
		_fail("reload did not restore the magazine (ammo=%d)" % w.ammo)

func _pass(message: String) -> void:
	_passed += 1
	print("  [PASS] %s" % message)

func _fail(message: String) -> void:
	_failed += 1
	print("  [FAIL] %s" % message)

func _report() -> void:
	print("----")
	print("SHOOT: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
