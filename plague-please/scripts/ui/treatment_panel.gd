extends CanvasLayer
## Treatment Room's cure-them panel: shows an admitted patient's disease
## and lets the player Treat them using whatever cure potion is in
## InventoryManager's stock. This is where the reputation/gold reward for
## admitting them actually lands (via RunManager.resolve_case()) - IntakePanel
## only sent them here, it didn't reward anything yet, since "admitted" and
## "actually cured" aren't the same thing.
##
## Also shows the live death countdown (case.death_timer, ticking down in
## PatientQueue._tick_death_timers()) - "how sick is he, and how quickly
## will that kill him" made concrete instead of just a severity label.
## Refreshed every frame while open, same as ShopPanel's order ETAs.
##
## No Reject here - they're already admitted, not up for a second triage
## call. No potion in stock -> Treat fails with feedback and the panel
## stays open; Close/Escape backs out and leaves them waiting until the
## player comes back with the cure.

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var body_label: Label = $Panel/VBox/BodyScroll/BodyLabel
@onready var treat_button: Button = $Panel/VBox/TreatButton
@onready var close_button: Button = $Panel/CloseButton

var _patient: Patient
var _case: CaseFile


func _ready() -> void:
	layer = 20 # above room content/HUD, below TransitionScreen's fade (100)
	panel.visible = false
	treat_button.pressed.connect(_on_treat_pressed)
	close_button.pressed.connect(_leave)
	add_to_group("dialogue_ui")
	add_to_group("modal_ui")


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_open() and _case:
		body_label.text = _describe_case(_case)


func is_open() -> bool:
	return panel.visible


func open_with_patient(patient: Patient) -> void:
	if patient == null or patient.case == null:
		return
	SFX.play(&"open_dialogue")
	_patient = patient
	_case = patient.case
	name_label.text = _case.patient_name
	body_label.text = _describe_case(_case)
	panel.visible = true


func _describe_case(case: CaseFile) -> String:
	if case.true_disease == null:
		return "No obvious ailment on file - this shouldn't happen for an admitted patient."
	var recipe: PotionRecipeData = ContentDB.recipes.get(case.true_disease.cure_recipe_id)
	var cure_name := recipe.result_name if recipe else "an unknown cure"
	var in_stock := InventoryManager.get_potion_count(case.true_disease.cure_recipe_id)
	var lines: Array[String] = [
		case.true_disease.name,
		"",
		"Condition: %s" % case.true_disease.severity_label(),
	]
	if case.death_timer > 0.0:
		lines.append("Time left: %ds" % ceili(case.death_timer))
	lines.append("")
	lines.append("Needs: %s" % cure_name)
	lines.append("In stock: %d" % in_stock)
	return "\n".join(lines)


func _on_treat_pressed() -> void:
	if _case == null or _case.true_disease == null:
		return
	if not InventoryManager.consume_potion(_case.true_disease.cure_recipe_id):
		SFX.play(&"fail")
		body_label.text = "No cure in stock - brew one in the Alchemy Lab first."
		return
	Codex.record_cure_known(_case.true_disease.id) # it actually worked - now it's known, not just guessed
	RunManager.resolve_case(_case, &"admit") # the reward for this patient lands here, not at intake
	RunManager.day_stats["cured"] += 1
	if _patient and is_instance_valid(_patient):
		_patient.dismiss()
	panel.visible = false
	_patient = null
	_case = null


## Closes the panel without treating - the patient just keeps waiting
## until the player interacts again (hopefully with the cure in hand).
func _leave() -> void:
	if panel.visible:
		SFX.play(&"cancel")
	panel.visible = false
	_patient = null
	_case = null
