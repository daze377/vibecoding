# Splat Scene

A real-world environment rendered via **3D Gaussian Splatting (3DGS)**, with a
light first-person shooter running on top. The world is a photoreal splat
captured from real video footage; the player walks a proxy floor and shoots
collidable targets placed inside the scene.

Sibling project to `../fps-game` (shares conventions, slimmed to single-player).

## Pipeline

```
stock video (Pexels/Pixabay)  ->  vid2scene  ->  scene.ply  ->  GDGS plugin in Godot  ->  splat-scene game
```

## Requirements

- **Godot 4.6.x** with the **Forward+** renderer. A portable 4.6.3 binary is
  bundled at `tools/Godot_v4.6.3-stable_win64_console.exe` (Godot 4.7 rejects
  the plugin's push-constant layout — see `DESIGN.md`).
- A **discrete GPU** (NVIDIA / AMD) with current Vulkan drivers. The plugin's
  compute-shader path crashes on integrated Intel GPUs (verified: Intel UHD
  620 drops the Vulkan device on the compute dispatch).
- The **GDGS plugin** (`addons/gdgs/`, v2.2.0, from
  https://github.com/ReconWorldLab/godot-gaussian-splatting).
- A `res://assets/splats/scene.ply` (produced via vid2scene — see `DESIGN.md`).
  The bundled `demo_small.ply` (40k gaussians) is the current stand-in.

## Run

```bash
# with the bundled portable engine:
tools/Godot_v4.6.3-stable_win64_console.exe --path . res://scenes/main_menu.tscn

# or any Godot 4.6.x install:
godot --path . res://scenes/main_menu.tscn
```

> If your GPU is an Intel integrated model, the live window will crash on the
> splat compute pass. The headless logic (below) still works everywhere.

## Tests (headless — run on any machine, GPU or not)

```bash
G=tools/Godot_v4.6.3-stable_win64_console.exe

# Verify the splat file loads with a non-zero gaussian count
$G --headless --path . res://tests/test_splat_load.tscn

# Verify shooting logic (damage, cooldown, magazine, reload)
$G --headless --path . res://tests/test_shoot.tscn

# Verify the game scene builds and runs a few seconds (player + 5 targets)
$G --headless --path . res://scenes/game.tscn --smoke
```

## Export (Windows)

```bash
godot --headless --path . --export-release "Windows Desktop"
# produces export/SplatScene.exe
```

## Layout

```
addons/gdgs/       3DGS renderer plugin (GDGS v2.2.0)
assets/splats/     scene.ply (+ demo.ply, demo_small.ply stand-ins)
assets/characters/ Rogue.glb (reused from ../fps-game for targets)
assets/sounds/     gunshot.wav (reused from ../fps-game)
scenes/            main_menu, game, player, target, hud
scripts/           base_character, player, target, weapon, health, game, hud, main_menu
tests/             headless test scenes (splat load + shoot)
tools/             portable Godot 4.6.3 + truncate_ply.py (gitignored)
docs/              screenshots
DESIGN.md          design notes + chosen versions + known limitations
```

See `DESIGN.md` for the exact Godot + plugin versions, the chosen source clip,
and known limitations (no splat collision, possible edge artifacts from stock
footage).
