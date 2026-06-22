# Headless test: the Gaussian asset loads and has a non-zero point count.
# Catches import/path/format errors before the scene ever tries to render it.
extends Node

const SPLAT_PATH := "res://assets/splats/demo.ply"

var _passed := 0
var _failed := 0

func _ready() -> void:
	_test_master_bus()
	_test_splat_loads()
	_report()

func _test_splat_loads() -> void:
	var gaussian := load(SPLAT_PATH)
	if gaussian == null:
		_fail("splat resource is null (import failed?)")
		return
	if not (gaussian is GaussianResource):
		_fail("loaded resource is not a GaussianResource (got %s)" % typeof(gaussian))
		return
	if gaussian.point_count <= 0:
		_fail("point_count is %d — expected > 0" % gaussian.point_count)
		return
	_pass("splat loaded: %d gaussians, AABB=%s" % [gaussian.point_count, gaussian.aabb])

func _test_master_bus() -> void:
	# Sanity: audio bus exists (the gunshot sfx needs it).
	if AudioServer.get_bus_count() > 0 and AudioServer.get_bus_index("Master") >= 0:
		_pass("Master bus present")
	else:
		_fail("Master bus missing")

func _pass(message: String) -> void:
	_passed += 1
	print("  [PASS] %s" % message)

func _fail(message: String) -> void:
	_failed += 1
	print("  [FAIL] %s" % message)

func _report() -> void:
	print("----")
	print("SPLAT LOAD: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
