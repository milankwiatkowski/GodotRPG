extends Node
## Autoload: global signal bus. Unrelated systems (UI, minigames, patient
## flow, alchemy) talk through this instead of holding direct references to
## each other, so any of them can be reworked or swapped independently.

signal day_started(day_number: int)
signal day_ended(day_number: int, summary: Dictionary)

signal patient_called(case: CaseFile)
signal examination_started(case: CaseFile)
signal minigame_completed(minigame_id: StringName, case: CaseFile, result: Dictionary)

## verdict is one of &"admit", &"reject".
signal diagnosis_submitted(case: CaseFile, verdict: StringName)
signal diagnosis_resolved(case: CaseFile, was_correct: bool)

signal doppelganger_unmasked(case: CaseFile)
signal doppelganger_hunt_started(case: CaseFile)
signal doppelganger_hunt_resolved(case: CaseFile, success: bool)

signal potion_brewed(recipe: PotionRecipeData)
signal supplies_changed(ingredient_id: StringName, new_amount: int)

signal reputation_changed(new_value: int, delta: int)
signal gold_changed(new_value: int)
signal player_hp_changed(new_value: int, delta: int)
signal game_over(reason: String)
