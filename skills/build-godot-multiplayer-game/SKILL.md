---
name: build-godot-multiplayer-game
description: Build a 3D multiplayer shooter in Godot 4 the engineering-first way — scope a big game down to a slice, use free CC0 character models with real animations, share one body between players and bots, run all authority on the host, and test the game headless from the command line. Use when asked to build a Godot game, a battle-royale/FPS prototype, add bots or multiplayer to a game, or make a game project testable in CI. Worked example: projects/fps-game (Last Circle, a PUBG-style slice — task-23).
---

# Build a Godot 3D multiplayer game (the Last Circle way)

Every practice below was executed and verified end-to-end while building
**Last Circle** (`projects/fps-game`): real animated 3D characters, 5 bots
with a 3-state brain, host/join multiplayer, a shrinking zone, and a
last-one-standing win — all provable from the command line with no window.
Verified on Godot 4.5 and 4.6.3. Copy that project as a template.

## 1. Scope like a studio: big game → slice

Write a two-column table — *what PUBG has* vs *what our slice has* — into
a design file (`task-23.md`) before any code. The slice: one arena, 6
combatants, one weapon, one zone that shrinks on a timer, no loot, no
vehicles, no lobby. Every cut is a row in the table with a reason, so
"add it later" stays an informed decision instead of scope creep.

## 2. Assets: CC0 packs first, real models from day one

Order of preference: **CC0 packs** (KayKit, Kenney — no license risk, game
-ready glTF with animations baked in) → Mixamo (free rigs/animations,
needs conversion) → Blender (only for what you can't download). Last
Circle uses KayKit characters; the `.glb` drops into `assets/` and Godot
imports it with its `AnimationPlayer` intact — play `"Idle"`,
`"Walking_A"`, `"Running_A"`, `"2H_Ranged_Shoot"`, `"Death_A"` by name.

Two facts that cost time when missed:

- **GLB models face +Z; Godot's forward is -Z.** Set
  `model.rotation.y = PI` when attaching, or every character walks
  backwards.
- **Import before any headless run on a fresh machine:**
  `godot --headless --path . --import` — otherwise scenes fail to load.

## 3. Architecture: a bot is a player with a different brain

One `BaseCharacter` (CharacterBody3D) owns the body: capsule + model +
animation switching + health + 20 Hz state sync. Then:

- `player.gd` extends it with an *input* brain (mouse/WASD, SpringArm3D
  over-the-shoulder camera).
- `bot.gd` extends it with an *FSM* brain — **three states are plenty**:
  WANDER (random point, walk) → CHASE (nearest visible target) → ENGAGE
  (stop, shoot with imposed inaccuracy). More states added nothing in
  playtests.

Because both share one body, every rule (damage, zone, animations, death)
is written once and bots automatically exercise the same code paths the
player does — which is what makes bot-only CI matches meaningful.

## 4. Multiplayer: the host is the referee

All authority lives on the host (peer 1). Shooters *request*, the referee
*decides*:

- A hit is `request_hit.rpc_id(1, target_path, damage)` — clients never
  apply damage locally. The host clamps damage server-side
  (`mini(damage, Weapon.DAMAGE)`) so a hacked client gains nothing.
- The host owns spawning, the zone, and the win check; results replicate
  via `@rpc("authority")` calls.
- Bodies sync position/yaw/animation at 20 Hz (`SYNC_INTERVAL 0.05`)
  with an unreliable RPC — smooth enough, and lost packets don't matter.
- On `peer_connected`, first replay the existing roster to the newcomer
  (`rpc_id(peer_id, …)` per body), *then* spawn their body everywhere.

Late-join, host-quit, and same-machine two-instance tests all pass on
this model with zero reconciliation code.

## 5. Make the game testable from the command line

The single highest-leverage practice. Three layers, all headless:

1. **Rule tests** — a test scene (`tests/test_rules.tscn`) asserting pure
   rules: fire cooldown, magazine, reload, damage clamp, death-fires-once,
   zone radii match the design doc.
   `godot --headless --path . res://tests/test_rules.tscn`
2. **Smoke / botmatch flags** — the real game scene reads CLI args
   (`OS.get_cmdline_user_args()`, args after `--`): `--smoke` (run 8 s,
   print player count, exit 0), `--botmatch` (bots only; must end with
   ≤1 survivor inside 180 s — this is the win condition proving itself),
   `--mp-host` / `--mp-join` (two processes on one machine prove real
   networking).
3. **Screenshot flags** — `--shot=path.png` and `--menu-shot=path.png`
   stage a frame (pose the camera *and* the actors deterministically) and
   save the viewport. Needs a real window: run these *without*
   `--headless`. These keep README/slide images honest after UI changes.

Print a single grep-able verdict line (`SMOKE OK: …`, `BOTMATCH OK: …`)
and exit non-zero on failure so any CI can consume it.

## 6. UI that survives any window size

Build menu/HUD in code with anchors, never hard-coded pixel positions,
and set `window/stretch/mode="canvas_items"` + `aspect="expand"` in
project.godot. Hard-won specifics:

- To center a variable-width element (a "zone shrinks in Ns" pill), put
  it in a full-width `CenterContainer` strip — `set_anchors_preset` on a
  bare label keeps its old rect and it lands top-left.
- Theme programmatically with `StyleBoxFlat` overrides (bg color, corner
  radius, content margins) — no .theme resource needed for a small game.
- Seed procedural content (`rng.seed = 23`) so every peer builds the
  identical arena and screenshots stay comparable.

## 7. Windows + Godot CLI notes

- Use the `_console.exe` binary for terminal work — the regular exe
  detaches and swallows output.
- A downloaded "Godot_vX_win64.exe" path may actually be the *extracted
  folder*; the binary is inside it.
- An `ObjectDB instances leaked` warning on quit after a botmatch is
  noise from abrupt exit, not a test failure.
