# The local player: input -> move, aim, shoot. Single-player, so there is no
# authority check and no host referee — a confirmed hit applies damage directly.
extends BaseCharacter

const MOUSE_SENS := 0.0025
const LOCAL_BODY_VIS_LAYER := 5
const EYE_HEIGHT := 1.65
const PITCH_MIN := -1.2
const PITCH_MAX := 0.8

var weapon := Weapon.new()
var _head: Node3D
var _camera: Camera3D
var _ray: RayCast3D
var _body_layer_bit := 0
var _now := 0.0

func _ready() -> void:
	super()
	display_name = "You"
	get_node("NameLabel").text = display_name
	get_node("NameLabel").visible = false
	_build_camera_rig()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health.changed.connect(func(hp): get_tree().call_group("hud", "set_hp", hp))
	health.died.connect(_on_local_death)

func _build_camera_rig() -> void:
	_body_layer_bit = 1 << (LOCAL_BODY_VIS_LAYER - 1)
	_assign_visual_layer(get_node("Model"), _body_layer_bit)
	get_node("NameLabel").layers = _body_layer_bit

	_head = Node3D.new()
	_head.name = "CameraHead"
	_head.position.y = EYE_HEIGHT
	add_child(_head)

	_camera = Camera3D.new()
	_camera.current = true
	_head.add_child(_camera)
	# Hide our own body from the first-person camera so the view isn't blocked.
	# (Must happen after _camera exists — it writes _camera.cull_mask.)
	_set_local_body_visible(false)

	_ray = RayCast3D.new()
	_ray.target_position = Vector3(0, 0, -100)
	_ray.collision_mask = 0b11                 # world + characters
	# The camera is inside our own body, so the aim ray would pass through
	# ourselves — exclude our own body from the ray.
	_ray.add_exception(self)
	_camera.add_child(_ray)

func _set_local_body_visible(visible_flag: bool) -> void:
	if visible_flag:
		_camera.cull_mask |= _body_layer_bit
	else:
		_camera.cull_mask &= ~_body_layer_bit

func _assign_visual_layer(node: Node, mask: int) -> void:
	if node is VisualInstance3D:
		node.layers = mask
	for child in node.get_children():
		_assign_visual_layer(child, mask)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * MOUSE_SENS
		_head.rotation.x = clampf(
			_head.rotation.x - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	elif event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	_now += delta
	if not is_dead():
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
	var target := _find_character(_ray.get_collider())
	if target and not target.is_dead():
		# Never let the aim ray (which passes through our own body at close
		# range) hurt the local player.
		if target == self:
			return
		# Single-player: apply damage directly, no host referee.
		target.health.apply_damage(Weapon.DAMAGE)
		get_tree().call_group("hud", "show_hit_marker")
		get_tree().call_group("hud", "add_score")

func _find_character(node: Node) -> BaseCharacter:
	# A ray may hit an inner mesh/collision child; walk up to the owning body.
	var current := node
	while current:
		if current is BaseCharacter:
			return current
		current = current.get_parent()
	return null

func _on_local_death() -> void:
	# Spectate: lift the camera up and free the mouse.
	_head.position.y = 8.0
	_head.rotation.x = -0.6
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("hud", "show_death")
