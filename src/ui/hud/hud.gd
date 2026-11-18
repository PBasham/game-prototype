class_name Hud
extends CanvasLayer
## The in-world HUD: the hotbar (top left), the inventory panel (I or Tab) with the
## equipment and spell sections, the spellbook key (tap R: book out or away, hold R:
## spell wheel), the stack held on the mouse,
## tooltips, and pickup notes. Placeholder look until real UI art exists.
##
## Inventory panel: 4 rows of 10, the top row is the hotbar. On the right, the crafting
## list: hand crafting, or the recipes of the station you opened (right click or E on a
## Workbench, Furnace, Anvil). Click a recipe to craft one, Shift + click for 10; the
## mouse wheel scrolls a long list. A chest you open shows its 40 slots under your
## inventory (Shift + click moves a stack across). The mana bar is under the hotbar.
##   Left click: pick up a stack / put it down / swap / merge.
##   Right click: pick up half, or put one down from the stack on the mouse.
##   Shift + left click: move a stack between the hotbar and the rest.
##   Ctrl + right click: equip a book or conduit (swapping with the equipped one); on an
##   equipment slot, put it back in the inventory.
##   Click outside the panel with a stack on the mouse: throw it.
## Equipment (right of the grid): Book and Conduit slots. An empty book slot means the
## Basic Spellbook.
## Spellbook (under the grid): the equipped book's slots. Spells (under that): every
## spell you know. Click a spell to pick it up, then click a book slot to put it in the
## book, or a hotbar slot to make a shortcut. Right click a book slot to empty it.

const SLOT := 20
const GAP := 2
const MARGIN := Vector2(6, 6)
const BG := Color(0.07, 0.08, 0.1, 0.78)
const BG_HOT := Color(0.12, 0.13, 0.16, 0.88)
const BG_PANEL := Color(0.05, 0.06, 0.08, 0.6)
const EDGE := Color(1, 1, 1, 0.12)
const SELECTED := Color("f2d27a")
const TEXT := Color("f2ead8")
const DIM := Color("a8a090")
const BAD := Color(1.0, 0.35, 0.3, 0.45)

## Where a click landed.
enum Area { NONE, INVENTORY, EQUIPMENT, BOOK, SPELLS, CHEST, RECIPE, UPGRADE }
## Crafting list: row height and width.
const ROW := 22
const CRAFT_W := 252
const EQUIP_SLOTS: Array[StringName] = [CharacterData.SLOT_BOOK, CharacterData.SLOT_CONDUIT]

## Radius (UI px) of the spell wheel.
@export var wheel_radius := 44.0
## Holding R this long (seconds) opens the spell wheel; a shorter tap takes the
## spellbook out or puts it back.
@export var wheel_hold_seconds := 0.2
## Seconds a pickup note stays after the last item of that kind arrived.
@export var note_seconds := 1.6

var world: World
var open := false
## Stack held on the mouse (inventory open). "spell:<id>" = a spell being placed.
var cursor_id: StringName = &""
var cursor_count := 0
## The spell wheel is open (R held): its center and the highlighted spell.
var wheel_open := false
var wheel_center := Vector2.ZERO
var wheel_choice: StringName = &""
var _r_down := false
var _r_held := 0.0
## The crafting station (anchor tile) or chest the panel was opened from; NO_TILE = none
## (the panel shows hand crafting).
var station := World.NO_TILE
var chest := World.NO_TILE
## First crafting row shown (mouse wheel over the list scrolls).
var _craft_scroll := 0

var _grid: Grid
var _wheel: Wheel
var _name_label: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
var _notes: VBoxContainer
var _note_labels: Dictionary[StringName, Label] = {}
var _note_counts: Dictionary[StringName, int] = {}
var _note_age: Dictionary[StringName, float] = {}


## Draws the slots and handles clicks on them.
class Grid extends Control:
	var hud: Hud

	func _draw() -> void:
		hud.draw_grid(self)

	func _gui_input(event: InputEvent) -> void:
		hud.grid_input(event)


class Wheel extends Control:
	var hud: Hud

	func _draw() -> void:
		hud.draw_wheel(self)


func _ready() -> void:
	layer = 20
	_grid = Grid.new()
	_grid.hud = self
	_grid.position = MARGIN
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_grid)
	_wheel = Wheel.new()
	_wheel.hud = self
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.visible = false
	add_child(_wheel)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", TEXT)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_name_label)
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	style.set_content_margin_all(4)
	style.set_corner_radius_all(2)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text = Label.new()
	_tooltip_text.add_theme_font_size_override("font_size", 8)
	_tooltip_text.add_theme_color_override("font_color", TEXT)
	_tooltip.add_child(_tooltip_text)
	_tooltip.visible = false
	add_child(_tooltip)
	_notes = VBoxContainer.new()
	_notes.position = Vector2(6, 300)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	EventBus.item_picked_up.connect(_on_picked_up)
	world.station_opened.connect(_on_station_opened)
	world.container_opened.connect(_on_container_opened)
	world.character.inventory.changed.connect(_grid.queue_redraw)
	world.character.magic_changed.connect(_layout)
	world.player.selection_changed.connect(func(_s: int) -> void: _grid.queue_redraw())
	_layout()


