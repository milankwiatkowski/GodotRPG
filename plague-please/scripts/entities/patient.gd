extends CharacterBody2D
class_name Patient
## A walk-in patient: spawned by PatientQueue (see
## scripts/world/patient_queue.gd), walks to the reception queue point,
## waits there until the player interacts with them (Player._try_interact()),
## and leaves once IntakePanel resolves a verdict through
## RunManager.resolve_case(). No real pathfinding - each leg of a walk is a
## straight line - but dismiss() accepts an optional waypoint path so a
## multi-leg walk (e.g. through a corridor doorway) still avoids cutting
## through walls; see IntakePanel.INTAKE_TO_TREATMENT_PATH.

signal arrived_at_queue
signal dismissed
## Fires right as a LEAVING patient actually vanishes (see _on_reached()),
## as opposed to `dismissed` which fires the moment dismiss()/die() is
## *called* (used to free the queue slot immediately). IntakePanel uses
## this to delay HuntManager.start_hunt() until a wrongly-admitted
## doppelganger has actually reached Treatment Ward - "you get alerted
## after it turns," not the instant you click Admit.
signal gone

enum State { WALKING_IN, WAITING, LEAVING }

## One picked per CaseFile (see CaseFile.portrait_path / _apply_portrait())
## so the same 3-12 people waiting in a room don't all look identical -
## and, critically, so the *same* patient doesn't get a new random face
## every time their node is recreated (room reload, Intake -> Treatment
## hand-off). First batch is MinifolksVillagers (generic townsfolk);
## second is MinifolksVillagers2 (named trades) - same 32x32 idle/walk
## layout, just more faces to draw from.
const PORTRAITS: Array[String] = [
	"res://resources/sprite_frames/patient_nobleman.tres",
	"res://resources/sprite_frames/patient_noblewoman.tres",
	"res://resources/sprite_frames/patient_oldman.tres",
	"res://resources/sprite_frames/patient_oldwoman.tres",
	"res://resources/sprite_frames/patient_peasant.tres",
	"res://resources/sprite_frames/patient_villagerman.tres",
	"res://resources/sprite_frames/patient_villagerwoman.tres",
	"res://resources/sprite_frames/patient_worker.tres",
	"res://resources/sprite_frames/patient_blacksmith.tres",
	"res://resources/sprite_frames/patient_gatherer.tres",
	"res://resources/sprite_frames/patient_gravedigger.tres",
	"res://resources/sprite_frames/patient_hunter.tres",
	"res://resources/sprite_frames/patient_lumberjack.tres",
	"res://resources/sprite_frames/patient_merchant.tres",
	"res://resources/sprite_frames/patient_miner.tres",
	"res://resources/sprite_frames/patient_nun.tres",
	"res://resources/sprite_frames/patient_suspiciousmerchant.tres",
	"res://resources/sprite_frames/patient_thief.tres",
]

static func pick_random_portrait() -> String:
	return PORTRAITS[randi() % PORTRAITS.size()]

@export var speed: float = 50.0

## The generated case this patient represents. Set by setup().
var case: CaseFile

var _state: State = State.WALKING_IN
var _target: Vector2
var _entry_point: Vector2
var _facing_right: bool = true

## Remaining waypoints after `_target` for a multi-leg walk (see
## dismiss()'s `path` param) - popped one at a time as each leg is
## reached, so a route can dodge a wall corner instead of cutting through
## it on one straight line.
var _remaining_path: Array[Vector2] = []

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("patients")
	if prompt_label:
		prompt_label.visible = false


## Case is set by the time this runs (setup()/setup_waiting() call it
## after assigning `case`) - unlike the old _ready()-time random pick,
## this reuses case.portrait_path if it's already set (same case seen in
## a different room, or the room reloaded) and only rolls a new one the
## first time a case is ever actually displayed.
func _apply_portrait() -> void:
	if sprite == null or case == null:
		return
	if case.portrait_path == "":
		case.portrait_path = pick_random_portrait()
	sprite.sprite_frames = load(case.portrait_path)
	sprite.play(&"idle")


