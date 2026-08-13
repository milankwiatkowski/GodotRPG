extends Control
## Shown whenever GameClock crosses a day boundary (see
## RunManager.end_current_day() -> EventBus.day_ended ->
## GameManager._on_day_ended(), which transitions here). Reads
## GameManager.last_day_number/last_day_summary directly rather than
## having data passed through the scene-transition mechanism - simplest
## way to hand a Dictionary across a scene swap in this codebase's
## existing pattern (see GameManager.pending_spawn_position for the same
## idea applied to spawn positions).

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var cured_label: Label = $Panel/VBox/TabContainer/Patients/CuredLabel
@onready var died_label: Label = $Panel/VBox/TabContainer/Patients/DiedLabel
@onready var doppel_rejected_label: Label = $Panel/VBox/TabContainer/Patients/DoppelRejectedLabel
@onready var doppel_admitted_label: Label = $Panel/VBox/TabContainer/Patients/DoppelAdmittedLabel
@onready var earned_label: Label = $Panel/VBox/TabContainer/Finances/EarnedLabel
@onready var spent_label: Label = $Panel/VBox/TabContainer/Finances/SpentLabel
@onready var net_label: Label = $Panel/VBox/TabContainer/Finances/NetLabel
@onready var chart: GoldChart = $Panel/VBox/TabContainer/Finances/GoldChart
@onready var continue_button: Button = $Panel/VBox/ContinueButton


func _ready() -> void:
	var summary: Dictionary = GameManager.last_day_summary
	title_label.text = "Day %d Report" % GameManager.last_day_number

	cured_label.text = "Patients Cured: %d" % summary.get("cured", 0)
	died_label.text = "Patients Died: %d" % summary.get("died", 0)
	doppel_rejected_label.text = "Dopplegangers Rejected: %d" % summary.get("doppel_rejected", 0)
	doppel_admitted_label.text = "Dopplegangers Let In: %d" % summary.get("doppel_admitted", 0)

	var earned: int = summary.get("gold_earned", 0)
	var spent: int = summary.get("gold_spent", 0)
	earned_label.text = "Gold Earned: %d" % earned
	spent_label.text = "Gold Spent: %d" % spent
	net_label.text = "Net: %+d" % (earned - spent)
	chart.set_history(summary.get("gold_history", []))

	continue_button.pressed.connect(_on_continue_pressed)
	SFX.play(&"open_dialogue")


func _on_continue_pressed() -> void:
	SFX.play(&"click")
	GameManager.continue_after_day_report()
