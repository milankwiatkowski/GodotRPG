extends Node
## Autoload (CorpseManager): what happens to a patient after they die (see
## Patient.die(), called both by the doppelganger's kill and by disease
## death_timer running out - see patient_queue.gd). Three linked jobs:
##
## 1. Corpses (`_corpses`) - each dead patient leaves a Corpse node lying
##    in Treatment Ward. Left alone too long (TRANSFORM_DELAY), it turns
##    into a chasing monster - see 3. Picking one up (E, PICKUP_COOLDOWN
##    between attempts) removes the node and defuses that timer for good;
##    `carried_case` is the single source of truth for "what am I
##    carrying," polled by Player (speed debuff) and hud.gd (the
##    "Carrying" box) rather than any node reference, since a carried body
##    has no world node at all until it's dropped off.
## 2. Disposal - DisposalStation (in the Morgue area) clears `carried_case`
##    via dispose_carried(). That's the only way out for something you've
##    already picked up; there's no "drop it here" outside the Morgue.
## 3. Chase monsters (`_chases`) - once a corpse transforms, it's no
##    longer "a corpse problem," it's a "monster problem": tracked the
##    same way HuntManager tracks the doppelganger hunt (global timer-free
##    state that survives scene changes, a visible node that doesn't),
##    except it follows the player into *any* room rather than staying
##    fixed to one - see on_room_entered(), called by
##    TransitionScreen.change_scene() after every scene swap.

const CORPSE_SCENE: PackedScene = preload("res://scenes/patients/Corpse.tscn")
const MONSTER_SCENE: PackedScene = preload("res://scenes/patients/CorpseMonster.tscn")
const MONSTER_PORTRAITS: Array[String] = [
	"res://resources/sprite_frames/monster_werewolf.tres",
	"res://resources/sprite_frames/monster_slime.tres",
	"res://resources/sprite_frames/monster_orc.tres",
]

const TRANSFORM_DELAY := 45.0 # seconds a corpse can lie undisposed before it rises
const PICKUP_COOLDOWN := 1.0
const CARRY_SPEED_MULTIPLIER := 0.65
const NEGLECT_REPUTATION_PENALTY := -5
const SPAWN_OFFSET := Vector2(60, 60) # so a freshly-turned monster isn't literally on top of you

## {"case": CaseFile, "position": Vector2, "timer": float, "node": Corpse}
var _corpses: Array[Dictionary] = []
## {"case": CaseFile, "portrait": String, "node": CorpseMonster}
var _chases: Array[Dictionary] = []

var carried_case: CaseFile = null
var _pickup_cooldown: float = 0.0


func _process(delta: float) -> void:
	_pickup_cooldown = maxf(0.0, _pickup_cooldown - delta)
	for i in range(_corpses.size() - 1, -1, -1):
		_corpses[i]["timer"] -= delta
		if _corpses[i]["timer"] <= 0.0:
			_transform_to_monster(i)


## Called by Patient.die() at the position it died.
func register_corpse(case: CaseFile, global_pos: Vector2) -> void:
	var room := get_tree().current_scene
	if room == null:
		return
	var node: Corpse = CORPSE_SCENE.instantiate()
	room.add_child(node)
	node.global_position = global_pos
	node.case = case
	if case.portrait_path != "":
		node.set_portrait(load(case.portrait_path))
	_corpses.append({"case": case, "position": global_pos, "timer": TRANSFORM_DELAY, "node": node})


func pickup_cooldown_remaining() -> float:
	return _pickup_cooldown


func can_pickup() -> bool:
	return carried_case == null and _pickup_cooldown <= 0.0


## Called by Player when interacting with a Corpse in range. Returns false
## (does nothing) if already carrying one or still on cooldown.
func pickup_corpse(corpse_node: Corpse) -> bool:
	if not can_pickup():
		return false
	var index := -1
	for i in _corpses.size():
		if _corpses[i]["node"] == corpse_node:
			index = i
			break
	if index == -1:
		return false
	var entry: Dictionary = _corpses[index]
	_corpses.remove_at(index)
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()
	carried_case = entry["case"]
	_pickup_cooldown = PICKUP_COOLDOWN
	SFX.play(&"pickup")
	return true


## Called by DisposalStation (in the Morgue area). Returns false if not
## carrying anything right now.
func dispose_carried() -> bool:
	if carried_case == null:
		return false
	carried_case = null
	SFX.play(&"dispose")
	return true


func _transform_to_monster(index: int) -> void:
	var entry: Dictionary = _corpses[index]
	_corpses.remove_at(index)
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()
	RunManager.adjust_reputation(NEGLECT_REPUTATION_PENALTY)
	SFX.play(&"transform")
	var chase := {
		"case": entry["case"],
		"portrait": MONSTER_PORTRAITS[randi() % MONSTER_PORTRAITS.size()],
		"node": null,
	}
	_chases.append(chase)
	_spawn_chase_monster(chase)


func _spawn_chase_monster(chase: Dictionary) -> void:
	var room := get_tree().current_scene
	if room == null:
		return
	var monster: CorpseMonster = MONSTER_SCENE.instantiate()
	room.add_child(monster)
	monster.sprite.sprite_frames = load(chase["portrait"])
	monster.sprite.play(&"idle") # scene doesn't set an animation by default - nothing to play until frames exist
	var player := get_tree().get_first_node_in_group("player")
	monster.global_position = (player.global_position + SPAWN_OFFSET) if player else Vector2.ZERO
	monster.caught.connect(_on_chase_caught.bind(monster))
	chase["node"] = monster


func _on_chase_caught(monster: Node) -> void:
	for i in range(_chases.size() - 1, -1, -1):
		if _chases[i]["node"] == monster:
			_chases.remove_at(i)
			break
	if is_instance_valid(monster):
		monster.queue_free()


## Called by TransitionScreen.change_scene() after every scene swap -
## re-materializes whatever's needed: any still-pending corpse whose node
## didn't survive the reload, and any active chase monster following the
## player in. In practice this only matters for the Hospital <->
## DayReportScreen <-> Hospital round trip now that Intake/Treatment/
## AlchemyLab/SupplyRoom/Morgue are all one merged scene (see
## hospital_map.gd) rather than separate ones you'd otherwise lose these
## nodes swapping between.
func on_room_entered() -> void:
	var room := get_tree().current_scene
	if room == null:
		return
	for entry in _corpses:
		if entry["node"] == null or not is_instance_valid(entry["node"]):
			var node: Corpse = CORPSE_SCENE.instantiate()
			room.add_child(node)
			node.global_position = entry["position"]
			node.case = entry["case"]
			if entry["case"].portrait_path != "":
				node.set_portrait(load(entry["case"].portrait_path))
			entry["node"] = node
	for chase in _chases:
		if chase["node"] == null or not is_instance_valid(chase["node"]):
			_spawn_chase_monster(chase)
