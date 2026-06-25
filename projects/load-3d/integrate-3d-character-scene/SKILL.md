---
name: integrate-3d-character-scene
description: Integrate externally imported 3D game characters with imported scene or map models. Use when Codex needs to combine GLB/GLTF/FBX/OBJ character assets and environment assets in a game engine such as Godot, Unity, or Unreal, including scale matching, coordinate alignment, animation setup, player controls, camera follow, gravity/grounding, collision generation, doors or interactive props, spawn placement, and runtime validation.
---

# Integrate 3D Character Scene

## Overview

Use this skill to turn separately imported character and scene models into a playable 3D game setup. Prioritize a working runtime result over a visually correct editor preview: the player should stand on the visible ground, move in expected camera-relative directions, collide with walls/props, use appropriate animations, and remain readable at game scale.

For a detailed validation checklist, read `references/integration-checklist.md` when implementing or reviewing the integration.

## Workflow

1. Inspect the imported assets before coding.
   - Identify model file types, root node transforms, mesh names, animation names, texture dependencies, and units.
   - Determine which asset is the player character and which asset is the playable scene/map.
   - Check whether either asset is already scaled, rotated, or offset by import settings or scene nodes.

2. Establish a shared world convention.
   - Choose the engine's forward axis and up axis. In Godot, use `Y` up and typically `-Z` forward for camera-relative controls.
   - Normalize scale with visible comparisons: character height should be plausible against doors, stairs, roads, and buildings.
   - Keep gameplay scale on the controller/collision nodes, not only on the visual mesh. If the visual model is scaled, adjust capsule radius/height, camera offsets, speed, and interaction distances consistently.

3. Build the player as a controller root plus visual child.
   - Use a physics/controller root (`CharacterBody3D`, character controller, or pawn/capsule) as the authoritative position.
   - Put the imported character model under a child visual node so visual scale/rotation corrections do not corrupt physics.
   - Add a collision capsule sized to the character's body, with its feet aligned to the controller origin or a clearly documented foot offset.
   - Locate and configure imported animations. Loop idle/walk/run animations; avoid restarting walk animation every frame.

4. Generate or assign scene collision deliberately.
   - For static imported maps, generate mesh/trimesh collision for ground, roads, walls, stairs, and large buildings.
   - Do not rely on a fake flat floor once real map geometry exists; it hides floating feet and makes stairs impossible.
   - Exclude or simplify decorative meshes if they produce noisy collision.
   - For doors and movable props, keep them identifiable by name, group, tag, or metadata so their collision can be toggled independently.

5. Implement movement relative to the camera.
   - Convert keyboard/gamepad input into a world-space direction using camera yaw.
   - Apply acceleration/deceleration instead of teleport-like position changes.
   - Face the visual model toward the movement direction, correcting for any imported model forward-axis mismatch.
   - Keep animation state based on actual movement intent or velocity, and ensure walk/run loops continue smoothly while moving.

6. Ground the character with gravity plus surface snapping.
   - Apply gravity when not on the floor.
   - Raycast or shapecast downward from near the controller to keep feet on the visible surface.
   - Limit snap height with `max_step_up` and `max_step_down` so the player can use stairs but cannot climb walls.
   - Validate from high and low camera angles; floating is often hidden from a normal third-person camera.

7. Make collision stable on imported geometry.
   - Imported city/village meshes often contain dense triangles, roof edges, and narrow seams. If the character jitters or flashes backward, add a horizontal precheck, shape cast, or small-step movement pass before letting engine collision resolution push the controller.
   - Ignore floor-like normals for horizontal obstacle tests.
   - Slide along shallow side collisions, but stop on near head-on wall hits.
   - If the player starts trapped, move the spawn point to a raycast-confirmed open ground location instead of weakening collision globally.

8. Set up the camera as a third-person follow camera.
   - Parent a pivot or rig to the player/controller, not to the visual mesh.
   - Use mouse/gamepad yaw and pitch constraints.
   - Add camera collision so the camera does not clip through buildings.
   - Avoid starting with a top-down full-map view unless the target game design requires it.

9. Add scene interaction where collision blocks intended traversal.
   - Doors should be explicit interactive objects, not permanent invisible blockers.
   - Use a reachable interaction distance based on horizontal distance plus reasonable vertical tolerance.
   - When a door opens, update both visibility/animation and collision state. When it closes, restore collision.
   - Prefer animation or rotation for final polish, but a visibility/collision toggle is acceptable for a first playable pass.

10. Test by running the game, not only by inspecting the editor.
    - Launch the project and exercise movement in all directions.
    - Check feet from a raised camera view.
    - Walk into walls, doorways, stairs, curbs, and props.
    - Verify no backward popping, no wall penetration, no floating, no stuck spawn, and no animation freeze during continuous walking.

## Godot Implementation Notes

- Use `CharacterBody3D` for the player root when building a conventional third-person controller.
- Use `MeshInstance3D.create_trimesh_collision()` only for static scene geometry. For dynamic or interactive props, use simpler collision shapes when practical.
- Use `PhysicsRayQueryParameters3D` or shape queries for ground and obstacle probes.
- Set `floor_snap_length`, `floor_max_angle`, and `safe_margin` intentionally; imported mesh scale changes often require retuning these.
- Keep the camera rig independent from the imported character skeleton.
- Use groups or metadata such as `interactive_doors` and `door_closed` for imported mesh parts that need gameplay behavior.

## Completion Criteria

Do not consider the integration done until the player can:

- Spawn on real visible ground in an open area.
- Move forward/back/left/right relative to the camera.
- Stay grounded on streets, slopes, and stairs within configured step limits.
- Collide with buildings and walls without tunneling or sudden backward flashes.
- Open or pass through intended doors or gates.
- Show continuous idle/walk/run animations matching movement.
- Be viewed by a following camera at normal third-person distance.