func _input(event: InputEvent) -> void:
	if open and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# A click on the world with a stack on the mouse throws it.
	var mb := event as InputEventMouseButton
	if open and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and cursor_count > 0:
		_throw_cursor()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_notes(delta)
	var paused := world.get_tree().paused or (world.console != null and world.console.open)
	# Polled (not _input) so scripted runs can tap them too.
	if Input.is_action_just_pressed("inventory") and not paused:
		set_open(not open)
	_update_wheel(paused)
	var p := world.player
	var over := _grid.get_global_rect().has_point(_grid.get_global_mouse_position())
	p.input_blocked = over or cursor_count > 0 or paused or wheel_open
	_update_tooltip(over)
	if (station != World.NO_TILE or chest != World.NO_TILE) and not _in_reach_of(station if station != World.NO_TILE else chest):
		set_open(false)  # walked away from the station or chest
	_grid.queue_redraw()  # mana bar, recipe counts
	var item := p.held_item
	_name_label.text = item.display_name if item else ""
	if p.concentration:
		_name_label.text += ("\n" if _name_label.text != "" else "") + "Concentrating: %s" % p.concentration.display_name
	if cursor_count > 0:
		_grid.queue_redraw()


func set_open(value: bool) -> void:
	open = value
	if not open:
		station = World.NO_TILE
		chest = World.NO_TILE
	_craft_scroll = 0
	if not open and cursor_count > 0:
		if _cursor_is_spell():
			_clear_cursor()  # a spell being placed just goes back
		else:
			var left := world.character.inventory.add(cursor_id, cursor_count)
			cursor_count = left
			if left > 0:
				_throw_cursor()
			_clear_cursor()
	_layout()


func _on_station_opened(anchor: Vector2i) -> void:
	set_open(true)
	station = anchor
	_layout()


func _on_container_opened(anchor: Vector2i) -> void:
	set_open(true)
	chest = anchor
	_layout()


func _in_reach_of(anchor: Vector2i) -> bool:
	var p := world.player
	var at := world.tile_to_world(anchor) + Vector2(World.TILE, 0)
	at.x += roundf((p.global_position.x - at.x) / (world.data.width * World.TILE)) * world.data.width * World.TILE
	return at.distance_to(p.chest()) <= (world.interact_tiles + 4.0) * World.TILE \
		and world.object_anchor(anchor) == anchor


# --- layout ------------------------------------------------------------------------------

func _layout() -> void:
	if open:
		var bottom := _spells_origin().y + _rows(_known().size()) * (SLOT + GAP)
		if chest != World.NO_TILE:
			bottom = _book_origin().y + 4 * (SLOT + GAP) + 4
		bottom = maxf(bottom, _craft_origin().y + 6 * ROW + 16)
		_grid.size = Vector2(_craft_origin().x + CRAFT_W, bottom)
	else:
		_grid.size = Vector2(10 * (SLOT + GAP) - GAP, SLOT + 6)
	_name_label.position = MARGIN + Vector2(0, (_grid.size.y if open else SLOT + 6) + 2)
	_grid.queue_redraw()


func _craft_origin() -> Vector2:
	return Vector2(_equip_origin().x + SLOT + 104, 12)


## The recipes the list shows: the open station's, or hand crafting.
func recipes() -> Array[RecipeData]:
	var def := world.object_at(station) if station != World.NO_TILE else null
	if def and def.station != &"":
		return Crafting.recipes_for(def.station, def.station_tier)
	return Crafting.recipes_for(&"")


func _rows_shown() -> int:
	return int((_grid.size.y - _craft_origin().y - (ROW if _upgrade_shown() else 0)) / ROW)


func _recipe_rect(i: int) -> Rect2:
	return Rect2(_craft_origin() + Vector2(0, (i - _craft_scroll) * ROW), Vector2(CRAFT_W - 4, ROW - 2))


func _upgrade_shown() -> bool:
	var def := world.object_at(station) if station != World.NO_TILE else null
	return def != null and def.upgrade_to != &""


func _upgrade_rect() -> Rect2:
	return Rect2(_craft_origin() + Vector2(0, _rows_shown() * ROW), Vector2(CRAFT_W - 4, ROW - 2))


func _rows(n: int) -> int:
	return maxi(1, ceili(n / 10.0))


func _equip_origin() -> Vector2:
	return Vector2(10 * (SLOT + GAP) + 8, 0)


func _book_origin() -> Vector2:
	return Vector2(0, 4 * (SLOT + GAP) + 12)


