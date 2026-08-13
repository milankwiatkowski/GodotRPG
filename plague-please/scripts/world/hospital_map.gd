extends Node2D
## Root script for the merged Hospital map - Intake, Treatment, Alchemy
## Lab, Supply Room, and the Morgue all live in this one scene now,
## connected by walkable corridors instead of teleporting doors between
## separate scenes. Same relative layout as before (Intake north,
## Treatment south, Alchemy Lab west, Supply Room east, Morgue further
## south past Treatment) - merged so monsters (the doppelganger, a
## neglected corpse's revenant) can actually walk/pathfind between areas
## instead of needing to be torn down and respawned every time the player
## crossed a scene boundary.
##
## Its only job: if a doppelganger hunt is currently running, make sure
## the monster is actually spawned (see HuntManager.resume_if_active()) -
## relevant after the Hospital <-> DayReportScreen <-> Hospital round
## trip, since that's still a real scene swap.

func _ready() -> void:
	HuntManager.resume_if_active()
