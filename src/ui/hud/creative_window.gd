class_name CreativeWindow
extends HudWindow
## The Creative window (F7, or console `creative`; debug builds for now): every item in
## the game, the dev and test things, and enemies to spawn. Tabs and a search box narrow
## the grid. Items like crafting: click puts one on the mouse, Shift + click 10, Ctrl +
## click a full stack (clicking again adds more, up to a stack). Right click: an
## infinite stack, which is never used up (placing, eating, throwing). Spells (Test
## tab) go on the mouse to drop on a quick slot. Enemies: click spawns one in front of
## you, Shift + click 5. Nothing else changes (no flying or god mode): it's just the menu.

const SLOT := Hud.SLOT
const STEP := Hud.STEP
const PAD := Hud.PAD
const COLS := 10
const TAB_H := 12
## Rows shown before the grid scrolls.
@export var rows_shown := 6

enum Part { NONE, ITEM, TAB, SEARCH }

## Tab name -> the kinds it shows (empty = all; the special tabs are matched by name).
## [name, category] (`category_of`); the last three are special lists.
const TABS: Array = [
	["All", &""], ["Blocks", &"blocks"], ["Furniture", &"furniture"], ["Stations", &"stations"],
	["Storage", &"storage"], ["Weapons", &"weapons"], ["Armor", &"armor"], ["Magic", &"magic"],
	["Consumables", &"consumables"], ["Materials", &"materials"],
	["Dev", &""],  # the dev cheat items (Dev Grimoire, Dev Focus, Dev Ring, Dev Tome)
	["Test", &""],  # test things: the placeholder held items, test books, test spells
	["Enemies", &""],  # every enemy: click to spawn
]
const DEV_TAB := 10
const TEST_TAB := 11
const ENEMY_TAB := 12


## Which Creative tab an item goes on: blocks (and walls, seeds, torches, rope),
## furniture, stations, storage (chests, cabinets, barrels, nets), weapons (and tools),
## armor (and accessories), magic (books, conduits, tomes, scrolls, pages),
## consumables (food, potions, coatings, throwables) or materials (the rest).
static func category_of(it: ItemData) -> StringName:
	match it.kind:
		ItemData.Kind.BLOCK, ItemData.Kind.WALL, ItemData.Kind.SEED:
			return &"blocks"
		ItemData.Kind.TOOL, ItemData.Kind.WEAPON:
			return &"weapons"
		ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY:
			return &"armor"
		ItemData.Kind.BOOK, ItemData.Kind.CONDUIT, ItemData.Kind.TOME, ItemData.Kind.SCROLL, ItemData.Kind.PAGE:
			return &"magic"
		ItemData.Kind.FOOD:
			return &"consumables"
		ItemData.Kind.FURNITURE:
			var def := Registry.get_def(&"objects", it.places_object) as ObjectDef
			if def and def.station != &"":
				return &"stations"
			if def and (def.container_slots > 0 or def.liquid_capacity > 0):
				return &"storage"
			return &"furniture"
	if it.throw_speed > 0.0 or it.buff_poison_hits > 0:
		return &"consumables"
	return &"materials"
## Test books (console `books`).
const TEST_BOOKS: Array[StringName] = [&"spellbook_t1", &"spellbook_t2", &"spellbook_t3"]
## Where an enemy appears: this many tiles in front of you.
@export var spawn_tiles := 6.0

var tab := 0
var search := ""
var searching := false
var scroll := 0
var _all: Array[ItemData] = []


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Creative")


## Every item (data/items and the runtime dev items), not spells, by name.
func all_items() -> Array[ItemData]:
	if _all.is_empty():
		var seen := {}
		for d in Registry.get_all(&"items"):
			var it := d as ItemData
			if it and not it.is_spell() and not it.obsolete and not seen.has(it.id):
				seen[it.id] = true
				_all.append(it)
		for it in ItemData.runtime_items():
			if not it.is_spell() and not seen.has(it.id):
				seen[it.id] = true
				_all.append(it)
		_all.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	return _all


## What the current tab shows (filtered by the search): ItemData (spells too on the
## Test tab) or EnemyData on the Enemies tab.
func shown() -> Array:
	var q := search.strip_edges().to_lower()
	var out: Array = []
	for entry in _tab_entries():
		var name: String = entry.display_name
		if q != "" and not q in name.to_lower():  # by name only (ids can say "bookcase")
			continue
		out.append(entry)
	return out


