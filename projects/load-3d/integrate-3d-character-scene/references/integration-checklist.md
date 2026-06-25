# Integration Checklist

Use this checklist while implementing or reviewing imported character/scene integration.

## Asset Inspection

- Confirm imported model paths, root node names, mesh names, material/texture dependencies, and animation names.
- Record any import-time scale or rotation corrections.
- Inspect the character's visual forward direction. If the character walks sideways or backward, fix the model child rotation or movement-facing formula.
- Inspect the scene's likely walkable areas: roads, floors, stairs, sidewalks, bridges, interiors, doorways.

## Scale and Alignment

- Compare character height against doors, windows, benches, stairs, and roads.
- Match controller collision to visual body scale.
- Align the visual feet with the controller origin or with the bottom of the collision capsule.
- Tune speeds after scale is fixed. Do not compensate for wrong scale by only changing camera distance.

## Grounding

- Use gravity for vertical motion.
- Snap to the nearest valid floor below the controller only when falling or grounded.
- Reject ground hits with steep normals.
- Use step limits:
  - `max_step_up`: allows stairs and curbs, blocks walls.
  - `max_step_down`: keeps the player stuck to small descents, avoids snapping to distant lower roofs/streets.
- Validate foot contact with a ray from above the feet to below the feet and report the gap.

## Collision

- Static map: use trimesh or generated collision.
- Player: use a capsule or character controller, not mesh collision.
- Doors: isolate collision so it can be disabled when opened.
- Decorative foliage, tiny props, and broken scan fragments may need disabled or simplified collision.
- If the player pops backward:
  - Probe horizontally before moving.
  - Move in small steps.
  - Slide along side normals.
  - Stop on head-on normals.
  - Reduce unsafe `safe_margin` or overly large capsule radius only after confirming scale is correct.

## Camera and Controls

- Input should be camera-relative: forward moves toward the camera rig's forward direction projected onto the ground plane.
- Mouse/gamepad yaw should rotate the camera, not the whole map.
- Camera pivot follows the controller root.
- Camera collision prevents clipping into walls.
- Test from normal third-person distance and from a raised angle to reveal floating.

## Animations

- Loop locomotion animations.
- Do not restart walk animation every physics frame.
- Switch between idle/walk/run by intent or horizontal velocity.
- If the imported walk cycle has root motion, either consume it intentionally or disable it so the controller remains authoritative.

## Interactions

- Use tags/groups/metadata for doors and interactable props.
- Measure interaction primarily in horizontal distance, with a reasonable vertical tolerance for uneven maps.
- Opening a door must update collision and visuals/animation together.
- Closing a door should avoid trapping the player inside the door volume.

## Runtime Tests

Run the actual game and verify:

- The scene loads without missing textures or import errors.
- The character spawns on visible ground.
- Movement works in all four directions.
- The character does not drift, float, jitter, or suddenly step backward.
- Feet remain grounded when walking and when idle.
- Buildings/walls block movement.
- Doors/gates meant for traversal can open and close.
- Stairs/curbs work within expected step height.
- Camera follows the player and sees nearby environment instead of only showing a full-map overview.
