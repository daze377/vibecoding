extends Node3D

var _village_map: Node
var _player: Player


func _ready() -> void:
	_village_map = get_node_or_null("VillageMap")
	_player = get_node_or_null("Player")

	# 1. Generate trimesh colliders for the imported scan. The character should
	#    stand on the real visible geometry, not on an artificial flat plane.
	if _village_map:
		_generate_collisions(_village_map)
		print("[Main] village trimesh collisions generated.")

	# 2. Wait for the physics world so we can raycast.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 3. Pick a spawn point on the actual visible map surface.
	var spawn_point := _village_center()
	if _village_map:
		spawn_point = _preferred_spawn_point()
		if spawn_point == Vector3.ZERO:
			spawn_point = _find_clear_spawn()
	if _player:
		_player.global_position = spawn_point + Vector3.UP * 0.015
		print("[Main] player spawn at %s" % _player.global_position)

	# 4. Notify the player that physics bodies are available.
	if _player and _player.has_method("notify_world_ready"):
		_player.notify_world_ready()

	print("[Main] ready complete.")


func _preferred_spawn_point() -> Vector3:
	var xz := Vector3(-1.0, 0.0, -13.0)
	var bounds := _combined_aabb(_village_map) if _village_map else AABB()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, bounds.end.y + 4.0, xz.z),
			Vector3(xz.x, bounds.position.y - 2.0, xz.z))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3.ZERO
	var normal: Vector3 = hit.normal
	if normal.y < 0.55:
		return Vector3.ZERO
	var point := Vector3(xz.x, hit.position.y, xz.z)
	print("[Main] preferred spawn at %s" % point)
	return point


# Generate a StaticBody per mesh using its triangle mesh.
func _generate_collisions(root_node: Node) -> void:
	var count := 0
	var door_count := 0
	for mesh in _collect_meshes(root_node):
		var mi: MeshInstance3D = mesh
		if mi.mesh == null:
			continue
		mi.create_trimesh_collision()
		if mi.name.to_lower().contains("door"):
			mi.add_to_group("interactive_doors")
			mi.set_meta("door_closed", true)
			door_count += 1
		count += 1
	print("[Main] trimesh colliders: %d, interactive doors: %d." % [count, door_count])


