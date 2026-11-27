class_name ItemData
extends GameData
## An item: what it looks like in the inventory and in hand, how it stacks, and what it
## does when used (mine, chop, place, plant). Files: data/items/<id>.tres.
##
## Left click uses it on the front layer, right click on the back layer (blocks placed
## as background, background mined). The held look's item type (data/item_types)
## decides the arm animation; the fields below decide the effect.
##
## Spells (data/spells) are ItemData too (SpellData): a hotbar spell shortcut is the id
## "spell:<spell id>".

## New kinds go at the end (saved .tres files store the number).
enum Kind { MATERIAL, BLOCK, WALL, TOOL, SPELL, SEED, WEAPON, BOOK, CONDUIT, TOME, FURNITURE, FOOD, ARMOR, ACCESSORY, SCROLL, PAGE }
## Schools of magic (Phase 25): every spell has one, and so do school weapons. Gear
## raises a school's damage (`<school>_damage` stats), a school weapon in hand
## amplifies its school's spells (`school_amp`), and its hits leave the school's mark,
## which that school's spells cash in (`Schools.MARK_PAYOFF`).
enum School { NONE, STORM, ARCANE, AIR, SPIRIT, LIFE }
## Weapon skills on right click.
enum Skill { NONE, LEAP_SLAM }

const SPELL_PREFIX := "spell:"

@export var kind := Kind.MATERIAL
## Inventory icon: 16x16, or 32x32 for detailed art (drawn the same size).
@export var icon: Texture2D
## Small symbol drawn in the top right corner of its inventory slot (what's in a
## flask, say). 8x8 art. Empty = none.
@export var badge: Texture2D
## Most per inventory slot (9999 for blocks, 999 for materials, 1 for tools).
@export var max_stack := 999
## How it looks and animates in hand. Null = held like a small block.
@export var held: HeldItemLook
## Size (px) the item is drawn when it lies in the world as a drop. 0 = by kind: small
## things (materials, seeds) 10, blocks and books 11, tools and weapons 13, furniture 14.
@export var drop_size := 0
## Can be put on display (see can_display: small things only). Off to forbid it.
@export var displayable := true

@export_group("Mining")
## Damage to blocks per hit (swinging tools), or per second (beam).
@export var mining_damage := 0.0
## Damage to trees per hit (axes).
@export var axe_damage := 0.0
## Mines continuously while held (the mining spell), instead of once per swing.
@export var beam := false
## Square area mined, in tiles (2 = 2x2).
@export var mining_area := 1
## Largest area the area toggle (Ctrl + mouse wheel) can pick. 0 = same as mining_area
## (no toggle).
@export var mining_area_max := 0
## The mining area is round (a circle as wide as the area) instead of square.
@export var mining_round := false
## How far from the player it reaches, in tiles.
@export var reach_tiles := 10.0
## When in the swing the hit lands (0..1 through the attack animation).
@export_range(0.0, 1.0) var impact_at := 0.5

@export_group("Placing")
## Block id placed with left click (data/tiles).
@export var places_block: StringName = &""
## Wall id placed with right click, as the back layer (data/walls).
@export var places_wall: StringName = &""
## Tile object placed with left click (data/objects): rope, torches.
@export var places_object: StringName = &""
## Lit in your hand (a torch): lights this many tiles around you while held (0 = not).
@export var held_light_radius := 0.0
@export var held_light_color := Color(1, 0.86, 0.62)
## Plants something: &"tree" (a sapling on grass) or &"grass" (turns dirt to grass).
@export var plants: StringName = &""
## Can be placed anywhere in reach; otherwise it must touch a block or a wall.
@export var free_place := false
## Largest square the area toggle can place at once. 0 = as big as the Mining Spell
## digs (its max area, Empower's Area); 1 = always one at a time (tree seeds).
@export var place_area_max := 0
## Placing reach in tiles. 0 = the spellbook's build_reach_tiles.
@export var place_reach_tiles := 0.0

