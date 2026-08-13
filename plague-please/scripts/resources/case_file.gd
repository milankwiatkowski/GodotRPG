extends Resource
class_name CaseFile
## Generated per patient per shift: the ground truth (is it a real disease?
## a doppelganger?) plus everything the player has uncovered about it so far.
## This is the object that flows from the waiting room -> examination
## minigames -> the player's final verdict.

@export var patient_name: String = ""
@export var archetype: PatientArchetypeData

## Null if the patient is healthy or is a doppelganger.
@export var true_disease: DiseaseData

@export var is_doppelganger: bool = false
@export var doppelganger_profile: DopplegangerProfile

## Symptoms actually presented to the player this case (may include red
## herrings, may omit some real symptoms until a minigame reveals them).
@export var presented_symptoms: Array[SymptomData] = []

## Filled in during examination as the player uncovers things. Not meant to
## be authored by hand, so it's a plain runtime field rather than @export.
var discovered_symptoms: Array[SymptomData] = []
var minigame_results: Dictionary = {} # minigame_id (StringName) -> result Dictionary

## Which Patient.PORTRAITS entry this case's patient looks like - rolled
## once (see Patient._apply_portrait()) and kept for the case's whole
## life, not re-rolled per Patient node. The same CaseFile instance flows
## from Intake through Treatment (RoomState.push() hands off the object
## itself, not a copy), so pinning this here is what keeps a patient
## looking like the same person in both rooms instead of getting a new
## random face every time their node is recreated.
var portrait_path: String = ""

## Seconds left before this patient dies if not cured - only meaningful
## once admitted to Treatment (see IntakePanel._on_admit_pressed()) and
## only for a real disease (true_disease != null). -1 means "not at risk
## right now" (not yet admitted, healthy, or a doppelganger). Ticked down
## in PatientQueue._tick_death_timers() - see TreatmentRoom specifically.
var death_timer: float = -1.0

func record_minigame_result(minigame_id: StringName, result: Dictionary) -> void:
	minigame_results[minigame_id] = result
	if result.has("revealed_symptoms"):
		for symptom in result["revealed_symptoms"]:
			if symptom not in discovered_symptoms:
				discovered_symptoms.append(symptom)