func _tab_entries() -> Array:
	match tab:
		DEV_TAB:
			return all_items().filter(func(it: ItemData) -> bool: return ItemData.is_runtime(it.id) and not _is_test(it))
		TEST_TAB:
			var out: Array = all_items().filter(func(it: ItemData) -> bool: return _is_test(it))
			for e: Array in DevMagic.STYLE_SPELLS:
				var sp := ItemData.find(ItemData.spell_key(e[0]))
				if sp:
					out.append(sp)
			var beam := ItemData.find(ItemData.spell_key(&"dev_wide_beam"))
			if beam:
				out.append(beam)
			return out
		ENEMY_TAB:
			var enemies: Array = Registry.get_all(&"enemies").duplicate()
			enemies.sort_custom(func(a: GameData, b: GameData) -> bool: return a.display_name < b.display_name)
			return enemies
	var cat: StringName = TABS[tab][1]
	return all_items().filter(func(it: ItemData) -> bool: return cat == &"" or category_of(it) == cat)


## Test things: the placeholder held items (DevHeldItems) and the test books.
func _is_test(it: ItemData) -> bool:
	if TEST_BOOKS.has(it.id):
		return true
	for h in DevHeldItems.items():
		if h.id == it.id:
			return true
	return false


func title_right() -> String:
	return "%d %s" % [shown().size(), "enemies" if tab == ENEMY_TAB else "items"]


func set_searching(on: bool) -> void:
	searching = on
	hud.world.player.typing = on
	queue_redraw()


func search_key(k: InputEventKey) -> bool:
	if not searching or k == null or not k.pressed:
		return false
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		set_searching(false)
	elif k.keycode == KEY_BACKSPACE:
		search = search.substr(0, maxi(0, search.length() - 1))
	elif k.unicode >= 32:
		search += char(k.unicode)
	else:
		return true
	scroll = 0
	queue_redraw()
	return true


## Tabs wrap onto a second row when they don't fit across.
func tab_rect(i: int) -> Rect2:
	var font := ThemeDB.fallback_font
	var right := PAD + COLS * STEP - Hud.GAP
	var x := float(PAD)
	var row := 0
	for k in i + 1:
		var w := _tab_w(font, k)
		if x + w > right and x > PAD:
			x = PAD
			row += 1
		if k == i:
			return Rect2(x, BODY_TOP + row * (TAB_H + 2), w, TAB_H)
		x += w + 2
	return Rect2()


func _tabs_bottom() -> float:
	return tab_rect(TABS.size() - 1).end.y


