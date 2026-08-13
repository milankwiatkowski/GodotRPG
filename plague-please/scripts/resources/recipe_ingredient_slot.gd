extends Resource
class_name RecipeIngredientSlot
## One "N of this ingredient" line inside a PotionRecipeData.

@export var ingredient: IngredientData
@export_range(1, 10) var quantity: int = 1
