class_name TileTypes
extends RefCounted
## Fast numeric lookup for one Registry category of TileDefs (blocks or walls).
##
## World data stores small integers, not resources. Index 0 is always "empty".
## Indices are assigned by sorted id, so they're stable for the same content set.
## Saves will store an id palette so content changes never corrupt old worlds.

const EMPTY := 0

var category: StringName
var _defs: Array[TileDef] = [null]
var _index: Dictionary[StringName, int] = {}
var _collision := PackedInt32Array([TileDef.Collision.NONE])
var _row := PackedInt32Array([-1])
var _climbable := PackedByteArray([0])


func _init(registry_category: StringName, registry: Node = null) -> void:
	category = registry_category
	var reg: Node = registry if registry != null else Engine.get_main_loop().root.get_node("/root/Registry")
	var defs: Array[GameData] = reg.get_all(category)
	defs.sort_custom(func(a: GameData, b: GameData) -> bool: return String(a.id) < String(b.id))
	for data in defs:
		var def := data as TileDef
		if def == null:
			continue
		_index[def.id] = _defs.size()
		_defs.append(def)
		_collision.append(def.collision)
		_row.append(def.atlas_row)
		_climbable.append(1 if def.climbable else 0)


func size() -> int:
	return _defs.size()


func index_of(id: StringName) -> int:
	return _index.get(id, -1)


func def(index: int) -> TileDef:
	return _defs[index] if index > 0 and index < _defs.size() else null


func collision(index: int) -> int:
	return _collision[index] if index >= 0 and index < _collision.size() else TileDef.Collision.SOLID


func atlas_row(index: int) -> int:
	return _row[index]


func climbable(index: int) -> bool:
	return index > 0 and index < _climbable.size() and _climbable[index] == 1


## Collision of whatever block uses an atlas row (for building the TileSet).
func collision_for_row(row: int) -> int:
	for i in range(1, _row.size()):
		if _row[i] == row:
			return _collision[i]
	return TileDef.Collision.NONE


## Whether tile `a` visually joins its neighbor `b` (no rough edge between them).
## Solid blocks join any solid block or the world's bottom edge; everything else
## (platforms, ropes) only joins its own kind.
func connects(a: int, b: int) -> bool:
	if b == WorldData.OUT_OF_BOUNDS:
		return collision(a) == TileDef.Collision.SOLID
	if collision(a) == TileDef.Collision.SOLID:
		return collision(b) == TileDef.Collision.SOLID
	return a == b
