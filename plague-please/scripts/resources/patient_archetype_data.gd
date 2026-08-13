extends Resource
class_name PatientArchetypeData
## A "template" a generated patient is drawn from: name pool, look, and the
## pool of diseases (or doppelganger risk) that archetype can be assigned.

@export var id: StringName = &""
@export var name_pool: PackedStringArray = []
@export var portraits: Array[Texture2D] = []

## Diseases this archetype may randomly be assigned during patient generation.
@export var possible_diseases: Array[DiseaseData] = []

## Chance (0-1) that a patient generated from this archetype is actually a
## doppelganger wearing this archetype's appearance.
@export_range(0.0, 1.0) var doppelganger_chance: float = 0.0

@export var flavor_dialogue: PackedStringArray = []