func _spells_origin() -> Vector2:
	return _book_origin() + Vector2(0, _rows(world.character.book_slot_count()) * (SLOT + GAP) + 12)


func _known() -> Array[StringName]:
	return world.character.known_spells


## Rect of slot `i` in a 10-wide block starting at `origin`.
func _cell(origin: Vector2, i: int) -> Rect2:
	return Rect2(origin + Vector2((i % 10) * (SLOT + GAP), (i / 10) * (SLOT + GAP)), Vector2(SLOT, SLOT))


func _equip_cell(i: int) -> Rect2:
	return Rect2(_equip_origin() + Vector2(0, i * (SLOT + GAP + 4)), Vector2(SLOT, SLOT))


## [Area, index] under a point in the grid's space.
func hit(local: Vector2) -> Array:
	var rows := 4 if open else 1
	for i in rows * 10:
		if _cell(Vector2.ZERO, i).has_point(local):
			return [Area.INVENTORY, i]
	if not open:
		return [Area.NONE, -1]
	for i in EQUIP_SLOTS.size():
		if _equip_cell(i).has_point(local):
			return [Area.EQUIPMENT, i]
	var list := recipes()
	for i in range(_craft_scroll, mini(list.size(), _craft_scroll + _rows_shown())):
		if _recipe_rect(i).has_point(local):
			return [Area.RECIPE, i]
	if _upgrade_shown() and _upgrade_rect().has_point(local):
		return [Area.UPGRADE, 0]
	if chest != World.NO_TILE:
		for i in Inventory.SIZE:
			if _cell(_book_origin(), i).has_point(local):
				return [Area.CHEST, i]
		return [Area.NONE, -1]
	for i in world.character.book_slot_count():
		if _cell(_book_origin(), i).has_point(local):
			return [Area.BOOK, i]
	for i in _known().size():
		if _cell(_spells_origin(), i).has_point(local):
			return [Area.SPELLS, i]
	return [Area.NONE, -1]


## Inventory slot under a point (or -1). Tests use this.
func slot_at(local: Vector2) -> int:
	var h := hit(local)
	return h[1] if h[0] == Area.INVENTORY else -1


# --- drawing -----------------------------------------------------------------------------

