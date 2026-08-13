extends Control
class_name MinigameBase
## Base contract every examination minigame scene must extend. This is the
## "plug" future minigames plug into: ExaminationController instances a
## minigame's scene, calls start(case), and waits for `finished` before
## moving the player on to a verdict.
##
## To add a new minigame later:
##   1. Make a scene whose root script extends MinigameBase.
##   2. Set `minigame_id` to a unique name (e.g. &"pulse_check").
##   3. Call finish(success, result) when the player completes it. `result`
##      can carry e.g. {"revealed_symptoms": Array[SymptomData], "score": 0.8}.
##   4. Register the scene in an ExaminationController's minigame_registry.

## Unique id this minigame registers under. Set per-subclass/scene.
@export var minigame_id: StringName = &""

signal finished(success: bool, result: Dictionary)

var case: CaseFile

## Called by ExaminationController right after instancing. Override to set
## up whatever the minigame needs from the case (symptoms to hide, etc).
func start(active_case: CaseFile) -> void:
	case = active_case

## Call this from the subclass when the minigame concludes.
func finish(success: bool, result: Dictionary = {}) -> void:
	if case:
		case.record_minigame_result(minigame_id, result)
	finished.emit(success, result)
	EventBus.minigame_completed.emit(minigame_id, case, result)