func _tab_w(font: Font, i: int) -> float:
	return font.get_string_size(String(TABS[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8


func search_rect() -> Rect2:
	return Rect2(PAD, _tabs_bottom() + 3, PAD + COLS * STEP - Hud.GAP - PAD, 11)


func _grid_top() -> float:
	return search_rect().end.y + 4


func cell(i: int) -> Rect2:
	var k := i - scroll * COLS
	return Rect2(PAD + (k % COLS) * STEP, _grid_top() + (k / COLS) * STEP, SLOT, SLOT)


func layout() -> void:
	size = Vector2(PAD * 2 + COLS * STEP - Hud.GAP, _grid_top() + rows_shown * STEP - Hud.GAP + PAD)
	var rows := ceili(shown().size() / float(COLS))
	scroll = clampi(scroll, 0, maxi(0, rows - rows_shown))


func hit(local: Vector2) -> Array:
	for i in TABS.size():
		if tab_rect(i).has_point(local):
			return [Part.TAB, i]
	if search_rect().has_point(local):
		return [Part.SEARCH, 0]
	var list := shown()
	for i in range(scroll * COLS, mini(list.size(), (scroll + rows_shown) * COLS)):
		if cell(i).has_point(local):
			return [Part.ITEM, i]
	return [Part.NONE, -1]


func draw_body(font: Font) -> void:
	var h := hit(get_local_mouse_position()) if hovered() else [Part.NONE, -1]
	for i in TABS.size():
		var state := UiSkin.Btn.PRESSED if tab == i else (UiSkin.Btn.HOT if h[0] == Part.TAB and h[1] == i else UiSkin.Btn.NORMAL)
		UiSkin.button(self, tab_rect(i), String(TABS[i][0]), state)
		if tab == i:  # the open tab: a gold underline
			var tr := tab_rect(i)
			draw_rect(Rect2(tr.position.x + 2, tr.end.y + 0.5, tr.size.x - 4, 1), UiSkin.GOLD)
	var sr := search_rect()
	UiSkin.slot(self, sr, UiSkin.SlotLook.SELECTED if searching else (UiSkin.SlotLook.HOT if h[0] == Part.SEARCH else UiSkin.SlotLook.NORMAL))
	var blink := searching and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0
	var text := search + ("_" if blink else "")
	if search == "" and not searching:
		text = "Search..."
	draw_string(font, sr.position + Vector2(3, 8), text, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 6, 6,
		UiSkin.TEXT if search != "" or searching else UiSkin.DIM)
	var list := shown()
	for i in range(scroll * COLS, mini(list.size(), (scroll + rows_shown) * COLS)):
		var r := cell(i)
		var hot: bool = h[0] == Part.ITEM and h[1] == i
		UiSkin.slot(self, r, UiSkin.SlotLook.HOT if hot else UiSkin.SlotLook.NORMAL)
		if list[i] is EnemyData:
			_enemy_icon(r.grow(-2), list[i] as EnemyData)
		else:
			hud._draw_item(self, font, r, list[i], 1)
	var rows := ceili(list.size() / float(COLS))
	if scroll > 0:
		draw_string(font, Vector2(size.x - PAD - 6, _grid_top() - 2), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	if scroll + rows_shown < rows:
		draw_string(font, Vector2(size.x - PAD - 6, size.y - 1), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)


func body_click(mb: InputEventMouseButton) -> void:
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var rows := ceili(shown().size() / float(COLS))
		scroll = clampi(scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows - rows_shown))
		return
	var h := hit(mb.position)
	if h[0] != Part.SEARCH and searching:
		set_searching(false)
	match h[0]:
		Part.TAB:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				tab = h[1]
				scroll = 0
		Part.SEARCH:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				set_searching(not searching)
		Part.ITEM:
			var entry: Variant = shown()[h[1]]
			if entry is EnemyData:
				if mb.button_index == MOUSE_BUTTON_LEFT:
					spawn(entry as EnemyData, 5 if mb.shift_pressed else 1)
				return
			var it: ItemData = entry
			if it.is_spell():
				if mb.button_index == MOUSE_BUTTON_LEFT:
					hud.give_cursor(ItemData.spell_key(it.id), 1)  # drop it on a quick slot
				return
			var stack := maxi(it.max_stack, 1)
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				hud.give_cursor(it.id, stack, {"infinite": true})
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				hud.give_cursor(it.id, stack if mb.ctrl_pressed else (10 if mb.shift_pressed else 1))


func tooltip_at(local: Vector2) -> Array:
	var h := hit(local)
	if h[0] == Part.ITEM:
		var entry: Variant = shown()[h[1]]
		if entry is EnemyData:
			var e := entry as EnemyData
			return [null, "%s\nHealth %d, damage %d\nClick: spawn one in front of you. Shift: 5." % [
				e.display_name, roundi(e.max_health), roundi(e.contact_damage)]]
		if (entry as ItemData).is_spell():
			return [entry, "Click: onto the mouse, then drop it on a quick slot."]
		return [entry, "Click: 1. Shift: 10. Ctrl: a stack. Right click: an infinite stack."]
	return [null, ""]


## Spawns `count` of an enemy a few tiles in front of you, spread out a little.
func spawn(e: EnemyData, count: int) -> void:
	var p := hud.world.player
	for i in count:
		var at := p.global_position + Vector2(p.facing * (spawn_tiles + i * 1.5) * World.TILE, -World.TILE * 2.0)
		hud.world.request_spawn_enemy(e, at)


func _enemy_icon(r: Rect2, e: EnemyData) -> void:
	if e.texture == null:
		return
	var f := Vector2(e.frame_size)
	var k := minf(r.size.x / f.x, r.size.y / f.y)
	var dst := Rect2(r.position + (r.size - f * k) * 0.5, f * k)
	draw_texture_rect_region(e.texture, dst, Rect2(Vector2.ZERO, f), e.tint)
