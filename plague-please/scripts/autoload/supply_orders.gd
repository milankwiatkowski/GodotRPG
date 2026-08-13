extends Node
## Autoload: ingredient ordering. Placing an order (ShopPanel) spends gold
## immediately and queues a delivery that arrives after ORDER_DELAY seconds
## - ticked here, not in the Supply Room scene, since a scene node stops
## processing entirely the moment its scene unloads and the player walks
## off to do something else while waiting is the whole point.

signal order_placed(ingredient_id: StringName, quantity: int)
signal order_delivered(ingredient_id: StringName, quantity: int)

const ORDER_BATCH_SIZE := 3
const ORDER_DELAY := 20.0 # seconds

## Each entry: {"ingredient_id": StringName, "quantity": int, "time_left": float}
var _pending: Array[Dictionary] = []

func _process(delta: float) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i]["time_left"] -= delta
		if _pending[i]["time_left"] <= 0.0:
			var order := _pending[i]
			InventoryManager.add_ingredient(order["ingredient_id"], order["quantity"])
			order_delivered.emit(order["ingredient_id"], order["quantity"])
			_pending.remove_at(i)

## Spends gold and queues a delivery. Returns false (spends nothing) if the
## player can't afford ORDER_BATCH_SIZE units at the ingredient's cost.
func place_order(ingredient: IngredientData) -> bool:
	var total_cost := ingredient.cost * ORDER_BATCH_SIZE
	if not RunManager.spend_gold(total_cost):
		return false
	_pending.append({
		"ingredient_id": ingredient.id,
		"quantity": ORDER_BATCH_SIZE,
		"time_left": ORDER_DELAY,
	})
	order_placed.emit(ingredient.id, ORDER_BATCH_SIZE)
	return true

func get_pending_orders() -> Array[Dictionary]:
	return _pending
