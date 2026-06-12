# The local player: input → move, aim, shoot. Only the owning peer runs
# input; everyone else sees this body through _sync_state.
extends BaseCharacter

const MOUSE_SENS := 0.0025

var weapon := Weapon.new()
var _spring: SpringArm3D
var _camera: Camera3D
var _ray: RayCast3D
var _now := 0.0

func _ready() -> void:
	super()
	display_name = "Player %s" % name.trim_prefix("Player_")
	get_node("NameLabel").text = display_name
	if is_multiplayer_authority():
		_build_camera_rig()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		health.changed.connect(func(hp): get_tree().call_group("hud", "set_hp", hp))
		health.died.connect(_on_local_death)

func _build_camera_rig() -> void:
	_spring = SpringArm3D.new()
	_spring.position = Vector3(0.45, 1.6, 0)   # over-the-shoulder
	_spring.spring_length = 2.6
	_spring.collision_mask = 1
	add_child(_spring)
	_camera = Camera3D.new()
	_camera.current = true
	_spring.add_child(_camera)
	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -100)
	_ray.collision_mask = 0b11                 # world + characters
	_camera.add_child(_ray)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		_spring.rotation.x = clampf(
			_spring.rotation.x - event.relative.y * MOUSE_SENS, -1.1, 0.5)
	elif event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_now += delta
	if is_multiplayer_authority() and not is_dead():
		weapon.update(_now)
		_handle_move(delta)
		if Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_try_shoot()
		if Input.is_action_just_pressed("reload"):
			weapon.start_reload(_now)
		get_tree().call_group("hud", "set_ammo", weapon.ammo,
			weapon.is_reloading(_now))
	super(delta)

func _handle_move(_delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right",
		"move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_SPEED

func _try_shoot() -> void:
	if not weapon.fire(_now):
		return
	flash_muzzle()
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var target := _ray.get_collider()
		if target is BaseCharacter and not target.is_dead():
			# Ask the referee (host). rpc_id(1, …) runs locally when we ARE the host.
			get_node("/root/Game").request_hit.rpc_id(
				1, target.get_path(), Weapon.DAMAGE)
			get_tree().call_group("hud", "show_hit_marker")

func _on_local_death() -> void:
	# Spectate: detach the camera high above the arena.
	var pivot := Node3D.new()
	get_node("/root/Game").add_child(pivot)
	pivot.position = Vector3(0, 55, 35)
	_spring.reparent(pivot)
	_spring.rotation.x = -0.9
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("hud", "show_death")