## Called by PatientSpawner right after instancing and positioning this
## patient at its entry point. queue_position is where it walks to and
## waits (global coordinates).
func setup(new_case: CaseFile, queue_position: Vector2) -> void:
	case = new_case
	name = case.patient_name if case and case.patient_name != "" else "Patient"
	_entry_point = global_position
	_target = queue_position
	_apply_portrait()


## Restores a patient RoomState already had a case for (the room was left
## and re-entered while they were still waiting) - drops straight into
## WAITING at the caller-set position instead of walking in, so it reads
## as "they were here the whole time," not a fresh arrival. Caller sets
## global_position first, same as it does before calling setup().
## leave_target is used if this patient is later dismissed, same as
## setup()'s spawn point.
func setup_waiting(existing_case: CaseFile, leave_target: Vector2) -> void:
	case = existing_case
	name = case.patient_name if case and case.patient_name != "" else "Patient"
	_entry_point = leave_target
	_state = State.WAITING
	if prompt_label:
		prompt_label.visible = true
	_apply_portrait()


func is_waiting() -> bool:
	return _state == State.WAITING


## Called by IntakePanel once the player has admitted/rejected this
## patient - walks out, then frees itself. Defaults to walking back the
## way they came in; IntakePanel passes an explicit final exit_target plus
## a `path` of intermediate waypoints for a sick (or wrongly-admitted
## doppelganger) patient instead, so they visibly head off toward
## Treatment Ward via the corridor doorway rather than back out the way
## they arrived (the same CaseFile then reappears as a fresh Patient node
## waiting in Treatment's own queue - see RoomState.push() /
## PatientQueue._spawn_into_slot() - same portrait via
## CaseFile.portrait_path, so it reads as the same person continuing
## their walk, not two different people).
func dismiss(exit_target: Vector2 = Vector2.INF, path: Array[Vector2] = []) -> void:
	if _state == State.LEAVING:
		return
	if not path.is_empty():
		_remaining_path = path.duplicate()
		_remaining_path.append(exit_target)
		_target = _remaining_path.pop_front()
	else:
		_target = exit_target if exit_target != Vector2.INF else _entry_point
		_remaining_path.clear()
	_state = State.LEAVING
	if prompt_label:
		prompt_label.visible = false
	dismissed.emit()


## Death (doppelganger_monster.gd melee-killing whoever it's caught up to,
## or a sickness death_timer running out - PatientQueue._tick_death_timers()).
## No calm walk-out like dismiss() - frees the queue slot the same way
## (dismissed signal), then hands off to CorpseManager to leave a body
## behind instead of just vanishing - see CorpseManager.register_corpse().
func die() -> void:
	if _state == State.LEAVING:
		return
	SFX.play(&"kill")
	if prompt_label:
		prompt_label.visible = false
	dismissed.emit()
	RunManager.day_stats["died"] += 1
	CorpseManager.register_corpse(case, global_position)
	queue_free()


func _physics_process(_delta: float) -> void:
	if _state == State.WAITING:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation()
		return
	_step_toward(_target)
	_update_animation()


func _step_toward(target: Vector2) -> void:
	var to_target := target - global_position
	if to_target.length() < 3.0:
		velocity = Vector2.ZERO
		move_and_slide()
		_on_reached()
	else:
		velocity = to_target.normalized() * speed
		move_and_slide()
		if to_target.x > 0.01:
			_facing_right = true
		elif to_target.x < -0.01:
			_facing_right = false


func _update_animation() -> void:
	if sprite == null:
		return
	sprite.flip_h = not _facing_right
	var anim := &"walk" if velocity.length() > 0.01 else &"idle"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _on_reached() -> void:
	if _state == State.WALKING_IN:
		_state = State.WAITING
		if prompt_label:
			prompt_label.visible = true
		arrived_at_queue.emit()
	elif _state == State.LEAVING:
		if not _remaining_path.is_empty():
			_target = _remaining_path.pop_front()
			return
		gone.emit()
		queue_free()
