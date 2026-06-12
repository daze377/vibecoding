# The shrinking circle — the battle-royale signature (task-23.md §7).
# The host runs the schedule and the damage; everyone renders the wall.
extends Node3D

signal phase_changed(phase: int, radius: float)

const RADII: Array[float] = [60.0, 35.0, 18.0, 6.0]
const WAIT_TIME := 10.0
const SHRINK_TIME := 15.0
const DAMAGE_PER_SECOND := 5

var center := Vector3.ZERO
var current_radius: float = RADII[0]
var phase := 0
var _phase_time := 0.0
var _damage_accum := 0.0
var _wall: MeshInstance3D

func _ready() -> void:
	_wall = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 40.0
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.55, 1.0, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cylinder.material = material
	_wall.mesh = cylinder
	add_child(_wall)
	if multiplayer.is_server():
		var angle := randf() * TAU
		_set_center.rpc(Vector3(cos(angle), 0, sin(angle)) * (randf() * 25.0))

@rpc("authority", "call_local", "reliable")
func _set_center(point: Vector3) -> void:
	center = point

func _process(delta: float) -> void:
	if multiplayer.is_server():
		_run_schedule(delta)
		_sync_zone.rpc(phase, current_radius, _phase_time)
	_wall.position = center
	_wall.scale = Vector3(current_radius, 1, current_radius)

func _run_schedule(delta: float) -> void:
	if phase >= RADII.size() - 1:
		current_radius = RADII[-1]
		_tick_damage(delta)
		return
	_phase_time += delta
	if _phase_time <= WAIT_TIME:
		current_radius = RADII[phase]
	elif _phase_time <= WAIT_TIME + SHRINK_TIME:
		var t := (_phase_time - WAIT_TIME) / SHRINK_TIME
		current_radius = lerpf(RADII[phase], RADII[phase + 1], t)
	else:
		phase += 1
		_phase_time = 0.0
		phase_changed.emit(phase, RADII[phase])
	_tick_damage(delta)

func _tick_damage(delta: float) -> void:
	_damage_accum += delta
	if _damage_accum < 1.0:
		return
	_damage_accum = 0.0
	for body in get_tree().get_nodes_in_group("characters"):
		if body.is_dead():
			continue
		var flat: Vector3 = body.global_position - center
		flat.y = 0
		if flat.length() > current_radius:
			body.health.apply_damage(DAMAGE_PER_SECOND)

func seconds_to_next_phase() -> int:
	if phase >= RADII.size() - 1:
		return 0
	return maxi(int(ceil(WAIT_TIME + SHRINK_TIME - _phase_time)), 0)

@rpc("authority", "call_remote", "unreliable")
func _sync_zone(remote_phase: int, radius: float, time: float) -> void:
	phase = remote_phase
	current_radius = radius
	_phase_time = time
