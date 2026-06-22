# A static shootable target placed inside the splat scene. Unlike the fps-game
# bot it has no AI — it just stands, takes damage, dies, and respawns so the
# player always has something to shoot. (3DGS itself can't be raycast-hit, so
# these collidable bodies are the things the weapon actually hits.)
extends BaseCharacter

const RESPAWN_DELAY := 4.0

var _respawn_at := -1.0
var _now := 0.0
var _spawn_position := Vector3.ZERO

func _ready() -> void:
	super()
	display_name = "Target"
	get_node("NameLabel").text = display_name
	_spawn_position = global_position
	health.died.connect(_on_target_died)

func _physics_process(delta: float) -> void:
	_now += delta
	# Hold the target in place (no movement input); only gravity + animation
	# from the base class apply. When dead, count down to a respawn.
	if is_dead() and _respawn_at > 0.0 and _now >= _respawn_at:
		_respawn()
	super(delta)

func _on_target_died() -> void:
	_respawn_at = _now + RESPAWN_DELAY

func _respawn() -> void:
	_respawn_at = -1.0
	global_position = _spawn_position
	# Refill health and re-enable collisions so the target is shootable again.
	health.hp = Health.MAX_HP
	health.changed.emit(health.hp)
	collision_layer = 2
	# Nudge the animation back to idle (the base _on_died plays Death_A).
	current_anim = ""
	_play_anim("Idle")
