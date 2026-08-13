extends Station
## The Morgue's disposal pit. Interacting while carrying a body
## (CorpseManager.carried_case) gets rid of it for good - see
## CorpseManager.dispose_carried(). Does nothing if you're not carrying
## anything; there's no other way to put a body down once picked up.

func interact() -> void:
	CorpseManager.dispose_carried()
