# A bot: the same body as a player, driven by a tiny state machine.
# Bots live only on the host — clients just see synced bodies.
extends BaseCharacter

const SIGHT_RANGE := 25.0
const FIRE_RANGE := 18.0
const FIRE_INTERVAL := 0.6
const HIT_CHANCE := 0.45
const BOT_DAMAGE := 18

enum State { WANDER, CHASE, SHOOT }

var state := State.WANDER
var target: BaseCharacter = null
var _wander_point := Vector3.ZERO
var _think_accum := 0.0
var _fire_accum := 0.0

func _ready() -> void:
	model_path = "res://assets/characters/Rogue.glb"
	super()
	display_name = name.replace("_", " ")
	get_node("NameLabel").text = display_name
	_pick_wander_point()

func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and not is_dead():
		_think_accum += delta
		if _think_accum >= 0.3:
			_think_accum = 0.0
			_think()
		_act(delta)
	super(delta)

# --- the brain ----------------------------------------------------------------

func _think() -> void:
	target = _nearest_enemy()
	if target == null:
		state = State.WANDER
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= FIRE_RANGE and _has_line_of_sight(target):
		state = State.SHOOT
	elif distance <= SIGHT_RANGE:
		state = State.CHASE
	else:
		state = State.WANDER

func _act(delta: float) -> void:
	match state:
		State.WANDER:
			if global_position.distance_to(_wander_point) < 2.0:
				_pick_wander_point()
			_walk_toward(_wander_point, WALK_SPEED * 0.7)
		State.CHASE:
			if target:
				_walk_toward(target.global_position, SPRINT_SPEED * 0.75)
		State.SHOOT:
			velocity.x = 0
			velocity.z = 0
			if target:
				_face(target.global_position)
				_fire_accum += delta
				if _fire_accum >= FIRE_INTERVAL:
					_fire_accum = 0.0
					_shoot_at(target)

func _walk_toward(point: Vector3, speed: float) -> void:
	_face(point)
	var direction := (point - global_position)
	direction.y = 0
	direction = direction.normalized()
	# whisker: if a wall is dead ahead, slide sideways a bit
	var space := get_world_3d().direct_space_state
	var ahead := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP, global_position + Vector3.UP + direction * 2.5, 1)
	if space.intersect_ray(ahead):
		direction = direction.rotated(Vector3.UP, 0.9)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func _face(point: Vector3) -> void:
	var flat := point
	flat.y = global_position.y
	if global_position.distance_to(flat) > 0.1:
		look_at(flat, Vector3.UP)
		rotation.x = 0

func _shoot_at(victim: BaseCharacter) -> void:
	flash_muzzle()
	if randf() < HIT_CHANCE and _has_line_of_sight(victim):
		get_node("/root/Game").apply_hit(victim.get_path(), BOT_DAMAGE)

func _nearest_enemy() -> BaseCharacter:
	var best: BaseCharacter = null
	var best_distance := SIGHT_RANGE
	for body in get_tree().get_nodes_in_group("characters"):
		if body == self or body.is_dead():
			continue
		var distance: float = global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

func _has_line_of_sight(victim: BaseCharacter) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.4,
		victim.global_position + Vector3.UP * 1.0, 1)   # walls only
	return space.intersect_ray(query).is_empty()

func _pick_wander_point() -> void:
	var zone := get_node_or_null("/root/Game/Zone")
	var radius: float = zone.current_radius * 0.8 if zone else 40.0
	var center: Vector3 = zone.center if zone else Vector3.ZERO
	var angle := randf() * TAU
	_wander_point = center + Vector3(cos(angle), 0, sin(angle)) * randf() * radius
