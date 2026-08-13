extends Node
## Autoload (Codex): what the player has personally discovered this run -
## which diseases they've seen the symptoms of, which cures they've
## actually used successfully, and which doppelganger tells they've
## uncovered. Nothing here is authored ahead of time and nothing is ever
## just handed to the player - it starts empty every run (see
## start_new_run(), called from RunManager.start_new_run()) and only
## fills in as the player plays:
##
##   - record_disease_seen()      - Inspect Closely on a sick patient at
##                                   Intake (see IntakePanel._on_inspect_pressed()).
##   - record_cure_known()        - actually curing someone with it (see
##                                   TreatmentPanel._on_treat_pressed()) -
##                                   knowing the symptoms doesn't tell you
##                                   the cure, brewing blind does.
##   - record_doppelganger_seen() - Inspect Closely on a doppelganger, or
##                                   catching one loose in Treatment Ward
##                                   (see HuntManager._on_monster_caught()).
##
## CodexScreen.tscn (toggled with the "codex" action - see codex_screen.gd)
## reads these to decide whether to show a real entry or a "???"
## placeholder for anything the player hasn't earned yet.

var known_diseases: Dictionary = {}      # StringName (disease id) -> true
var known_cures: Dictionary = {}         # StringName (disease id) -> true
var known_dopplegangers: Dictionary = {} # StringName (profile id) -> true


func start_new_run() -> void:
	known_diseases.clear()
	known_cures.clear()
	known_dopplegangers.clear()


func record_disease_seen(disease_id: StringName) -> void:
	if disease_id != &"":
		known_diseases[disease_id] = true


func record_cure_known(disease_id: StringName) -> void:
	if disease_id != &"":
		known_cures[disease_id] = true


func record_doppelganger_seen(profile_id: StringName) -> void:
	if profile_id != &"":
		known_dopplegangers[profile_id] = true


func is_disease_known(disease_id: StringName) -> bool:
	return known_diseases.get(disease_id, false)


func is_cure_known(disease_id: StringName) -> bool:
	return known_cures.get(disease_id, false)


func is_doppelganger_known(profile_id: StringName) -> bool:
	return known_dopplegangers.get(profile_id, false)
