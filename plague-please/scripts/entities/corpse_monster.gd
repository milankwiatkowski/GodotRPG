extends CharacterBody2D
class_name CorpseMonster
## What an undisposed corpse turns into (see CorpseManager) - unlike
## DoppelgangerMonster's stalk-and-melee-a-patient behavior, this one
## hunts the player directly: chases whoever's in group "player" every
## physics frame, re-targeting each frame so it's never lost even
## mid-room. Follows the player across rooms too - CorpseManager respawns
## it in whichever room is current on every scene change (see
## TransitionScreen.change_scene(), which calls
## CorpseManager.on_room_entered()), the same way DoppelgangerMonster gets
## resummoned into Treatment Ward specifically, just generalized to
## "wherever the player currently is" instead of one fixed room.
##
## Slower than the player (speed 65 vs 90) so outrunning it is always
## possible - the threat is in cornering yourself or ignoring it, not raw
## speed. But it's not harmless if you let it catch up: once in
## MELEE_RANGE it plays its "attack" animation and lands
## DAMAGE_PER_HIT on RunManager.player_hp every ATTACK_COOLDOWN seconds
## for as long as you stay in range and don't fight back. Player
## interacting with it (catch()) ends the threat outright regardless of
## its own attack timing.

signal caught

const MELEE_RANGE := 22.0
const ATTACK_COOLDOWN := 1.5
const DAMAGE_PER_HIT := 8

@export var speed: float = 65.0

enum State { CHASING, ATTACKING }
var _state: State = State.CHASING
var _attack_cooldown: float = 0.0
var _facing_right: bool = true

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	add_to_group("corpse_monster")


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if _state == State.ATTACKING:
		velocity = Vector2.ZERO
		move_and_slide()
		return # animation-finished callback (_on_attack_finished) drives what happens next

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(&"idle")
		return

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() <= MELEE_RANGE:
		velocity = Vector2.ZERO
		move_and_slide()
		if _attack_cooldown <= 0.0:
			_start_attack()
		else:
			_update_animation(&"idle")
	else:
		velocity = to_player.normalized() * speed
		if to_player.x > 0.01:
			_facing_right = true
		elif to_player.x < -0.01:
			_facing_right = false
		move_and_slide()
		_update_animation(&"walk")


func _start_attack() -> void:
	_state = State.ATTACKING
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(&"attack"):
		if not sprite.animation_finished.is_connected(_on_attack_finished):
			sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)
		sprite.play(&"attack")
	else:
		_on_attack_finished()


func _on_attack_finished() -> void:
	# Only actually lands if the player's still in range when the swing
	# finishes - stepping back mid-animation dodges it.
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) <= MELEE_RANGE:
		RunManager.damage_player(DAMAGE_PER_HIT)
	_attack_cooldown = ATTACK_COOLDOWN
	_state = State.CHASING


func _update_animation(anim: StringName) -> void:
	if sprite == null:
		return
	sprite.flip_h = not _facing_right
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


## Called by Player when it interacts with this monster in range - fights
## it off outright (no HP system for enemies in this game, so "fight" is
## just "successfully interact with it"), same convention as
## DoppelgangerMonster.catch().
func catch() -> void:
	caught.emit()
