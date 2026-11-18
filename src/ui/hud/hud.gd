class_name Hud
extends CanvasLayer
## The in-world HUD: the hotbar (top left), the inventory panel (I or Tab) with the
## equipment and spell sections, the crafting window (K, or right click a station), the
## chest window, the spellbook key (tap R: book out or away, hold R: spell wheel), the
## stack held on the mouse, tooltips, and pickup notes. Drawn with UiSkin.
##
## Inventory panel (I or Tab): rows of 10 (the character's inventory size), the top row
## is the hotbar. Items only; to the right are the Craft (K), Equip (P) and Spells (L)
## buttons.
##   Left click: pick up a stack / put it down / swap / merge.
##   Right click: pick up half, or put one down from the stack on the mouse.
##   Shift + left click: move a stack between the hotbar and the rest (or into the open
##   chest).
##   Ctrl + right click: equip armor, an accessory, a book or a conduit (swapping with the
##   equipped one).
##   Click outside the windows with a stack on the mouse: throw it.
## Equipment window (P, EquipmentWindow) and Spell Index (L, SpellWindow): movable
## windows (drag the title bar), opened in the middle of the screen. Opening either opens
## the inventory too; closing the inventory closes them.
##
## Windows (crafting, chest) open on the right side of the screen, apart from the
## inventory. Crafting: click a recipe in the list, then Craft, x10 or All.

const SLOT := 20
const GAP := 2
const STEP := SLOT + GAP
## Space inside a window frame.
const PAD := 6
const MARGIN := Vector2(4, 4)
const TITLE_H := 14
const BAD := Color(1.0, 0.35, 0.3, 0.45)

## Where a click landed.
enum Area { NONE, INVENTORY, CRAFT_BUTTON, EQUIP_BUTTON, SPELLS_BUTTON, CHEST, CHEST_TAKE,
	CHEST_DEPOSIT, RECIPE, CRAFT, CLOSE }
## Equipment slots, in columns of 3: armor (head, chest, legs), accessories, magic (book,
## conduit).
const EQUIP_SLOTS: Array[StringName] = CharacterData.ALL_SLOTS
const EQUIP_LABELS: Array[String] = ["Head", "Body", "Legs", "Acc", "Acc", "Acc", "Book", "Cond"]
const EQUIP_NAMES: Array[String] = ["Head armor", "Chest armor", "Leg armor", "Accessory", "Accessory",
	"Accessory", "Spellbook (empty: the Basic Spellbook)", "Conduit"]
## Width of the button column right of the inventory grid.
const EQUIP_W := 3 * STEP - GAP

## Crafting window: size, list width, row height.
const CRAFT_SIZE := Vector2(288, 214)
const LIST_W := 134
const ROW_H := 18
## Craft buttons: how many each makes (0 = as many as you can).
const CRAFT_AMOUNTS: Array[int] = [1, 10, 0]

## Radius (UI px) of the spell wheel.
@export var wheel_radius := 44.0
## Holding R this long (seconds) opens the spell wheel; a shorter tap takes the
## spellbook out or puts it back.
@export var wheel_hold_seconds := 0.2
## Seconds a pickup note stays after the last item of that kind arrived.
@export var note_seconds := 1.6
## Windows (crafting, chest): gap from the right edge of the screen and from the top.
@export var window_right := 8.0
@export var window_top := 40.0

var world: World
## The inventory panel is open.
var open := false
## The crafting window is open (hand crafting, or the station in `station`).
var crafting := false
## The Equipment window (P) is open.
var equipping := false
## The Spell Index (L) is open.
var spells_open := false
## Stack held on the mouse (inventory open). "spell:<id>" = a spell being placed.
var cursor_id: StringName = &""
var cursor_count := 0
## The spell wheel is open (R held): its center and the highlighted spell.
var wheel_open := false
var wheel_center := Vector2.ZERO
var wheel_choice: StringName = &""
var _r_down := false
var _r_held := 0.0
## The crafting station (anchor tile) or chest that was opened; NO_TILE = none.
var station := World.NO_TILE
var chest := World.NO_TILE
## The magic bag (ItemBag) that's open, or null.
var bag: ItemBag
## Selected crafting entry (an index into recipes(); recipes().size() = the upgrade).
var selected_recipe := 0
## First crafting row shown (mouse wheel over the list scrolls).
var _craft_scroll := 0

var _inv: Pane
var _craft: Pane
var _chest: Pane
var _equip: EquipmentWindow
var _spells: SpellWindow
var _status: Pane
## Buff icons with their time left, above the status panel.
var _buffs: Pane
const STATUS_SIZE := Vector2(140, 44)
const STATUS_BARS: Array[Array] = [
	["icon_health", "d83a3a"], ["icon_mana", "3a7ae0"], ["icon_hunger", "d8942a"],
]
var _status_icons: Array[Texture2D] = []
var _death: Label
## Black fade when you sleep.
var _fade: ColorRect
var _death_sub: Label
var _wheel: Wheel
var _name_label: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
var _notes: VBoxContainer
var _note_labels: Dictionary[StringName, Label] = {}
var _note_counts: Dictionary[StringName, int] = {}
var _note_age: Dictionary[StringName, float] = {}


## A window: drawing and clicks go to the HUD.
class Pane extends Control:
	var draw_fn: Callable
	var input_fn: Callable

	func _draw() -> void:
		draw_fn.call(self)

	func _gui_input(event: InputEvent) -> void:
		input_fn.call(self, event)


class Wheel extends Control:
	var hud: Hud

	func _draw() -> void:
		hud.draw_wheel(self)


