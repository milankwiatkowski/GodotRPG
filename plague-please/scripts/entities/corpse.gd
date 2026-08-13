extends Node2D
class_name Corpse
## A dead patient's remains, left lying in Treatment Ward - see
## Patient.die() (which spawns one of these instead of just despawning)
## and CorpseManager (which owns the undisposed-too-long -> monster timer
## and the pickup/carry/dispose flow). Purely visual + an interact target;
## CorpseManager is the source of truth for "does this still need
## handling," not this node.

## The case this used to be. Kept for the pickup UI ("Carrying: <name>").
var case: CaseFile

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("corpses")
	# "his sprite is rotated 90 degrees" - rotate just the sprite (not
	# this whole node) so PromptLabel stays upright and readable.
	sprite.rotation_degrees = 90.0


## Sets the frozen look - one still frame from the dead patient's own
## portrait (see Patient.PORTRAITS), not a separate corpse art asset.
func set_portrait(sprite_frames: SpriteFrames) -> void:
	if sprite_frames and sprite_frames.has_animation(&"idle"):
		sprite.texture = sprite_frames.get_frame_texture(&"idle", 0)
