extends Resource
class_name PotionRecipeData
## A brewable cure: what it costs to make and which disease it treats.

@export var id: StringName = &""
@export var result_name: String = ""
@export var icon: Texture2D
@export var ingredients: Array[RecipeIngredientSlot] = []
@export_range(1, 10) var brew_time_minutes: int = 1

## Disease this potion cures when administered correctly.
@export var cures_disease_id: StringName = &""

@export_multiline var side_effects_on_misuse: String = ""
