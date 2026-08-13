extends Node
## Autoload: tracks ingredient stock and brewed potion stock. Alchemy Lab UI
## reads/writes through this rather than touching save data directly.

var ingredient_stock: Dictionary = {} # StringName -> int
var potion_stock: Dictionary = {}     # StringName -> int

func add_ingredient(id: StringName, amount: int = 1) -> void:
	ingredient_stock[id] = get_ingredient_count(id) + amount
	EventBus.supplies_changed.emit(id, ingredient_stock[id])

func get_ingredient_count(id: StringName) -> int:
	return ingredient_stock.get(id, 0)

func can_afford_recipe(recipe: PotionRecipeData) -> bool:
	for slot in recipe.ingredients:
		if get_ingredient_count(slot.ingredient.id) < slot.quantity:
			return false
	return true

## Spends the required ingredients and adds one potion to stock.
## Returns false (and spends nothing) if supplies are insufficient.
func brew(recipe: PotionRecipeData) -> bool:
	if not can_afford_recipe(recipe):
		return false
	for slot in recipe.ingredients:
		add_ingredient(slot.ingredient.id, -slot.quantity)
	potion_stock[recipe.id] = potion_stock.get(recipe.id, 0) + 1
	EventBus.potion_brewed.emit(recipe)
	return true

func get_potion_count(recipe_id: StringName) -> int:
	return potion_stock.get(recipe_id, 0)

## Spends one potion of the given recipe (e.g. Emergency Room treating a
## patient). Returns false (and spends nothing) if none are in stock.
func consume_potion(recipe_id: StringName) -> bool:
	var count := get_potion_count(recipe_id)
	if count <= 0:
		return false
	potion_stock[recipe_id] = count - 1
	return true
