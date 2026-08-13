extends Resource
class_name DiseaseData
## A real, treatable illness a patient can actually have.

@export var id: StringName = &""
@export var name: String = ""
@export_multiline var lore_text: String = ""
@export var symptoms: Array[SymptomData] = []
@export var contagious: bool = false
@export_range(1, 5) var severity: int = 1

## Id of the PotionRecipeData that cures this disease.
@export var cure_recipe_id: StringName = &""

## Days until a misdiagnosed/untreated case escalates (worsens or the patient dies).
@export var days_to_escalate: int = 3

## Real seconds a Treatment Ward patient with this disease survives once
## admitted, before dying if not cured in time - see
## CaseFile.death_timer / PatientQueue._tick_death_timers(). Deliberately
## keeps using days_to_escalate as the basis (so authoring a new disease's
## pacing is still just "how many days," same field either way) rather
## than adding a second, parallel "seconds" field to author by hand.
const SECONDS_PER_ESCALATION_DAY := 15.0
func death_time_seconds() -> float:
	return days_to_escalate * SECONDS_PER_ESCALATION_DAY

## Human-readable read on severity for the dialogue box - "how sick is
## he," in words rather than a raw 1-5 number.
func severity_label() -> String:
	match severity:
		1: return "Mild"
		2: return "Moderate"
		3: return "Severe"
		4: return "Grave"
		_: return "Critical"
