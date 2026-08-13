extends Node
## Autoload (HuntManager): the "rare random event" - what happens after a
## doppelganger is wrongly admitted. It doesn't leave through Intake's
## exit like a normal patient; it heads for Treatment Ward - same as any
## admitted patient would - and reverts to its true form once it's there,
## so admitting one is the trigger, not a coin flip on its own.
## EventBus.doppelganger_hunt_started fires an alert (see hud.gd) telling
## the player to get to Treatment and catch it before the clock runs out.
##
## While it's loose, it doesn't just wander harmlessly - it actively
## hunts down waiting patients, one at a time, in melee (see
## doppelganger_monster.gd - the monster node owns its own
## targeting/attack pacing, not a room-wide timer). That patient is gone
## for good - no cure, no reward, ever. The longer the hunt drags on, the
## more it costs beyond the escape/suspicion penalty.
##
## A countdown starts immediately regardless of anything else going on;
## resume_if_active() (called once from hospital_map.gd's _ready(), plus
## after every TransitionScreen scene swap - Hospital/AlchemyLab/Intake/
## etc. are all one merged scene now, so this only actually matters for
## the Hospital <-> DayReportScreen <-> Hospital round trip) re-spawns the
## monster if a hunt is running and its node didn't survive that swap.

const HUNT_DURATION := 45.0
const CATCH_REPUTATION_BONUS := 3
const CATCH_GOLD_REWARD := 10
const CATCH_SUSPICION_RELIEF := -20
const ESCAPE_SUSPICION_PENALTY := 25

const MONSTER_SCENE: PackedScene = preload("res://scenes/patients/DoppelgangerMonster.tscn")

## Treatment Ward's interior in the merged map (see hospital_map.gd) -
## roughly x:[-160,160] y:[48,240]. Spawn well clear of the walls.
const SPAWN_X_RANGE := Vector2(-140.0, 140.0)
const SPAWN_Y_RANGE := Vector2(70.0, 220.0)

var active_case: CaseFile
var time_left: float = 0.0

var _monster: Node = null

func _process(delta: float) -> void:
	if active_case == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		_resolve(false)
		return
	if _monster != null and not is_instance_valid(_monster):
		# The scene it was in got unloaded (a Hospital <-> DayReportScreen
		# swap frees the whole tree) - resume_if_active() respawns it.
		_monster = null

func is_active() -> bool:
	return active_case != null

## Starts (or restarts) the hunt for this case and spawns the monster
## immediately if the Hospital map happens to already be loaded.
func start_hunt(case: CaseFile) -> void:
	active_case = case
	time_left = HUNT_DURATION
	EventBus.doppelganger_hunt_started.emit(case)
	resume_if_active()

## Spawns the visible monster (in Treatment Ward's area) if a hunt is
## currently running and nothing's spawned yet.
func resume_if_active() -> void:
	if active_case == null:
		return
	if _monster != null and is_instance_valid(_monster):
		return
	_monster = null
	var room := get_tree().current_scene
	if room == null:
		return
	var monster: Node2D = MONSTER_SCENE.instantiate()
	room.add_child(monster)
	monster.global_position = Vector2(
		randf_range(SPAWN_X_RANGE.x, SPAWN_X_RANGE.y),
		randf_range(SPAWN_Y_RANGE.x, SPAWN_Y_RANGE.y),
	)
	monster.caught.connect(_on_monster_caught)
	_monster = monster

func _on_monster_caught() -> void:
	_resolve(true)

func _resolve(success: bool) -> void:
	var case := active_case
	active_case = null
	if success:
		RunManager.adjust_reputation(CATCH_REPUTATION_BONUS)
		RunManager.add_gold(CATCH_GOLD_REWARD)
		RunManager.adjust_suspicion(CATCH_SUSPICION_RELIEF)
		if case and case.doppelganger_profile:
			Codex.record_doppelganger_seen(case.doppelganger_profile.id) # caught it - its tells are known now even if it was never Inspected
	else:
		RunManager.adjust_suspicion(ESCAPE_SUSPICION_PENALTY)
	EventBus.doppelganger_hunt_resolved.emit(case, success)
	if _monster and is_instance_valid(_monster):
		_monster.queue_free()
	_monster = null
