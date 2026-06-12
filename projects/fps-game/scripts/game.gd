# The match referee: builds the arena, spawns everyone, applies damage,
# and decides the winner. All authority lives here, on the host.
extends Node3D

const ARENA_SIZE := 120.0
const COVER_COUNT := 26
const SPAWN_RADIUS := 45.0

var match_over := false
var _win_accum := 0.0

@onready var players: Node3D = Node3D.new()

func _ready() -> void:
	name = "Game"
	_build_environment()
	_build_arena()
	players.name = "Players"
	add_child(players)

	var zone := Node3D.new()
	zone.name = "Zone"
	zone.set_script(load("res://scripts/zone.gd"))
	add_child(zone)

	add_child(load("res://scenes/hud.tscn").instantiate())

	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--smoke" or arg == "--botmatch" or arg.begins_with("--shot"):
			Net.bot_count = maxi(Net.bot_count, 5)

	if multiplayer.is_server():
		_spawn_player(1)
		for index in Net.bot_count:
			_spawn_bot(index)
		multiplayer.peer_connected.connect(_on_peer_joined)
		multiplayer.peer_disconnected.connect(_on_peer_left)
	_handle_cli_flags(args)

# --- spawning ----------------------------------------------------------------

func _spawn_position(seat: int) -> Vector3:
	var angle := TAU * float(seat) / 12.0
	return Vector3(cos(angle), 0, sin(angle)) * SPAWN_RADIUS + Vector3(0, 0.5, 0)

func _on_peer_joined(peer_id: int) -> void:
	# tell the newcomer about everyone already here…
	for body in players.get_children():
		if body.name.begins_with("Player_"):
			_spawn_remote_player.rpc_id(peer_id, int(str(body.name).split("_")[1]))
		else:
			_spawn_remote_bot.rpc_id(peer_id, int(str(body.name).split("_")[1]))
	# …then spawn their body everywhere
	_spawn_player(peer_id)

func _on_peer_left(peer_id: int) -> void:
	var body := players.get_node_or_null("Player_%d" % peer_id)
	if body:
		body.queue_free()

func _spawn_player(peer_id: int) -> void:
	_spawn_remote_player.rpc(peer_id)
	_spawn_remote_player(peer_id)

func _spawn_bot(index: int) -> void:
	_spawn_remote_bot.rpc(index)
	_spawn_remote_bot(index)

@rpc("authority", "call_remote", "reliable")
func _spawn_remote_player(peer_id: int) -> void:
	if players.has_node("Player_%d" % peer_id):
		return
	var body: CharacterBody3D = load("res://scenes/player.tscn").instantiate()
	body.name = "Player_%d" % peer_id
	body.position = _spawn_position(peer_id % 12)
	players.add_child(body)
	body.set_multiplayer_authority(peer_id)
	body.add_to_group("characters")

@rpc("authority", "call_remote", "reliable")
func _spawn_remote_bot(index: int) -> void:
	if players.has_node("Bot_%d" % index):
		return
	var body: CharacterBody3D = load("res://scenes/bot.tscn").instantiate()
	body.name = "Bot_%d" % index
	body.position = _spawn_position(6 + index)
	players.add_child(body)
	body.set_multiplayer_authority(1)
	body.add_to_group("characters")

# --- damage (host = referee) -----------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_hit(target_path: NodePath, damage: int) -> void:
	if not multiplayer.is_server():
		return
	apply_hit(target_path, mini(damage, Weapon.DAMAGE))

func apply_hit(target_path: NodePath, damage: int) -> void:
	var target := get_node_or_null(target_path)
	if target is BaseCharacter and not target.is_dead():
		target.health.apply_damage(damage)

# --- win condition ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server() or match_over:
		return
	_win_accum += delta
	if _win_accum < 1.0:
		return
	_win_accum = 0.0
	var alive: Array[Node] = []
	for body in get_tree().get_nodes_in_group("characters"):
		if not body.is_dead():
			alive.append(body)
	if alive.size() == 1 and players.get_child_count() >= 2:
		_announce_winner.rpc(alive[0].display_name)
		_announce_winner(alive[0].display_name)
	elif alive.is_empty() and players.get_child_count() >= 1:
		_announce_winner.rpc("The circle")
		_announce_winner("The circle")

@rpc("authority", "call_remote", "reliable")
func _announce_winner(winner: String) -> void:
	if match_over:
		return
	match_over = true
	get_tree().call_group("hud", "show_winner", winner)
	await get_tree().create_timer(8.0).timeout
	Net.back_to_menu()

# --- arena building ---------------------------------------------------------------

func _build_environment() -> void:
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
	add_child(world)

func _build_arena() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23                      # same arena for every player
	_add_box(Vector3(0, -0.5, 0), Vector3(ARENA_SIZE, 1, ARENA_SIZE),
		Color(0.42, 0.52, 0.36))       # ground
	var half := ARENA_SIZE / 2.0
	for side in [-1, 1]:
		_add_box(Vector3(side * half, 2, 0), Vector3(1, 5, ARENA_SIZE), Color(0.5, 0.45, 0.4))
		_add_box(Vector3(0, 2, side * half), Vector3(ARENA_SIZE, 5, 1), Color(0.5, 0.45, 0.4))
	for index in COVER_COUNT:
		var size := Vector3(rng.randf_range(2, 5), rng.randf_range(1.5, 4), rng.randf_range(2, 5))
		var pos := Vector3(rng.randf_range(-half + 8, half - 8), size.y / 2,
			rng.randf_range(-half + 8, half - 8))
		var tone := rng.randf_range(0.35, 0.7)
		_add_box(pos, size, Color(tone, tone * 0.9, tone * 0.75))

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(mesh)
	body.add_child(shape)
	add_child(body)

# --- automation hooks (smoke tests & screenshots, used by the build) ---------------

func _handle_cli_flags(args: PackedStringArray) -> void:
	if "--smoke" in args:
		await get_tree().create_timer(8.0).timeout
		print("SMOKE OK: game scene ran 8s — players=%d" % players.get_child_count())
		get_tree().quit(0)
	if "--mp-report" in args:
		await get_tree().create_timer(12.0).timeout
		print("MP REPORT: id=%d players=%d" % [
			multiplayer.get_unique_id(), players.get_child_count()])
		get_tree().quit(0)
	if "--botmatch" in args:
		# the playtest from task-23.md §9: a bot match must end with 1 survivor
		var elapsed := 0.0
		while not match_over and elapsed < 180.0:
			await get_tree().create_timer(1.0).timeout
			elapsed += 1.0
		var survivors := 0
		for body in get_tree().get_nodes_in_group("characters"):
			if not body.is_dead():
				survivors += 1
		print("BOTMATCH %s: over=%s survivors=%d after %ds"
			% ["OK" if match_over and survivors <= 1 else "FAIL",
				match_over, survivors, int(elapsed)])
		get_tree().quit(0 if match_over and survivors <= 1 else 1)
	for arg in args:
		if arg.begins_with("--shot="):
			await get_tree().create_timer(1.0).timeout
			# stage the frame: two bots strolling in front of the camera
			var hero := players.get_node_or_null("Player_1")
			for index in 2:
				var bot := players.get_node_or_null("Bot_%d" % index)
				if hero and bot:
					bot.global_position = (hero.global_position
						+ hero.global_transform.basis.z * -(7.0 + index * 4)
						+ Vector3(index * 3 - 1.5, 0, 0))
			await get_tree().create_timer(2.0).timeout
			var image := get_viewport().get_texture().get_image()
			image.save_png(arg.trim_prefix("--shot="))
			print("SCREENSHOT saved")
			get_tree().quit(0)
