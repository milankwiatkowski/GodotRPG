extends Node
## Autoload: top-level application state machine (main menu -> run -> day
## loop -> day report -> game over) and scene swapping. UI screens call
## into this rather than calling get_tree().change_scene_to_file() directly.

enum State { MAIN_MENU, DAY_IN_PROGRESS, DAY_REPORT, GAME_OVER }

var state: State = State.MAIN_MENU

## Set by RoomDoor just before it hands off to TransitionScreen.change_scene()
## so the player lands near the door they used in the destination room
## instead of wherever that scene's Player node happens to be parked.
## Vector2.INF means "no override, use the scene's own Player position" -
## TransitionScreen resets it back to INF once consumed.
var pending_spawn_position: Vector2 = Vector2.INF

## Frozen at the moment a day ends (see _on_day_ended()) - DayReportScreen
## reads these directly on _ready() rather than data being passed through
## the scene-transition mechanism.
var last_day_number: int = 0
var last_day_summary: Dictionary = {}

func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	EventBus.day_ended.connect(_on_day_ended)

func goto_main_menu() -> void:
	state = State.MAIN_MENU
	TransitionScreen.change_scene("res://scenes/main/MainMenu.tscn")

func start_new_run() -> void:
	RunManager.start_new_run()
	state = State.DAY_IN_PROGRESS
	TransitionScreen.change_scene("res://scenes/hospital/Hospital.tscn")

func _on_day_ended(day_number: int, summary: Dictionary) -> void:
	state = State.DAY_REPORT
	last_day_number = day_number
	last_day_summary = summary
	TransitionScreen.change_scene("res://scenes/ui/DayReportScreen.tscn")

## Called by DayReportScreen's Continue button.
func continue_after_day_report() -> void:
	if reputation_or_suspicion_ended_the_run():
		return # _on_game_over() already redirected; Continue shouldn't un-end a lost run
	state = State.DAY_IN_PROGRESS
	TransitionScreen.change_scene("res://scenes/hospital/Hospital.tscn")

func reputation_or_suspicion_ended_the_run() -> bool:
	return state == State.GAME_OVER

func _on_game_over(reason: String) -> void:
	state = State.GAME_OVER
	print("Game over: ", reason)
	# TODO: show a game-over screen with the reason ("reputation" / "suspicion").
