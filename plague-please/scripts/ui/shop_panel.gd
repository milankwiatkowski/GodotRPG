extends CanvasLayer
## Supply Room's ordering UI: lists every known IngredientData (from
## ContentDB) with its per-batch cost, lets the player place an order
## against RunManager.gold, and shows what's currently on the way.
## Orders aren't instant - SupplyOrders (autoload) delivers them after a
## delay that keeps ticking even if the player leaves the room.

@onready var panel: Control = $Panel
@onready var ingredient_list: VBoxContainer = $Panel/VBox/IngredientScroll/IngredientList
@onready var orders_list: VBoxContainer = $Panel/VBox/OrdersScroll/OrdersList
@onready var feedback_label: Label = $Panel/VBox/FeedbackLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

const ROW_FONT_COLOR := Color(0.32, 0.2, 0.1, 1)


func _ready() -> void:
	layer = 20 # above room content/HUD, below TransitionScreen's fade (100)
	panel.visible = false
	close_button.pressed.connect(close)
	add_to_group("shop_ui")
	add_to_group("modal_ui")
	SupplyOrders.order_delivered.connect(_on_order_delivered)


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Keep the ETA countdown live while the panel's actually open - cheap
	# to just rebuild the small list every frame rather than track deltas.
	if is_open():
		_rebuild_orders_list()


func is_open() -> bool:
	return panel.visible


func open() -> void:
	_rebuild_ingredient_list()
	_rebuild_orders_list()
	feedback_label.text = ""
	panel.visible = true


func close() -> void:
	if panel.visible:
		SFX.play(&"cancel")
	panel.visible = false


func _rebuild_ingredient_list() -> void:
	for child in ingredient_list.get_children():
		child.queue_free()
	if ContentDB.ingredients.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Nothing for sale yet."
		empty_label.add_theme_font_size_override("font_size", 8)
		empty_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		ingredient_list.add_child(empty_label)
		return
	for ingredient in ContentDB.ingredients.values():
		ingredient_list.add_child(_build_ingredient_row(ingredient))


func _build_ingredient_row(ingredient: IngredientData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	if ingredient.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = ingredient.icon
		icon_rect.custom_minimum_size = Vector2(16, 16)
		# IGNORE_SIZE, not FIT_WIDTH_PROPORTIONAL - see brew_panel.gd's
		# _build_row() for why (ScrollContainer + FIT_WIDTH_PROPORTIONAL can
		# let a texture's native size override custom_minimum_size).
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", ROW_FONT_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var batch_cost := ingredient.cost * SupplyOrders.ORDER_BATCH_SIZE
	label.text = "%s - %dx for %dg (have %d)" % [
		ingredient.name, SupplyOrders.ORDER_BATCH_SIZE, batch_cost, InventoryManager.get_ingredient_count(ingredient.id),
	]
	row.add_child(label)

	var order_button := Button.new()
	order_button.text = "Order"
	order_button.custom_minimum_size = Vector2(38, 16)
	order_button.add_theme_font_size_override("font_size", 8)
	order_button.pressed.connect(_on_order_pressed.bind(ingredient))
	row.add_child(order_button)

	return row


func _rebuild_orders_list() -> void:
	for child in orders_list.get_children():
		child.queue_free()
	var orders := SupplyOrders.get_pending_orders()
	if orders.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No orders on the way."
		empty_label.add_theme_font_size_override("font_size", 8)
		empty_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		orders_list.add_child(empty_label)
		return
	for order in orders:
		var ingredient: IngredientData = ContentDB.ingredients.get(order["ingredient_id"])
		var display_name: String = ingredient.name if ingredient else str(order["ingredient_id"])
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		label.text = "%dx %s - arriving in %ds" % [order["quantity"], display_name, ceili(order["time_left"])]
		orders_list.add_child(label)


func _on_order_pressed(ingredient: IngredientData) -> void:
	if SupplyOrders.place_order(ingredient):
		SFX.play(&"order_placed")
		feedback_label.text = "Ordered %dx %s." % [SupplyOrders.ORDER_BATCH_SIZE, ingredient.name]
	else:
		SFX.play(&"fail")
		feedback_label.text = "Not enough gold to order %s." % ingredient.name
	_rebuild_ingredient_list()
	_rebuild_orders_list()


func _on_order_delivered(ingredient_id: StringName, quantity: int) -> void:
	if not is_open():
		return
	SFX.play(&"coin")
	var ingredient: IngredientData = ContentDB.ingredients.get(ingredient_id)
	feedback_label.text = "%dx %s delivered!" % [quantity, ingredient.name if ingredient else str(ingredient_id)]
	_rebuild_ingredient_list()
