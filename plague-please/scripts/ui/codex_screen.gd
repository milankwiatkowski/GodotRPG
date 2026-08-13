extends CanvasLayer
## The player's field notes: what they've personally learned this run
## about diseases (symptoms from Inspecting, cures from actually curing
## someone) and dopplegangers (tells from Inspecting or catching one) -
## see Codex (autoload) for the discovery tracking itself. Toggled with
## the "codex" action (I) from anywhere in the Hospital, styled like
## DayReportScreen's Panel/TabContainer. Pauses the game while open
## (get_tree().paused) since it's a look-things-up screen, not something
## meant to be read while a monster's on you - process_mode ALWAYS keeps
## this node (and only this node) still taking input while paused so it
## can close itself again.
##
## Undiscovered entries show as "???" rather than being hidden outright -
## the player should be able to see *how much* they don't know yet, not
## just what they do.

const ROW_FONT_COLOR := Color(0.32, 0.2, 0.1, 1)
const UNKNOWN_COLOR := Color(0.55, 0.5, 0.46, 1)

@onready var panel: Control = $Panel
@onready var disease_list: VBoxContainer = $Panel/VBox/TabContainer/Diseases/DiseaseScroll/DiseaseList
@onready var doppelganger_list: VBoxContainer = $Panel/VBox/TabContainer/Dopplegangers/DoppelScroll/DoppelList
@onready var close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	layer = 30 # above room panels (20)/HUD - this is a full pause overlay
	process_mode = Node.PROCESS_MODE_ALWAYS # keep taking input while get_tree().paused
	visible = false # hides both Background (the dim backdrop) and Panel in one shot - CanvasLayer.visible cascades to everything under it
	close_button.pressed.connect(close)
	add_to_group("modal_ui")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"codex") and not (is_open() == false and _other_modal_open()):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Won't open on top of an already-open dialogue/shop panel (Intake,
## Treatment, Brew, Supply) - avoids stacking modals, or Escape closing
## the wrong one.
func _other_modal_open() -> bool:
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui != self and ui.has_method("is_open") and ui.is_open():
			return true
	return false


func is_open() -> bool:
	return visible


func open() -> void:
	_rebuild_diseases()
	_rebuild_dopplegangers()
	visible = true
	get_tree().paused = true
	SFX.play(&"open_dialogue")


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	SFX.play(&"cancel")


func _rebuild_diseases() -> void:
	for child in disease_list.get_children():
		child.queue_free()
	if ContentDB.diseases.is_empty():
		_add_empty_row(disease_list, "Nothing on file yet.")
		return
	for disease in ContentDB.diseases.values():
		disease_list.add_child(_build_disease_row(disease))


func _build_disease_row(disease: DiseaseData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 9)
	var body_label := Label.new()
	body_label.add_theme_font_size_override("font_size", 8)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if Codex.is_disease_known(disease.id):
		name_label.text = disease.name
		name_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		var symptom_names: Array[String] = []
		for symptom in disease.symptoms:
			symptom_names.append(symptom.display_name)
		var lines: Array[String] = ["Symptoms: %s" % ", ".join(symptom_names)]
		if Codex.is_cure_known(disease.id):
			var recipe: PotionRecipeData = ContentDB.recipes.get(disease.cure_recipe_id)
			lines.append("Cure: %s" % (recipe.result_name if recipe else "unknown"))
		else:
			lines.append("Cure: not yet discovered - brew something and find out.")
		body_label.text = "\n".join(lines)
		body_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", UNKNOWN_COLOR)
		body_label.text = "Not yet encountered - Inspect Closely at Intake to learn what this looks like."
		body_label.add_theme_color_override("font_color", UNKNOWN_COLOR)

	box.add_child(name_label)
	box.add_child(body_label)
	return box


func _rebuild_dopplegangers() -> void:
	for child in doppelganger_list.get_children():
		child.queue_free()
	if ContentDB.dopplegangers.is_empty():
		_add_empty_row(doppelganger_list, "Nothing on file yet.")
		return
	for profile in ContentDB.dopplegangers.values():
		doppelganger_list.add_child(_build_doppelganger_row(profile))


func _build_doppelganger_row(profile: DopplegangerProfile) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 9)
	var body_label := Label.new()
	body_label.add_theme_font_size_override("font_size", 8)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if Codex.is_doppelganger_known(profile.id):
		name_label.text = profile.name
		name_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		var tell_names: Array[String] = []
		for tell in profile.tells:
			tell_names.append(tell.display_name)
		var disguise := String(profile.disguise_archetype.id).capitalize() if profile.disguise_archetype else "a patient"
		body_label.text = "Disguises as: %s\nTells: %s" % [disguise, ", ".join(tell_names)]
		body_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", UNKNOWN_COLOR)
		body_label.text = "Not yet unmasked - Inspect Closely, or catch one loose in Treatment Ward."
		body_label.add_theme_color_override("font_color", UNKNOWN_COLOR)

	box.add_child(name_label)
	box.add_child(body_label)
	return box


func _add_empty_row(list: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", UNKNOWN_COLOR)
	list.add_child(label)
