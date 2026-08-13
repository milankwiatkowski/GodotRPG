extends CanvasLayer
## Alchemy Lab's brewing UI: lists every known PotionRecipeData (from
## ContentDB) with its ingredient costs and current stock, and lets the
## player brew one if they can afford it. Rebuilds its row list each time
## it opens, so a newly-authored recipe .tres shows up with no extra
## wiring - see docs/ARCHITECTURE.md on adding content.

@onready var panel: Control = $Panel
@onready var recipe_list: VBoxContainer = $Panel/VBox/RecipeScroll/RecipeList
@onready var feedback_label: Label = $Panel/VBox/FeedbackLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

const ROW_FONT_COLOR := Color(0.32, 0.2, 0.1, 1)


func _ready() -> void:
	layer = 20 # above room content/HUD, below TransitionScreen's fade (100)
	panel.visible = false
	close_button.pressed.connect(close)
	add_to_group("brew_ui")
	add_to_group("modal_ui")
	# SupplyOrders delivers in the background regardless of scene/panel
	# state - refresh live if a delivery lands while this is already open,
	# instead of only ever reflecting stock as of the last open().
	EventBus.supplies_changed.connect(func(_id, _amount): if is_open(): _rebuild_list())


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return panel.visible


func open() -> void:
	_rebuild_list()
	feedback_label.text = ""
	panel.visible = true


func close() -> void:
	if panel.visible:
		SFX.play(&"cancel")
	panel.visible = false


func _rebuild_list() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	if ContentDB.recipes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No known recipes yet."
		empty_label.add_theme_font_size_override("font_size", 8)
		empty_label.add_theme_color_override("font_color", ROW_FONT_COLOR)
		recipe_list.add_child(empty_label)
		return
	for recipe in ContentDB.recipes.values():
		recipe_list.add_child(_build_row(recipe))


func _build_row(recipe: PotionRecipeData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	if recipe.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = recipe.icon
		icon_rect.custom_minimum_size = Vector2(16, 16)
		# IGNORE_SIZE, not FIT_WIDTH_PROPORTIONAL - inside a ScrollContainer
		# (unbounded width, since it scrolls) FIT_WIDTH_PROPORTIONAL can let
		# the very first row's icon fall back to its texture's native pixel
		# size instead of custom_minimum_size, which then drags the whole
		# list (and the panel around it) wide open. IGNORE_SIZE never lets
		# the texture's own size leak into the minimum-size calculation.
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", ROW_FONT_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s (%s) - stock %d" % [
		recipe.result_name, _ingredients_text(recipe), InventoryManager.get_potion_count(recipe.id),
	]
	row.add_child(label)

	var brew_button := Button.new()
	brew_button.text = "Brew"
	brew_button.custom_minimum_size = Vector2(36, 16)
	brew_button.add_theme_font_size_override("font_size", 8)
	brew_button.pressed.connect(_on_brew_pressed.bind(recipe))
	row.add_child(brew_button)

	return row


## Shows what's actually in stock next to what's needed - without this an
## ingredient batch that just got delivered by SupplyOrders is invisible
## here, no way to tell it actually arrived versus never having been
## ordered at all (ShopPanel already shows stock per-ingredient in the
## Supply Room; the Lab needs the same confirmation for the same numbers).
func _ingredients_text(recipe: PotionRecipeData) -> String:
	var parts: Array[String] = []
	for slot in recipe.ingredients:
		var have := InventoryManager.get_ingredient_count(slot.ingredient.id)
		parts.append("%dx %s (have %d)" % [slot.quantity, slot.ingredient.name, have])
	return ", ".join(parts)


func _on_brew_pressed(recipe: PotionRecipeData) -> void:
	if InventoryManager.brew(recipe):
		feedback_label.text = "Brewed %s!" % recipe.result_name # SFX.play(&"brew_success") fires via EventBus.potion_brewed
	else:
		SFX.play(&"fail")
		feedback_label.text = "Not enough ingredients for %s." % recipe.result_name
	_rebuild_list()
