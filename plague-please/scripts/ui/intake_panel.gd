extends CanvasLayer
## Intake Room's arrival panel: replaces the old separate reception
## Dialogue/Examination panels now that intake is one room. On open, all
## you get is the patient's own flavor line - no symptoms yet, sick or
## not. "Inspect Closely" is the actual test: it reveals presented_symptoms
## for a genuinely sick patient (an ordinary, explainable set, plus a
## severity read - see DiseaseData.severity_label()) or a doppelganger's
## tells (deliberately uncanny-sounding - "eyes ripple like water" isn't a
## real fever symptom). Nothing hidden for a healthy patient either way.
## This is the whole diagnostic loop until real examination minigames
## exist: test everyone, and if what you find doesn't read like a real
## illness, that's the tell.
##
## Admit doesn't always resolve immediately: a genuinely sick patient gets
## pushed onto RoomState's "TreatmentRoom" queue instead and only actually
## rewards reputation/gold once TreatmentPanel cures them - admitting isn't
## the same as successfully treating. Their death_timer starts ticking the
## moment they're admitted (see DiseaseData.death_time_seconds()) - the
## more severe the disease, the less time to actually cure them.
## A healthy patient resolves right here. A (wrongly) admitted doppelganger
## also resolves right here (reputation hit lands immediately), but it
## doesn't reveal itself on the spot either - it walks the same corridor
## route to Treatment Ward as any admitted patient and only turns into the
## hunted monster once it actually gets there - see _on_admit_pressed()
## and doppelganger_hunt.gd.
##
## The corner Close button / Escape backs out without deciding anything -
## the patient just keeps waiting.

const GENERIC_FLAVOR := "They wait quietly, saying nothing you can diagnose from here. Inspect them closely to see what's actually wrong."

## World-space point just past Intake's exit into the shared vertical
## corridor, and a second point right at the doorway gap in Intake's own
## south wall - see INTAKE_TO_TREATMENT_PATH below.
const TREATMENT_BOUND_EXIT := Vector2(0, 10)
const INTAKE_CORRIDOR_GAP := Vector2(0, -184)

## An admitted patient (sick, or a doppelganger playing along) doesn't
## walk a single straight line to TREATMENT_BOUND_EXIT - from most queue
## slots that line cuts diagonally through Intake's own wall instead of
## through the corridor doorway. Walking INTAKE_CORRIDOR_GAP first lines
## them up with the (x=[-48,48]) gap in the wall before heading
## south, then straight down the corridor to TREATMENT_BOUND_EXIT (passed
## separately as dismiss()'s exit_target - this is just the intermediate
## leg(s) before it) - see Patient.dismiss()'s path parameter.
const INTAKE_TO_TREATMENT_PATH: Array[Vector2] = [INTAKE_CORRIDOR_GAP]

## Matches Patient.zone_name for whichever patients this panel should
## handle - both IntakePanel and TreatmentPanel exist simultaneously in
## the merged Hospital scene now, so Player._try_interact() uses this to
## pick the right one instead of grabbing whichever's first in the
## "dialogue_ui" group.
@export var zone_name: String = "IntakeRoom"

@onready var panel: Control = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var body_label: Label = $Panel/VBox/BodyScroll/BodyLabel
@onready var inspect_button: Button = $Panel/VBox/InspectButton
@onready var buttons: Control = $Panel/VBox/Buttons
@onready var admit_button: Button = $Panel/VBox/Buttons/AdmitButton
@onready var reject_button: Button = $Panel/VBox/Buttons/RejectButton
@onready var close_button: Button = $Panel/CloseButton

var _patient: Patient
var _case: CaseFile


func _ready() -> void:
	layer = 20 # above room content/HUD, below TransitionScreen's fade (100)
	panel.visible = false
	inspect_button.pressed.connect(_on_inspect_pressed)
	admit_button.pressed.connect(_on_admit_pressed)
	reject_button.pressed.connect(_on_reject_pressed)
	close_button.pressed.connect(_leave)
	add_to_group("dialogue_ui")
	add_to_group("modal_ui")


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return panel.visible


func open_with_patient(patient: Patient) -> void:
	if patient == null or patient.case == null:
		return
	SFX.play(&"open_dialogue")
	_patient = patient
	_case = patient.case
	name_label.text = _case.patient_name
	body_label.text = _flavor_text()
	inspect_button.visible = true
	buttons.visible = false
	panel.visible = true


