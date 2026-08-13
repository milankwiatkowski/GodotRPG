extends Resource
class_name IngredientData
## A raw alchemy ingredient the player can stock and spend on brewing.

@export var id: StringName = &""
@export var name: String = ""
@export var icon: Texture2D

## Alchemical properties used to match ingredients against recipe requirements,
## e.g. "cooling", "toxic", "binding", "purifying", "earthy".
@export var properties: PackedStringArray = []

@export_range(1, 5) var rarity: int = 1
@export var cost: int = 0
