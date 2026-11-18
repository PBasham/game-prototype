class_name SpawnCondition
extends Resource
## Something that must be true for a SpawnEntry's enemy to spawn. Subclasses say what
## (KillCountCondition so far). An entry with several conditions needs all of them.
## `world` is the World, typed as Node so data tools can load these without the game.


func met(_world: Node) -> bool:
	return true


## Short text for the dev console (`spawns`), e.g. "needs 1 Green Slime slain (0 so far)".
func describe(_world: Node) -> String:
	return ""
