extends Station
## The Supply Room's shelf. Interacting opens whichever node is in the
## "shop_ui" group (ShopPanel.tscn, instanced alongside this station in
## the merged Hospital.tscn - see hospital_map.gd).

func interact() -> void:
	var panels := get_tree().get_nodes_in_group("shop_ui")
	if not panels.is_empty() and panels[0].has_method("open"):
		SFX.play(&"open_station")
		panels[0].open()
