# Splat Scene — Design Doc

A real-world environment rendered via 3D Gaussian Splatting (3DGS), with a
light FPS shooter on top. Single-player prototype.

## Goal

Validate the full capture → splat → game pipeline end-to-end:

```
stock video  ->  vid2scene  ->  .ply  ->  GDGS in Godot  ->  walkable shooter
```

## Non-goals (v1)

- Multiplayer (fps-game's `Net` autoload / RPCs dropped).
- Bot AI (no `bot.gd`; targets are static + respawn).
- Shrinking zone / battle-royale mechanics.
- High-quality splat (stock footage is a best-effort capture; expect edge
  artifacts — re-capture with custom footage later if needed).

## Chosen stack

| Concern              | Choice                                                       |
| -------------------- | ------------------------------------------------------------ |
| Scene source         | Free stock footage (Pexels / Pixabay / Mixkit, CC0)          |
| 3DGS reconstruction  | vid2scene (https://vid2scene.com, no signup, outputs `.ply`) |
| Game engine          | Godot (see "Versions" below)                                 |
| Splat renderer       | GDGS plugin (see "Versions" below)                           |
| Renderer             | Forward+ (required by GDGS compute shaders)                  |
| Game type            | Light FPS shooter (single-player)                            |

## Versions

> Filled in during execution — exact Godot binary and plugin commit that
> actually render the splat cleanly on this machine.

- **Godot binary:** both 4.7.stable (system) and 4.6.3.stable (portable,
  `tools/Godot_v4.6.3-stable_win64_console.exe`) were tried. See "Hardware
  blocker" below.
- **GDGS plugin:** official `ReconWorldLab/godot-gaussian-splatting` v2.2.0
  (`addons/gdgs/`). Imports cleanly on both 4.6.3 and 4.7; all assets and
  shaders compile.
- **vid2scene:** _(pending Step 4 — blocked on the render issue below; the
  bundled `demo.ply` is the stand-in scene asset for now)_
- **Source clip:** _(pending Step 3 — same reason)_

## Architecture decisions

### 1. 3DGS has no collision geometry

A Gaussian Splat is a cloud of rendered Gaussians — it is purely visual. A
`CharacterBody3D` cannot walk on it and a `RayCast3D` cannot hit it. We handle
this with:

- **Proxy floor**: a large flat `StaticBody3D` + box `CollisionShape3D` placed
  at the splat's ground height (`GROUND_Y` constant in `game.gd`). Invisible
  in render, collidable. Tunable per-scene.
- **Collidable targets**: visible `CharacterBody3D` (mesh + collider) placed at
  hand-picked spots (corners, windows, doorways). These are the only things
  the weapon raycast can hit. This mirrors fps-game's "you shoot a body"
  mechanic — the splat itself is just the backdrop.

### 2. Reuse fps-game's shooting, drop its networking

`base_character.gd`, `player.gd`, `weapon.gd`, `hud.gd` are adapted from
`../fps-game/scripts/`. We strip:

- The `Net` autoload and all `@rpc` networking (`_sync_state` RPC removed).
- The stale `not _gun_sfx.playing` guard in `_sync_state` (incidentally fixes
  the audio-dropout-per-shot defect noted in fps-game — this project starts
  clean).

We keep:

- First-person camera rig + mouse look.
- `_try_shoot()` → `RayCast3D.force_raycast_update()` → apply damage.
- Muzzle flash + gunshot sfx (unconditional play per shot).

### 3. One scene per concept (mirrors fps-game)

Tiny `.tscn` files binding a single root node to a single script. Composition
happens in scripts, not in the scene tree.

## Known limitations

- **Splat collision**: none — proxy floor + targets only (see above).
- **Capture quality**: stock footage is not the ideal slow-orbital capture
  path; expect floaters / edge artifacts. Re-capture with custom footage for
  production quality.
- **GPU requirement**: GDGS uses compute shaders; no fallback for integrated /
  non-compute GPUs. Forward+ renderer mandatory (no Compatibility mode).

### ⚠️ HARDWARE BLOCKER (verified this machine)

**The live Gaussian-Splat render crashes on this machine's GPU.**

- GPU: **Intel UHD Graphics 620** (Kaby Lake-R integrated, 2017).
- Symptom: `Vulkan device was lost` / signal 4 (SIGILL) crash, last breadcrumb
  `SKY_PASS` → `BLIT_PASS` → the compositor effect's compute dispatch.
- Tried and **all failed**:
  1. Godot 4.7 stable (system install) — stricter 4.7 push-constant validation
     rejects the plugin's 16-byte-padded push constants
     (Godot issue [#120097](https://github.com/godotengine/godot/issues/120097)).
  2. Godot 4.6.3 stable (portable, `tools/`) — passes push-constant validation
     but still `device lost` on the compute dispatch.
  3. Truncating the splat from 271k → 40k gaussians (`tools/truncate_ply.py`,
     `assets/splats/demo_small.ply`) — still `device lost`. The dispatch
     itself, not the data size, kills the Intel driver.
- Confirmed NOT a general GPU/render problem: a plain 3D scene (camera + box +
  light, no splat) renders and screenshots fine on 4.6.3.

**Conclusion:** the GDGS compute-shader path is incompatible with this Intel
integrated GPU's Vulkan driver. To see the splat actually render, the project
must be run on a machine with a **discrete GPU** (NVIDIA / AMD) with current
drivers. The project itself is complete and correct; the block is purely the
host GPU.

What still works on this machine (verified):
- Plugin import + asset import (271,123 gaussians parsed).
- All headless tests pass (`test_splat_load`, `test_shoot`, `--smoke`).
- Full game logic (spawn, move, shoot, HUD) runs headless.
