# Builds the splat scene: the GSplatNode renders the real-world Gaussian Splat
# as the backdrop; a proxy floor gives the player something to walk on (splats
# have no collision); static targets are placed at hand-picked spots so there
# is something to shoot (splats can't be raycast-hit). Single-player.
extends Node3D

# --- scene assets ---------------------------------------------------------------
# The Gaussian asset. Swap this to res://assets/splats/scene.ply (your own
# vid2scene output) and the rest of the scene keeps working.
# NOTE: uses the 40k-gaussian truncation of the bundled demo.ply because the
# full 271k-gaussian splat drops the Vulkan device on the Intel UHD 620 in this
# machine. On a discrete GPU, switch back to demo.ply (or your scene.ply).
const SPLAT_PATH := "res://assets/splats/demo_small.ply"

# --- layout constants (tuned for demo.ply; adjust per scene) ---------------------
const GROUND_Y := 0.0          # proxy floor height — set to the splat's ground level
const FLOOR_EXTENT := 60.0     # how far the invisible floor extends (half-size)
const PLAYER_SPAWN := Vector3(0, GROUND_Y + 1.0, 6)

var _targets: Node3D

func _ready() -> void:
	name = "Game"
	_build_environment()
	# The Gaussian Splat renderer needs a real GPU (compute shaders). Skip the
	# splat + compositor setup when running headless so smoke tests can verify
	# the game logic (spawn, move, shoot) without a render device.
	if not DisplayServer.get_name().begins_with("headless"):
		_build_splat()
	_build_proxy_floor()
	_spawn_player()
	_targets = Node3D.new()
	_targets.name = "Targets"
	add_child(_targets)
	_spawn_targets()
	add_child(load("res://scenes/hud.tscn").instantiate())
	_setup_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_handle_cli_flags()

# --- input actions (set up in code, like fps-game — no project.godot [input]) ---
func _setup_input_actions() -> void:
	var define := func(action: String, codes: Array):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in codes:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	define.call("move_forward", [KEY_W])
	define.call("move_back", [KEY_S])
	define.call("move_left", [KEY_A])
	define.call("move_right", [KEY_D])
	define.call("jump", [KEY_SPACE])
	define.call("sprint", [KEY_SHIFT])
	define.call("reload", [KEY_R])
	define.call("toggle_mouse", [KEY_ESCAPE])
	# Shoot on left mouse button.
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", click)

# --- splat rendering ------------------------------------------------------------
func _build_splat() -> void:
	# The GaussianSplatNode renders the real-world splat. Actual compositing
	# happens through a CompositorEffect on the WorldEnvironment below.
	var splat := GaussianSplatNode.new()
	splat.name = "SceneSplat"
	var gaussian := load(SPLAT_PATH)
	splat.gaussian = gaussian
	add_child(splat)

func _build_environment() -> void:
	# A WorldEnvironment is REQUIRED by the GDGS plugin — the splat is rendered
	# via a Compositor -> CompositorEffect (gaussian_compositor_effect.gd).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world := WorldEnvironment.new()
	world.environment = environment

	# Attach the Gaussian splat compositor effect only when a render device is
	# available. The effect's render callback needs Vulkan + compute shaders, so
	# instantiating it headless hangs/crashes on render-callback registration.
	if not DisplayServer.get_name().begins_with("headless"):
		var compositor := Compositor.new()
		var effect := CompositorEffect.new()
		effect.script = load("res://addons/gdgs/runtime/compositor/gaussian_compositor_effect.gd")
		# In Godot 4.7 the effect list is the `compositor_effects` array
		# property (no add_effect() method).
		compositor.compositor_effects = [effect]
		world.compositor = compositor
	add_child(world)

# --- proxy floor (splats have no collision geometry) ----------------------------
func _build_proxy_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "ProxyFloor"
	body.collision_layer = 1          # "world" layer — the player walks on it
	body.position = Vector3(0, GROUND_Y, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(FLOOR_EXTENT * 2.0, 0.2, FLOOR_EXTENT * 2.0)
	shape.shape = box
	body.add_child(shape)
	# Optional faint grid so the player can tell they're moving over an
	# otherwise-invisible floor.
	var mesh := MeshInstance3D.new()
	var grid := BoxMesh.new()
	grid.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.15, 0.18, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.mesh = grid
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)

# --- spawning -------------------------------------------------------------------
func _spawn_player() -> void:
	var body: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	body.name = "Player"
	body.position = PLAYER_SPAWN
	add_child(body)
	body.add_to_group("characters")

func _spawn_targets() -> void:
	# A small ring of targets around the spawn point. These are the only
	# raycast-hittable things in the scene besides the floor.
	var spots := [
		Vector3(-5, 0, -4),
		Vector3(0, 0, -6),
		Vector3(5, 0, -4),
		Vector3(-7, 0, 2),
		Vector3(7, 0, 2),
	]
	for index in spots.size():
		var body: CharacterBody3D = load("res://scenes/target.tscn").instantiate()
		body.name = "Target_%d" % index
		body.position = spots[index]
		_targets.add_child(body)
		body.add_to_group("characters")

# --- automation hooks (headless smoke tests) -------------------------------------
func _has_cli_flag(flag: String) -> bool:
	# A flag can land in either list depending on how the scene is launched:
	# `godot --path . scene.tscn --smoke` puts --smoke in get_cmdline_args(),
	# while flags after a `--` separator go into get_cmdline_user_args().
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()

func _handle_cli_flags() -> void:
	if _has_cli_flag("--smoke"):
		await get_tree().create_timer(3.0).timeout
		print("SMOKE OK: scene ran 3s — targets=%d" % _targets.get_child_count())
		get_tree().quit(0)
	# Screenshot hook (live render only): renders a frame, saves a PNG, exits.
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			var path := arg.trim_prefix("--shot=")
			await get_tree().create_timer(2.0).timeout
			var image := get_viewport().get_texture().get_image()
			image.save_png(path)
			print("SCREENSHOT saved: %s" % path)
			get_tree().quit(0)
