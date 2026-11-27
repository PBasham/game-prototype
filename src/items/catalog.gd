class_name Catalog
extends RefCounted
## What the Catalog book knows (CatalogWindow draws it): every item and enemy in the
## game, which ones this character has found, and the recipes that make or use an
## item, known or not. Everyone starts with the book (J, or left click it).
##
## Found: an item once it's been in your inventory (CharacterData.seen_items), an enemy
## once you've slain one (CharacterData.slain), its drops as you see them drop
## (seen_drops). A recipe is known when its discovery items have been seen
## (RecipeData.unlock_items, empty = always); unknown ones show blacked out, with their
## station, so you know there's something to find.


## Every item a player can have (not spells or dev items), by name.
static func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in Registry.get_all(&"items"):
		var it := d as ItemData
		if it and not it.is_spell() and not it.obsolete:
			out.append(it)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	return out


static func all_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for d in Registry.get_all(&"enemies"):
		var e := d as EnemyData
		if e:
			out.append(e)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.display_name < b.display_name)
	return out


static func item_found(c: CharacterData, id: StringName) -> bool:
	return c != null and c.seen_items.has(id)


static func enemy_found(c: CharacterData, id: StringName) -> bool:
	return c != null and c.slain.has(id)


## How many of the list are found: [found, total].
static func item_progress(c: CharacterData) -> Vector2i:
	var items := all_items()
	return Vector2i(items.filter(func(it: ItemData) -> bool: return item_found(c, it.id)).size(), items.size())


static func enemy_progress(c: CharacterData) -> Vector2i:
	var list := all_enemies()
	return Vector2i(list.filter(func(e: EnemyData) -> bool: return enemy_found(c, e.id)).size(), list.size())


## Crafting recipes that make the item.
static func recipes_making(id: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for d in Registry.get_all(&"recipes"):
		var r := d as RecipeData
		if r and r.output == id:
			out.append(r)
	return _sorted(out)


## Crafting recipes that use the item.
static func recipes_using(id: StringName) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for d in Registry.get_all(&"recipes"):
		var r := d as RecipeData
		if r and r.inputs.has(id):
			out.append(r)
	return _sorted(out)


static func _sorted(list: Array[RecipeData]) -> Array[RecipeData]:
	list.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return list


static func recipe_known(c: CharacterData, r: RecipeData) -> bool:
	return c != null and c.unlocked(r.unlock_items)


## A station's name ("By hand" for none): the lowest tier object of that station kind.
static func station_name(station: StringName) -> String:
	if station == &"":
		return "By hand"
	var best: ObjectDef = null
	for d in Registry.get_all(&"objects"):
		var o := d as ObjectDef
		if o and o.station == station and (best == null or o.station_tier < best.station_tier):
			best = o
	if best:
		return best.display_name
	return {&"spell_weaving": "Spell Weaving Table", &"scribing": "Spell Weaving Table"}.get(station, String(station).capitalize())


## Enemies you've seen drop this item.
static func dropped_by(c: CharacterData, id: StringName) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	if c == null:
		return out
	for e in all_enemies():
		if c.seen_drops.get(e.id, {}).has(id):
			out.append(e)
	return out


## An enemy's drops: [item, seen] for each thing it can drop (unseen ones stay hidden).
static func drops_of(c: CharacterData, e: EnemyData) -> Array[Array]:
	var out: Array[Array] = []
	var seen: Dictionary = c.seen_drops.get(e.id, {}) if c else {}
	for l in e.loot:
		var it := ItemData.find(l.item)
		if it:
			out.append([it, seen.has(l.item)])
	return out