# Raycast straight down at a world XZ point; return the highest hit Y, or the
# village AABB bottom if nothing was hit.
func _find_ground_y_at(xz: Vector3) -> float:
	var bounds := _combined_aabb(_village_map) if _village_map else AABB()
	var fallback := bounds_bottom_y()
	var space := get_world_3d().direct_space_state
	var from := Vector3(xz.x, bounds.end.y + 4.0, xz.z)
	var to := Vector3(xz.x, bounds.position.y - 4.0, xz.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		print("[Main] no ground hit at %s, fallback Y=%.3f" % [xz, fallback])
		return fallback
	print("[Main] ground hit at %s Y=%.3f" % [xz, hit.position.y])
	return hit.position.y


# Scan a grid of candidate points and return one on real visible geometry.
func _find_clear_spawn() -> Vector3:
	var best := _village_center()
	var space := get_world_3d().direct_space_state
	var bounds := _combined_aabb(_village_map)
	var top_y := bounds.end.y + 4.0
	var bottom_y := bounds.position.y - 1.0
	var cx := bounds.get_center().x
	var cz := bounds.get_center().z
	var preferred_spawn := Vector2(-4.0, -14.0)
	var offsets := [Vector2(0, 0), Vector2(0.09, 0), Vector2(-0.09, 0), Vector2(0, 0.09), Vector2(0, -0.09)]
	var candidates: Array[Vector3] = []
	for gx in range(int(bounds.position.x) + 2, int(bounds.end.x) - 1, 2):
		for gz in range(int(bounds.position.z) + 2, int(bounds.end.z) - 1, 2):
			var clear := true
			var candidate_y := -INF
			for off in offsets:
				var px: float = gx + off.x
				var pz: float = gz + off.y
				var qg := PhysicsRayQueryParameters3D.create(
						Vector3(px, top_y, pz), Vector3(px, bottom_y, pz))
				qg.collide_with_bodies = true
				qg.collide_with_areas = false
				var hit := space.intersect_ray(qg)
				if hit.is_empty():
					clear = false
					break
				var normal: Vector3 = hit.normal
				if normal.y < 0.55:
					clear = false
					break
				candidate_y = max(candidate_y, hit.position.y)
				if candidate_y < bounds.position.y + 0.55:
					clear = false
					break
				var qo := PhysicsRayQueryParameters3D.create(
						Vector3(px, hit.position.y + 0.75, pz), Vector3(px, hit.position.y + 0.08, pz))
				qo.collide_with_bodies = true
				qo.collide_with_areas = false
				var ov := space.intersect_ray(qo)
				if not ov.is_empty() and ov.normal.y < 0.55:
					clear = false
					break
			if clear:
				candidates.append(Vector3(gx, candidate_y, gz))
	if not candidates.is_empty():
		# Prefer a point near the village centre so the player starts among the
		# streets/buildings, but penalize high roof-like surfaces.
		var best_score := -1.0
		var best_cand: Vector3 = candidates[0]
		var angles := [0.0, 0.785, 1.571, 2.356, 3.142, 3.927, 4.712, 5.498]
		for c in candidates:
			var min_clear := 100.0
			for a in angles:
				var dx: float = sin(a)
				var dz: float = cos(a)
				var qr := PhysicsRayQueryParameters3D.create(
						Vector3(c.x + dx * 0.2, c.y + 0.18, c.z + dz * 0.2),
						Vector3(c.x + dx * 2.0, c.y + 0.18, c.z + dz * 2.0))
				qr.collide_with_bodies = true
				qr.collide_with_areas = false
				var rh := space.intersect_ray(qr)
				var d: float = 2.0
				if not rh.is_empty():
					d = Vector2(c.x, c.z).distance_to(Vector2(rh.position.x, rh.position.z)) - 0.5
				min_clear = min(min_clear, d)
			var centre_distance := (c as Vector3).distance_to(Vector3(cx, 0, cz))
			var preferred_distance := Vector2(c.x, c.z).distance_to(preferred_spawn)
			var height_penalty: float = max(c.y - (bounds.position.y + 1.6), 0.0) * 0.5
			var score: float = min(min_clear, 1.6) - 0.08 * centre_distance - 0.55 * preferred_distance - height_penalty
			if score > best_score:
				best_score = score
				best_cand = c
		best = best_cand
		print("[Main] clear spawn found at %s (score=%.2f of %d candidates)" % [best, best_score, candidates.size()])
	else:
		print("[Main] no clear spawn candidate, using centre")
	return best


func _village_center() -> Vector3:
	var bounds := _combined_aabb(_village_map) if _village_map else AABB(Vector3.ZERO, Vector3(10, 1, 10))
	return bounds.get_center()


func bounds_bottom_y() -> float:
	var bounds := _combined_aabb(_village_map) if _village_map else AABB()
	return bounds.position.y


func _collect_meshes(root_node: Node) -> Array:
	var out: Array = []
	_collect_meshes_recursive(root_node, out)
	return out


func _collect_meshes_recursive(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes_recursive(child, out)


func _combined_aabb(root_node: Node) -> AABB:
	_force_update_3d_transforms(root_node)
	var meshes := _collect_meshes(root_node)
	if meshes.is_empty():
		return AABB()
	var has := false
	var result := AABB()
	for mesh in meshes:
		var mi: MeshInstance3D = mesh
		var ab := _global_aabb(mi)
		if not has:
			result = ab
			has = true
		else:
			result = result.merge(ab)
	return result


func _force_update_3d_transforms(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).force_update_transform()
	for child in node.get_children():
		_force_update_3d_transforms(child)


func _global_aabb(mesh: MeshInstance3D) -> AABB:
	var local := mesh.get_aabb()
	var xform := mesh.global_transform
	var points := [
		local.position,
		local.position + Vector3(local.size.x, 0.0, 0.0),
		local.position + Vector3(0.0, local.size.y, 0.0),
		local.position + Vector3(0.0, 0.0, local.size.z),
		local.position + Vector3(local.size.x, local.size.y, 0.0),
		local.position + Vector3(local.size.x, 0.0, local.size.z),
		local.position + Vector3(0.0, local.size.y, local.size.z),
		local.position + local.size,
	]
	var first: Vector3 = xform * points[0]
	var bounds := AABB(first, Vector3.ZERO)
	for index in range(1, points.size()):
		bounds = bounds.expand(xform * points[index])
	return bounds
