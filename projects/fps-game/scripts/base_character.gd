# Everything a body in the arena shares — players and bots alike.
# A bot is just this body with a different brain (task-23.md §5).
class_name BaseCharacter
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_SPEED := 4.5
const SYNC_INTERVAL := 0.05

var display_name := "?"
var model_path := "res://assets/characters/Knight.glb"
var health: Health
var current_anim := "Idle"
var _anim_player: AnimationPlayer
var _shoot_flash: OmniLight3D
var _gun_sfx: AudioStreamPlayer3D
var _sync_accum := 0.0
var _shot_recently := 0.0

func _ready() -> void:
	collision_layer = 2          # "characters" layer — bullets look for this
	_build_body()
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.died.connect(_on_died)

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	var model: Node3D = load(model_path).instantiate()
	model.name = "Model"
	model.rotation.y = PI       # GLB faces +Z; Godot forward is -Z
	add_child(model)
	_anim_player = model.find_child("AnimationPlayer", true, false)

	_shoot_flash = OmniLight3D.new()
	_shoot_flash.light_color = Color(1.0, 0.85, 0.4)
	_shoot_flash.light_energy = 0.0
	_shoot_flash.position = Vector3(0, 1.4, -0.6)
	add_child(_shoot_flash)

	# 3D gunshot audio, positioned at the muzzle. Attenuation makes distant
	# gunshots (other players, bots across the arena) quieter.
	_gun_sfx = AudioStreamPlayer3D.new()
	_gun_sfx.name = "GunSfx"
	_gun_sfx.stream = load("res://assets/sounds/gunshot.wav")
	_gun_sfx.position = Vector3(0, 1.4, -0.6)
	_gun_sfx.unit_size = 8.0          # how far the sound carries
	_gun_sfx.max_db = 2.0
	# Polyphonic mode: every shot gets its own voice, so rapid fire never
	# drops a shot to a still-playing tail or a stop()/play() race.
	_gun_sfx.max_polyphony = 6
	_gun_sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	_gun_sfx.bus = "Master"
	add_child(_gun_sfx)

	var label := Label3D.new()
	label.text = display_name
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.name = "NameLabel"
	add_child(label)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority() and not is_dead():
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()
		_update_animation()
	if is_multiplayer_authority():
		_sync_accum += delta
		if _sync_accum >= SYNC_INTERVAL:
			_sync_accum = 0.0
			_sync_state.rpc(global_position, rotation.y, current_anim)
	_shot_recently = maxf(_shot_recently - delta, 0.0)
	_shoot_flash.light_energy = maxf(_shoot_flash.light_energy - delta * 40.0, 0.0)

# --- animation ---------------------------------------------------------------

func _update_animation() -> void:
	var next := "Idle"
	if is_dead():
		next = "Death_A"
	elif _shot_recently > 0.0:
		next = "2H_Ranged_Shoot"
	else:
		var speed := Vector2(velocity.x, velocity.z).length()
		if speed > 6.0:
			next = "Running_A"
		elif speed > 0.5:
			next = "Walking_A"
	_play_anim(next)
	# keep the leg cadence synced while moving (speed changes each frame)
	if _anim_player and next in ["Running_A", "Walking_A"]:
		_sync_playback_speed(next)

func _play_anim(next: String) -> void:
	if next == current_anim or _anim_player == null:
		return
	current_anim = next
	# Movement / idle clips must loop, or the legs freeze after one cycle
	# (these GLB clips are authored as loop_mode=NONE).
	if next in ["Idle", "Unarmed_Idle", "2H_Melee_Idle",
			"Walking_A", "Walking_B", "Walking_Backwards",
			"Running_A", "Running_B",
			"Running_Strafe_Left", "Running_Strafe_Right",
			"Jump_Idle"]:
		_force_loop(next)
	_anim_player.play(next, 0.15)
	_sync_playback_speed(next)

func _force_loop(anim_name: String) -> void:
	if not _anim_player.has_animation(anim_name):
		return
	var anim: Animation = _anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR

func _sync_playback_speed(anim_name: String) -> void:
	# Match the leg cadence to how fast we're actually moving so feet plant on
	# the ground instead of moonwalking.
	var speed := Vector2(velocity.x, velocity.z).length()
	var scale := 1.0
	if anim_name == "Running_A":
		scale = clampf(speed / SPRINT_SPEED, 0.6, 1.4)
	elif anim_name == "Walking_A":
		scale = clampf(speed / WALK_SPEED, 0.6, 1.4)
	_anim_player.speed_scale = scale

func flash_muzzle() -> void:
	_shoot_flash.light_energy = 4.0
	_shot_recently = 0.35
	if _gun_sfx:
		# Polyphonic: each shot plays on its own voice, so a burst always
		# has one bang per round with no stop()/play() race.
		_gun_sfx.play()

# --- network sync --------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable")
func _sync_state(pos: Vector3, yaw: float, anim: String) -> void:
	global_position = pos
	rotation.y = yaw
	# a freshly-fired shot arrives via the animation name — flash & bang on
	# every client so remote gunfire is seen and heard.
	if anim == "2H_Ranged_Shoot" and current_anim != "2H_Ranged_Shoot":
		_shoot_flash.light_energy = 4.0
		if _gun_sfx and not _gun_sfx.playing:
			_gun_sfx.play()
	_play_anim(anim)

# --- life & death ----------------------------------------------------------------

func is_dead() -> bool:
	return health != null and health.is_dead()

func _on_died() -> void:
	_play_anim("Death_A")
	collision_layer = 0          # corpses stop blocking bullets
	get_tree().call_group("hud", "flash_message", display_name + " is down")
