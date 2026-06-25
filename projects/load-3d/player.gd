extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var walk_speed := 0.62
@export var run_speed := 1.25
@export var acceleration := 18.0
@export var turn_speed := 14.0
@export var gravity := 24.0
@export var body_radius := 0.065
@export var obstacle_probe_distance := 0.24
@export var ground_probe_up := 0.18
@export var ground_probe_down := 0.42
@export var max_step_up := 0.11
@export var max_step_down := 0.18
@export var min_floor_normal_y := 0.55
@export var max_backward_push := 0.018
@export var interact_distance := 1.1

@export_group("Camera")
@export var mouse_sensitivity := 0.0025
@export var camera_min_pitch := -0.9
@export var camera_max_pitch := 0.35
@export var camera_distance := 0.75
@export var camera_height := 0.28
@export var camera_collision_margin := 0.06

const ANIM_IDLE := "Pose"
const ANIM_WALK := "walking"
const ANIM_GREET := "salute"

var _model: Node3D
var _anim_player: AnimationPlayer
var _camera_pivot: Node3D
var _camera: Camera3D
var _wall_cast: RayCast3D
var _cam_yaw := 0.0
var _cam_pitch := -0.18
var _greeting := false
var _current_anim := ""
var _horizontal_velocity := Vector3.ZERO


func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	safe_margin = 0.004

	_model = get_node_or_null("Model")
	_camera_pivot = get_node_or_null("CameraPivot")
	if _camera_pivot:
		_camera = _camera_pivot.get_node_or_null("Camera3D")
		_wall_cast = _camera_pivot.get_node_or_null("WallCast") as RayCast3D

	_find_animation_player()
	_configure_animations()
	_play_idle()
	_apply_camera_transform()

	if _camera:
		_camera.current = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= event.relative.x * mouse_sensitivity
		_cam_pitch = clamp(_cam_pitch - event.relative.y * mouse_sensitivity, camera_min_pitch, camera_max_pitch)
		_apply_camera_transform()

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = max(camera_distance - 0.08, 0.45)
			_apply_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = min(camera_distance + 0.08, 1.5)
			_apply_camera_transform()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("greet") and not _greeting:
		_trigger_greet()

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_toggle_nearest_door()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	var move_dir := _camera_relative_input()
	move_dir = _resolve_obstacle_direction(move_dir)
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var target := move_dir * speed

	var before_move := global_position
	_horizontal_velocity.x = move_toward(_horizontal_velocity.x, target.x, acceleration * delta)
	_horizontal_velocity.z = move_toward(_horizontal_velocity.z, target.z, acceleration * delta)

	# Let the engine solve gravity/floor contact, then move horizontally with
	# small collision-checked steps. This avoids sudden pushback from dense
	# imported triangle meshes while still keeping real map collisions.
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_snap_to_ground()
	_move_horizontally(_horizontal_velocity * delta)
	_suppress_backward_push(before_move, move_dir)

	if _camera_pivot:
		_camera_pivot.global_position = global_position + Vector3.UP * camera_height

	if move_dir.length_squared() > 0.001:
		_face_direction(move_dir, delta)

	_update_animation(move_dir.length_squared() > 0.001)


func _camera_relative_input() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.001:
		return Vector3.ZERO

	var yaw_basis := Basis(Vector3.UP, _cam_yaw)
	var forward := yaw_basis * Vector3.FORWARD
	var right := yaw_basis * Vector3.RIGHT
	var direction := right * input.x + forward * -input.y
	direction.y = 0.0
	return direction.normalized()


func _resolve_obstacle_direction(direction: Vector3) -> Vector3:
	if direction.length_squared() < 0.001:
		return Vector3.ZERO

	var hit := _horizontal_obstacle_hit(direction.normalized())
	if hit.is_empty():
		return direction

	var normal: Vector3 = hit.normal
	normal.y = 0.0
	if normal.length_squared() < 0.001:
		return Vector3.ZERO
	normal = normal.normalized()
	var hit_distance: float = hit.get("distance", body_radius)
	if hit_distance < body_radius + 0.18 or direction.normalized().dot(normal) < -0.25:
		return Vector3.ZERO

	var slid := direction.slide(normal)
	slid.y = 0.0
	if slid.length_squared() < 0.001:
		return Vector3.ZERO
	return slid.normalized()


func _horizontal_obstacle_hit(direction: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var base := global_position
	var cast_length: float = body_radius + obstacle_probe_distance
	var side: Vector3 = direction.cross(Vector3.UP).normalized() * body_radius * 0.8
	var origins := [
		base + Vector3.UP * 0.12,
		base + Vector3.UP * 0.24,
		base + Vector3.UP * 0.12 + side,
		base + Vector3.UP * 0.12 - side,
	]

	var closest := {}
	var closest_distance: float = INF
	for origin in origins:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * cast_length)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		if str(hit.collider).contains("WalkFloor"):
			continue
		var normal: Vector3 = hit.normal
		if normal.y > 0.55:
			continue
		var distance: float = origin.distance_to(hit.position)
		if distance < closest_distance:
			closest_distance = distance
			hit["distance"] = distance
			closest = hit
	return closest


func _snap_to_ground() -> void:
	if velocity.y > 0.0:
		return

	var hit := _ground_hit_at(global_position)
	if hit.is_empty():
		return

	var ground_y: float = hit.position.y
	var delta_y: float = ground_y - global_position.y
	if delta_y > max_step_up or delta_y < -max_step_down:
		return

	global_position.y = ground_y
	velocity.y = -0.1