func _ready() -> void:
	layer = 20
	_inv = _pane(_draw_inventory, _inventory_input)
	_inv.position = MARGIN
	_craft = _pane(_draw_crafting, _crafting_input)
	_craft.size = CRAFT_SIZE
	_chest = _pane(_draw_chest, _chest_input)
	_equip = EquipmentWindow.new(self)
	_equip.close_pressed.connect(toggle_equipment)
	add_child(_equip)
	_spells = SpellWindow.new(self)
	_spells.close_pressed.connect(toggle_spells)
	add_child(_spells)
	_buffs = _pane(_draw_buffs, func(_p: Pane, _e: InputEvent) -> void: pass)
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = _pane(_draw_status, func(_p: Pane, _e: InputEvent) -> void: pass)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.size = STATUS_SIZE
	for b: Array in STATUS_BARS:
		_status_icons.append(load(UiSkin.DIR + String(b[0]) + ".png") as Texture2D)
	_wheel = Wheel.new()
	_wheel.hud = self
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.visible = false
	add_child(_wheel)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", UiSkin.TEXT)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_name_label)
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UiSkin.box("panel", 6.0))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text = Label.new()
	_tooltip_text.add_theme_font_size_override("font_size", 8)
	_tooltip_text.add_theme_color_override("font_color", UiSkin.TEXT)
	_tooltip.add_child(_tooltip_text)
	_tooltip.visible = false
	add_child(_tooltip)
	_death = Label.new()
	_death.add_theme_font_size_override("font_size", 16)
	_death.add_theme_color_override("font_color", Color("ff7a6a"))
	_death.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_death.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death.visible = false
	_death.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_death)
	_death_sub = Label.new()
	_death_sub.add_theme_font_size_override("font_size", 8)
	_death_sub.add_theme_color_override("font_color", UiSkin.TEXT)
	_death_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_death_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_sub.visible = false
	_death_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_death_sub)
	_notes = VBoxContainer.new()
	_notes.position = Vector2(6, 300)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	EventBus.item_picked_up.connect(_on_picked_up)
	world.station_opened.connect(_on_station_opened)
	world.container_opened.connect(_on_container_opened)
	world.bag_opened.connect(_on_bag_opened)
	world.slept.connect(_on_slept)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	move_child(_fade, 0)
	EventBus.player_died.connect(_on_player_died)
	world.character.inventory.changed.connect(_redraw)
	world.character.magic_changed.connect(_layout)
	world.character.equipment_changed.connect(func() -> void: _layout.call_deferred())
	world.player.selection_changed.connect(func(_s: int) -> void: _redraw())
	_layout()


func _pane(draw_fn: Callable, input_fn: Callable) -> Pane:
	var p := Pane.new()
	p.draw_fn = draw_fn
	p.input_fn = input_fn
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	return p


func _redraw() -> void:
	_inv.queue_redraw()
	_status.queue_redraw()
	_buffs.queue_redraw()
	_craft.queue_redraw()
	_chest.queue_redraw()
	_equip.queue_redraw()
	_spells.queue_redraw()


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
	if Input.is_action_just_pressed("crafting") and not paused:
		toggle_crafting()
	if Input.is_action_just_pressed("equipment") and not paused:
		toggle_equipment()
	if Input.is_action_just_pressed("spells") and not paused:
		toggle_spells()
	_update_wheel(paused)
	var p := world.player
	var over := _over_pane()
	p.input_blocked = over != null or cursor_count > 0 or paused or wheel_open
	_update_tooltip(over if over else (_buffs if _buff_at_mouse() != &"" else null))
	if (station != World.NO_TILE or chest != World.NO_TILE) and not _in_reach_of(station if station != World.NO_TILE else chest):
		close_window()  # walked away from the station or chest
	if bag != null and (not is_instance_valid(bag) or bag.is_queued_for_deletion()
			or bag.global_position.distance_to(p.chest()) > (world.interact_tiles + 4.0) * World.TILE):
		close_window()  # emptied (it vanished) or walked away
	_redraw()  # mana bar, recipe counts, hover
	var item := p.held_item
	_name_label.text = item.display_name if item else ""
	if p.concentration:
		_name_label.text += ("\n" if _name_label.text != "" else "") + "Concentrating: %s" % p.concentration.display_name


## The window under the mouse, or null.
func _over_pane() -> Control:
	for pane: Control in [_spells, _equip, _craft, _chest, _inv]:
		if pane.visible and pane.get_global_rect().has_point(pane.get_global_mouse_position()):
			return pane
	return null


## Opens or closes the inventory. Closing also closes the crafting and chest windows.
func set_open(value: bool) -> void:
	open = value
	if not open:
		station = World.NO_TILE
		chest = World.NO_TILE
		bag = null
		crafting = false
		equipping = false
		spells_open = false
		if cursor_count > 0:
			if _cursor_is_spell():
				_clear_cursor()  # a spell being placed just goes back
			else:
				var left := world.character.inventory.add(cursor_id, cursor_count)
				cursor_count = left
				if left > 0:
					_throw_cursor()
				_clear_cursor()
	_layout()


## K: the hand crafting window (with the inventory), or closes the crafting window.
func toggle_crafting() -> void:
	if crafting:
		close_window()
		return
	chest = World.NO_TILE
	bag = null
	station = World.NO_TILE
	_open_crafting()


## P: the equipment window (with the inventory), or closes it.
func toggle_equipment() -> void:
	equipping = not equipping
	if equipping:
		open = true
		_equip.refresh_look()
	_layout()


## L: the Spell Index (with the inventory), or closes it.
func toggle_spells() -> void:
	spells_open = not spells_open
	if spells_open:
		open = true
	_layout()


func _open_crafting() -> void:
	open = true
	crafting = true
	selected_recipe = 0
	_craft_scroll = 0
	_layout()


