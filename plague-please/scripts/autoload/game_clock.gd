extends Node
## Autoload (GameClock): the in-game calendar - Month/Day/Hour - ticking
## regardless of which scene is loaded, unlike PatientQueue's old
## room-scoped spawn timer. Drives two things:
##
## 1. New Intake arrivals land straight in RoomState's "IntakeRoom" queue
##    on a fixed real-time cadence (PATIENT_ARRIVAL_INTERVAL), whether or
##    not Intake Room is even the current scene. PatientQueue no longer
##    rolls its own cases (see patient_queue.gd) - it only ever
##    materializes a *visible* Patient node for whatever's already
##    queued, same as it always did for Treatment. Capped at
##    MAX_INTAKE_BACKLOG so ignoring the room for a long time doesn't
##    queue up an unbounded pile.
## 2. Crossing a day boundary (HOURS_PER_DAY hours) ends the day - see
##    RunManager.end_current_day(), which builds/emits the day's summary
##    (EventBus.day_ended) and GameManager shows the Day Report screen.

const SECONDS_PER_HOUR := 10.0
const HOURS_PER_DAY := 24
const DAYS_PER_MONTH := 30
const PATIENT_ARRIVAL_INTERVAL := 5.0 # real seconds = half an in-game hour
const MAX_INTAKE_BACKLOG := 30

var hour: int = 8 # start a run mid-morning, not the stroke of midnight
var day: int = 1
var month: int = 1

var _hour_timer: float = 0.0
var _patient_timer: float = PATIENT_ARRIVAL_INTERVAL


func _process(delta: float) -> void:
	_hour_timer += delta
	while _hour_timer >= SECONDS_PER_HOUR:
		_hour_timer -= SECONDS_PER_HOUR
		_advance_hour()

	_patient_timer -= delta
	if _patient_timer <= 0.0:
		_patient_timer = PATIENT_ARRIVAL_INTERVAL
		_spawn_intake_arrival()


func _advance_hour() -> void:
	hour += 1
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		if day > DAYS_PER_MONTH:
			day = 1
			month += 1
		RunManager.end_current_day()


func _spawn_intake_arrival() -> void:
	var queue: Array = RoomState.get_queue("IntakeRoom")
	if queue.size() >= MAX_INTAKE_BACKLOG:
		return
	queue.append(RunManager.generate_case())


## "M1 D5 14:00" - compact enough for the HUD corner.
func format_clock() -> String:
	return "M%d D%d %02d:00" % [month, day, hour]


func reset() -> void:
	hour = 8
	day = 1
	month = 1
	_hour_timer = 0.0
	_patient_timer = PATIENT_ARRIVAL_INTERVAL