## Pre-inspect text: never reveals symptoms, sick or not - that's what
## Inspect Closely is for.
func _flavor_text() -> String:
	if _case.archetype and not _case.archetype.flavor_dialogue.is_empty():
		return '"%s"' % _case.archetype.flavor_dialogue[0]
	return GENERIC_FLAVOR


## Post-inspect text: the real symptom list (presented_symptoms +
## whatever record_minigame_result() just revealed), plus - for a real
## disease - a severity read ("how sick is he"): the worse it is, the
## less time they'll survive once admitted if you don't cure them fast
## (see DiseaseData.death_time_seconds()). A doppelganger gets an extra
## unsettling line ahead of its tells - the hint that something's off,
## without spelling out "this is a monster."
func _inspected_text() -> String:
	var symptoms := _case.presented_symptoms.duplicate()
	symptoms.append_array(_case.discovered_symptoms)
	if symptoms.is_empty():
		return "A close look turns up nothing unusual. Seems healthy."
	var lines: Array[String] = []
	if _case.is_doppelganger:
		lines.append("Something about this doesn't add up...")
	for symptom in symptoms:
		lines.append("- %s: %s" % [symptom.display_name, symptom.description])
	if _case.true_disease:
		lines.append("")
		lines.append("Condition: %s - won't last long without a cure once admitted." % _case.true_disease.severity_label())
	return "\n".join(lines)


func _on_inspect_pressed() -> void:
	if _case == null:
		return
	SFX.play(&"click")
	var revealed: Array[SymptomData] = []
	if _case.is_doppelganger and _case.doppelganger_profile:
		revealed = _case.doppelganger_profile.tells
		Codex.record_doppelganger_seen(_case.doppelganger_profile.id)
	elif _case.true_disease:
		Codex.record_disease_seen(_case.true_disease.id)
	_case.record_minigame_result(&"basic_observation", {"revealed_symptoms": revealed})
	body_label.text = _inspected_text()
	inspect_button.visible = false
	buttons.visible = true


func _on_admit_pressed() -> void:
	if _case == null:
		return
	if _case.is_doppelganger:
		# Wrong call - it's not actually sick, it's the monster. Reputation
		# hit lands immediately via resolve_case(), but it still walks out
		# like a normal admitted patient would (see INTAKE_TO_TREATMENT_PATH)
		# and only turns into the hunted monster once it's actually reached
		# Treatment Ward - HuntManager.start_hunt() waits for Patient.gone.
		RunManager.resolve_case(_case, &"admit")
		_dismiss_toward_treatment(true)
	elif _case.true_disease != null:
		# Correct call, but not the reward yet - they still need curing,
		# and now they're on the clock: death_timer starts now, sized to
		# how severe their disease is. Walks toward Treatment instead of
		# back out the way they came.
		_case.death_timer = _case.true_disease.death_time_seconds()
		RoomState.push("TreatmentRoom", _case)
		_dismiss_toward_treatment(false)
	else:
		# Healthy and admitted: correct, nothing further to do.
		RunManager.resolve_case(_case, &"admit")
		_dismiss_out()


func _on_reject_pressed() -> void:
	if _case == null:
		return
	RunManager.resolve_case(_case, &"reject")
	_dismiss_out()


## Walks the corridor route to Treatment Ward (see INTAKE_TO_TREATMENT_PATH)
## instead of back out the way they came. start_hunt_on_exit: true only for
## a wrongly-admitted doppelganger - HuntManager.start_hunt() fires once
## Patient.gone confirms they've actually arrived, not the instant the
## verdict's given.
func _dismiss_toward_treatment(start_hunt_on_exit: bool) -> void:
	if _patient and is_instance_valid(_patient):
		if start_hunt_on_exit:
			var doppel_case := _case
			_patient.gone.connect(func(): HuntManager.start_hunt(doppel_case), CONNECT_ONE_SHOT)
		_patient.dismiss(TREATMENT_BOUND_EXIT, INTAKE_TO_TREATMENT_PATH)
	panel.visible = false
	_patient = null
	_case = null


## Rejected/resolved-healthy: walks back out the way they came in.
func _dismiss_out() -> void:
	if _patient and is_instance_valid(_patient):
		_patient.dismiss()
	panel.visible = false
	_patient = null
	_case = null


## Closes the panel without deciding anything - the patient just keeps
## waiting in the queue until the player interacts again.
func _leave() -> void:
	if panel.visible:
		SFX.play(&"cancel")
	panel.visible = false
	_patient = null
	_case = null