## Closes the crafting or chest window, keeping the inventory open.
func close_window() -> void:
	crafting = false
	station = World.NO_TILE
	chest = World.NO_TILE
	bag = null
	_layout()


func _on_station_opened(anchor: Vector2i) -> void:
	chest = World.NO_TILE
	bag = null
	station = anchor
	_open_crafting()


func _on_bag_opened(opened: ItemBag) -> void:
	crafting = false
	station = World.NO_TILE
	chest = World.NO_TILE
	open = true
	bag = opened
	_layout()


## The open chest's or bag's slots (null when neither is open).
func _store() -> Inventory:
	if bag != null and is_instance_valid(bag):
		return bag.inventory
	return world.container_at(chest) if chest != World.NO_TILE else null


func _store_open() -> bool:
	return chest != World.NO_TILE or (bag != null and is_instance_valid(bag))


const DEATH_CAUSES := {&"fall": "You fell too far.", &"starving": "You starved.", &"enemy": "You were slain."}


func _on_slept() -> void:
	_fade.color.a = 1.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(_fade, "color:a", 0.0, 1.2)


func _on_player_died(cause: StringName) -> void:
	_death.text = "You died"
	var lines := PackedStringArray()
	if DEATH_CAUSES.has(cause):
		lines.append(DEATH_CAUSES[cause])
	if world.info.death_drop == WorldInfo.DeathDrop.BAG:
		lines.append("Your items are in a magic bag where you fell.")
	_death_sub.text = "\n".join(lines)
	var view := _view_size()
	_death.size = Vector2(view.x, 20)
	_death.position = Vector2(0, view.y * 0.5 - 70)
	_death_sub.size = Vector2(view.x, 24)
	_death_sub.position = Vector2(0, view.y * 0.5 - 48)
	_death.visible = true
	_death_sub.visible = true
	get_tree().create_timer(world.respawn_seconds).timeout.connect(func() -> void:
		_death.visible = false
		_death_sub.visible = false)


func _on_container_opened(anchor: Vector2i) -> void:
	bag = null
	crafting = false
	station = World.NO_TILE
	open = true
	chest = anchor
	_layout()


func _in_reach_of(anchor: Vector2i) -> bool:
	var p := world.player
	var def := world.object_at(anchor)
	var w := def.width_tiles if def else 1
	var at := world.tile_to_world(anchor) + Vector2(w * World.TILE * 0.5, 0)
	at.x += roundf((p.global_position.x - at.x) / (world.data.width * World.TILE)) * world.data.width * World.TILE
	return at.distance_to(p.chest()) <= (world.interact_tiles + 4.0 + w * 0.5) * World.TILE \
		and world.object_anchor(anchor) == anchor


# --- layout ------------------------------------------------------------------------------

func _inventory() -> Inventory:
	return world.character.inventory


func _layout() -> void:
	if open:
		var bottom := maxf(_rows(_inventory().size) * STEP - GAP, 3 * 20.0 - 4.0) + PAD * 2
		_inv.size = Vector2(_equip_origin().x + EQUIP_W + PAD, bottom)
	else:
		_inv.size = Vector2(PAD * 2 + 10 * STEP - GAP, PAD * 2 + SLOT)
	_name_label.position = MARGIN + Vector2(2, _inv.size.y + 2)
	var view := _view_size()
	_status.position = Vector2(MARGIN.x, view.y - STATUS_SIZE.y - MARGIN.y)
	_buffs.size = Vector2(STATUS_SIZE.x, BUFF_STEP)
	_buffs.position = _status.position - Vector2(0, BUFF_STEP + 8)
	_craft.visible = open and crafting
	_craft.position = Vector2(view.x - CRAFT_SIZE.x - window_right, window_top)
	_chest.visible = open and _store_open()
	if _chest.visible:
		var store := _store()
		var n := store.size if store else 40
		_chest.size = Vector2(PAD * 2 + 10 * STEP - GAP, 22 + _rows(n) * STEP - GAP + 6 + 16 + PAD)
		_chest.position = Vector2(view.x - _chest.size.x - window_right, window_top)
	if open and equipping:
		_equip.show_at(_equip_spot())
		_equip.refresh_look()
	else:
		_equip.visible = false
	if open and spells_open:
		_spells.show_at(_spell_window_spot())
	else:
		_spells.visible = false
	_redraw()






## Where the Equipment window opens the first time: the middle of the screen, nudged
## down below the inventory when there's room.
func _equip_spot() -> Vector2:
	var at := _equip.centered()
	var below := _inv.position.y + _inv.size.y + 4
	if at.y < below and below + _equip.size.y <= _view_size().y:
		at.y = below
	return at


## Where the Spell Index opens the first time: beside the Equipment window if it's open.
## If you haven't moved the Equipment window, the two are centered together; otherwise
## the index goes on whichever side has room, or in the middle.
func _spell_window_spot() -> Vector2:
	var mid := _spells.centered()
	if not _equip.visible:
		return mid
	var view := _view_size()
	if not _equip.moved:
		var both := _equip.size.x + 4 + _spells.size.x
		if both <= view.x:
			_equip.position.x = floorf((view.x - both) * 0.5)
			return Vector2(_equip.position.x + _equip.size.x + 4, _equip.position.y)
	var right := _equip.position.x + _equip.size.x + 4
	if right + _spells.size.x <= view.x:
		return Vector2(right, _equip.position.y)
	var left := _equip.position.x - _spells.size.x - 4
	return Vector2(left, _equip.position.y) if left >= 0.0 else mid


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640, 360)


func _grid_origin() -> Vector2:
	return Vector2(PAD, PAD)


