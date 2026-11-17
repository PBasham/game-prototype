class_name Hud
extends CanvasLayer
## The in-world HUD: the hotbar (top left), the inventory panel (I or Tab) with the
## equipment and spell sections, the spellbook key (tap R: book out or away, hold R:
## spell wheel), the stack held on the mouse,
## tooltips, and pickup notes. Placeholder look until real UI art exists.
##
## Inventory panel: 4 rows of 10, the top row is the hotbar.
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
enum Area { NONE, INVENTORY, EQUIPMENT, BOOK, SPELLS }
const EQUIP_SLOTS: Array[StringName] = [CharacterData.SLOT_BOOK, CharacterData.SLOT_CONDUIT]

## Radius (UI px) of the spell wheel.
@export var wheel_radius := 44.0
## Holding R this long (seconds) opens the spell wheel; a shorter tap takes the
## spellbook out or puts it back.
@export var wheel_hold_seconds := 0.2

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

var _grid: Grid
var _wheel: Wheel
var _name_label: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
var _notes: VBoxContainer


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


func _process(_delta: float) -> void:
	var paused := world.get_tree().paused or (world.console != null and world.console.open)
	# Polled (not _input) so scripted runs can tap them too.
	if Input.is_action_just_pressed("inventory") and not paused:
		set_open(not open)
	_update_wheel(paused)
	var p := world.player
	var over := _grid.get_global_rect().has_point(_grid.get_global_mouse_position())
	p.input_blocked = over or cursor_count > 0 or paused or wheel_open
	_update_tooltip(over)
	var item := p.held_item
	_name_label.text = item.display_name if item else ""
	if p.concentration:
		_name_label.text += ("\n" if _name_label.text != "" else "") + "Concentrating: %s" % p.concentration.display_name
	if cursor_count > 0:
		_grid.queue_redraw()


func set_open(value: bool) -> void:
	open = value
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


# --- layout ------------------------------------------------------------------------------

func _layout() -> void:
	if open:
		_grid.size = Vector2(_equip_origin().x + SLOT + 110, _spells_origin().y + _rows(_known().size()) * (SLOT + GAP))
	else:
		_grid.size = Vector2(10 * (SLOT + GAP) - GAP, SLOT)
	_name_label.position = MARGIN + Vector2(0, (_grid.size.y if open else SLOT) + 2)
	_grid.queue_redraw()


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
		_draw_magic(g, font)
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
	_grid.queue_redraw()


## Left click with the panel open: pick up, put down, merge or swap.
func click_slot(slot: int) -> void:
	var inv := world.character.inventory
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
func right_click_slot(slot: int) -> void:
	var inv := world.character.inventory
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
		c.put_in_book(i, _cursor_spell())
		_clear_cursor()
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


func _on_picked_up(item_id: StringName, count: int) -> void:
	var item := ItemData.find(item_id)
	var l := Label.new()
	l.text = "+%d %s" % [count, item.display_name if item else String(item_id)]
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_notes.add_child(l)
	_notes.position.y = 344 - _notes.get_child_count() * 12
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		l.queue_free()
		_notes.position.y = 344 - (_notes.get_child_count() - 1) * 12)