func draw_grid(g: Control) -> void:
	var c := world.character
	var inv := c.inventory
	var font := ThemeDB.fallback_font
	var rows := 4 if open else 1
	if open:
		g.draw_rect(Rect2(Vector2(-4, -4), g.size + Vector2(8, 8)), Color(0.03, 0.04, 0.06, 0.82))
	for i in rows * 10:
		var r := _cell(Vector2.ZERO, i)
		g.draw_rect(r, BG_HOT if i < Inventory.HOTBAR else BG)
		g.draw_rect(r, SELECTED if i == world.player.selected else EDGE, false, 1.0)
		var item := inv.item(i)
		if item:
			_draw_item(g, font, r, item, inv.counts[i])
		if i < Inventory.HOTBAR:
			g.draw_string(font, r.position + Vector2(2, 7), str((i + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DIM)
	if open:
		if chest != World.NO_TILE:
			_draw_chest(g, font)
		else:
			_draw_magic(g, font)
		_draw_crafting(g, font)
	else:
		_draw_mana(g)
	if cursor_count > 0:
		var item := ItemData.find(cursor_id)
		var m := g.get_local_mouse_position()
		if item and item.icon:
			g.draw_texture_rect(item.icon, Rect2(m + Vector2(2, 2), Vector2(16, 16)), false)
		if cursor_count > 1:
			_draw_count(g, font, Rect2(m, Vector2(SLOT, SLOT)), cursor_count)


func _draw_item(g: Control, font: Font, r: Rect2, item: ItemData, count: int) -> void:
	if item.icon:
		g.draw_texture_rect(item.icon, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false)
	if item.is_spell():
		# Spell shortcut: a small mark, and red when it can't be cast right now.
		g.draw_rect(Rect2(r.position + Vector2(SLOT - 5, 1), Vector2(4, 4)), Color("7fd4ff"))
		if world.character.cast_problem(item as SpellData) != "":
			g.draw_rect(r.grow(-1), BAD)
	elif count > 1:
		_draw_count(g, font, r, count)


func _draw_magic(g: Control, font: Font) -> void:
	var c := world.character
	# Equipment.
	var labels := ["Book", "Conduit"]
	for i in EQUIP_SLOTS.size():
		var r := _equip_cell(i)
		g.draw_rect(r, BG_HOT)
		g.draw_rect(r, EDGE, false, 1.0)
		var item := ItemData.find(c.equipment[EQUIP_SLOTS[i]]) if c.equipment[EQUIP_SLOTS[i]] != &"" else null
		var text: String = labels[i]
		if item:
			_draw_item(g, font, r, item, 1)
			text += ": " + item.display_name
		elif i == 0:
			var basic := c.book()
			if basic and basic.icon:
				g.draw_texture_rect(basic.icon, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false, Color(1, 1, 1, 0.45))
			text += ": Basic (empty slot)"
		else:
			text += ": none"
		g.draw_string(font, r.position + Vector2(SLOT + 4, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, TEXT)
	# The book's slots.
	var book := c.book()
	var title := "Spellbook: %s (%d slots)" % [book.display_name if book else "?", c.book_slot_count()]
	g.draw_string(font, _book_origin() + Vector2(0, -3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
	var loadout := c.book_loadout()
	for i in loadout.size():
		var r := _cell(_book_origin(), i)
		g.draw_rect(r, BG_PANEL)
		g.draw_rect(r, EDGE, false, 1.0)
		var spell := ItemData.find(ItemData.spell_key(loadout[i])) if loadout[i] != &"" else null
		if spell:
			_draw_item(g, font, r, spell, 1)
	# Known spells.
	g.draw_string(font, _spells_origin() + Vector2(0, -3), "Spells you know (click one, then a book or hotbar slot)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
	var known := _known()
	for i in known.size():
		var r := _cell(_spells_origin(), i)
		g.draw_rect(r, BG_PANEL)
		g.draw_rect(r, SELECTED if c.in_book(known[i]) else EDGE, false, 1.0)
		var spell := ItemData.find(ItemData.spell_key(known[i]))
		if spell and spell.icon:
			g.draw_texture_rect(spell.icon, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false)


## Mana bar under the hotbar.
func _draw_mana(g: Control) -> void:
	var p := world.player
	var w := 10 * (SLOT + GAP) - GAP
	var r := Rect2(0, SLOT + 2, w, 3)
	g.draw_rect(r, Color(0, 0, 0, 0.55))
	var k := 1.0 if p.infinite_mana else clampf(p.mana / maxf(p.max_mana, 1.0), 0.0, 1.0)
	g.draw_rect(Rect2(r.position, Vector2(w * k, 3)), Color("5aa0ff") if not p.infinite_mana else Color("b07aff"))


func _draw_chest(g: Control, font: Font) -> void:
	var store := world.container_at(chest)
	var def := world.object_at(chest)
	g.draw_string(font, _book_origin() + Vector2(0, -3), def.display_name if def else "Chest",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
	if store == null:
		return
	for i in Inventory.SIZE:
		var r := _cell(_book_origin(), i)
		g.draw_rect(r, BG)
		g.draw_rect(r, EDGE, false, 1.0)
		var item := store.item(i)
		if item:
			_draw_item(g, font, r, item, store.counts[i])


func _draw_crafting(g: Control, font: Font) -> void:
	var inv := world.character.inventory
	var def := world.object_at(station) if station != World.NO_TILE else null
	var title := "Crafting by hand"
	if def and def.station != &"":
		title = "%s (tier %d)" % [def.display_name, def.station_tier]
	g.draw_string(font, _craft_origin() + Vector2(0, -3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
	var list := recipes()
	if list.is_empty():
		g.draw_string(font, _craft_origin() + Vector2(4, 12), "Nothing to craft here yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
	var hover := hit(g.get_local_mouse_position())
	for i in range(_craft_scroll, mini(list.size(), _craft_scroll + _rows_shown())):
		var r := list[i]
		var rect := _recipe_rect(i)
		var times := Crafting.times_craftable(inv, r)
		var hot: bool = hover[0] == Area.RECIPE and hover[1] == i
		g.draw_rect(rect, BG_HOT if hot else BG_PANEL)
		var out := ItemData.find(r.output)
		var a := 1.0 if times > 0 else 0.4
		if out and out.icon:
			g.draw_texture_rect(out.icon, Rect2(rect.position + Vector2(2, 2), Vector2(16, 16)), false, Color(1, 1, 1, a))
		var label_text := (out.display_name if out else String(r.output)) + (" x%d" % r.output_count if r.output_count > 1 else "")
		g.draw_string(font, rect.position + Vector2(21, 9), label_text, HORIZONTAL_ALIGNMENT_LEFT, 110, 7, Color(TEXT, a))
		# Inputs: icon and count, red when short.
		var x := 21.0
		for k: StringName in r.inputs:
			var it := ItemData.find(k)
			if it and it.icon:
				g.draw_texture_rect(it.icon, Rect2(rect.position + Vector2(x, 10), Vector2(9, 9)), false, Color(1, 1, 1, a))
			var short := inv.count_of(k) < r.inputs[k]
			g.draw_string(font, rect.position + Vector2(x + 10, 18), str(r.inputs[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
				Color("ff8a7a") if short else Color(DIM, a))
			x += 28.0
		for q in r.requires:
			var it := ItemData.find(q)
			if it and it.icon:
				var has := inv.count_of(q) > 0
				g.draw_texture_rect(it.icon, Rect2(rect.position + Vector2(x, 10), Vector2(9, 9)), false,
					Color(1, 1, 1, a) if has else Color(1, 0.5, 0.45, 0.8))
				g.draw_string(font, rect.position + Vector2(x + 10, 18), "keep", HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
					Color(DIM, a) if has else Color("ff8a7a"))
				x += 34.0
		if times > 0:
			g.draw_string(font, rect.position + Vector2(CRAFT_W - 30, 9), "x%d" % times, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DIM)
	if list.size() > _rows_shown():
		g.draw_string(font, _craft_origin() + Vector2(CRAFT_W - 70, -3), "wheel: more", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DIM)
	if _upgrade_shown():
		var ur := _upgrade_rect()
		var ok := _can_upgrade()
		g.draw_rect(ur, BG_HOT if ok else BG_PANEL)
		var next := world.objects.def(world.objects.index_of(def.upgrade_to)) as ObjectDef
		var text := "Upgrade to %s:" % (next.display_name if next else String(def.upgrade_to))
		for k: StringName in def.upgrade_cost:
			text += " %d %s" % [def.upgrade_cost[k], Crafting._name(k)]
		g.draw_string(font, ur.position + Vector2(4, 13), text, HORIZONTAL_ALIGNMENT_LEFT, CRAFT_W - 8, 7,
			Color(TEXT, 1.0 if ok else 0.45))


func _draw_count(g: Control, font: Font, r: Rect2, n: int) -> void:
	var text := str(n)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var at := r.position + Vector2(SLOT - w - 1, SLOT - 2)
	g.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0, 0, 0, 0.8))
	g.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, TEXT)


# --- clicks ------------------------------------------------------------------------------

func grid_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if open and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
			and mb.position.x >= _craft_origin().x:
		var most := maxi(recipes().size() - _rows_shown(), 0)
		_craft_scroll = clampi(_craft_scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
		_grid.accept_event()
		return
	var h := hit(mb.position)
	if h[0] == Area.NONE:
		return
	_grid.accept_event()
	var left := mb.button_index == MOUSE_BUTTON_LEFT
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	match h[0]:
		Area.INVENTORY:
			var slot: int = h[1]
			if not open:
				if left:
					world.player.select_slot(slot)  # hotbar click selects
			elif right and mb.ctrl_pressed:
				quick_equip(slot)
			elif left and mb.shift_pressed:
				if chest != World.NO_TILE:
					_move_stack(world.character.inventory, slot, world.container_at(chest))
				else:
					_quick_move(slot)
			elif left:
				click_slot(slot)
			elif right:
				right_click_slot(slot)
		Area.EQUIPMENT:
			if (right and mb.ctrl_pressed) or (left and mb.shift_pressed):
				quick_unequip(EQUIP_SLOTS[h[1]])
			elif left:
				click_equipment(EQUIP_SLOTS[h[1]])
		Area.BOOK:
			if left:
				click_book_slot(h[1])
			elif right:
				world.character.put_in_book(h[1], &"")
		Area.SPELLS:
			if left:
				click_known_spell(h[1])
		Area.CHEST:
			var store := world.container_at(chest)
			if store:
				if left and mb.shift_pressed:
					_move_stack(store, h[1], world.character.inventory)
				elif left:
					click_slot(h[1], store)
				elif right:
					right_click_slot(h[1], store)
		Area.RECIPE:
			if left:
				craft(recipes()[h[1]], 10 if mb.shift_pressed else 1)
		Area.UPGRADE:
			if left:
				upgrade_station()
	_grid.queue_redraw()


## Crafts a recipe up to `times` times from the inventory; extra output drops at your
## feet.
func craft(r: RecipeData, times: int) -> int:
	var result := Crafting.craft(world.character.inventory, r, times)
	if int(result[1]) > 0:
		world.request_spawn_drop(r.output, int(result[1]), world.player.chest(), Vector2.ZERO, true)
	if int(result[0]) > 0:
		EventBus.item_picked_up.emit(r.output, int(result[0]) * r.output_count)
	return int(result[0])


func _can_upgrade() -> bool:
	var def := world.object_at(station) if station != World.NO_TILE else null
	if def == null or def.upgrade_to == &"":
		return false
	for k: StringName in def.upgrade_cost:
		if world.character.inventory.count_of(k) < def.upgrade_cost[k]:
			return false
	return true


## Upgrades the open station in place to its next tier (same footprint expected).
func upgrade_station() -> bool:
	if not _can_upgrade():
		return false
	var def := world.object_at(station)
	var next := world.objects.index_of(def.upgrade_to)
	if next <= 0:
		return false
	for k: StringName in def.upgrade_cost:
		world.character.inventory.remove(k, def.upgrade_cost[k])
	world.request_set_object(station, next)
	return true


## Shift + click with a chest open: the whole stack to the other side.
func _move_stack(from: Inventory, slot: int, to: Inventory) -> void:
	if to == null or from.is_empty(slot) or String(from.ids[slot]).begins_with(ItemData.SPELL_PREFIX):
		return
	var id := from.ids[slot]
	var left := to.add(id, from.counts[slot])
	from.set_slot(slot, id if left > 0 else &"", left)


## Left click with the panel open: pick up, put down, merge or swap. `inv` = a chest
## (null = your inventory).
func click_slot(slot: int, inv: Inventory = null) -> void:
	if inv == null:
		inv = world.character.inventory
	elif _cursor_is_spell():
		return  # spell shortcuts don't go in chests
	if cursor_count == 0:
		if not inv.is_empty(slot):
			cursor_id = inv.ids[slot]
			cursor_count = inv.counts[slot]
			inv.set_slot(slot, &"", 0)
		return
	if inv.is_empty(slot):
		inv.set_slot(slot, cursor_id, cursor_count)
		_clear_cursor()
	elif inv.ids[slot] == cursor_id and not _cursor_is_spell():
		var cap := Inventory.max_stack(cursor_id)
		var n := mini(cursor_count, cap - inv.counts[slot])
		inv.set_slot(slot, cursor_id, inv.counts[slot] + n)
		cursor_count -= n
		if cursor_count <= 0:
			_clear_cursor()
	elif inv.ids[slot] == cursor_id:
		_clear_cursor()  # the same shortcut is already there
	else:
		var id := inv.ids[slot]
		var count := inv.counts[slot]
		inv.set_slot(slot, cursor_id, cursor_count)
		cursor_id = id
		cursor_count = count


## Right click: take half (empty mouse) or put one down.
func right_click_slot(slot: int, inv: Inventory = null) -> void:
	if inv == null:
		inv = world.character.inventory
	elif _cursor_is_spell():
		return
	if cursor_count == 0:
		if inv.is_empty(slot):
			return
		var half := ceili(inv.counts[slot] / 2.0)
		cursor_id = inv.ids[slot]
		cursor_count = inv.take(slot, half)
		return
	if inv.is_empty(slot) or (inv.ids[slot] == cursor_id and inv.counts[slot] < Inventory.max_stack(cursor_id)):
		inv.set_slot(slot, cursor_id, (0 if inv.is_empty(slot) else inv.counts[slot]) + 1)
		cursor_count -= 1
		if cursor_count <= 0:
			_clear_cursor()


## Book or conduit slot: put the item on the mouse there (if it fits), taking out what
## was there.
func click_equipment(slot: StringName) -> void:
	var c := world.character
	if cursor_count == 0:
		var taken := c.equip(slot, &"")
		if taken != &"":
			cursor_id = taken
			cursor_count = 1
		return
	var item := ItemData.find(cursor_id)
	if cursor_count != 1 or not CharacterData.fits(slot, item):
		EventBus.debug_message.emit("That doesn't go there")
		return
	var old := c.equip(slot, cursor_id)
	if old != &"":
		cursor_id = old
		cursor_count = 1
	else:
		_clear_cursor()


## Ctrl + right click on an inventory slot: equip it (book or conduit), swapping with
## what was equipped.
func quick_equip(slot: int) -> void:
	var c := world.character
	var item := c.inventory.item(slot)
	if item == null:
		return
	for eq in EQUIP_SLOTS:
		if CharacterData.fits(eq, item):
			var old := c.equip(eq, item.id)
			c.inventory.set_slot(slot, old, 1 if old != &"" else 0)
			return


## Ctrl + right click (or shift + click) on an equipment slot: back into the inventory.
func quick_unequip(eq: StringName) -> void:
	var c := world.character
	var item_id: StringName = c.equipment[eq]
	if item_id == &"" or c.inventory.room_for(item_id) <= 0:
		return
	c.equip(eq, &"")
	c.inventory.add(item_id, 1)


func click_book_slot(i: int) -> void:
	var c := world.character
	if _cursor_is_spell():
		if c.put_in_book(i, _cursor_spell()):
			_clear_cursor()
		else:
			EventBus.debug_message.emit("Too powerful for this spellbook (needs a book for higher tiers)")
	elif cursor_count == 0:
		var loadout := c.book_loadout()
		if loadout[i] != &"":
			cursor_id = ItemData.spell_key(loadout[i])
			cursor_count = 1
			c.put_in_book(i, &"")


func click_known_spell(i: int) -> void:
	if cursor_count > 0:
		if _cursor_is_spell():
			_clear_cursor()
		return
	cursor_id = ItemData.spell_key(_known()[i])
	cursor_count = 1


## Shift + click: hotbar <-> the rest of the inventory.
func _quick_move(slot: int) -> void:
	var inv := world.character.inventory
	if inv.is_empty(slot):
		return
	var to_hotbar := slot >= Inventory.HOTBAR
	var id := inv.ids[slot]
	var n := inv.counts[slot]
	var lo := 0 if to_hotbar else Inventory.HOTBAR
	var hi := Inventory.HOTBAR if to_hotbar else Inventory.SIZE
	var cap := Inventory.max_stack(id)
	for pass_i in 2:  # first top up matching stacks, then empty slots
		for i in range(lo, hi):
			if n <= 0:
				break
			if pass_i == 0 and inv.ids[i] == id and inv.counts[i] < cap:
				var k := mini(n, cap - inv.counts[i])
				inv.set_slot(i, id, inv.counts[i] + k)
				n -= k
			elif pass_i == 1 and inv.is_empty(i):
				var k := mini(n, cap)
				inv.set_slot(i, id, k)
				n -= k
	inv.set_slot(slot, id if n > 0 else &"", n)


func _cursor_is_spell() -> bool:
	return cursor_count > 0 and String(cursor_id).begins_with(ItemData.SPELL_PREFIX)


func _cursor_spell() -> StringName:
	return StringName(String(cursor_id).trim_prefix(ItemData.SPELL_PREFIX))


func _throw_cursor() -> void:
	var p := world.player
	var dir := 1.0 if p.get_global_mouse_position().x >= p.global_position.x else -1.0
	world.request_spawn_drop(cursor_id, cursor_count, p.chest() + Vector2(dir * 10.0, 0),
		Vector2(dir * p.throw_speed * World.TILE, -6.0 * World.TILE), true)
	_clear_cursor()


func _clear_cursor() -> void:
	cursor_id = &""
	cursor_count = 0
	_grid.queue_redraw()


# --- spell wheel -------------------------------------------------------------------------

func _update_wheel(paused: bool) -> void:
	# R: tap = take the spellbook out (or put it back), hold = spell wheel.
	if Input.is_action_just_pressed("spellbook") and not paused and not open:
		_r_held = 0.0
		_r_down = true
	if _r_down:
		_r_held += get_process_delta_time()
		if not wheel_open and _r_held >= wheel_hold_seconds:
			wheel_open = true
			wheel_center = _wheel.get_local_mouse_position()
			wheel_choice = &""
		if not Input.is_action_pressed("spellbook"):
			_r_down = false
			if not wheel_open:
				world.player.toggle_spellbook()
	if not wheel_open:
		_wheel.visible = false
		return
	_wheel.visible = true
	var spells := wheel_spells()
	var d := _wheel.get_local_mouse_position() - wheel_center
	wheel_choice = &""
	if d.length() > 8.0 and not spells.is_empty():
		wheel_choice = spells[wheel_index(d.angle(), spells.size())]
	_wheel.queue_redraw()
	if not _r_down:
		wheel_open = false
		_wheel.visible = false
		if wheel_choice != &"":
			world.player.ready_spell(wheel_choice)


## The spells on the wheel: the book's slots that have one.
func wheel_spells() -> Array[StringName]:
	var out: Array[StringName] = []
	for s in world.character.book_loadout():
		if s != &"":
			out.append(s)
	return out


## Which of `n` wheel segments an angle (radians, 0 = right) falls in. Segment 0 is at
## the top, going clockwise.
static func wheel_index(angle: float, n: int) -> int:
	var a := fposmod(angle + PI * 0.5 + PI / n, TAU)
	return clampi(int(a / (TAU / n)), 0, n - 1)


func draw_wheel(w: Control) -> void:
	var spells := wheel_spells()
	var font := ThemeDB.fallback_font
	w.draw_circle(wheel_center, wheel_radius + 14.0, Color(0.03, 0.04, 0.06, 0.55))
	if spells.is_empty():
		w.draw_string(font, wheel_center + Vector2(-40, 3), "No spells in your book", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, DIM)
		return
	for i in spells.size():
		var a := -PI * 0.5 + TAU * i / spells.size()
		var at := wheel_center + Vector2.from_angle(a) * wheel_radius
		var spell := ItemData.find(ItemData.spell_key(spells[i])) as SpellData
		var r := Rect2(at - Vector2(SLOT, SLOT) * 0.5, Vector2(SLOT, SLOT))
		var chosen := spells[i] == wheel_choice
		w.draw_rect(r, BG_HOT)
		w.draw_rect(r, SELECTED if chosen else EDGE, false, 1.0)
		if spell and spell.icon:
			w.draw_texture_rect(spell.icon, r.grow(-2), false)
		if spell and world.character.cast_problem(spell) != "":
			w.draw_rect(r.grow(-1), BAD)
	var label := "Pick a spell"
	if wheel_choice != &"":
		var chosen_spell := ItemData.find(ItemData.spell_key(wheel_choice)) as SpellData
		label = chosen_spell.display_name if chosen_spell else String(wheel_choice)
		var why := world.character.cast_problem(chosen_spell)
		if why != "":
			label += " (%s)" % why
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	w.draw_string(font, wheel_center + Vector2(-lw * 0.5, wheel_radius + 26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, TEXT)


# --- tooltips and notes ------------------------------------------------------------------

func _update_tooltip(over: bool) -> void:
	var item: ItemData = null
	if over and cursor_count == 0:
		var h := hit(_grid.get_local_mouse_position())
		var c := world.character
		match h[0]:
			Area.INVENTORY:
				item = c.inventory.item(h[1])
			Area.EQUIPMENT:
				var id: StringName = c.equipment[EQUIP_SLOTS[h[1]]]
				item = ItemData.find(id) if id != &"" else (c.book() if h[1] == 0 else null)
			Area.BOOK:
				var s: StringName = c.book_loadout()[h[1]]
				item = ItemData.find(ItemData.spell_key(s)) if s != &"" else null
			Area.SPELLS:
				item = ItemData.find(ItemData.spell_key(_known()[h[1]]))
			Area.CHEST:
				var store := world.container_at(chest)
				item = store.item(h[1]) if store else null
			Area.RECIPE:
				var r: RecipeData = recipes()[h[1]]
				var out := ItemData.find(r.output)
				var miss := Crafting.missing(c.inventory, r)
				_tooltip.visible = true
				_tooltip_text.text = (tooltip_for(out, c) if out else String(r.output)) + \
					("\nClick: craft 1, Shift + click: 10" if miss.is_empty() else "\nNeed: " + ", ".join(miss))
				_tooltip.reset_size()
				_tooltip.position = _grid.get_global_mouse_position() + Vector2(10, 8)
				return
	_tooltip.visible = item != null
	if item == null:
		return
	_tooltip_text.text = tooltip_for(item, world.character)
	_tooltip.reset_size()
	_tooltip.position = _grid.get_global_mouse_position() + Vector2(10, 8)


static func tooltip_for(item: ItemData, c: CharacterData = null) -> String:
	var lines := PackedStringArray([item.display_name])
	if item.mining_damage > 0.0:
		var area: String = str(item.mining_area) if item.mining_area_max <= item.mining_area \
			else "%d to %d" % [item.mining_area, item.mining_area_max]
		lines.append("%s mining %s, area %s" % [str(item.mining_damage),
			"per second" if item.beam else "per hit", area])
	if item.axe_damage > 0.0:
		lines.append("%s chopping per hit" % str(item.axe_damage))
	if item.reach_tiles > 0.0 and (item.mining_damage > 0.0 or item.axe_damage > 0.0):
		lines.append("Reach %s tiles" % str(item.reach_tiles))
	match item.kind:
		ItemData.Kind.BOOK:
			lines.append("Spellbook: %d slots, spell power x%s" % [item.spell_slots, str(item.spell_power)])
		ItemData.Kind.CONDUIT:
			lines.append("Conduit (%s): spell power x%s, +%s reach" % [String(item.conduit_type),
				str(item.spell_power), str(item.spell_reach_bonus)])
		ItemData.Kind.TOME:
			var s := ItemData.find(ItemData.spell_key(item.tome_spell))
			lines.append("Tome: casts %s" % (s.display_name if s else String(item.tome_spell)))
	if item is SpellData:
		var spell := item as SpellData
		if spell.requires_conduit != &"":
			lines.append("Needs a %s conduit" % String(spell.requires_conduit))
		if c and c.cast_problem(spell) != "":
			lines.append("Can't cast now: %s" % c.cast_problem(spell))
	elif item.places_wall != &"":
		lines.append("Right click: place as a back wall")
	if item.description != "":
		lines.append(item.description)
	return "\n".join(lines)


## Pickup notes: one line per item, adding up while items keep arriving.
func _on_picked_up(item_id: StringName, count: int) -> void:
	var note: Label = _note_labels.get(item_id)
	if note == null or not is_instance_valid(note):
		note = Label.new()
		note.add_theme_font_size_override("font_size", 8)
		note.add_theme_color_override("font_color", TEXT)
		note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		_notes.add_child(note)
		_note_labels[item_id] = note
		_note_counts[item_id] = 0
	_note_counts[item_id] += count
	var item := ItemData.find(item_id)
	note.text = "+%d %s" % [_note_counts[item_id], item.display_name if item else String(item_id)]
	note.modulate.a = 1.0
	_note_age[item_id] = 0.0
	_place_notes()


func _update_notes(delta: float) -> void:
	for item_id: StringName in _note_age.keys():
		_note_age[item_id] += delta
		var note: Label = _note_labels.get(item_id)
		var age: float = _note_age[item_id]
		if age > note_seconds:
			note.modulate.a = 1.0 - (age - note_seconds) / 0.5
		if age > note_seconds + 0.5:
			note.queue_free()
			_note_labels.erase(item_id)
			_note_counts.erase(item_id)
			_note_age.erase(item_id)
			_place_notes.call_deferred()


func _place_notes() -> void:
	_notes.position.y = 344 - _notes.get_child_count() * 12
