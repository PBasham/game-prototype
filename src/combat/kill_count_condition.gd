class_name KillCountCondition
extends SpawnCondition
## Met once at least `count` of an enemy have been slain in this world (by anyone).

@export var enemy: StringName = &"green_slime"
@export var count := 1


static func make(enemy_id: StringName, n: int) -> KillCountCondition:
	var c := KillCountCondition.new()
	c.enemy = enemy_id
	c.count = n
	return c


## `world` is the World (typed loosely so data tools can load this without the game).
func met(world: Node) -> bool:
	return world != null and _kills(world) >= count


func describe(world: Node) -> String:
	var path := "res://data/enemies/%s.tres" % enemy
	var d := load(path) as GameData if ResourceLoader.exists(path) else null
	var label := d.display_name if d else String(enemy)
	return "needs %d %s slain (%d so far)" % [count, label, _kills(world)]


func _kills(world: Node) -> int:
	return int(world.call(&"kill_count", enemy)) if world else 0