@export_group("Weapon")
## Damage per swing to enemies in front of you (0 = not a melee weapon).
@export var melee_damage := 0.0
## How far the swing reaches, in tiles from your chest.
@export var melee_reach := 4.5
## Mining tools and spells: the hardest blocks they can mine at all (a block needs
## TileDef.min_mining_power). How fast they mine is mining_damage.
@export var mining_power := 0
## Hits along a line toward the cursor (punches, spears later) instead of sweeping an
## arc in front (swords). ItemUser.aimed_hit_limit_degrees caps how far up or down.
@export var melee_aims := false
## How hard it knocks enemies back (tiles/s).
@export var knockback := 12.0
## A hit staggers: the enemy's hop or slither is cut short and it starts over. Off for a
## light push that doesn't interrupt (fists), so a flurry can't keep an enemy pinned.
@export var staggers := true
@export_group("School weapon")
## Its school: hits leave that school's mark, and it amplifies that school's spells
## while it's in your hand (or your hotbar slot, while you cast).
@export var school := School.NONE
## While held: that school's spells do this much more (0.2 = +20%).
@export var school_amp := 0.0
## The mark its hits leave: damage per tick, ticks every Schools.MARK_TICK seconds for
## this long (Storm: shocked).
@export var mark_damage := 0.0
@export var mark_seconds := 0.0
## Right click: a weapon skill (LEAP_SLAM: leap toward the cursor, axes up, and slam
## down for an area hit).
@export var skill := Skill.NONE
@export var skill_damage := 0.0
@export var skill_radius_tiles := 4.0
@export var skill_cooldown := 4.0
## LEAP_SLAM: speed forward and height of the leap (tiles/s, tiles).
@export var skill_leap_speed := 28.0
@export var skill_leap_height := 3.0
@export_group("Equipment")
## Armor slot: &"head", &"chest" or &"legs" (kind ARMOR). Accessories go in any
## accessory slot.
@export var equip_slot: StringName = &""
## Damage taken from enemies is reduced by half the total defense.
@export var defense := 0
## Stat bonuses while equipped (CharacterData.STATS lists the names): max_health,
## max_mana (points), mana_regen (per second), move_speed, jump, melee_damage,
## magic_damage, mining_speed, summon_damage, storm_damage, arcane_damage, air_damage,
## spirit_damage, life_damage (fractions: 0.1 = +10%), summon_slots (extra summons out
## at once: 1 = one more).
@export var stats: Dictionary[StringName, float] = {}
## How it looks on the character: overlay textures by doll part name ("Head", "Torso",
## "Front Arm Upper"...), each laid out like one row of the parts sheet (see
## docs/character-art.md). Empty = not drawn.
@export var wear: Dictionary[String, Texture2D] = {}
## A helmet that hides the hair.
@export var hides_hair := false
@export_group("Scroll")
## A spell scroll, one use (made at the Spell Weaving Table). Left click: cast this spell
## once for free, at base power (no mana, reagents, book or tier needed). Scrolls don't
## teach spells (Spell Pages do).
@export var teaches_spell: StringName = &""
## Left click on a concentration or held-beam spell: how long it runs free (seconds).
## 0 = the defaults (Player.scroll_concentration_seconds / scroll_beam_seconds).
@export var scroll_seconds := 0.0
@export_group("Storage")
## Which special storage takes it: &"lumber" (Lumber Rack: logs, wood), &"potion"
## (Potion Cabinet: potions, flasks, coatings). Chests take anything.
@export var storage_tags: Array[StringName] = []
## The color it shows as in a Potion Cabinet (the liquid / wax); clear = worked out
## from the icon.
@export var shelf_color := Color(0, 0, 0, 0)
## How it looks on a potion shelf (Phase 35): the bottle it comes in. Clay is opaque
## (a cork and a band show what's inside: `bottle_contents`); glass shows the liquid.
## NONE: a Clay Flask.
enum BottleShape { NONE, CLAY_THIN, CLAY_REGULAR, CLAY_LARGE, GLASS_THIN, GLASS_REGULAR, GLASS_LARGE }
@export var bottle_shape := BottleShape.NONE
## What's inside, for its shelf look (alpha 0 = an empty bottle).
@export var bottle_contents := Color(0, 0, 0, 0)
## Its picture standing on a potion shelf, in art px of the furniture (detail 2). Empty:
## the icon at half size (ObjectLayer.shelf_texture).
@export var shelf_sprite: Texture2D
## Retired (the old display Shelf): kept so old saves load, left out of the Creative
## window and the Catalog, and no longer crafted.
@export var obsolete := false
@export_group("Spell page")
## A Spell Page (found, not crafted): left click learns this spell for good, and the
## page is used up. The only way to learn spells that aren't `learnable_at_table`.
@export var learns_spell: StringName = &""
@export_group("Food and potions")
## Eating or drinking it (left click while holding it) refills this much hunger...
@export var food_value := 0.0
## ...heals this much health...
@export var heal_value := 0.0
## ...and restores this much mana.
@export var mana_value := 0.0
## Potions: after drinking, no other item with the same sickness for this long
## (Terraria's Potion Sickness). Empty = none.
@export var sickness: StringName = &""
@export var sickness_seconds := 0.0
## A timed buff it gives (Well Fed, Poison Coating). 0 seconds = none.
@export var buff_name := ""
@export_multiline var buff_description := ""
@export var buff_seconds := 0.0
## While the buff lasts: extra health per second, and move speed (0.1 = +10%).
@export var buff_health_regen := 0.0
@export var buff_move_speed := 0.0
## While the buff lasts: the next this many melee hits poison what they hit.
@export var buff_poison_hits := 0
@export_group("Poison")
## Poison this item puts on enemies (coatings, the poison flask's cloud): damage per
## second, for this many seconds.
@export var poison_dps := 0.0
@export var poison_seconds := 0.0
@export_group("Throwing")
## Left click throws one (it's used up): the Poison Flask. Speed in tiles per second.
@export var throw_speed := 0.0
## What happens where it lands: &"poison_cloud" (a cloud that poisons enemies inside).
@export var throw_effect: StringName = &""
## The cloud's size in tiles and how long it lasts.
@export var cloud_tiles := Vector2(6, 4)
@export var cloud_seconds := 5.0
@export_group("Magic")
## Unused (spells don't go in books any more); kept so older files still load.
@export var spell_slots := 0
## Spellbooks: the highest spell tier the book can hold.
@export var max_spell_tier := 1
## Spellbooks: the book is your building tool too (like Starbound's matter manipulator).
## Placing blocks, walls and grass seeds reaches this far (tiles)...
@export var build_reach_tiles := 12.0
## Unused since Phase 41 (placing area follows the Mining Spell); kept so files load.
@export var build_area_max := 3
## Spellbooks, conduits and tomes: multiplies spell strength (mining damage for now).
@export var spell_power := 1.0
## Conduits: extra reach for spells, in tiles.
@export var spell_reach_bonus := 0.0
## Conduits: the kind of conduit (spells can require one, e.g. &"focus").
@export var conduit_type: StringName = &""
## Tomes: the one spell this tome casts (data/spells id). Held on the hotbar.
@export var tome_spell: StringName = &""
@export_group("")


