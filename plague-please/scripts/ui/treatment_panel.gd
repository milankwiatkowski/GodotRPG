extends CanvasLayer
## Treatment Room's cure-them panel: shows an admitted patient's condition
## and lets the player try administering a potion from stock. This is
## where the reputation/gold reward for admitting them actually lands (via
## RunManager.resolve_case()) - IntakePanel only sent them here, it didn't
## reward anything yet, since "admitted" and "actually cured" aren't the
## same thing.
##
## Deliberately doesn't name the cure up front - see Codex. Every potion
## currently in stock is listed as a "Try" option; picking the right one
## cures the patient and permanently records the cure in Codex (so future
## admissions of the same disease show it directly - see
## _describe_case()). Picking a wrong one just wastes that potion (its own
## PotionRecipeData.side_effects_on_misuse line plays as feedback) and the
## patient keeps waiting, death timer still running - no other penalty,
## the cost is the wasted brew.
##
## Also shows the live death countdown (case.death_timer, ticking down in
## PatientQueue._tick_death_timers()) - "how sick is he, and how quickly
## will that kill him" made concrete instead of just a severity label.
## Refreshed every frame while open, same as ShopPanel's order ETAs.
##
## No Reject here - they're already admitted, not up for a second triage
## call. Close/Escape backs out and leaves them waiting until the player
## comes back with a cure to try.

const ROW_FONT_COLOR := Color(0.32, 0.2, 0.1, 1)

## Matches Patient.zone_name for whichever patients this panel should
## handle - see IntakePanel.zone_name for why this is needed now that
## both panels exist simultaneously in the merged Hospital scene.
@export var zone_name: String = "TreatmentRoom"

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var body_label: Label = $Panel/VBox/BodyScroll/BodyLabel
@onready var options_list: VBoxContainer = $Panel/VBox/OptionsScroll/OptionsList
@onready var close_button: Button = $Panel/CloseButton

var _patient: Patient
var _case: CaseFile


func _ready() -> void:
	layer = 20 # above room content/HUD, below TransitionScreen's fade (100)
	panel.visible = false
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
	_rebuild_options()
	panel.visible = true


func _describe_case(case: CaseFile) -> String:
	if case.true_disease == null:
		return "No obvious ailment on file - this shouldn't happen for an admitted patient."
	var lines: Array[String] = [
		case.true_disease.name,
		"",
		"Condition: %s" % case.true_disease.severity_label(),
	]
	if case.death_timer > 0.0:
		lines.append("Time left: %ds" % ceili(case.death_timer))
	lines.append("")
	if Codex.is_cure_known(case.true_disease.id):
		var recipe: PotionRecipeData = ContentDB.recipes.get(case.true_disease.cure_recipe_id)
		var cure_name := recipe.result_name if recipe else "an unknown cure"
		lines.append("Known cure: %s (in stock: %d)" % [cure_name, InventoryManager.get_potion_count(case.true_disease.cure_recipe_id)])
	else:
		lines.append("No cure discovered yet - try administering something from stock and see what happens.")
	return "\n".join(lines)


## Lists every potion currently in stock as a "Try" option - not just the
## correct one, since the whole point is the player doesn't know which is
## right until they've cured this disease once.
func _rebuild_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	var any_in_stock := false
	for recipe in ContentDB.recipes.values():
		var count := InventoryManager.get_potion_count(recipe.id)
		if count <= 0:
			continue
		any_in_stock = true
		options_list.add_child(_build_option_row(recipe, count))
	if not any_in_stock:
		var label := Label.new()
		label.text = "Nothing brewed yet - bring a potion from the Alchemy Lab."
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		options_list.add_child(label)


func _build_option_row(recipe: PotionRecipeData, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	if recipe.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = recipe.icon
		icon_rect.custom_minimum_size = Vector2(14, 14)
		# IGNORE_SIZE, not FIT_WIDTH_PROPORTIONAL - see brew_panel.gd's
		# _build_row() for why (ScrollContainer + FIT_WIDTH_PROPORTIONAL can
		# let a texture's native size override custom_minimum_size).
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", ROW_FONT_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s (stock %d)" % [recipe.result_name, count]
	row.add_child(label)

	var try_button := Button.new()
	try_button.text = "Try"
	try_button.custom_minimum_size = Vector2(32, 16)
	try_button.add_theme_font_size_override("font_size", 8)
	try_button.pressed.connect(_on_try_pressed.bind(recipe))
	row.add_child(try_button)

	return row


func _on_try_pressed(recipe: PotionRecipeData) -> void:
	if _case == null or _case.true_disease == null:
		return
	if not InventoryManager.consume_potion(recipe.id):
		return # stock changed under us (shouldn't normally happen) - just bail, list will refresh
	if recipe.id == _case.true_disease.cure_recipe_id:
		Codex.record_cure_known(_case.true_disease.id) # it actually worked - now it's known, not just guessed
		RunManager.resolve_case(_case, &"admit") # the reward for this patient lands here, not at intake
		RunManager.day_stats["cured"] += 1
		if _patient and is_instance_valid(_patient):
			_patient.dismiss()
		panel.visible = false
		_patient = null
		_case = null
	else:
		SFX.play(&"fail")
		var side_effect := recipe.side_effects_on_misuse if recipe.side_effects_on_misuse != "" else "Nothing happens - that wasn't it."
		body_label.text = _describe_case(_case) + "\n\n" + side_effect
		_rebuild_options() # that potion's stock just dropped


## Closes the panel without treating - the patient just keeps waiting
## until the player comes back with something to try.
func _leave() -> void:
	if panel.visible:
		SFX.play(&"cancel")
	panel.visible = false
	_patient = null
	_case = null
