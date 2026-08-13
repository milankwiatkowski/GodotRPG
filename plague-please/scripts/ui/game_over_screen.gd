extends Control
## Shown the moment a run actually ends (reputation hits 0, suspicion hits
## 100, or player_hp hits 0 - see RunManager._check_game_over() ->
## EventBus.game_over -> GameManager._on_game_over(), which transitions
## here immediately, from wherever the player happened to be). Reads
## GameManager.game_over_reason/last_day_number directly, same pattern as
## DayReportScreen reading last_day_summary.
##
## There's no "Continue" here on purpose - the run is over. The only way
## forward is Main Menu -> Begin Shift, a fresh RunManager.start_new_run().
## Before this screen existed, GameManager._on_game_over() only set state
## and printed to the console - DayReportScreen's Continue button would
## silently no-op once state was GAME_OVER (continue_after_day_report()'s
## early-return guard) with no feedback at all, reading exactly like a
## broken button rather than "the run is over."

const REASON_TEXT := {
	"reputation": "Your reputation has collapsed. The hospital's been shut down - too many patients misdiagnosed, too many bodies unaccounted for.",
	"suspicion": "Suspicion finally boiled over. They know what's really been slipping through Intake - and what you let in.",
	"hp": "You didn't survive the night.",
}

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var reason_label: Label = $Panel/VBox/ReasonLabel
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var menu_button: Button = $Panel/VBox/MenuButton


func _ready() -> void:
	title_label.text = "Game Over"
	reason_label.text = REASON_TEXT.get(GameManager.game_over_reason, "The run has ended.")
	stats_label.text = "Made it to Day %d - Reputation %d, Suspicion %d, Gold %d" % [
		RunManager.current_day, RunManager.reputation, RunManager.suspicion, RunManager.gold,
	]
	menu_button.pressed.connect(_on_menu_pressed)
	SFX.play(&"open_dialogue")


func _on_menu_pressed() -> void:
	SFX.play(&"click")
	GameManager.goto_main_menu()