func _move_horizontally(motion: Vector3) -> void:
	motion.y = 0.0
	if motion.length_squared() < 0.0000001:
		return

	var remaining := motion
	for i in range(3):
		if remaining.length_squared() < 0.0000001:
			return
		if _try_horizontal_step(remaining):
			return

		var hit := _horizontal_obstacle_hit(remaining.normalized())
		if hit.is_empty():
			_horizontal_velocity = Vector3.ZERO
			return
		var normal: Vector3 = hit.normal
		normal.y = 0.0
		if normal.length_squared() < 0.001:
			_horizontal_velocity = Vector3.ZERO
			return
		normal = normal.normalized()
		remaining = remaining.slide(normal)
		if remaining.dot(motion) <= 0.0:
			_horizontal_velocity = Vector3.ZERO
			return


func _try_horizontal_step(motion: Vector3) -> bool:
	var start := global_position
	var transform := global_transform
	if not test_move(transform, motion):
		global_position += motion
		_snap_to_ground()
		return true

	var up := Vector3.UP * max_step_up
	if test_move(transform, up):
		return false
	var stepped_transform := transform.translated(up)
	if test_move(stepped_transform, motion):
		return false

	global_position = start + up + motion
	_snap_to_ground()
	return true


func _suppress_backward_push(before_move: Vector3, move_dir: Vector3) -> void:
	if move_dir.length_squared() < 0.001:
		return
	var horizontal_delta := global_position - before_move
	horizontal_delta.y = 0.0
	var backstep := horizontal_delta.dot(move_dir.normalized())
	if backstep >= -max_backward_push:
		return
	global_position.x = before_move.x
	global_position.z = before_move.z
	velocity.x = 0.0
	velocity.z = 0.0


func _ground_hit_at(world_position: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			world_position + Vector3.UP * ground_probe_up,
			world_position + Vector3.DOWN * ground_probe_down)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.normal
	if normal.y < min_floor_normal_y:
		return {}
	return hit


func _toggle_nearest_door() -> void:
	var nearest: MeshInstance3D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("interactive_doors"):
		if not node is MeshInstance3D:
			continue
		var door := node as MeshInstance3D
		var vertical_gap: float = abs(global_position.y - door.global_position.y)
		if vertical_gap > 1.6:
			continue
		var distance: float = Vector2(global_position.x, global_position.z).distance_to(
				Vector2(door.global_position.x, door.global_position.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = door

	if nearest == null or nearest_distance > interact_distance:
		return

	var closed := bool(nearest.get_meta("door_closed", true))
	var now_closed := not closed
	nearest.set_meta("door_closed", now_closed)
	nearest.visible = now_closed
	_set_collision_enabled(nearest, now_closed)


func _set_collision_enabled(root_node: Node, enabled: bool) -> void:
	if root_node is CollisionObject3D:
		var collision_object := root_node as CollisionObject3D
		collision_object.collision_layer = 1 if enabled else 0
		collision_object.collision_mask = 1 if enabled else 0
	if root_node is CollisionShape3D:
		(root_node as CollisionShape3D).disabled = not enabled
	for child in root_node.get_children():
		_set_collision_enabled(child, enabled)


func _face_direction(direction: Vector3, delta: float) -> void:
	if not _model:
		return
	var target_yaw := atan2(direction.x, direction.z)
	var diff := angle_difference(_model.rotation.y, target_yaw)
	_model.rotation.y += diff * min(turn_speed * delta, 1.0)


func _apply_camera_transform() -> void:
	if not _camera_pivot or not _camera:
		return

	_camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	var distance: float = camera_distance

	if _wall_cast:
		_wall_cast.target_position = Vector3(0.0, 0.0, camera_distance)
		_wall_cast.force_raycast_update()
		if _wall_cast.is_colliding():
			var hit_distance: float = _wall_cast.global_position.distance_to(_wall_cast.get_collision_point())
			distance = max(hit_distance - camera_collision_margin, 0.28)

	_camera.position = Vector3(0.0, 0.0, distance)


func _update_animation(moving: bool) -> void:
	if not _anim_player or _greeting:
		return
	var desired := ANIM_WALK if moving else ANIM_IDLE
	if desired == _current_anim:
		return
	if _anim_player.has_animation(desired):
		_anim_player.play(desired)
		_current_anim = desired


func _play_idle() -> void:
	if _anim_player and _anim_player.has_animation(ANIM_IDLE):
		_anim_player.play(ANIM_IDLE)
		_current_anim = ANIM_IDLE


func _configure_animations() -> void:
	if not _anim_player:
		return
	for animation_name in [ANIM_IDLE, ANIM_WALK]:
		if _anim_player.has_animation(animation_name):
			var animation := _anim_player.get_animation(animation_name)
			animation.loop_mode = Animation.LOOP_LINEAR


func _trigger_greet() -> void:
	if not _anim_player or not _anim_player.has_animation(ANIM_GREET):
		return
	_greeting = true
	_anim_player.play(ANIM_GREET)
	_anim_player.animation_finished.connect(_on_greet_finished, CONNECT_ONE_SHOT)


func _on_greet_finished(_anim_name: String) -> void:
	_greeting = false
	_current_anim = ""


func _find_animation_player() -> void:
	if _model:
		_anim_player = _find_first(_model, "AnimationPlayer") as AnimationPlayer


func _find_first(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first(child, type_name)
		if found:
			return found
	return null


func notify_world_ready() -> void:
	pass
