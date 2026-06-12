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

func _play_anim(next: String) -> void:
	if next == current_anim or _anim_player == null:
		return
	current_anim = next
	_anim_player.play(next, 0.15)

func flash_muzzle() -> void:
	_shoot_flash.light_energy = 4.0
	_shot_recently = 0.35

# --- network sync --------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable")
func _sync_state(pos: Vector3, yaw: float, anim: String) -> void:
	global_position = pos
	rotation.y = yaw
	_play_anim(anim)

# --- life & death ----------------------------------------------------------------

func is_dead() -> bool:
	return health != null and health.is_dead()

func _on_died() -> void:
	_play_anim("Death_A")
	collision_layer = 0          # corpses stop blocking bullets
	get_tree().call_group("hud", "flash_message", display_name + " is down")
