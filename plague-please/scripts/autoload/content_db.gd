extends Node
## Autoload: loads every data-driven Resource under res://data on startup and
## indexes it by `id` so the rest of the game can look content up cheaply.
## Add new content by dropping a new .tres into the matching res://data
## subfolder in the editor - no code changes needed.

const DATA_ROOT := "res://data"

var symptoms: Dictionary = {}      # StringName -> SymptomData
var diseases: Dictionary = {}      # StringName -> DiseaseData
var archetypes: Dictionary = {}    # StringName -> PatientArchetypeData
var ingredients: Dictionary = {}   # StringName -> IngredientData
var recipes: Dictionary = {}       # StringName -> PotionRecipeData
var dopplegangers: Dictionary = {} # StringName -> DopplegangerProfile

func _ready() -> void:
	_load_folder(DATA_ROOT + "/symptoms", symptoms)
	_load_folder(DATA_ROOT + "/diseases", diseases)
	_load_folder(DATA_ROOT + "/patients", archetypes)
	_load_folder(DATA_ROOT + "/ingredients", ingredients)
	_load_folder(DATA_ROOT + "/recipes", recipes)
	_load_folder(DATA_ROOT + "/dopplegangers", dopplegangers)
	print("[ContentDB] loaded %d symptoms, %d diseases, %d archetypes, %d ingredients, %d recipes, %d dopplegangers" % [
		symptoms.size(), diseases.size(), archetypes.size(), ingredients.size(), recipes.size(), dopplegangers.size(),
	])

func _load_folder(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(path + "/" + file_name)
			if res and "id" in res and res.id != &"":
				into[res.id] = res
			elif res:
				push_warning("[ContentDB] %s/%s has no id set, skipping" % [path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

func random_archetype() -> PatientArchetypeData:
	if archetypes.is_empty():
		return null
	return archetypes.values()[randi() % archetypes.size()]
