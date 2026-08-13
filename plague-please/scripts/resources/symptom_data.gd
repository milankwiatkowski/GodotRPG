extends Resource
class_name SymptomData
## A single observable sign a patient can present during examination.
## Symptoms are the building blocks diseases and doppelganger disguises are made of.
## Minigames read these to decide what they should let the player discover.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## True if this symptom is a misleading "red herring" not tied to any real cause.
@export var is_red_herring: bool = false

## Free-form tags minigames/UI can query, e.g. "visual", "smell", "vitals",
## "wound", "doppelganger_tell".
@export var tags: PackedStringArray = []
