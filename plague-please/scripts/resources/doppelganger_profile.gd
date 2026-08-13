extends Resource
class_name DopplegangerProfile
## Defines one "flavor" of doppelganger: what patient archetype it hides
## behind, the subtle tells that expose it, and how dangerous it is once
## unmasked and hunted.

@export var id: StringName = &""
@export var name: String = ""
@export_multiline var lore_text: String = ""

## The patient archetype this doppelganger disguises itself as.
@export var disguise_archetype: PatientArchetypeData

## Subtle symptoms/tells that expose the doppelganger under close examination.
@export var tells: Array[SymptomData] = []

@export_range(1, 5) var threat_level: int = 1

## Id used by the (future) hunt system to pick a behavior/AI pattern once
## this doppelganger is unmasked and flees into the hospital.
@export var hunt_behavior_id: StringName = &"default"