## Looks up an item by id: data/items, spells ("spell:<id>", data/spells), plus
## runtime-only dev items in debug builds.
## Items that were merged into others: older saves load them as the new id.
const RENAMED: Dictionary[StringName, StringName] = {
	&"rock": &"stone", &"flint": &"stone", &"stick": &"wood", &"wood_planks": &"wood",
}


static func find(item_id: StringName) -> ItemData:
	if _empowered.has(item_id):
		return _empowered[item_id]
	if _runtime.has(item_id):
		return _runtime[item_id]
	var category := &"items"
	var key := item_id
	if String(item_id).begins_with(SPELL_PREFIX):
		category = &"spells"
		key = StringName(String(item_id).trim_prefix(SPELL_PREFIX))
	var tree := Engine.get_main_loop() as SceneTree
	var registry: Node = tree.root.get_node_or_null(^"/root/Registry") if tree else null
	if registry:
		return registry.call(&"get_def", category, key) as ItemData
	var path := "res://data/%s/%s.tres" % [category, key]
	return load(path) as ItemData if ResourceLoader.exists(path) else null


## The inventory id of a spell shortcut.
static func spell_key(spell_id: StringName) -> StringName:
	return StringName(SPELL_PREFIX + String(spell_id))


func is_spell() -> bool:
	return false


## Items made at runtime (debug builds' placeholder weapons). Not content.
static var _runtime: Dictionary[StringName, ItemData] = {}


static func register_runtime(item: ItemData) -> void:
	_runtime[spell_key(item.id) if item.is_spell() else item.id] = item


## The runtime-only items (dev items in debug builds), by key.
static func runtime_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.assign(_runtime.values())
	return out


## The playing character's spells with their Empower ranks applied (copies of the
## spell data), so every cast, tooltip and tool check sees the empowered numbers.
## Set by `CharacterData.apply_empower`.
static var _empowered: Dictionary[StringName, ItemData] = {}


static func set_empowered(spells: Array[ItemData]) -> void:
	_empowered.clear()
	for s in spells:
		_empowered[spell_key(s.id)] = s


## Runtime-only items aren't saved.
static func is_runtime(item_id: StringName) -> bool:
	return _runtime.has(item_id)


func validate() -> PackedStringArray:
	var problems := super()
	if icon == null:
		problems.append("%s: no icon" % id)
	if max_stack < 1:
		problems.append("%s: max_stack < 1" % id)
	return problems


## Size (px) of the item as a drop in the world (see drop_size).
## Whether it can be set down on display (tables, shelves, floors): small things only,
## not tools, weapons, armor, spells, or anything that places blocks or furniture.
func can_display() -> bool:
	if not displayable or is_spell():
		return false
	if places_block != &"" or places_wall != &"" or places_object != &"":
		return false
	return kind in [Kind.MATERIAL, Kind.FOOD, Kind.SEED, Kind.SCROLL]


## Places something in the world (a block, wall, furniture, a sapling or grass seeds).
func is_placeable() -> bool:
	return places_block != &"" or places_wall != &"" or places_object != &"" or plants != &""


func drop_pixels() -> float:
	if drop_size > 0:
		return float(drop_size)
	match kind:
		Kind.MATERIAL, Kind.SEED, Kind.FOOD:
			return 10.0
		Kind.TOOL, Kind.WEAPON, Kind.ARMOR:
			return 13.0
		Kind.FURNITURE:
			return 14.0
	return 11.0


## Whether special storage that takes `tag` takes this item: its `storage_tags`, plus
## "food" (food, not potions or coatings) and "book" (books, tomes, scrolls, pages,
## paper) worked out from what it is.
func has_storage_tag(tag: StringName) -> bool:
	if tag in storage_tags:
		return true
	match tag:
		&"food":
			return kind == Kind.FOOD and not (&"potion" in storage_tags) and buff_poison_hits == 0
		&"book":
			return kind in [Kind.BOOK, Kind.TOME, Kind.SCROLL, Kind.PAGE] or id in [&"paper", &"blank_scroll"]
	return false