func _rows(n: int) -> int:
	return maxi(1, ceili(n / 10.0))


func _equip_origin() -> Vector2:
	return _grid_origin() + Vector2(10 * STEP + 6, 0)


func _craft_button_rect() -> Rect2:
	return Rect2(_equip_origin() + Vector2(0, 2), Vector2(EQUIP_W - 2, 16))


func _equip_button_rect() -> Rect2:
	return Rect2(_equip_origin() + Vector2(0, 22), Vector2(EQUIP_W - 2, 16))


func _spells_button_rect() -> Rect2:
	return Rect2(_equip_origin() + Vector2(0, 42), Vector2(EQUIP_W - 2, 16))






func _known() -> Array[StringName]:
	return world.character.known_spells


## Rect of slot `i` in a 10-wide block starting at `origin`.
func _cell(origin: Vector2, i: int) -> Rect2:
	return Rect2(origin + Vector2((i % 10) * STEP, (i / 10) * STEP), Vector2(SLOT, SLOT))


func _close_rect(pane: Pane) -> Rect2:
	return Rect2(pane.size.x - 19, 6, 12, 10)


## [Area, index] under a point in the inventory panel.
func hit(local: Vector2) -> Array:
	var inv := _inventory()
	var n := inv.size if open else Inventory.HOTBAR
	for i in n:
		if _cell(_grid_origin(), i).has_point(local):
			return [Area.INVENTORY, i]
	if not open:
		return [Area.NONE, -1]
	if _craft_button_rect().has_point(local):
		return [Area.CRAFT_BUTTON, 0]
	if _equip_button_rect().has_point(local):
		return [Area.EQUIP_BUTTON, 0]
	if _spells_button_rect().has_point(local):
		return [Area.SPELLS_BUTTON, 0]
	return [Area.NONE, -1]


## Inventory slot under a point in the inventory panel (or -1).
func slot_at(local: Vector2) -> int:
	var h := hit(local)
	return h[1] if h[0] == Area.INVENTORY else -1


# --- drawing: inventory ------------------------------------------------------------------

func _draw_inventory(g: Control) -> void:
	var c := world.character
	var inv := c.inventory
	var font := ThemeDB.fallback_font
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var hover := hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	var n := inv.size if open else Inventory.HOTBAR
	for i in n:
		var r := _cell(_grid_origin(), i)
		var look := UiSkin.SlotLook.NORMAL
		if i == world.player.selected:
			look = UiSkin.SlotLook.SELECTED
		elif hover[0] == Area.INVENTORY and hover[1] == i:
			look = UiSkin.SlotLook.HOT
		UiSkin.slot(g, r, look)
		var item := inv.item(i)
		if item:
			_draw_item(g, font, r, item, inv.counts[i])
		if i < Inventory.HOTBAR:
			g.draw_string(font, r.position + Vector2(3, 8), str((i + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
				Color(UiSkin.DIM, 0.8))
	if open:
		var br := _craft_button_rect()
		var state := UiSkin.Btn.PRESSED if crafting else (UiSkin.Btn.HOT if hover[0] == Area.CRAFT_BUTTON else UiSkin.Btn.NORMAL)
		UiSkin.button(g, br, "Craft (K)", state)
		var er := _equip_button_rect()
		state = UiSkin.Btn.PRESSED if equipping else (UiSkin.Btn.HOT if hover[0] == Area.EQUIP_BUTTON else UiSkin.Btn.NORMAL)
		UiSkin.button(g, er, "Equip (P)", state)
		var sr := _spells_button_rect()
		state = UiSkin.Btn.PRESSED if spells_open else (UiSkin.Btn.HOT if hover[0] == Area.SPELLS_BUTTON else UiSkin.Btn.NORMAL)
		UiSkin.button(g, sr, "Spells (L)", state)
	_draw_cursor_stack(g)


## The stack on the mouse, drawn by whichever window the mouse is over (or the
## inventory).
func _draw_cursor_stack(g: Control) -> void:
	if cursor_count <= 0:
		return
	var over := _over_pane()
	if (over == null and g != _inv) or (over != null and over != g):
		return
	var item := ItemData.find(cursor_id)
	var m := g.get_local_mouse_position()
	if item and item.icon:
		g.draw_texture_rect(item.icon, Rect2(m + Vector2(2, 2), Vector2(16, 16)), false)
	if cursor_count > 1:
		_draw_count(g, ThemeDB.fallback_font, Rect2(m, Vector2(SLOT, SLOT)), cursor_count)


func _draw_item(g: Control, font: Font, r: Rect2, item: ItemData, count: int, alpha: float = 1.0) -> void:
	if item.icon:
		g.draw_texture_rect(item.icon, Rect2(r.position + (r.size - Vector2(16, 16)) * 0.5, Vector2(16, 16)), false,
			Color(1, 1, 1, alpha))
	if item.is_spell():
		# Spell shortcut: a small mark, and red when it can't be cast right now.
		g.draw_rect(Rect2(r.position + Vector2(SLOT - 6, 2), Vector2(4, 4)), Color("7fd4ff"))
		if world.character.cast_problem(item as SpellData) != "":
			g.draw_rect(r.grow(-2), BAD)
	elif count > 1:
		_draw_count(g, font, r, count)













## Space per buff icon (px).
const BUFF_STEP := 20


## Buffs on you, left to right, above the status panel: the spell's icon in a slot and
## the time left under it. Hover one for what it does.
func _draw_buffs(g: Control) -> void:
	var p := world.player
	var font := ThemeDB.fallback_font
	var i := 0
	for effect: StringName in p.buffs:
		var spell: SpellData = p.buff_spells.get(effect)
		var r := Rect2(i * BUFF_STEP, 0, BUFF_STEP - 2, BUFF_STEP - 2)
		UiSkin.slot(g, r, UiSkin.SlotLook.MAGIC)
		if spell and spell.icon:
			# Blinks in its last 10 seconds.
			var left: float = p.buffs[effect]
			var a := 1.0 if left > 10.0 or fmod(left, 0.5) > 0.2 else 0.35
			g.draw_texture_rect(spell.icon, Rect2(r.position + Vector2(1, 1), Vector2(16, 16)), false, Color(1, 1, 1, a))
		var text := _clock(p.buffs[effect])
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		g.draw_string_outline(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y + 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0, 0, 0, 0.8))
		g.draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y + 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)
		i += 1


