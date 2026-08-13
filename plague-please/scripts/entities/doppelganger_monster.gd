extends CharacterBody2D
class_name DoppelgangerMonster
## The doppelganger's true form, loose in Treatment Ward after slipping
## past reception undetected. scripts/systems/doppelganger_hunt.gd
## (HuntManager) owns the catch/escape timing and consequences; this node
## owns its own predation - it actively hunts down the patients waiting
## to be cured, one at a time, rather than a room-wide timer picking a
## random victim out of thin air:
##
## SEEKING - no current target (or the last one's gone/no longer waiting):
## picks the nearest waiting Patient and walks toward it.
## In range (MELEE_RANGE) - stops, plays the "attack" animation, and
## after ATTACK_COOLDOWN seconds since its last kill (so it's never
## faster than one patient every ATTACK_COOLDOWN seconds, no matter how
## quickly it reaches the next one) actually kills them
## (Patient.die()) and goes back to SEEKING for a new target.
##
## Player interacting with it (catch()) ends the hunt outright regardless
## of what it's doing.
##
## It never leaves Treatment Ward - it only ever considers waiting
## patients whose position is inside HuntManager's SPAWN_X_RANGE/
## SPAWN_Y_RANGE (Treatment's own interior, well clear of its walls - see
## doppelganger_hunt.gd), and its own position is clamped to that same box
## every frame so it can't wander out into the corridor even chasing a
## target near the doorway.

signal caught

enum State { SEEKING, ATTACKING }

const MELEE_RANGE := 22.0
const ATTACK_COOLDOWN := 5.0 # matches "not faster than 1 kill every 5 seconds"

@export var speed: float = 70.0

var _state: State = State.SEEKING
var _target: Patient = null
var _attack_ready_at: float = 0.0 # Time.get_ticks_msec()-scale cooldown, tracked in seconds via _process
var _cooldown_timer: float = 0.0
var _facing_right: bool = true

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	add_to_group("doppelganger_monster")


func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	if _state == State.ATTACKING:
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_to_treatment_ward()
		return # animation-finished callback (_on_attack_finished) drives what happens next

	if _target == null or not is_instance_valid(_target) or not _target.is_waiting():
		_target = _find_nearest_patient()

	if _target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(&"idle")
		_clamp_to_treatment_ward()
		return

	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() <= MELEE_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		if _cooldown_timer <= 0.0:
			_start_attack()
		else:
			_update_animation(&"idle")
	else:
		velocity = to_target.normalized() * speed
		if to_target.x > 0.01:
			_facing_right = true
		elif to_target.x < -0.01:
			_facing_right = false
		move_and_slide()
		_update_animation(&"walk")

	_clamp_to_treatment_ward()


## Only patients actually inside Treatment Ward count as prey - a waiting
## Intake patient never pulls this thing toward the doorway.
func _find_nearest_patient() -> Patient:
	var nearest: Patient = null
	var nearest_dist := INF
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(npc) or not npc.is_waiting():
			continue
		if not _inside_treatment_ward(npc.global_position):
			continue
		var dist: float = global_position.distance_to(npc.global_position)
		if dist < nearest_dist:
			nearest = npc
			nearest_dist = dist
	return nearest


func _inside_treatment_ward(pos: Vector2) -> bool:
	return pos.x >= HuntManager.SPAWN_X_RANGE.x and pos.x <= HuntManager.SPAWN_X_RANGE.y \
		and pos.y >= HuntManager.SPAWN_Y_RANGE.x and pos.y <= HuntManager.SPAWN_Y_RANGE.y


func _clamp_to_treatment_ward() -> void:
	global_position.x = clampf(global_position.x, HuntManager.SPAWN_X_RANGE.x, HuntManager.SPAWN_X_RANGE.y)
	global_position.y = clampf(global_position.y, HuntManager.SPAWN_Y_RANGE.x, HuntManager.SPAWN_Y_RANGE.y)


func _start_attack() -> void:
	_state = State.ATTACKING
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"attack"):
		if not sprite.animation_finished.is_connected(_on_attack_finished):
			sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
		sprite.play(&"attack")
	else:
		# No attack animation available for some reason - land the kill
		# immediately rather than getting stuck in ATTACKING forever.
		_on_attack_finished()


func _on_attack_finished() -> void:
	if _target and is_instance_valid(_target) and _target.is_waiting():
		_target.die()
	_target = null
	_cooldown_timer = ATTACK_COOLDOWN
	_state = State.SEEKING


func _update_animation(anim: StringName) -> void:
	if sprite == null:
		return
	sprite.flip_h = not _facing_right
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


## Called by Player when it interacts with this monster in range.
func catch() -> void:
	caught.emit()
