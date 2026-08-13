extends Node2D
## Manages up to `slot_count` patients waiting at once in a zone, backed by
## RoomState so the whole queue - not just one patient - survives a
## Hospital scene reload. Replaces the old one-at-a-time PatientSpawner.
##
## `zone_name` is the RoomState key ("IntakeRoom"/"TreatmentRoom") - no
## longer inferred from the current scene's name, since Intake/Treatment/
## AlchemyLab/SupplyRoom/Morgue all now live in one merged Hospital scene
## (see hospital_map.gd) rather than being separate scenes you teleport
## between. "Room" in the name/RoomState keys is legacy vocabulary at this
## point - think "zone."
##
## Never rolls its own cases - only ever materializes a *visible* Patient
## node for whatever RoomState already has queued for this zone. Intake's
## own arrivals are rolled by GameClock (see scripts/autoload/game_clock.gd),
## straight into RoomState, on a fixed real-time cadence. Treatment's queue
## only ever grows via RoomState.push(), called by IntakePanel when a sick
## patient is admitted.
##
## Entering the game always resumes RoomState's queue first, instantly
## (no walk-in) - they were already here, not just arriving. A patient
## whose case is already sitting in RoomState but has no live node yet
## gets a normal walk-in the next time a slot frees up - see _process().

const PATIENT_SCENE: PackedScene = preload("res://scenes/patients/Patient.tscn")

## RoomState queue key for this zone - "IntakeRoom" or "TreatmentRoom".
@export var zone_name: String = "IntakeRoom"
## World-space positions patients queue at and wait, front to back (this
## node's own `position` should stay at the origin - see hospital_map.gd's
## generator, which places every PatientQueue at Vector2.ZERO and bakes
## world coordinates straight into these arrays).
@export var slot_positions: Array[Vector2] = [Vector2(-20, 0), Vector2(0, 0), Vector2(20, 0)]
## World-space point patients walk in from and walk back out to.
@export var spawn_point: Vector2 = Vector2.ZERO
## Seconds between checking for a new arrival to walk in (only matters
## while a slot is free and RoomState actually has someone waiting).
@export var spawn_interval: float = 4.0

var _slot_patients: Array = [] # Patient or null, size == slot_positions.size()
var _spawn_timer: float = 0.0


func _ready() -> void:
	_slot_patients.resize(slot_positions.size())
	# Deferred: the scene's own children (this queue included) are still
	# being added to the tree during _ready() propagation, and
	# add_child() on a parent that's mid-setup fails outright.
	call_deferred("_resume_queue")


## Instantly re-shows everyone RoomState already remembers for this zone -
## no walk-in, no spawn-timer delay, since they were "already here" before
## the scene reloaded.
func _resume_queue() -> void:
	var queue: Array = RoomState.get_queue(zone_name)
	for i in slot_positions.size():
		var case: CaseFile = _next_unslotted_case(queue)
		if case == null:
			break
		_spawn_into_slot(i, case, true)
	_spawn_timer = spawn_interval


func _process(delta: float) -> void:
	if zone_name == "TreatmentRoom":
		# Only Treatment's admitted-but-not-yet-cured patients are at risk
		# of dying from their own disease.
		_tick_death_timers(delta)
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var free_slot := _find_free_slot()
	if free_slot == -1:
		return
	var queue: Array = RoomState.get_queue(zone_name)
	var case: CaseFile = _next_unslotted_case(queue)
	if case == null:
		return
	_spawn_into_slot(free_slot, case, false)
	_spawn_timer = spawn_interval


## Sickness clock: "the more sick he is, the quicker he'll die" made real.
## Only ticks for slotted, actually-waiting patients with a real disease
## and a running timer (see IntakePanel._on_admit_pressed(), which sets
## death_timer the moment they're admitted).
func _tick_death_timers(delta: float) -> void:
	for i in _slot_patients.size():
		var p = _slot_patients[i]
		if p == null or not is_instance_valid(p) or not p.is_waiting():
			continue
		var case: CaseFile = p.case
		if case == null or case.true_disease == null or case.death_timer <= 0.0:
			continue
		case.death_timer -= delta
		if case.death_timer <= 0.0:
			p.die()


func _find_free_slot() -> int:
	for i in _slot_patients.size():
		if _slot_patients[i] == null or not is_instance_valid(_slot_patients[i]):
			return i
	return -1


## The first case in RoomState's queue for this zone that doesn't already
## have a Patient node occupying a slot.
func _next_unslotted_case(queue: Array) -> CaseFile:
	for case in queue:
		var already_slotted := false
		for p in _slot_patients:
			if p and is_instance_valid(p) and p.case == case:
				already_slotted = true
				break
		if not already_slotted:
			return case
	return null


func _spawn_into_slot(index: int, case: CaseFile, already_waiting: bool) -> void:
	var patient: Patient = PATIENT_SCENE.instantiate()
	patient.zone_name = zone_name
	get_parent().add_child(patient)
	var slot_global := to_global(slot_positions[index])
	if already_waiting:
		patient.global_position = slot_global
		patient.setup_waiting(case, to_global(spawn_point))
	else:
		patient.global_position = to_global(spawn_point)
		patient.setup(case, slot_global)
	patient.dismissed.connect(_on_patient_dismissed.bind(index, case))
	_slot_patients[index] = patient


func _on_patient_dismissed(index: int, case: CaseFile) -> void:
	RoomState.remove(zone_name, case)
	_slot_patients[index] = null