## The buff under the mouse (effect id), or &"".
func _buff_at_mouse() -> StringName:
	var local := _buffs.get_local_mouse_position()
	var i := 0
	for effect: StringName in world.player.buffs:
		if Rect2(i * BUFF_STEP, 0, BUFF_STEP - 2, BUFF_STEP - 2).has_point(local):
			return effect
		i += 1
	return &""


## Seconds as m:ss.
static func _clock(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


## Health, mana and hunger, bottom left: an icon, a bar and the numbers.
func _draw_status(g: Control) -> void:
	var p := world.player
	var font := ThemeDB.fallback_font
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	if world.clock:
		# The time of day on the panel's top edge.
		var text := world.clock.label()
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var r := Rect2(g.size.x - tw - 14, -6, tw + 10, 11)
		UiSkin.title(g, r, "")
		g.draw_string(font, r.position + Vector2(5, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.INK)
	var values := [
		[p.health, p.max_health, false], [p.mana, p.max_mana, p.infinite_mana], [p.hunger, p.max_hunger, false],
	]
	for i in STATUS_BARS.size():
		var y := 6.0 + i * 11.0
		if _status_icons[i]:
			g.draw_texture(_status_icons[i], Vector2(7, y))
		var r := Rect2(18, y + 1, 82, 6)
		g.draw_rect(r, Color("120b07"))
		var v: Array = values[i]
		var k := 1.0 if v[2] else clampf(float(v[0]) / maxf(float(v[1]), 1.0), 0.0, 1.0)
		var fill := Color(STATUS_BARS[i][1]) if not v[2] else Color("b07aff")
		var w := (r.size.x - 2) * k
		g.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w, 4)), fill)
		g.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w, 1)), fill.lightened(0.35))
		var text := "inf" if v[2] else "%d" % roundi(float(v[0]))
		g.draw_string(font, Vector2(104, y + 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)


func _draw_count(g: Control, font: Font, r: Rect2, n: int) -> void:
	var text := str(n)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var at := r.position + Vector2(SLOT - w - 2, SLOT - 3)
	g.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0, 0, 0, 0.8))
	g.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)


func _close_button(g: Control, hover: bool) -> void:
	var r := _close_rect(g as Pane)
	UiSkin.button(g, r, "x", UiSkin.Btn.HOT if hover else UiSkin.Btn.NORMAL)


# --- drawing: chest ----------------------------------------------------------------------

func _chest_hit(local: Vector2) -> Array:
	if _close_rect(_chest).has_point(local):
		return [Area.CLOSE, 0]
	var store := _store()
	if store:
		for i in store.size:
			if _cell(Vector2(PAD, 22), i).has_point(local):
				return [Area.CHEST, i]
	var b := _chest_buttons()
	if b[0].has_point(local):
		return [Area.CHEST_TAKE, 0]
	if b[1].has_point(local):
		return [Area.CHEST_DEPOSIT, 0]
	return [Area.NONE, -1]


func _chest_buttons() -> Array[Rect2]:
	var y := _chest.size.y - PAD - 16
	return [Rect2(PAD, y, 60, 16), Rect2(PAD + 64, y, 70, 16)]


