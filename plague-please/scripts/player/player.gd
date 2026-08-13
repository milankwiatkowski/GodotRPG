extends CharacterBody2D
class_name HospitalPlayer
## Top-down 4-directional walk controller. No combat here - Plague, Please
## isn't an action game, this just gets the player between rooms and up to
## patients/stations. Movement inspiration (input mapping, normalized
## diagonal movement, move_and_slide) taken from the rp-game project's
## player controller, stripped down to the walk-only subset this needs.
##
## Swap in real art later: give this node an AnimatedSprite2D named
## "AnimatedSprite2D" with "idle"/"walk" animations and it's picked up
## automatically; until then PlaceholderVisual (a plain shape) stands in.

const INTERACT_RANGE := 24.0
const FOOTSTEP_INTERVAL := 0.32 # seconds between steps while walking

@export var speed: float = 90.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _facing_right: bool = true
var _footstep_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	# While any modal panel is open (patient dialogue, brewing, shop, ...)
	# interact does nothing else and movement is frozen - same convention
	# as rp-game's dialogue freeze, generalized to every panel type via the
	# shared "modal_ui" group instead of one hardcoded node.
	var open_modal := _get_open_modal()
	if open_modal:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("interact"):
		_try_interact()

	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

	var effective_speed := speed
	if CorpseManager.carried_case != null:
		effective_speed *= CorpseManager.CARRY_SPEED_MULTIPLIER
	velocity = input_vector * effective_speed
	move_and_slide()

	_update_facing(input_vector)
	_update_animation(input_vector)
	_update_footsteps(input_vector, delta)


func _get_open_modal() -> Node:
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.has_method("is_open") and ui.is_open():
			return ui
	return null


## Interact priority: the two dangerous, time-sensitive things first
## (chasing revenant, then the doppelganger monster), then a waiting
## patient, then a corpse to pick up, then the nearest station (cauldron,
## supply shelf, disposal pit, ...). Only a couple of these ever actually
## apply in a given room today, but checking in this order costs nothing
## and means a future room that has more than one won't need reordering.
func _try_interact() -> void:
	var revenant := _find_nearest_in_group("corpse_monster", INTERACT_RANGE)
	if revenant:
		revenant.catch()
		return

	var monster := _find_nearest_in_group("doppelganger_monster", INTERACT_RANGE)
	if monster:
		monster.catch()
		return

	var patient := _find_nearest_waiting_patient(INTERACT_RANGE)
	if patient:
		var ui := _find_dialogue_ui_for_zone(patient.zone_name)
		if ui:
			ui.open_with_patient(patient)
		return

	var corpse := _find_nearest_in_group("corpses", INTERACT_RANGE)
	if corpse and CorpseManager.can_pickup():
		CorpseManager.pickup_corpse(corpse)
		return

	var station := _find_nearest_in_group("stations", INTERACT_RANGE)
	if station and station.has_method("interact"):
		station.interact()


## Both IntakePanel and TreatmentPanel are in the "dialogue_ui" group at
## the same time now that they're one merged scene - pick the one whose
## own zone_name matches the patient's, instead of always grabbing
## whichever happens to be first in the group (the old assumption, back
## when a scene only ever had one dialogue panel in it).
func _find_dialogue_ui_for_zone(zone: String) -> Node:
	for ui in get_tree().get_nodes_in_group("dialogue_ui"):
		if ui.has_method("open_with_patient") and ui.get("zone_name") == zone:
			return ui
	return null


func _find_nearest_waiting_patient(max_range: float) -> Patient:
	var nearest: Patient = null
	var nearest_dist := INF
	for npc in get_tree().get_nodes_in_group("npcs"):
		if not is_instance_valid(npc) or not npc.is_waiting():
			continue
		var dist: float = global_position.distance_to(npc.global_position)
		if dist <= max_range and dist < nearest_dist:
			nearest = npc
			nearest_dist = dist
	return nearest


func _find_nearest_in_group(group: StringName, max_range: float) -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist <= max_range and dist < nearest_dist:
			nearest = node
			nearest_dist = dist
	return nearest


func _update_facing(input_vector: Vector2) -> void:
	if input_vector.x > 0.01:
		_facing_right = true
	elif input_vector.x < -0.01:
		_facing_right = false


func _update_animation(input_vector: Vector2) -> void:
	if sprite == null:
		return
	sprite.flip_h = not _facing_right
	var anim := &"walk" if input_vector.length() > 0.01 else &"idle"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _update_footsteps(input_vector: Vector2, delta: float) -> void:
	if input_vector.length() < 0.01:
		_footstep_timer = 0.0 # start the next walk cycle on a fresh step
		return
	_footstep_timer -= delta
	if _footstep_timer <= 0.0:
		SFX.play(&"footstep", -8.0) # quieter than UI/event sounds - it repeats a lot
		_footstep_timer = FOOTSTEP_INTERVAL