func _draw_chest(g: Control) -> void:
	var store := _store()
	var def := world.object_at(chest) if chest != World.NO_TILE else null
	var font := ThemeDB.fallback_font
	var hover := _chest_hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var title := def.display_name if def else "Chest"
	var right := "%d slots" % store.size if store else ""
	if bag != null and is_instance_valid(bag):
		title = "Magic Bag"
		right = bag.owner_name
	UiSkin.title(g, Rect2(4, 4, g.size.x - 24, TITLE_H), title, right)
	_close_button(g, hover[0] == Area.CLOSE)
	if store:
		for i in store.size:
			var r := _cell(Vector2(PAD, 22), i)
			UiSkin.slot(g, r, UiSkin.SlotLook.HOT if hover[0] == Area.CHEST and hover[1] == i else UiSkin.SlotLook.NORMAL)
			var item := store.item(i)
			if item:
				_draw_item(g, font, r, item, store.counts[i])
	var b := _chest_buttons()
	UiSkin.button(g, b[0], "Take all", UiSkin.Btn.HOT if hover[0] == Area.CHEST_TAKE else UiSkin.Btn.NORMAL)
	UiSkin.button(g, b[1], "Deposit all", UiSkin.Btn.HOT if hover[0] == Area.CHEST_DEPOSIT else UiSkin.Btn.NORMAL)
	g.draw_string(font, Vector2(b[1].end.x + 6, b[1].position.y + 11), "Shift + click: move a stack",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	_draw_cursor_stack(g)


# --- drawing: crafting -------------------------------------------------------------------

## The recipes the window shows: the open station's, or hand crafting.
func recipes() -> Array[RecipeData]:
	var def := world.object_at(station) if station != World.NO_TILE else null
	if def and def.station != &"":
		return Crafting.recipes_for(def.station, def.station_tier)
	return Crafting.recipes_for(&"")


func _station_def() -> ObjectDef:
	return world.object_at(station) if station != World.NO_TILE else null


func _upgrade_shown() -> bool:
	var def := _station_def()
	return def != null and def.upgrade_to != &""


## List entries: the recipes, plus the upgrade (when the station has one).
func _entry_count() -> int:
	return recipes().size() + (1 if _upgrade_shown() else 0)


func _list_rect() -> Rect2:
	return Rect2(PAD, 22, LIST_W, CRAFT_SIZE.y - 22 - PAD)


func _rows_shown() -> int:
	return int(_list_rect().size.y / ROW_H)


func _row_rect(i: int) -> Rect2:
	var l := _list_rect()
	return Rect2(l.position + Vector2(0, (i - _craft_scroll) * ROW_H), Vector2(LIST_W - 5, ROW_H - 1))


func _detail_rect() -> Rect2:
	var x := PAD + LIST_W + 6
	return Rect2(x, 22, CRAFT_SIZE.x - x - PAD, CRAFT_SIZE.y - 22 - PAD)


func _craft_button_rects() -> Array[Rect2]:
	var d := _detail_rect()
	var out: Array[Rect2] = []
	if selected_recipe >= recipes().size():
		out.append(Rect2(d.position.x, d.end.y - 16, d.size.x, 16))  # Upgrade
		return out
	var w := (d.size.x - 8) / 3.0
	for i in 3:
		out.append(Rect2(d.position.x + i * (w + 4), d.end.y - 16, w, 16))
	return out


func _craft_hit(local: Vector2) -> Array:
	if _close_rect(_craft).has_point(local):
		return [Area.CLOSE, 0]
	for i in range(_craft_scroll, mini(_entry_count(), _craft_scroll + _rows_shown())):
		if _row_rect(i).has_point(local):
			return [Area.RECIPE, i]
	var b := _craft_button_rects()
	for i in b.size():
		if b[i].has_point(local):
			return [Area.CRAFT, i]
	return [Area.NONE, -1]


func _draw_crafting(g: Control) -> void:
	var inv := _inventory()
	var font := ThemeDB.fallback_font
	var def := _station_def()
	var hover := _craft_hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var is_station := def != null and def.station != &""
	UiSkin.title(g, Rect2(4, 4, g.size.x - 24, TITLE_H), def.display_name if is_station else "Crafting by hand",
		"Tier %d" % def.station_tier if is_station else "")
	_close_button(g, hover[0] == Area.CLOSE)
	var list := recipes()
	selected_recipe = clampi(selected_recipe, 0, maxi(_entry_count() - 1, 0))
	# The list.
	var lr := _list_rect()
	g.draw_rect(lr, Color(0, 0, 0, 0.22))
	if list.is_empty():
		g.draw_string(font, lr.position + Vector2(4, 12), "Nothing to craft here yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.DIM)
	for i in range(_craft_scroll, mini(_entry_count(), _craft_scroll + _rows_shown())):
		var rect := _row_rect(i)
		var hot: bool = hover[0] == Area.RECIPE and hover[1] == i
		if i == selected_recipe or hot:
			UiSkin.row_highlight(g, rect)
		if i == selected_recipe:
			g.draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), UiSkin.GOLD)
		if i >= list.size():
			var next := _upgrade_def()
			_draw_icon(g, _item_icon(def.upgrade_to), rect.position + Vector2(3, 1), 1.0 if _can_upgrade() else 0.45)
			g.draw_string(font, rect.position + Vector2(22, 12), "Upgrade to %s" % (next.display_name if next else "?"),
				HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 26, 7, UiSkin.GOLD)
			continue
		var r := list[i]
		var times := Crafting.times_craftable(inv, r)
		var a := 1.0 if times > 0 else 0.45
		var out := ItemData.find(r.output)
		_draw_icon(g, out.icon if out else null, rect.position + Vector2(3, 1), a)
		var label_text := (out.display_name if out else String(r.output)) + (" x%d" % r.output_count if r.output_count > 1 else "")
		g.draw_string(font, rect.position + Vector2(22, 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 46, 7,
			Color(UiSkin.TEXT, a))
		if times > 0:
			var t := str(times)
			var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
			g.draw_string(font, Vector2(rect.end.x - tw - 3, rect.position.y + 12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.GOOD)
	# Scroll bar.
	if _entry_count() > _rows_shown():
		var track := Rect2(lr.end.x - 3, lr.position.y, 2, lr.size.y)
		g.draw_rect(track, Color(0, 0, 0, 0.4))
		var k := float(_rows_shown()) / _entry_count()
		var top := float(_craft_scroll) / _entry_count()
		g.draw_rect(Rect2(track.position + Vector2(0, track.size.y * top), Vector2(2, track.size.y * k)), UiSkin.GOLD)
	# Details.
	var d := _detail_rect()
	if _entry_count() == 0:
		return
	if selected_recipe >= list.size():
		_draw_upgrade_detail(g, font, d, def, hover)
	else:
		_draw_recipe_detail(g, font, d, list[selected_recipe], hover)
	_draw_cursor_stack(g)


func _item_icon(item_id: StringName) -> Texture2D:
	var it := ItemData.find(item_id)
	return it.icon if it else null


func _draw_icon(g: Control, tex: Texture2D, at: Vector2, alpha: float = 1.0) -> void:
	if tex:
		g.draw_texture_rect(tex, Rect2(at, Vector2(16, 16)), false, Color(1, 1, 1, alpha))


func _draw_recipe_detail(g: Control, font: Font, d: Rect2, r: RecipeData, hover: Array) -> void:
	var inv := _inventory()
	var out := ItemData.find(r.output)
	var big := Rect2(d.position, Vector2(36, 36))
	UiSkin.slot(g, big)
	if out and out.icon:
		g.draw_texture_rect(out.icon, Rect2(big.position + Vector2(2, 2), Vector2(32, 32)), false)
	var name_text := out.display_name if out else String(r.output)
	g.draw_string(font, d.position + Vector2(42, 12), name_text, HORIZONTAL_ALIGNMENT_LEFT, d.size.x - 42, 8, UiSkin.TEXT)
	var sub := "Makes %d" % r.output_count
	if out and out.description != "":
		sub = out.description
	g.draw_multiline_string(font, d.position + Vector2(42, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, d.size.x - 42, 6, 2,
		UiSkin.DIM)
	var y := d.position.y + 48
	g.draw_string(font, Vector2(d.position.x, y), "Needs", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	y += 4
	for k: StringName in r.inputs:
		y = _ingredient_row(g, font, d, y, k, "%d / %d" % [inv.count_of(k), r.inputs[k]], inv.count_of(k) >= r.inputs[k])
	if not r.requires.is_empty():
		y += 4
		g.draw_string(font, Vector2(d.position.x, y + 8), "Tools (kept)", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
		y += 12
		for q in r.requires:
			var has := inv.count_of(q) > 0
			y = _ingredient_row(g, font, d, y, q, "have" if has else "missing", has)
	var times := Crafting.times_craftable(inv, r)
	var labels := ["Craft", "x10", "All (%d)" % times]
	var b := _craft_button_rects()
	for i in b.size():
		var state := UiSkin.Btn.DISABLED if times <= 0 else (UiSkin.Btn.HOT if hover[0] == Area.CRAFT and hover[1] == i else UiSkin.Btn.NORMAL)
		UiSkin.button(g, b[i], labels[i], state)


## One "icon name  have / need" line; returns the next y.
func _ingredient_row(g: Control, font: Font, d: Rect2, y: float, item_id: StringName, right: String, ok: bool) -> float:
	var it := ItemData.find(item_id)
	if it and it.icon:
		g.draw_texture_rect(it.icon, Rect2(Vector2(d.position.x, y + 1), Vector2(12, 12)), false)
	g.draw_string(font, Vector2(d.position.x + 15, y + 10), it.display_name if it else String(item_id),
		HORIZONTAL_ALIGNMENT_LEFT, d.size.x - 60, 7, UiSkin.TEXT)
	var w := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	g.draw_string(font, Vector2(d.end.x - w, y + 10), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOOD if ok else UiSkin.BAD)
	return y + 14


func _upgrade_def() -> ObjectDef:
	var def := _station_def()
	if def == null or def.upgrade_to == &"":
		return null
	var i := world.objects.index_of(def.upgrade_to)
	return world.objects.def(i) as ObjectDef if i > 0 else null


func _draw_upgrade_detail(g: Control, font: Font, d: Rect2, def: ObjectDef, hover: Array) -> void:
	var inv := _inventory()
	var next := _upgrade_def()
	g.draw_string(font, d.position + Vector2(0, 10), "Upgrade to %s" % (next.display_name if next else "?"),
		HORIZONTAL_ALIGNMENT_LEFT, d.size.x, 8, UiSkin.TEXT)
	g.draw_string(font, d.position + Vector2(0, 22), "Replaces this station in place.", HORIZONTAL_ALIGNMENT_LEFT, d.size.x, 6,
		UiSkin.DIM)
	var y := d.position.y + 30
	for k: StringName in def.upgrade_cost:
		y = _ingredient_row(g, font, d, y, k, "%d / %d" % [inv.count_of(k), def.upgrade_cost[k]], inv.count_of(k) >= def.upgrade_cost[k])
	var b := _craft_button_rects()
	var ok := _can_upgrade()
	UiSkin.button(g, b[0], "Upgrade", UiSkin.Btn.DISABLED if not ok else (UiSkin.Btn.HOT if hover[0] == Area.CRAFT else UiSkin.Btn.NORMAL))


# --- clicks ------------------------------------------------------------------------------

func _inventory_input(pane: Pane, event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var h := hit(mb.position)
	if h[0] == Area.NONE:
		if cursor_count > 0 and mb.button_index == MOUSE_BUTTON_LEFT:
			pane.accept_event()  # don't throw a stack by clicking the panel's frame
		return
	pane.accept_event()
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
				if _store_open():
					_move_stack(_inventory(), slot, _store())
				else:
					_quick_move(slot)
			elif left:
				click_slot(slot)
			elif right:
				right_click_slot(slot)
		Area.CRAFT_BUTTON:
			if left:
				toggle_crafting()
		Area.EQUIP_BUTTON:
			if left:
				toggle_equipment()
		Area.SPELLS_BUTTON:
			if left:
				toggle_spells()
	_redraw()


func _chest_input(pane: Pane, event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	pane.accept_event()
	var h := _chest_hit(mb.position)
	var store := _store()
	var left := mb.button_index == MOUSE_BUTTON_LEFT
	match h[0]:
		Area.CLOSE:
			if left:
				close_window()
		Area.CHEST:
			if store:
				if left and mb.shift_pressed:
					_move_stack(store, h[1], _inventory())
				elif left:
					click_slot(h[1], store)
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					right_click_slot(h[1], store)
		Area.CHEST_TAKE:
			if left and store:
				for i in store.size:
					_move_stack(store, i, _inventory())
		Area.CHEST_DEPOSIT:
			if left and store:
				deposit_all(store)
	_redraw()


## Moves everything below the hotbar into a chest (topping up stacks it already has).
func deposit_all(store: Inventory) -> void:
	var inv := _inventory()
	for i in range(Inventory.HOTBAR, inv.size):
		_move_stack(inv, i, store)


func _crafting_input(pane: Pane, event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	pane.accept_event()
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var most := maxi(_entry_count() - _rows_shown(), 0)
		_craft_scroll = clampi(_craft_scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var h := _craft_hit(mb.position)
	match h[0]:
		Area.CLOSE:
			close_window()
		Area.RECIPE:
			selected_recipe = h[1]
			if mb.double_click and selected_recipe < recipes().size():
				craft(recipes()[selected_recipe], 1)
		Area.CRAFT:
			if selected_recipe >= recipes().size():
				upgrade_station()
			else:
				var r := recipes()[selected_recipe]
				var amount := CRAFT_AMOUNTS[h[1]]
				craft(r, amount if amount > 0 else Crafting.times_craftable(_inventory(), r))
	_redraw()


## Crafts a recipe up to `times` times from the inventory; extra output drops at your
## feet.
func craft(r: RecipeData, times: int) -> int:
	if times <= 0:
		return 0
	var result := Crafting.craft(world.character.inventory, r, times)
	if int(result[1]) > 0:
		world.request_spawn_drop(r.output, int(result[1]), world.player.chest(), Vector2.ZERO, true)
	if int(result[0]) > 0:
		EventBus.item_picked_up.emit(r.output, int(result[0]) * r.output_count)
	return int(result[0])


func _can_upgrade() -> bool:
	var def := _station_def()
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
	# The first slot it fits, preferring an empty one (accessories).
	var target: StringName = &""
	for eq in EQUIP_SLOTS:
		if CharacterData.fits(eq, item) and (target == &"" or (c.equipment[target] != &"" and c.equipment[eq] == &"")):
			target = eq
	if target != &"":
		var old := c.equip(target, item.id)
		c.inventory.set_slot(slot, old, 1 if old != &"" else 0)


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
	var hi := Inventory.HOTBAR if to_hotbar else inv.size
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
	_redraw()


# --- spell wheel -------------------------------------------------------------------------

func _update_wheel(paused: bool) -> void:
	# R: tap = take the spellbook out (or put it back), hold = spell wheel.
	if Input.is_action_just_pressed("spellbook") and not paused and not open:
		_r_held = 0.0
		_r_down = true
		world.player.r_combo_used = false
	if _r_down:
		_r_held += get_process_delta_time()
		if not wheel_open and _r_held >= wheel_hold_seconds and not world.player.r_combo_used:
			wheel_open = true
			wheel_center = _wheel.get_local_mouse_position()
			wheel_choice = &""
		if not Input.is_action_pressed("spellbook"):
			_r_down = false
			if world.player.r_combo_used:
				# R + number was a quick cast: letting go of R does nothing else.
				wheel_open = false
				wheel_choice = &""
				_wheel.visible = false
				return
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
		w.draw_string(font, wheel_center + Vector2(-40, 3), "No spells in your book", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.DIM)
		return
	for i in spells.size():
		var a := -PI * 0.5 + TAU * i / spells.size()
		var at := wheel_center + Vector2.from_angle(a) * wheel_radius
		var spell := ItemData.find(ItemData.spell_key(spells[i])) as SpellData
		var r := Rect2(at - Vector2(SLOT, SLOT) * 0.5, Vector2(SLOT, SLOT))
		var chosen := spells[i] == wheel_choice
		UiSkin.slot(w, r, UiSkin.SlotLook.SELECTED if chosen else UiSkin.SlotLook.MAGIC)
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
	w.draw_string(font, wheel_center + Vector2(-lw * 0.5, wheel_radius + 26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)


# --- tooltips and notes ------------------------------------------------------------------

func _update_tooltip(over: Control) -> void:
	var item: ItemData = null
	var extra := ""
	var extra_only := ""
	if over and cursor_count == 0:
		var c := world.character
		var h: Array = [Area.NONE, -1]
		if over == _inv:
			h = hit(over.get_local_mouse_position())
		elif over == _chest:
			h = _chest_hit(over.get_local_mouse_position())
		elif over == _craft:
			h = _craft_hit(over.get_local_mouse_position())
		elif over == _buffs:
			var effect := _buff_at_mouse()
			var spell: SpellData = world.player.buff_spells.get(effect)
			if spell:
				extra_only = "%s, %s left\n%s" % [spell.display_name, _clock(world.player.buffs[effect]), spell.description]
		elif over is HudWindow:
			var t: Array = (over as HudWindow).tooltip_at(over.get_local_mouse_position())
			item = t[0]
			extra_only = t[1]
		match h[0]:
			Area.INVENTORY:
				item = c.inventory.item(h[1])
			Area.CHEST:
				var store := _store()
				item = store.item(h[1]) if store else null
			Area.RECIPE:
				if h[1] < recipes().size():
					var r: RecipeData = recipes()[h[1]]
					item = ItemData.find(r.output)
					extra = "\nDouble click: craft 1"
	_tooltip.visible = item != null or extra_only != ""
	if not _tooltip.visible:
		return
	_tooltip_text.text = extra_only if item == null else tooltip_for(item, world.character) + extra
	_tooltip.reset_size()
	var at := over.get_global_mouse_position() + Vector2(10, 8)
	var view := _view_size()
	at.x = minf(at.x, view.x - _tooltip.size.x - 2)
	at.y = minf(at.y, view.y - _tooltip.size.y - 2)
	_tooltip.position = at


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
		note.add_theme_color_override("font_color", UiSkin.TEXT)
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
	# Above the health, mana and hunger panel.
	_notes.position.y = _view_size().y - STATUS_SIZE.y - MARGIN.y - 20 - _notes.get_child_count() * 12
