class_name Hud
extends CanvasLayer
## The in-world HUD: the hotbar (top left), the inventory panel (I or Tab) with the
## equipment and spell sections, the crafting window (K, or right click a station), the
## chest window, the spellbook key (tap R: book out or away, hold R: spell wheel), the
## stack held on the mouse, tooltips, and pickup notes. Drawn with UiSkin.
##
## Inventory panel (I or Tab): rows of 10 (the character's inventory size), the top row
## is the hotbar. Items only; to the right are the Craft (K), Equip (P), Spells (L) and Catalog (J)
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
enum Area { NONE, INVENTORY, CRAFT_BUTTON, EQUIP_BUTTON, SPELLS_BUTTON, CATALOG_BUTTON, CHEST, CHEST_TAKE,
	CHEST_DEPOSIT, RECIPE, CRAFT, CLOSE, TAB, GROUP, SEARCH, CHEST_STACK, CHEST_RENAME, TRASH }
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
## Stations whose window has tabs: station kind to tab names. The Spell Weaving Table:
## Spells (learn spells) and Scrolls (scribe spells you know). Create and Empower come
## with Magic progression.
const STATION_TABS := { &"alchemy": ["Potions", "Coatings", "Flasks"],
	&"spell_weaving": ["Learn", "Empower"]}
const TAB_H := 14
const ROW_H := 18
## Craft buttons: how many each makes (0 = as many as you can).
## Crafting window bottom row: [-] [amount] [+] [Craft].
enum CraftBtn { MINUS, FIELD, PLUS, CRAFT }

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
## Dev builds: the Dev items window (F7) is shown.
var dev_items_open := false
## Stack held on the mouse (inventory open). "spell:<id>" = a spell being placed.
var cursor_id: StringName = &""
var cursor_count := 0
## The data of the item on the mouse (a coated weapon's coating), carried with it.
var cursor_meta: Dictionary = {}
## The spell wheel is open (R held): its center and the highlighted spell.
var wheel_open := false
var wheel_center := Vector2.ZERO
## The slot picked on the open wheel (&"" = none), and which wheel is open (&"q", &"e").
var wheel_choice: StringName = &""
var wheel_key: StringName = &""
var _key_held := 0.0
## The crafting station (anchor tile) or chest that was opened; NO_TILE = none.
var station := World.NO_TILE
var chest := World.NO_TILE
## The magic bag (ItemBag) that's open, or null.
var bag: ItemBag
## Selected crafting entry (an index into recipes(); recipes().size() = the upgrade).
var selected_recipe := 0
## How many times the Craft button crafts (the [-] [n] [+] field).
var craft_amount := 1
## The amount field is taking typed digits (clicked); the next digit replaces it.
var _amount_typing := false
var _amount_fresh := false
## The full screen world map (N).
var map_view: MapView
## The chat line (Enter) and its log: /sit, /wave, /cheer...
var chat: ChatBox
## Which tab of a station with tabs is shown (STATION_TABS).
var craft_tab := 0
## Spell Weaving Table filters (like the Spell Index): -1 = All, else a SpellData.Group,
## and the search text (typing in it while `weave_searching`).
var weave_group := -1
var weave_search := ""
var weave_searching := false
const FILTER_H := 12
var _recipe_cache: Array[RecipeData] = []
var _recipe_key := ""
## First crafting row shown (mouse wheel over the list scrolls).
var _craft_scroll := 0

var _inv: Pane
var _craft: Pane
var _chest: Pane
var _equip: EquipmentWindow
var _spells: SpellWindow
var _dev_items: DevItemsWindow
var _catalog: CatalogWindow
var catalog_open := false
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
## The quick spell keys beside the hotbar: Q and E (their current pick), Z, X, C.
var _quick: Pane
var _name_label: Label
## The held spell's icon, left of its name (a spell in hand).
var _name_icon: TextureRect
## The spell you're concentrating on (Fly, Mend...): its icon and name, under that.
var _conc_icon: TextureRect
var _conc_label: Label
## The held weapon's coating (and later other effects): icon and hits left.
var _effect_icon: TextureRect
var _effect_label: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
## Crafting's materials (inventory + nearby chests), rebuilt each frame (craft_stock).
var _stock: CraftStock
var _stock_frame := -1
## A mouse press began on a window; world clicks stay blocked until it's released.
var _press_on_ui := false
## The tooltip's title line and its right side (a book's tier).
var _tooltip_title: Label
var _tooltip_right: Label
## Small text between the title and the right side: a spell's types.
var _tooltip_types: Label
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
	map_view = MapView.new(world)
	add_child(map_view)
	chat = ChatBox.new(self)
	add_child(chat)
	_spells = SpellWindow.new(self)
	_spells.close_pressed.connect(toggle_spells)
	add_child(_spells)
	_dev_items = DevItemsWindow.new(self)
	_dev_items.close_pressed.connect(toggle_dev_items)
	add_child(_dev_items)
	_catalog = CatalogWindow.new(self)
	_catalog.close_pressed.connect(toggle_catalog)
	add_child(_catalog)
	_quick = _pane(_draw_quick, func(_p: Pane, _e: InputEvent) -> void: pass)
	_quick.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_name_icon = TextureRect.new()
	_name_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_name_icon.size = Vector2(12, 12)
	_name_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_name_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_icon)
	_conc_icon = _name_icon.duplicate() as TextureRect
	add_child(_conc_icon)
	_conc_label = _name_label.duplicate() as Label
	_conc_label.add_theme_color_override("font_color", Color("c9a8ff"))
	add_child(_conc_label)
	_effect_icon = _name_icon.duplicate() as TextureRect
	add_child(_effect_icon)
	_effect_label = _name_label.duplicate() as Label
	_effect_label.add_theme_color_override("font_color", Color("9be36b"))
	add_child(_effect_label)
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UiSkin.box("panel", 6.0))
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 0)
	_tooltip.add_child(tip_box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	tip_box.add_child(head)
	_tooltip_title = Label.new()
	_tooltip_title.add_theme_font_size_override("font_size", 8)
	_tooltip_title.add_theme_color_override("font_color", UiSkin.TEXT)
	_tooltip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tooltip_title)
	_tooltip_types = Label.new()
	_tooltip_types.add_theme_font_size_override("font_size", 6)
	_tooltip_types.add_theme_color_override("font_color", UiSkin.DIM)
	_tooltip_types.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_tooltip_types)
	_tooltip_right = Label.new()
	_tooltip_right.add_theme_font_size_override("font_size", 8)
	_tooltip_right.add_theme_color_override("font_color", UiSkin.GOLD)
	head.add_child(_tooltip_right)
	_tooltip_text = Label.new()
	_tooltip_text.add_theme_font_size_override("font_size", 8)
	_tooltip_text.add_theme_color_override("font_color", UiSkin.TEXT)
	tip_box.add_child(_tooltip_text)
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
	world.character.recipe_discovered.connect(func(what: String) -> void:
		EventBus.debug_message.emit("New recipe: %s" % what)
		EventBus.sound_requested.emit(&"learn_spell", world.player.chest())
		_recipe_key = ""
		_redraw())
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
	_quick.queue_redraw()
	_status.queue_redraw()
	_buffs.queue_redraw()
	_craft.queue_redraw()
	_chest.queue_redraw()
	_equip.queue_redraw()
	_spells.queue_redraw()
	_dev_items.queue_redraw()
	_catalog.queue_redraw()


func _input(event: InputEvent) -> void:
	# The chat line takes every key while it's open; Enter opens it when nothing else
	# is being typed into.
	if chat.open and chat.handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("chat") and not _typing_elsewhere():
		chat.open_chat()
		get_viewport().set_input_as_handled()
		return
	# A click that starts on a window (its close button, say) never reaches the world,
	# even if the window closes under the mouse: blocked until the button comes up.
	var press := event as InputEventMouseButton
	if press and press.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if press.pressed and _over_pane() != null:
			_press_on_ui = true
			world.player.input_blocked = true
		elif not press.pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_press_on_ui = false
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F7 and OS.is_debug_build():
		toggle_dev_items()
		get_viewport().set_input_as_handled()
		return
	if renaming and _rename_key(key):
		get_viewport().set_input_as_handled()
		return
	if _dev_items.searching and _dev_items.search_key(key):
		get_viewport().set_input_as_handled()
		return
	if _amount_typing and _amount_key(event):
		get_viewport().set_input_as_handled()  # digits don't pick hotbar slots
		return
	if _spells.searching and _spells.search_key(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if weave_searching and _weave_search_key(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	var mod := event as InputEventKey
	if mod and mod.keycode in [KEY_SHIFT, KEY_CTRL, KEY_META] and _craft.visible:
		_craft.queue_redraw()  # the amount and costs follow Shift / Ctrl
	if map_view.visible and event.is_action_pressed("ui_cancel"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if open and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Right click on the world with a stack on the mouse throws it (left click uses it,
	# like Terraria). A spell shortcut on the mouse is thrown away with either button.
	var mb := event as InputEventMouseButton
	if open and mb and mb.pressed and cursor_count > 0 and (mb.button_index == MOUSE_BUTTON_RIGHT
			or (mb.button_index == MOUSE_BUTTON_LEFT and _cursor_placeable() == null)):
		# Right click over a free table or shelf spot puts one down there instead.
		var p := world.player
		if not (mb.button_index == MOUSE_BUTTON_RIGHT and p.mouse_stack
				and world.try_place_display(p.aim_point(), p)):
			_throw_cursor()
		get_viewport().set_input_as_handled()


## Something else has the keyboard (the console, a search box, renaming, the amount).
func _typing_elsewhere() -> bool:
	return (world.console != null and world.console.open) or _spells.searching or _dev_items.searching \
		or renaming or weave_searching or _amount_typing or map_view.visible


## Opens or closes the world map (N).
func toggle_map() -> void:
	move_child(map_view, -1)  # over every window
	map_view.toggle()


func _process(delta: float) -> void:
	_update_notes(delta)
	var paused := world.get_tree().paused or (world.console != null and world.console.open) or _spells.searching \
		or _dev_items.searching or renaming \
		or weave_searching or chat.open
	# Polled (not _input) so scripted runs can tap them too.
	if Input.is_action_just_pressed("inventory") and not paused:
		set_open(not open)
	if Input.is_action_just_pressed("crafting") and not paused:
		toggle_crafting()
	if Input.is_action_just_pressed("equipment") and not paused:
		toggle_equipment()
	if Input.is_action_just_pressed("spells") and not paused:
		toggle_spells()
	if Input.is_action_just_pressed("catalog") and not paused:
		toggle_catalog()
	if Input.is_action_just_pressed("map") and not paused:
		toggle_map()
	if map_view.visible:
		paused = true  # the map covers the screen: no playing under it
	_update_wheel(paused)
	var p := world.player
	var over := _over_pane()
	# The stack on the mouse is held and used like the hotbar (placing shows the preview).
	var place := _cursor_placeable() if over == null and not paused and not wheel_open else null
	if p.mouse_stack != place:
		p.mouse_stack = place
		p.mouse_take = _take_cursor_one
		p.mouse_left = func() -> int: return cursor_count
		p.mouse_meta = func() -> Dictionary: return cursor_meta
		if place and p.stowed:
			p.toggle_stowed()  # placing takes the hand back out
		p.refresh_held()
	var on_buff := _buff_at_mouse() != &"" or _quick_key_at_mouse() != &""
	p.input_blocked = over != null or (cursor_count > 0 and place == null) or paused or wheel_open or on_buff \
		or _press_on_ui
	if on_buff and not paused and Input.is_action_just_pressed("use_secondary"):
		dismiss_buff(_buff_entry_at_mouse())
	_update_tooltip(over if over else (_buffs if _buff_at_mouse() != &"" else
		(_quick if _quick_key_at_mouse() != &"" else null)))
	if (station != World.NO_TILE or chest != World.NO_TILE) and not _in_reach_of(station if station != World.NO_TILE else chest):
		close_window()  # walked away from the station or chest
	if bag != null and (not is_instance_valid(bag) or bag.is_queued_for_deletion()
			or bag.global_position.distance_to(p.chest()) > (world.interact_tiles + 4.0) * World.TILE):
		close_window()  # emptied (it vanished) or walked away
	_redraw()  # mana bar, recipe counts, hover
	var item := p.held_item
	_name_label.text = item.display_name if item else ""
	# A spell in hand: its icon before the name, in a magic blue.
	var spell_in_hand := item != null and item.is_spell() and not p.stowed
	_name_icon.visible = spell_in_hand and item.icon != null
	_name_icon.texture = item.icon if spell_in_hand else null
	_name_label.position.x = MARGIN.x + 2 + (14 if _name_icon.visible else 0)
	_name_label.add_theme_color_override("font_color", Color("9fd4ff") if spell_in_hand else UiSkin.TEXT)
	# The held weapon's coating: its icon and hits left, in green.
	var coat := Coating.of(p.held_meta()) if item and not p.stowed else []
	_effect_icon.visible = not coat.is_empty() and (coat[0] as ItemData).icon != null
	_effect_icon.texture = (coat[0] as ItemData).icon if not coat.is_empty() else null
	_effect_label.visible = not coat.is_empty()
	_effect_label.text = "%s: %d hits" % [(coat[0] as ItemData).display_name, coat[1]] if not coat.is_empty() else ""
	var line_y := _name_label.position.y + 14
	_effect_label.position = Vector2(MARGIN.x + 2 + (14 if _effect_icon.visible else 0), line_y)
	_effect_icon.position = Vector2(MARGIN.x + 2, line_y + 1)
	if _effect_label.visible:
		line_y += 14
	# Concentrating: the spell's icon and name in violet, on the next line.
	var conc := p.concentration
	_conc_icon.visible = conc != null and conc.icon != null
	_conc_icon.texture = conc.icon if conc else null
	_conc_label.visible = conc != null
	_conc_label.text = conc.display_name if conc else ""
	_conc_label.position = Vector2(MARGIN.x + 2 + (14 if _conc_icon.visible else 0), line_y)
	_conc_icon.position = Vector2(MARGIN.x + 2, line_y + 1)


## The window under the mouse, or null.
func _over_pane() -> Control:
	for pane: Control in [_catalog, _dev_items, _spells, _equip, _craft, _chest, _inv]:
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
		dev_items_open = false
		catalog_open = false
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


## F7 (dev builds) or console `creative`: the Dev items window (with the inventory).
func toggle_dev_items() -> void:
	dev_items_open = not dev_items_open
	if dev_items_open:
		open = true
	_layout()


## Puts `count` of an item on the mouse (the Dev items window). The same item adds up
## to a stack; something else on the mouse goes back to the inventory first.
func give_cursor(item_id: StringName, count: int, meta: Dictionary = {}) -> void:
	if cursor_count > 0 and cursor_id != item_id:
		if _cursor_is_spell():
			_clear_cursor()
		else:
			var left := world.character.inventory.add(cursor_id, cursor_count)
			cursor_count = left
			if left > 0:
				_throw_cursor()
			_clear_cursor()
	var cap := Inventory.max_stack(item_id)
	if cursor_id != item_id or cursor_count == 0 or not meta.is_empty():
		cursor_meta = meta.duplicate()
	cursor_count = mini(cap, (cursor_count if cursor_id == item_id else 0) + count)
	cursor_id = item_id
	_redraw()


## J (or left click the Catalog book): the Catalog, with the inventory (so items can
## be dropped on its Recipes slot), or closes it.
func toggle_catalog() -> void:
	catalog_open = not catalog_open
	if catalog_open:
		open = true
	_layout()


## The Catalog, on an item's recipes (from an item's right click menu later, tests).
func show_catalog_recipes(it: ItemData) -> void:
	if not catalog_open:
		toggle_catalog()
	_catalog.show_recipes(it)


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
	craft_amount = 1
	_craft_scroll = 0
	craft_tab = 0
	_layout()


## Closes the crafting or chest window, keeping the inventory open.
func close_window() -> void:
	if renaming:
		set_renaming(false)
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
	if world.info.death_drop == WorldInfo.DeathDrop.PERMADEATH:
		lines.append("Permadeath: %s is a ghost now." % world.character.name)
	elif world.info.death_drop != WorldInfo.DeathDrop.KEEP:
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
	_name_icon.position = MARGIN + Vector2(2, _inv.size.y + 3)
	_quick.size = Vector2(PAD * 2 + QUICK_KEYS_SHOWN.size() * STEP - GAP + 4, PAD * 2 + SLOT + QUICK_LABEL_H)
	_quick.position = _inv.position + Vector2(_inv.size.x + 4, 0)
	var view := _view_size()
	_status.position = Vector2(MARGIN.x, view.y - STATUS_SIZE.y - MARGIN.y)
	_buffs.size = Vector2(STATUS_SIZE.x, BUFF_STEP)
	_buffs.position = _status.position - Vector2(0, BUFF_STEP + 8)
	_craft.visible = open and crafting
	if weave_searching and not (_craft.visible and _weave_filters_shown()):
		set_weave_searching(false)
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
	if open and dev_items_open:
		var screen := _view_size()
		_dev_items.layout()
		_dev_items.show_at(Vector2(screen.x - _dev_items.size.x - 8, screen.y - _dev_items.size.y - 8))
	else:
		_dev_items.visible = false
		if _dev_items.searching:
			_dev_items.set_searching(false)
	if open and catalog_open:
		_catalog.show_at(_catalog.centered())
	else:
		_catalog.visible = false
	if open and spells_open:
		_spells.show_at(_spell_window_spot())
	else:
		_spells.visible = false
		if _spells.searching:
			_spells.set_searching(false)
	_redraw()






## Where the Equipment window opens the first time: the middle of the screen, nudged
## down below the inventory when there's room.
func _equip_spot() -> Vector2:
	var at := _equip.centered()
	var below := _inv.position.y + _inv.size.y + 4
	if at.y < below and below + _equip.size.y <= _status.position.y - 4:
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


## The Catalog (J) button: last row, left of the trash.
func _catalog_button_rect() -> Rect2:
	var t := trash_rect()
	var x := _equip_origin().x
	return Rect2(Vector2(x, t.position.y + 2), Vector2(t.position.x - x - GAP, 16))






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
	if _catalog_button_rect().has_point(local):
		return [Area.CATALOG_BUTTON, 0]
	if trash_rect().has_point(local):
		return [Area.TRASH, 0]
	return [Area.NONE, -1]


## The trash slot: bottom right of the open inventory, level with the last row.
func trash_rect() -> Rect2:
	var last := _cell(_grid_origin(), _inventory().size - 1)
	return Rect2(Vector2(_equip_origin().x + EQUIP_W - 2 - SLOT, last.position.y), Vector2(SLOT, SLOT))


## Puts the stack on the mouse in the trash (the one there before is gone for good), or
## takes the trashed stack back onto an empty mouse.
func click_trash() -> void:
	var t := world.character.trash
	if cursor_count > 0:
		if _cursor_is_spell():
			return
		t.set_slot(0, cursor_id, cursor_count, cursor_meta)
		_clear_cursor()
		EventBus.sound_requested.emit(&"ui_click", world.player.global_position)
	elif t.counts[0] > 0:
		cursor_id = t.ids[0]
		cursor_count = t.counts[0]
		cursor_meta = t.metas[0]
		t.set_slot(0, &"", 0, {})
	_redraw()


## Ctrl + click an inventory slot: straight to the trash (like Terraria).
func trash_slot(slot: int) -> void:
	var inv := _inventory()
	if inv.counts[slot] <= 0:
		return
	world.character.trash.set_slot(0, inv.ids[slot], inv.counts[slot], inv.metas[slot])
	inv.set_slot(slot, &"", 0, {})
	_redraw()


## Inventory slot under a point in the inventory panel (or -1).
func slot_at(local: Vector2) -> int:
	var h := hit(local)
	return h[1] if h[0] == Area.INVENTORY else -1


# --- drawing: quick spell keys -----------------------------------------------------------

const QUICK_KEYS_SHOWN: Array[StringName] = [&"q", &"e", &"z", &"x", &"c"]
## The strip above the quick slots that holds their key letters.
const QUICK_LABEL_H := 8


## The spell a quick key stands for right now: a wheel's last pick (or its first
## spell), or the Z X C slot. [slot, spell id] (&"" when empty).
func quick_key_spell(key: StringName) -> Array:
	var c := world.character
	var slot := key
	if key in CharacterData.WHEELS:
		slot = c.wheel_last.get(key, &"")
		if slot == &"" or c.quick_spell(slot) == &"":
			var filled := c.wheel(key)
			slot = filled[0] if not filled.is_empty() else &""
	return [slot, c.quick_spell(slot) if slot != &"" else &""]


## Where quick key `i` (QUICK_KEYS_SHOWN) sits in the panel beside the hotbar.
func _quick_key_rect(i: int) -> Rect2:
	# A small gap between the wheels (Q E) and the keys (Z X C).
	return Rect2(Vector2(PAD + i * STEP + (4 if i >= 2 else 0), PAD + QUICK_LABEL_H), Vector2(SLOT, SLOT))


## The quick key under the mouse in that panel (&"" if none).
func _quick_key_at_mouse() -> StringName:
	if not _quick.visible:
		return &""
	var local := _quick.get_local_mouse_position()
	for i in QUICK_KEYS_SHOWN.size():
		if _quick_key_rect(i).has_point(local):
			return QUICK_KEYS_SHOWN[i]
	return &""


## The tooltip for a quick key: its spell (with what the key does) or its item.
func _quick_key_tooltip(key: StringName) -> Array:
	var c := world.character
	if key in CharacterData.QUICK_KEYS and c.quick_item(key) != &"":
		var it := ItemData.find(c.quick_item(key))
		return [it, "\n%s: shortcut (you have %d)" % [String(key).to_upper(), c.inventory.count_of(c.quick_item(key))]]
	var pick := quick_key_spell(key)
	var spell := ItemData.find(ItemData.spell_key(pick[1])) as SpellData if pick[1] != &"" else null
	if spell == null:
		return [null, "%s: empty (set it up in the Equipment window, P)" % String(key).to_upper()]
	var how := "casts right away" if c.quick_casts(pick[0]) else "goes in your hand"
	return [spell, "\n%s: %s" % [String(key).to_upper(), how]]


func _draw_quick(g: Control) -> void:
	var c := world.character
	var p := world.player
	var font := ThemeDB.fallback_font
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var in_hand: StringName = p.held_item.id if p.selected < 0 and p.held_item and p.held_item.is_spell() else &""
	for i in QUICK_KEYS_SHOWN.size():
		var key := QUICK_KEYS_SHOWN[i]
		var r := _quick_key_rect(i)
		var pick := quick_key_spell(key)
		var spell := ItemData.find(ItemData.spell_key(pick[1])) as SpellData if pick[1] != &"" else null
		var shortcut := ItemData.find(c.quick_item(key)) if key in CharacterData.QUICK_KEYS and c.quick_item(key) != &"" else null
		UiSkin.slot(g, r, UiSkin.SlotLook.SELECTED if spell and spell.id == in_hand else
			(UiSkin.SlotLook.NORMAL if shortcut else UiSkin.SlotLook.MAGIC))
		if shortcut:
			var n := c.inventory.count_of(shortcut.id)
			_draw_item(g, font, r, shortcut, n, 1.0 if n > 0 else 0.35)
		if spell:
			_draw_item(g, font, r, spell, 1)
			if c.quick_casts(pick[0]):
				_draw_cast_mark(g, r)
		# The key letter above its slot, not over the icon.
		var label := String(key).to_upper()
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		g.draw_string(font, Vector2(r.position.x + (SLOT - lw) * 0.5, PAD + 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			UiSkin.TEXT)


# --- drawing: inventory ------------------------------------------------------------------

func _draw_inventory(g: Control) -> void:
	var c := world.character
	var inv := c.inventory
	var font := ThemeDB.fallback_font
	var hover := hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	var n := inv.size if open else Inventory.HOTBAR
	# The satchel (Patrick's moonweave concept): soft blue cloth, darker toward the
	# middle, cells set apart only by a faint hue change; tied off on the right when open.
	SatchelLook.draw_bag(g, g.size, _grid_origin(), n, SLOT, STEP)
	if open:
		SatchelLook.draw_knot(g, Vector2(g.size.x - 6.0, 60.0))
	for i in n:
		var r := _cell(_grid_origin(), i)
		if i == world.player.selected:
			SatchelLook.draw_cell_glow(g, r, true)
		elif hover[0] == Area.INVENTORY and hover[1] == i:
			SatchelLook.draw_cell_glow(g, r, false)
		var item := inv.item(i)
		if item:
			_draw_item(g, font, r, item, inv.counts[i], 1.0, inv.metas[i])
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
		state = UiSkin.Btn.PRESSED if catalog_open else (UiSkin.Btn.HOT if hover[0] == Area.CATALOG_BUTTON else UiSkin.Btn.NORMAL)
		UiSkin.button(g, _catalog_button_rect(), "Catalog", state)
		# The trash: a dimmer cell with a bin drawn in it until something's thrown away.
		var tr := trash_rect()
		var trash := c.trash
		SatchelLook.draw_trash(g, tr, hover[0] == Area.TRASH, trash.counts[0] <= 0)
		if trash.counts[0] > 0:
			_draw_item(g, font, tr, trash.item(0), trash.counts[0], 0.8, trash.metas[0])
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


func _draw_item(g: Control, font: Font, r: Rect2, item: ItemData, count: int, alpha: float = 1.0,
		meta: Dictionary = {}) -> void:
	if item.icon:
		g.draw_texture_rect(item.icon, Rect2(r.position + (r.size - Vector2(16, 16)) * 0.5, Vector2(16, 16)), false,
			Color(1, 1, 1, alpha))
	if item.badge:
		# 8 art pixels in 16/3 units: 2 screen pixels each at 1080p.
		var b := 16.0 / 3.0
		g.draw_texture_rect(item.badge, Rect2(r.position + Vector2(r.size.x - b - 1.5, 1.5), Vector2(b, b)), false,
			Color(1, 1, 1, alpha))
	var coating := Coating.of(meta)
	if not coating.is_empty():
		# Coated: the coating's badge in the bottom right corner.
		var coat: ItemData = coating[0]
		if coat.badge:
			var b := 16.0 / 3.0
			g.draw_texture_rect(coat.badge, Rect2(r.end - Vector2(b + 1.5, b + 1.5), Vector2(b, b)), false,
				Color(1, 1, 1, alpha))
	if item.is_spell():
		# Red when it can't be cast right now.
		if world.character.cast_problem(item as SpellData) != "":
			g.draw_rect(r.grow(-2), BAD)
	elif count > 1:
		_draw_count(g, font, r, count)













## Space per buff icon (px).
const BUFF_STEP := 20


## Buffs on you, left to right, above the status panel: the spell's icon in a slot and
## the time left under it. Hover one for what it does.
## What the buff row shows: your buffs, then your lights and familiars that are out.
## Each: [key, spell, seconds left, timed, count text ("2/3" for Wisps, else "")].
func buff_entries() -> Array[Array]:
	var p := world.player
	var out: Array[Array] = []
	for effect: StringName in p.buffs:
		var spell: SpellData = p.buff_spells.get(effect)
		out.append([effect, spell, p.buffs[effect], spell == null or spell.duration > 0.0, ""])
	for id in world.character.known_spells:
		var spell := ItemData.find(ItemData.spell_key(id)) as SpellData
		if spell == null or not spell.cast in [SpellData.Cast.SUMMON, SpellData.Cast.LIGHT]:
			continue
		var n := world.summons_of(spell).size()
		if n == 0:
			continue
		var most := maxi(spell.light_max, 1) if spell.light_placed else 1
		out.append([StringName("summon_" + String(id)), spell, world.summon_time_left(spell), true,
			"%d/%d" % [n, most] if most > 1 else ""])
	return out


func _draw_buffs(g: Control) -> void:
	var font := ThemeDB.fallback_font
	var entries := buff_entries()
	for i in entries.size():
		var e: Array = entries[i]
		var spell: SpellData = e[1]
		var left: float = e[2]
		var timed: bool = e[3]  # auras (Cozy) have no timer
		var r := Rect2(i * BUFF_STEP, 0, BUFF_STEP - 2, BUFF_STEP - 2)
		UiSkin.slot(g, r, UiSkin.SlotLook.MAGIC)
		if spell and spell.icon:
			# Blinks in its last 10 seconds.
			var a := 1.0 if not timed or left > 10.0 or fmod(left, 0.5) > 0.2 else 0.35
			g.draw_texture_rect(spell.icon, Rect2(r.position + Vector2(1, 1), Vector2(16, 16)), false, Color(1, 1, 1, a))
		var count: String = e[4]
		if count != "":
			g.draw_string_outline(font, r.position + Vector2(1, 6), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2,
				Color(0, 0, 0, 0.8))
			g.draw_string(font, r.position + Vector2(1, 6), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.GOLD)
		var text := _clock(left) if timed else ""
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		g.draw_string_outline(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y + 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0, 0, 0, 0.8))
		g.draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y + 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)


## The buff row entry under the mouse (see buff_entries), or [].
func _buff_entry_at_mouse() -> Array:
	var local := _buffs.get_local_mouse_position()
	var entries := buff_entries()
	for i in entries.size():
		if Rect2(i * BUFF_STEP, 0, BUFF_STEP - 2, BUFF_STEP - 2).has_point(local):
			return entries[i]
	return []


## Right click in the buff row: ends that buff, or sends its summons away. Sickness
## and auras (Cozy) can't be ended. True when something ended.
func dismiss_buff(entry: Array) -> bool:
	if entry.is_empty():
		return false
	var key: StringName = entry[0]
	var timed: bool = entry[3]
	if String(key).begins_with("summon_"):
		world.request_dismiss_summons(entry[1])
		return true
	if not timed or String(key).begins_with("sick_"):
		return false
	world.player.end_buff(key)
	return true


## The buff under the mouse (its key), or &"".
func _buff_at_mouse() -> StringName:
	var e := _buff_entry_at_mouse()
	return e[0] if not e.is_empty() else &""


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
		# Current and total (108/120); hunger is a share, so just the number.
		var text := "inf" if v[2] else ("%d/%d" % [roundi(float(v[0])), roundi(float(v[1]))] if i < 2 else "%d" % roundi(float(v[0])))
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
	if b[2].has_point(local):
		return [Area.CHEST_STACK, 0]
	if b[3].has_point(local) and bag == null:
		return [Area.CHEST_RENAME, 0]
	return [Area.NONE, -1]


## Take all, Deposit all, Quick stack, Rename.
func _chest_buttons() -> Array[Rect2]:
	var y := _chest.size.y - PAD - 16
	return [Rect2(PAD, y, 48, 16), Rect2(PAD + 50, y, 60, 16), Rect2(PAD + 112, y, 60, 16),
		Rect2(PAD + 174, y, 44, 16)]


func _draw_chest(g: Control) -> void:
	var store := _store()
	var def := world.object_at(chest) if chest != World.NO_TILE else null
	var font := ThemeDB.fallback_font
	var hover := _chest_hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var title := world.container_name(chest) if def else "Chest"
	if renaming:
		var blink := fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0
		title = _rename_text + ("_" if blink else "")
	var right := "%d slots" % store.size if store else ""
	if bag != null and is_instance_valid(bag):
		title = "Magic Bag"
		right = bag.owner_name
	if store and store.stack_cap > 0:
		var used := 0
		for i in store.size:
			used += store.counts[i]
		right = "%d / %d" % [used, store.stack_cap * store.size]
	UiSkin.title(g, Rect2(4, 4, g.size.x - 24, TITLE_H), title, right)
	_close_button(g, hover[0] == Area.CLOSE)
	if store and store.accepts_tag != &"":
		# Special storage: how full it is.
		var bar := Rect2(PAD, 18.5, g.size.x - PAD * 2, 2.5)
		g.draw_rect(bar, Color(0.1, 0.07, 0.05))
		g.draw_rect(Rect2(bar.position, Vector2(bar.size.x * store.fill(), bar.size.y)), Color("b8823e"))
	if store:
		for i in store.size:
			var r := _cell(Vector2(PAD, 22), i)
			UiSkin.slot(g, r, UiSkin.SlotLook.HOT if hover[0] == Area.CHEST and hover[1] == i else UiSkin.SlotLook.NORMAL)
			var item := store.item(i)
			if item:
				_draw_item(g, font, r, item, store.counts[i], 1.0, store.metas[i])
	var b := _chest_buttons()
	UiSkin.button(g, b[0], "Take all", UiSkin.Btn.HOT if hover[0] == Area.CHEST_TAKE else UiSkin.Btn.NORMAL)
	UiSkin.button(g, b[1], "Deposit all", UiSkin.Btn.HOT if hover[0] == Area.CHEST_DEPOSIT else UiSkin.Btn.NORMAL)
	UiSkin.button(g, b[2], "Quick stack", UiSkin.Btn.HOT if hover[0] == Area.CHEST_STACK else UiSkin.Btn.NORMAL)
	if bag == null:
		UiSkin.button(g, b[3], "Done" if renaming else "Rename",
			UiSkin.Btn.PRESSED if renaming else (UiSkin.Btn.HOT if hover[0] == Area.CHEST_RENAME else UiSkin.Btn.NORMAL))
	_draw_cursor_stack(g)


# --- drawing: crafting -------------------------------------------------------------------

## The recipes the window shows: the open station's, or hand crafting.
## The recipes in the open crafting window (and tab), as this character pays for them.
## Cached until the station, tab, known spells or scroll settings change.
func recipes() -> Array[RecipeData]:
	var def := world.object_at(station) if station != World.NO_TILE else null
	var c := world.character
	var key := "%s|%d|%d|%d|%s|%s|%d|%s|%d|%d" % [String(def.station) if def else "", def.station_tier if def else 0, craft_tab,
		hash(c.known_spells) if c else 0, world.scribe_cost_mult, world.scroll_max_mana_by_tier, weave_group,
		weave_search, c.seen_items.size() if c else 0, hash(c.empower) if c else 0]
	if key == _recipe_key:
		return _recipe_cache
	var list: Array[RecipeData] = []
	if def and def.station == &"spell_weaving":
		list = Crafting.empower_recipes(c) if craft_tab == 1 else Crafting.learn_recipes(c)
	elif def and def.station == &"scribing":
		list = Crafting.scroll_recipes(c, world.scroll_max_mana_by_tier, world.scribe_cost_mult)
	else:
		var base := Crafting.recipes_for(def.station, def.station_tier) if def and def.station != &"" \
			else Crafting.recipes_for(&"")
		var tabs: Array = STATION_TABS.get(def.station, []) if def else []
		for r in base:
			if c and not c.unlocked(r.unlock_items):
				continue  # not discovered yet
			if not tabs.is_empty():
				var t := r.tab if r.tab != "" else String(tabs[0])
				if t != String(tabs[craft_tab]):
					continue
			list.append(r)
	if _weave_filters_shown():
		list = list.filter(_weave_match)
	_recipe_key = key
	_recipe_cache = list
	return list


## Tab names for the open station (none for most).
func _tabs() -> Array:
	var def := _station_def()
	return STATION_TABS.get(def.station, []) if def else []


func _tab_rect(i: int) -> Rect2:
	return Rect2(PAD + i * 58, 22, 56, TAB_H)


## Below the tabs (and the spell filters), when there are any.
func _body_top() -> float:
	return 22.0 + (TAB_H + 3.0 if not _tabs().is_empty() else 0.0) + (FILTER_H + 3.0 if _weave_filters_shown() else 0.0)


## The Spell Weaving Table shows group buttons and a search box above its lists.
func _weave_filters_shown() -> bool:
	var def := _station_def()
	return def != null and def.station in [&"spell_weaving", &"scribing"]


func _filter_top() -> float:
	return 22.0 + (TAB_H + 3.0 if not _tabs().is_empty() else 0.0)


func _group_rect(i: int) -> Rect2:
	var font := ThemeDB.fallback_font
	var x := float(PAD)
	for k in range(-1, i):
		x += _group_w(font, k) + 2
	return Rect2(x, _filter_top(), _group_w(font, i), FILTER_H)


func _group_w(font: Font, i: int) -> float:
	var label := "All" if i < 0 else SpellData.GROUP_NAMES[i]
	return font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 7


func _weave_search_rect() -> Rect2:
	var x := _group_rect(SpellData.GROUP_NAMES.size() - 1).end.x + 4
	return Rect2(x, _filter_top(), CRAFT_SIZE.x - PAD - x, FILTER_H)


## The spell a Spell Weaving Table recipe is about (learning or a scroll).
static func recipe_spell(r: RecipeData) -> SpellData:
	if r.empower_spell != &"":
		return ItemData.find(ItemData.spell_key(r.empower_spell)) as SpellData
	if r.teaches != &"":
		return ItemData.find(ItemData.spell_key(r.teaches)) as SpellData
	var out := ItemData.find(r.output)
	if out and out.teaches_spell != &"":
		return ItemData.find(ItemData.spell_key(out.teaches_spell)) as SpellData
	return null


func _weave_match(r: RecipeData) -> bool:
	var spell := recipe_spell(r)
	if spell == null:
		return weave_group < 0 and weave_search == ""
	if weave_group >= 0 and spell.group != weave_group:
		return false
	var q := weave_search.strip_edges().to_lower()
	return q == "" or q in spell.display_name.to_lower() or q in spell.description.to_lower()


func set_weave_searching(on: bool) -> void:
	weave_searching = on
	world.player.typing = on
	_craft.queue_redraw()


## A key while typing in the Spell Weaving Table's search box. True if used.
func _weave_search_key(k: InputEventKey) -> bool:
	if not weave_searching or k == null or not k.pressed:
		return false
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		set_weave_searching(false)
	elif k.keycode == KEY_BACKSPACE:
		weave_search = weave_search.substr(0, maxi(0, weave_search.length() - 1))
	elif k.unicode >= 32:
		weave_search += char(k.unicode)
	else:
		return true
	selected_recipe = 0
	craft_amount = 1
	_craft_scroll = 0
	_recipe_key = ""
	_craft.queue_redraw()
	return true


## The crafter's max mana (some recipes need a big enough pool).
func _max_mana() -> float:
	return world.player.max_mana


## What crafting draws from: your inventory, then chests near you (free with the dev
## console's `freecraft`). Built once per frame.
func craft_stock() -> CraftStock:
	var frame := Engine.get_process_frames()
	if _stock == null or _stock_frame != frame or _stock.free != world.free_crafting:
		var from: Array[Inventory] = [world.character.inventory]
		from.append_array(world.chests_near(world.player.chest(), world.craft_chest_tiles))
		_stock = CraftStock.new(from, world.free_crafting)
		_stock_frame = frame
	return _stock


func _times(r: RecipeData) -> int:
	var n := Crafting.times_craftable(craft_stock(), r, INF if world.free_crafting else _max_mana())
	return mini(n, 1) if r.teaches != &"" or r.empower_node != &"" else n


func _station_def() -> ObjectDef:
	return world.object_at(station) if station != World.NO_TILE else null


func _upgrade_shown() -> bool:
	var def := _station_def()
	return def != null and def.upgrade_to != &""


## List entries: the recipes, plus the upgrade (when the station has one).
func _entry_count() -> int:
	return recipes().size() + (1 if _upgrade_shown() else 0)


func _list_rect() -> Rect2:
	var top := _body_top()
	return Rect2(PAD, top, LIST_W, CRAFT_SIZE.y - top - PAD)


func _rows_shown() -> int:
	return int(_list_rect().size.y / ROW_H)


func _row_rect(i: int) -> Rect2:
	var l := _list_rect()
	return Rect2(l.position + Vector2(0, (i - _craft_scroll) * ROW_H), Vector2(LIST_W - 5, ROW_H - 1))


func _detail_rect() -> Rect2:
	var x := PAD + LIST_W + 6
	var top := _body_top()
	return Rect2(x, top, CRAFT_SIZE.x - x - PAD, CRAFT_SIZE.y - top - PAD)


func _craft_button_rects() -> Array[Rect2]:
	var d := _detail_rect()
	var out: Array[Rect2] = []
	if selected_recipe >= recipes().size():
		out.append(Rect2(d.position.x, d.end.y - 16, d.size.x, 16))  # Upgrade
		return out
	var y := d.end.y - 16
	var x := d.position.x
	out.append(Rect2(x, y, 14, 16))  # -
	out.append(Rect2(x + 15, y, 26, 16))  # amount
	out.append(Rect2(x + 42, y, 14, 16))  # +
	out.append(Rect2(x + 60, y, d.size.x - 60, 16))  # Craft
	return out


func _craft_hit(local: Vector2) -> Array:
	if _close_rect(_craft).has_point(local):
		return [Area.CLOSE, 0]
	for i in _tabs().size():
		if _tab_rect(i).has_point(local):
			return [Area.TAB, i]
	if _weave_filters_shown():
		for i in range(-1, SpellData.GROUP_NAMES.size()):
			if _group_rect(i).has_point(local):
				return [Area.GROUP, i]
		if _weave_search_rect().has_point(local):
			return [Area.SEARCH, 0]
	for i in range(_craft_scroll, mini(_entry_count(), _craft_scroll + _rows_shown())):
		if _row_rect(i).has_point(local):
			return [Area.RECIPE, i]
	var b := _craft_button_rects()
	for i in b.size():
		if b[i].has_point(local):
			return [Area.CRAFT, i]
	return [Area.NONE, -1]


func _draw_crafting(g: Control) -> void:
	var inv := craft_stock()  # inventory + nearby chests
	var font := ThemeDB.fallback_font
	var def := _station_def()
	var hover := _craft_hit(g.get_local_mouse_position()) if _over_pane() == g else [Area.NONE, -1]
	UiSkin.panel(g, Rect2(Vector2.ZERO, g.size))
	var is_station := def != null and def.station != &""
	UiSkin.title(g, Rect2(4, 4, g.size.x - 24, TITLE_H), def.display_name if is_station else "Crafting by hand",
		"Tier %d" % def.station_tier if is_station else "")
	_close_button(g, hover[0] == Area.CLOSE)
	var tabs := _tabs()
	for i in tabs.size():
		var state := UiSkin.Btn.PRESSED if i == craft_tab else (UiSkin.Btn.HOT if hover[0] == Area.TAB and hover[1] == i else UiSkin.Btn.NORMAL)
		UiSkin.button(g, _tab_rect(i), String(tabs[i]), state)
	if _weave_filters_shown():
		for i in range(-1, SpellData.GROUP_NAMES.size()):
			var label := "All" if i < 0 else SpellData.GROUP_NAMES[i]
			var gs := UiSkin.Btn.PRESSED if i == weave_group else (UiSkin.Btn.HOT if hover[0] == Area.GROUP and hover[1] == i else UiSkin.Btn.NORMAL)
			UiSkin.button(g, _group_rect(i), label, gs)
		var sr := _weave_search_rect()
		UiSkin.slot(g, sr, UiSkin.SlotLook.SELECTED if weave_searching else (UiSkin.SlotLook.HOT if hover[0] == Area.SEARCH else UiSkin.SlotLook.NORMAL))
		var stext := weave_search + ("_" if weave_searching and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else "")
		if weave_search == "" and not weave_searching:
			stext = "Search..."
		g.draw_string(font, sr.position + Vector2(3, 8), stext, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 6, 6,
			UiSkin.TEXT if weave_search != "" or weave_searching else UiSkin.DIM)
	var list := recipes()
	selected_recipe = clampi(selected_recipe, 0, maxi(_entry_count() - 1, 0))
	# The list.
	var lr := _list_rect()
	g.draw_rect(lr, Color(0, 0, 0, 0.22))
	if list.is_empty():
		var empty := "Nothing to craft here yet"
		if _station_def() and _station_def().station == &"spell_weaving":
			empty = "Nothing left to learn here"
		elif _station_def() and _station_def().station == &"scribing":
			empty = "Learn a spell to scribe its scroll"
		g.draw_string(font, lr.position + Vector2(4, 12), empty, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.DIM)
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
		var times := _times(r)
		var a := 1.0 if times > 0 else 0.45
		var out := ItemData.find(r.output)
		_draw_icon(g, out.icon if out else null, rect.position + Vector2(3, 1), a)
		var label_text := (out.display_name if out else String(r.output)) + (" x%d" % r.output_count if r.output_count > 1 else "")
		var copying := r.requires_max_mana > 0.0
		if copying:
			label_text = r.display_name
		# Known spells' scrolls (cheaper) are listed in green.
		var label_color := UiSkin.GOOD if r.note != "" and not copying else UiSkin.TEXT
		g.draw_string(font, rect.position + Vector2(22, 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 46, 7,
			Color(label_color, a))
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
	var inv := craft_stock()  # inventory + nearby chests
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
	if r.note != "":
		g.draw_string(font, Vector2(d.position.x, y - 4), r.note, HORIZONTAL_ALIGNMENT_LEFT, d.size.x, 6, UiSkin.GOOD)
		y += 6
	g.draw_string(font, Vector2(d.position.x, y), "Needs", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	y += 4
	var n := planned_crafts(r)
	for k: StringName in r.inputs:
		var need: int = r.inputs[k] * n
		y = _ingredient_row(g, font, d, y, k, "%d / %d" % [inv.count_of(k), need], inv.count_of(k) >= need)
	if r.requires_max_mana > 0.0:
		var have := _max_mana()
		var ok := have >= r.requires_max_mana
		var right := "%d / %d" % [roundi(have), roundi(r.requires_max_mana)]
		g.draw_string(font, Vector2(d.position.x + 15, y + 10), "Max mana (kept)", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			UiSkin.TEXT)
		var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		g.draw_string(font, Vector2(d.end.x - rw, y + 10), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			UiSkin.GOOD if ok else UiSkin.BAD)
		y += 14
	if not r.requires.is_empty():
		y += 4
		g.draw_string(font, Vector2(d.position.x, y + 8), "Tools (kept)", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
		y += 12
		for q in r.requires:
			var has := inv.count_of(q) > 0
			y = _ingredient_row(g, font, d, y, q, "have" if has else "missing", has)
	var times := _times(r)
	if out and n * r.output_count > 1:
		var made := str(n * r.output_count)
		g.draw_string_outline(font, big.end - Vector2(font.get_string_size(made, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2, 2),
			made, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.85))
		g.draw_string(font, big.end - Vector2(font.get_string_size(made, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2, 2),
			made, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiSkin.TEXT)
	var b := _craft_button_rects()
	var hint := "Can make %d.  Shift: 10  Ctrl: a stack" % times
	if r.teaches != &"":
		hint = "Learn it once, it's yours for good." if times > 0 else "Not enough to learn it yet."
	elif r.empower_node != &"":
		hint = "Permanent, for this spell." if times > 0 else "Not enough to empower it yet."
	g.draw_string(font, Vector2(d.position.x, b[0].position.y - 3), hint, HORIZONTAL_ALIGNMENT_LEFT, d.size.x, 6, UiSkin.DIM)
	for i in b.size():
		var hot: bool = hover[0] == Area.CRAFT and hover[1] == i
		if (r.teaches != &"" or r.empower_node != &"") and i != CraftBtn.CRAFT:
			continue  # learning and empowering have no amount
		match i:
			CraftBtn.FIELD:
				UiSkin.slot(g, b[i], UiSkin.SlotLook.SELECTED if _amount_typing else UiSkin.SlotLook.NORMAL)
				var shown := craft_amount if _amount_typing else n
				var txt := str(shown) + ("_" if _amount_typing and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else "")
				var tw := font.get_string_size(str(shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
				var modded := shown != craft_amount
				g.draw_string(font, Vector2(b[i].get_center().x - tw * 0.5, b[i].position.y + 11), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiSkin.BAD if shown > times else (UiSkin.GOLD if modded else UiSkin.TEXT))
			CraftBtn.MINUS, CraftBtn.PLUS:
				UiSkin.button(g, b[i], "-" if i == CraftBtn.MINUS else "+", UiSkin.Btn.HOT if hot else UiSkin.Btn.NORMAL)
			_:
				var state := UiSkin.Btn.DISABLED if times <= 0 else (UiSkin.Btn.HOT if hot else UiSkin.Btn.NORMAL)
				UiSkin.button(g, b[i], "Learn" if r.teaches != &"" else ("Empower" if r.empower_node != &"" else "Craft"), state)


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
	var inv := craft_stock()  # inventory + nearby chests
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
			elif left and (mb.ctrl_pressed or mb.meta_pressed):
				trash_slot(slot)
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
		Area.CATALOG_BUTTON:
			if left:
				toggle_catalog()
		Area.TRASH:
			if left:
				click_trash()
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
		Area.CHEST_STACK:
			if left and store:
				quick_stack(store)
		Area.CHEST_RENAME:
			if left:
				set_renaming(not renaming)
	_redraw()


## Quick stack: moves only the items the chest already holds out of your backpack (not
## the hotbar), like Terraria's.
func quick_stack(store: Inventory) -> int:
	var inv := _inventory()
	var moved := 0
	for i in range(Inventory.HOTBAR, inv.size):
		if inv.is_empty(i) or store.count_of(inv.ids[i]) <= 0:
			continue
		var before := inv.counts[i]
		_move_stack(inv, i, store)
		moved += before - (inv.counts[i] if not inv.is_empty(i) else 0)
	return moved


## Typing a chest's name (Rename in the chest window). Enter or Done saves it, Esc
## cancels.
var renaming := false
var _rename_text := ""


func set_renaming(on: bool, keep: bool = true) -> void:
	if on and chest != World.NO_TILE:
		_rename_text = world.chest_names.get(world.wrap_tile(chest), "")
	elif renaming and keep and chest != World.NO_TILE:
		world.request_rename_chest(chest, _rename_text)
	renaming = on and chest != World.NO_TILE
	world.player.typing = renaming
	_redraw()


func _rename_key(k: InputEventKey) -> bool:
	if not renaming or k == null or not k.pressed:
		return false
	if k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		set_renaming(false)
	elif k.keycode == KEY_ESCAPE:
		set_renaming(false, false)
	elif k.keycode == KEY_BACKSPACE:
		_rename_text = _rename_text.substr(0, maxi(0, _rename_text.length() - 1))
	elif k.unicode >= 32 and _rename_text.length() < 24:
		_rename_text += char(k.unicode)
	_redraw()
	return true


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
		var over := _craft_hit(mb.position)
		if over[0] == Area.CRAFT and over[1] in [CraftBtn.MINUS, CraftBtn.FIELD, CraftBtn.PLUS]:
			set_craft_amount(craft_amount + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
			_redraw()
			return
		var most := maxi(_entry_count() - _rows_shown(), 0)
		_craft_scroll = clampi(_craft_scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
		return
	var h := _craft_hit(mb.position)
	if not (h[0] == Area.CRAFT and h[1] == CraftBtn.FIELD):
		_amount_typing = false
	if weave_searching and h[0] != Area.SEARCH:
		set_weave_searching(false)
	if mb.button_index == MOUSE_BUTTON_RIGHT and h[0] == Area.CRAFT and h[1] in [CraftBtn.MINUS, CraftBtn.PLUS]:
		set_craft_amount(craft_amount + (10 if h[1] == CraftBtn.PLUS else -10))
		_redraw()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	match h[0]:
		Area.CLOSE:
			close_window()
		Area.TAB:
			craft_tab = h[1]
			selected_recipe = 0
			craft_amount = 1
			_craft_scroll = 0
		Area.GROUP:
			weave_group = h[1]
			selected_recipe = 0
			craft_amount = 1
			_craft_scroll = 0
		Area.SEARCH:
			set_weave_searching(not weave_searching)
		Area.RECIPE:
			if selected_recipe != h[1]:
				craft_amount = 1
			selected_recipe = h[1]
			if mb.double_click and selected_recipe < recipes().size():
				craft(recipes()[selected_recipe], 1)
		Area.CRAFT:
			if selected_recipe >= recipes().size():
				upgrade_station()
			else:
				match h[1]:
					CraftBtn.MINUS, CraftBtn.PLUS:
						var step := 10 if mb.shift_pressed else 1
						set_craft_amount(craft_amount + (step if h[1] == CraftBtn.PLUS else -step))
					CraftBtn.FIELD:
						_amount_typing = true
						_amount_fresh = true
					_:
						craft_selected(mb.shift_pressed, mb.ctrl_pressed or mb.meta_pressed)
	_redraw()


func set_craft_amount(n: int) -> void:
	craft_amount = clampi(n, 1, 999)


## The Craft button: craft_amount times, or 10 with Shift, or as many as you can up to
## one stack of the output with Ctrl.
func craft_selected(shift: bool = false, ctrl: bool = false) -> int:
	if selected_recipe >= recipes().size():
		return 0
	var r := recipes()[selected_recipe]
	var made := craft(r, mini(_asked(r, shift, ctrl), _times(r)))
	if made > 0:
		craft_amount = 1  # the amount is for one craft; it doesn't stick
		_amount_typing = false
	return made


## How many crafts the Craft button asks for: the amount box, 10 with Shift, a stack of
## the output with Ctrl.
func _asked(r: RecipeData, shift: bool, ctrl: bool) -> int:
	if ctrl:
		var it := ItemData.find(r.output)
		return maxi(1, (it.max_stack if it else 999) / maxi(1, r.output_count))
	if shift:
		return 10
	return craft_amount


## What a click on Craft would do right now (Shift / Ctrl held count): with a modifier,
## as many as you can of what it asks for; else the amount box. Drives the amount shown
## and the costs.
func planned_crafts(r: RecipeData) -> int:
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var ctrl := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if r.teaches != &"" or r.empower_node != &"":
		return 1
	var asked := _asked(r, shift, ctrl)
	if shift or ctrl:
		var can := _times(r)
		return mini(asked, can) if can > 0 else asked
	return asked


## Typing a number into the amount field (after clicking it). Returns true if used.
func _amount_key(event: InputEvent) -> bool:
	var k := event as InputEventKey
	if not _amount_typing or k == null or not k.pressed:
		return false
	if k.keycode >= KEY_0 and k.keycode <= KEY_9 or k.keycode >= KEY_KP_0 and k.keycode <= KEY_KP_9:
		var digit := (k.keycode - KEY_0) if k.keycode <= KEY_9 else (k.keycode - KEY_KP_0)
		set_craft_amount(digit if _amount_fresh else craft_amount * 10 + digit)
		_amount_fresh = false
	elif k.keycode == KEY_BACKSPACE:
		craft_amount = maxi(1, craft_amount / 10)
		_amount_fresh = false
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_amount_typing = false
		craft_selected()
	elif k.keycode == KEY_ESCAPE:
		_amount_typing = false
	else:
		return false
	_redraw()
	return true


## Crafts a recipe up to `times` times from the inventory; extra output drops at your
## feet.
func craft(r: RecipeData, times: int) -> int:
	if times <= 0:
		return 0
	if r.teaches != &"":
		return learn(r)
	if r.empower_node != &"":
		return empower(r)
	var result := Crafting.craft(craft_stock(), r, times, INF if world.free_crafting else _max_mana())
	_stock = null  # counts changed
	if int(result[1]) > 0:
		world.request_spawn_drop(r.output, int(result[1]), world.player.chest(), Vector2.ZERO, true)
	if int(result[0]) > 0:
		EventBus.item_picked_up.emit(r.output, int(result[0]) * r.output_count)
		EventBus.sound_requested.emit(&"craft", Vector2.INF)
	return int(result[0])


## An Empower tab recipe: buys the next rank of the node on the spell. 1 if bought.
func empower(r: RecipeData) -> int:
	var c := world.character
	var spell := ItemData.find(ItemData.spell_key(r.empower_spell)) as SpellData
	var node := Registry.get_def(&"empower", r.empower_node) as EmpowerNode
	if spell == null or node == null:
		return 0
	var problem := c.empower_problem(spell, node)
	if problem != "":
		EventBus.debug_message.emit(problem)
		return 0
	c.buy_empower(spell, node)
	_stock = null
	_recipe_key = ""
	EventBus.debug_message.emit("%s: %s rank %d" % [spell.display_name, node.display_name, c.empower_rank(spell.id, node.id)])
	EventBus.sound_requested.emit(&"learn_spell", Vector2.INF)
	return 1


## A Spells tab recipe: pays the learn cost and teaches the spell. 1 if learned.
func learn(r: RecipeData) -> int:
	var c := world.character
	var stock := craft_stock()
	if c.knows(r.teaches) or Crafting.times_craftable(stock, r) <= 0:
		return 0
	for k: StringName in r.inputs:
		stock.remove(k, r.inputs[k])
	_stock = null
	c.learn_spell(r.teaches)
	var spell := ItemData.find(r.output)
	EventBus.debug_message.emit("You learned %s. Put it in a quick slot (Equipment, P)." % (spell.display_name if spell else String(r.teaches)))
	EventBus.sound_requested.emit(&"craft", Vector2.INF)
	selected_recipe = mini(selected_recipe, maxi(0, recipes().size() - 1))
	return 1


func _can_upgrade() -> bool:
	var def := _station_def()
	if def == null or def.upgrade_to == &"":
		return false
	for k: StringName in def.upgrade_cost:
		if craft_stock().count_of(k) < def.upgrade_cost[k]:
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
		craft_stock().remove(k, def.upgrade_cost[k])
	world.request_set_object(station, next)
	return true


## Shift + click with a chest open: the whole stack to the other side.
func _move_stack(from: Inventory, slot: int, to: Inventory) -> void:
	if to == null or from.is_empty(slot) or String(from.ids[slot]).begins_with(ItemData.SPELL_PREFIX):
		return
	var id := from.ids[slot]
	var meta := from.metas[slot]
	if not meta.is_empty():  # one item with its own data (a coated weapon): to an empty slot
		for i in to.size:
			if to.is_empty(i):
				to.set_slot(i, id, from.counts[slot], meta)
				from.clear(slot)
				from.changed.emit()
				return
		return
	var left := to.add(id, from.counts[slot])
	from.set_slot(slot, id if left > 0 else &"", left)


## Left click with the panel open: pick up, put down, merge or swap. `inv` = a chest
## (null = your inventory).
func click_slot(slot: int, inv: Inventory = null) -> void:
	if inv == null:
		inv = world.character.inventory
	if _cursor_is_spell():
		return  # spells go in quick slots (Equipment window), not the inventory
	if cursor_count == 0:
		if not inv.is_empty(slot):
			cursor_id = inv.ids[slot]
			cursor_count = inv.counts[slot]
			cursor_meta = inv.metas[slot]
			inv.set_slot(slot, &"", 0)
		return
	if not _cursor_is_spell() and not inv.accepts(cursor_id):
		EventBus.debug_message.emit("That doesn't go in here")
		return
	if inv.is_empty(slot) and cursor_count > inv.cap_for(cursor_id):
		# More than a slot holds here: fill it, keep the rest on the mouse.
		inv.set_slot(slot, cursor_id, inv.cap_for(cursor_id), cursor_meta)
		cursor_count -= inv.cap_for(cursor_id)
	elif inv.is_empty(slot):
		inv.set_slot(slot, cursor_id, cursor_count, cursor_meta)
		_clear_cursor()
	elif inv.ids[slot] == cursor_id and not _cursor_is_spell():
		var cap := inv.cap_for(cursor_id)
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
		var meta := inv.metas[slot]
		inv.set_slot(slot, cursor_id, cursor_count, cursor_meta)
		cursor_id = id
		cursor_count = count
		cursor_meta = meta


## Right click: take half (empty mouse) or put one down. With a coating on the mouse
## and a weapon in the slot: coats the weapon (uses one coating).
func right_click_slot(slot: int, inv: Inventory = null) -> void:
	if inv == null:
		inv = world.character.inventory
	if _cursor_is_spell():
		return
	var on_mouse := ItemData.find(cursor_id) if cursor_count > 0 else null
	var there := inv.item(slot)
	if on_mouse and on_mouse.buff_poison_hits > 0 and there and there.kind == ItemData.Kind.WEAPON:
		if Coating.apply(inv.metas[slot], there, on_mouse):
			inv.changed.emit()
			cursor_count -= 1
			if cursor_count <= 0:
				_clear_cursor()
			EventBus.debug_message.emit("%s coated: next %d hits poison" % [there.display_name, on_mouse.buff_poison_hits])
			EventBus.sound_requested.emit(&"craft", Vector2.INF)
		return
	if cursor_count == 0:
		if inv.is_empty(slot):
			return
		var half := ceili(inv.counts[slot] / 2.0)
		cursor_id = inv.ids[slot]
		cursor_count = inv.take(slot, half)
		return
	if not inv.accepts(cursor_id):
		return
	if inv.is_empty(slot) or (inv.ids[slot] == cursor_id and inv.counts[slot] < inv.cap_for(cursor_id)):
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
	var why := "That doesn't go there" if cursor_count != 1 else c.equip_problem(slot, item)
	if why != "":
		EventBus.debug_message.emit(why)
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
		if c.equip_problem(eq, item) == "" and (target == &"" or (c.equipment[target] != &"" and c.equipment[eq] == &"")):
			target = eq
	if target == &"":
		for eq in EQUIP_SLOTS:
			if CharacterData.fits(eq, item):
				EventBus.debug_message.emit(c.equip_problem(eq, item))  # already wearing one
				break
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


## A quick slot (Equipment window): with a spell picked up, puts it there; with
## nothing, picks its spell up.
func click_quick_slot(slot: StringName) -> void:
	var c := world.character
	if _cursor_is_spell():
		if c.set_quick(slot, _cursor_spell()):
			_clear_cursor()
		else:
			EventBus.debug_message.emit("Only Buff spells go in the buff set")
	elif cursor_count > 0:
		# An item: Z X C become a shortcut to it (the stack stays on the mouse).
		if not c.set_quick_item(slot, cursor_id):
			EventBus.debug_message.emit("Only Z, X and C take items")
	elif cursor_count == 0:
		var id := c.quick_spell(slot)
		if id != &"":
			cursor_id = ItemData.spell_key(id)
			cursor_count = 1
			c.set_quick(slot, &"")


## The Movement slot (Equipment window): a movement spell on the mouse becomes the
## one the movement key (F) uses.
func click_movement_slot() -> void:
	var c := world.character
	if not _cursor_is_spell():
		return
	if c.set_movement_spell(_cursor_spell()):
		_clear_cursor()
	else:
		EventBus.debug_message.emit("Only Fly-style movement spells go here (Fly, Levitate)")


func click_known_spell(spell_id: StringName) -> void:
	if cursor_count > 0:
		if _cursor_is_spell():
			_clear_cursor()
		return
	cursor_id = ItemData.spell_key(spell_id)
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
	var meta := inv.metas[slot]  # a coated weapon keeps its coating
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
				inv.set_slot(i, id, k, meta if not meta.is_empty() else null)
				n -= k
	inv.set_slot(slot, id if n > 0 else &"", n)


func _cursor_is_spell() -> bool:
	return cursor_count > 0 and String(cursor_id).begins_with(ItemData.SPELL_PREFIX)


func _cursor_spell() -> StringName:
	return StringName(String(cursor_id).trim_prefix(ItemData.SPELL_PREFIX))


## The stack on the mouse if it can be used in the world (inventory open): any item
## but a spell shortcut. Else null.
func _cursor_placeable() -> ItemData:
	if not open or cursor_count <= 0:
		return null
	var item := ItemData.find(cursor_id)
	return item if item and not item.is_spell() else null


## Uses up one item of the mouse stack (it was placed). False when it's empty.
func _take_cursor_one() -> bool:
	if cursor_count <= 0:
		return false
	cursor_count -= 1
	if cursor_count == 0:
		cursor_id = &""
		cursor_meta = {}
	return true


func _throw_cursor() -> void:
	var p := world.player
	var dir := 1.0 if p.get_global_mouse_position().x >= p.global_position.x else -1.0
	world.request_spawn_drop(cursor_id, cursor_count, p.chest() + Vector2(dir * 10.0, 0),
		Vector2(dir * p.throw_speed * World.TILE, -6.0 * World.TILE), true)
	_clear_cursor()


func _clear_cursor() -> void:
	cursor_id = &""
	cursor_count = 0
	cursor_meta = {}
	_redraw()


# --- spell wheel -------------------------------------------------------------------------

func _update_wheel(paused: bool) -> void:
	# Q and E: hold = that wheel (move toward a spell, let go), tap = its last pick again.
	if wheel_key == &"" and not paused and not open:
		for w: StringName in CharacterData.WHEELS:
			if Input.is_action_just_pressed(StringName("wheel_" + String(w))):
				wheel_key = w
				_key_held = 0.0
				break
	if wheel_key == &"":
		_wheel.visible = false
		return
	var action := StringName("wheel_" + String(wheel_key))
	var down := Input.is_action_pressed(action)
	_key_held += get_process_delta_time()
	if not wheel_open and down and _key_held >= wheel_hold_seconds:
		wheel_open = true
		wheel_center = _wheel.get_local_mouse_position()
		wheel_choice = &""
	if not down:
		var w := wheel_key
		var was_open := wheel_open
		var choice := wheel_choice
		wheel_key = &""
		wheel_open = false
		wheel_choice = &""
		_wheel.visible = false
		if not was_open:
			world.player.tap_wheel(w)
		elif choice != &"":
			world.player.pick_wheel(choice)
		_redraw()
		return
	if not wheel_open:
		return
	_wheel.visible = true
	var slots := wheel_slots()
	var d := _wheel.get_local_mouse_position() - wheel_center
	wheel_choice = &""
	if d.length() > 8.0 and not slots.is_empty():
		wheel_choice = slots[wheel_index(d.angle(), slots.size())]
	_wheel.queue_redraw()


## The filled slots of the open wheel.
func wheel_slots() -> Array[StringName]:
	return world.character.wheel(wheel_key) if wheel_key != &"" else ([] as Array[StringName])


## Which of `n` wheel segments an angle (radians, 0 = right) falls in. Segment 0 is at
## the top, going clockwise.
static func wheel_index(angle: float, n: int) -> int:
	var a := fposmod(angle + PI * 0.5 + PI / n, TAU)
	return clampi(int(a / (TAU / n)), 0, n - 1)


func draw_wheel(w: Control) -> void:
	var slots := wheel_slots()
	var c := world.character
	var font := ThemeDB.fallback_font
	w.draw_circle(wheel_center, wheel_radius + 14.0, Color(0.03, 0.04, 0.06, 0.55))
	var key := String(wheel_key).to_upper()
	var kw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	w.draw_string(font, wheel_center + Vector2(-kw * 0.5, 3), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiSkin.GOLD)
	if slots.is_empty():
		var empty := "Nothing on %s (Equipment window, P)" % key
		var ew := font.get_string_size(empty, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		w.draw_string(font, wheel_center + Vector2(-ew * 0.5, wheel_radius + 26.0), empty, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.DIM)
		return
	for i in slots.size():
		var a := -PI * 0.5 + TAU * i / slots.size()
		var at := wheel_center + Vector2.from_angle(a) * wheel_radius
		var spell := ItemData.find(ItemData.spell_key(c.quick_spell(slots[i]))) as SpellData
		var r := Rect2(at - Vector2(SLOT, SLOT) * 0.5, Vector2(SLOT, SLOT))
		var chosen := slots[i] == wheel_choice
		UiSkin.slot(w, r, UiSkin.SlotLook.SELECTED if chosen else UiSkin.SlotLook.MAGIC)
		if spell and spell.icon:
			w.draw_texture_rect(spell.icon, r.grow(-2), false)
		if spell and c.cast_problem(spell) != "":
			w.draw_rect(r.grow(-1), BAD)
		if c.quick_casts(slots[i]):
			_draw_cast_mark(w, r)
	var label := "Pick a spell"
	if wheel_choice != &"":
		var chosen_spell := ItemData.find(ItemData.spell_key(c.quick_spell(wheel_choice))) as SpellData
		label = chosen_spell.display_name if chosen_spell else String(wheel_choice)
		label += " (cast)" if c.quick_casts(wheel_choice) else " (in hand)"
		var why := c.cast_problem(chosen_spell)
		if why != "":
			label += ": " + why
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	w.draw_string(font, wheel_center + Vector2(-lw * 0.5, wheel_radius + 26.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)


## The "casts right away" mark on a quick slot: a small gold bolt in the top right corner.
func _draw_cast_mark(g: CanvasItem, r: Rect2) -> void:
	var o := r.position + Vector2(r.size.x - 6, 1)
	var bolt := PackedVector2Array([o + Vector2(3, 0), o + Vector2(0, 3), o + Vector2(2, 3), o + Vector2(1, 6),
		o + Vector2(5, 2), o + Vector2(3, 2), o + Vector2(4, 0)])
	g.draw_colored_polygon(bolt, UiSkin.GOLD)


# --- tooltips and notes ------------------------------------------------------------------

func _update_tooltip(over: Control) -> void:
	var item: ItemData = null
	var extra := ""
	var extra_only := ""
	var meta: Dictionary = {}
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
			var e := _buff_entry_at_mouse()
			if not e.is_empty() and e[1] != null:
				var spell: SpellData = e[1]
				var count: String = e[4]
				extra_only = "%s%s, %s left\n%s" % [spell.display_name, (" (%s out)" % count) if count != "" else "",
					_clock(e[2]), spell.description]
				if (e[3] and not String(e[0]).begins_with("sick_")) or String(e[0]).begins_with("summon_"):
					extra_only += "\nRight click: end it"
		elif over == _quick:
			var qt := _quick_key_tooltip(_quick_key_at_mouse())
			item = qt[0]
			if item:
				extra = qt[1]
			else:
				extra_only = qt[1]
		elif over is HudWindow:
			var t: Array = (over as HudWindow).tooltip_at(over.get_local_mouse_position())
			item = t[0]
			if item and t[1] != "":
				extra = "\n" + t[1]
			else:
				extra_only = t[1]
		match h[0]:
			Area.INVENTORY:
				item = c.inventory.item(h[1])
				meta = c.inventory.metas[h[1]]
			Area.TRASH:
				item = c.trash.item(0)
				meta = c.trash.metas[0]
				if item:
					extra = "\nTrashed: click to take it back. The next thing trashed replaces it."
				else:
					extra_only = "Trash\nDrop something here (or Ctrl + click it) to throw it away."
			Area.CHEST:
				var store := _store()
				item = store.item(h[1]) if store else null
				meta = store.metas[h[1]] if store else {}
			Area.RECIPE:
				if h[1] < recipes().size():
					var r: RecipeData = recipes()[h[1]]
					item = ItemData.find(r.output)
					extra = "\nDouble click: craft 1"
	if over == null and cursor_count == 0 and not world.player.input_blocked:
		# Hovering a chest in the world: its name.
		var a := world.object_anchor_visual(world.world_to_tile(world.get_global_mouse_position()))
		var def := world.object_at(a) if a != World.NO_TILE else null
		if def and def.container_slots > 0:
			extra_only = world.container_name(a)
	_tooltip.visible = item != null or extra_only != ""
	if not _tooltip.visible:
		return
	var full := extra_only if item == null else tooltip_for(item, world.character, meta) + extra
	# The first line is the title (with a book's tier on the right); the rest below it.
	var cut := full.find("\n")
	_tooltip_title.text = full if cut < 0 else full.substr(0, cut)
	_tooltip_text.text = "" if cut < 0 else full.substr(cut + 1)
	_tooltip_text.visible = cut >= 0
	_tooltip_right.text = tooltip_right(item) if item else ""
	_tooltip_right.visible = _tooltip_right.text != ""
	_tooltip_types.text = spell_types(item as SpellData) if item is SpellData else ""
	_tooltip_types.visible = _tooltip_types.text != ""
	_tooltip.reset_size()
	# Hovering a chest in the world, no window is under the mouse.
	var at := (over if over else _tooltip).get_global_mouse_position() + Vector2(10, 8)
	var view := _view_size()
	at.x = minf(at.x, view.x - _tooltip.size.x - 2)
	at.y = minf(at.y, view.y - _tooltip.size.y - 2)
	_tooltip.position = at


## The right side of a tooltip's title line: "Tier N" for spellbooks, the kind for conduits.
static func tooltip_right(item: ItemData) -> String:
	if item is SpellData:
		return "Tier %d" % (item as SpellData).tier
	if item and item.kind == ItemData.Kind.BOOK:
		return "Tier %d" % item.max_spell_tier
	if item and item.kind == ItemData.Kind.CONDUIT and item.conduit_type != &"":
		return String(item.conduit_type).capitalize()
	return ""


## A stat bonus as a line: "+10% Magic damage", "+20 Max mana".
static func stat_text(k: StringName, v: float) -> String:
	var names := {&"max_health": "Max health", &"max_mana": "Max mana", &"mana_regen": "Mana regen",
		&"move_speed": "Speed", &"jump": "Jump", &"melee_damage": "Melee damage",
		&"magic_damage": "Magic damage", &"mining_speed": "Mining speed",
		&"summon_slots": "Summon at a time", &"summon_damage": "Summon damage"}
	var label: String = names.get(k, String(k).capitalize())
	if k in [&"max_health", &"max_mana", &"mana_regen", &"summon_slots"]:
		return "%+d %s" % [roundi(v), label]
	return "%+d%% %s" % [roundi(v * 100.0), label]


static func tooltip_for(item: ItemData, c: CharacterData = null, meta: Dictionary = {}) -> String:
	if item is SpellData:
		return spell_tooltip(item as SpellData, c)
	var lines := PackedStringArray([item.display_name])
	if meta.get("infinite", false):
		lines.append("Infinite (dev): never runs out")
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
			# Name | Tier (the title line), spell power, then its modifiers.
			lines.append("Spell power x%s" % str(item.spell_power))
		ItemData.Kind.CONDUIT:
			# Just what it changes.
			lines.append("Spell power x%s" % str(item.spell_power))
			if item.spell_reach_bonus != 0.0:
				lines.append("%+d spell reach" % roundi(item.spell_reach_bonus))
		ItemData.Kind.TOME:
			var s := ItemData.find(ItemData.spell_key(item.tome_spell))
			lines.append("Tome: casts %s" % (s.display_name if s else String(item.tome_spell)))
	var coat := Coating.of(meta)
	if not coat.is_empty():
		lines.append("%s: %d hits left" % [(coat[0] as ItemData).display_name, coat[1]])
	# Modifiers (books, conduits, accessories): "+10% Magic damage".
	for k: StringName in item.stats:
		if item.stats[k] != 0.0:
			lines.append(stat_text(k, item.stats[k]))
	if item.places_wall != &"":
		lines.append("Right click: place as a back wall")
	if item.teaches_spell != &"":
		lines.append_array(scroll_lines(item, c))
		return "\n".join(lines)
	if item.description != "":
		lines.append(item.description)
	return "\n".join(lines)


## A spell's tooltip: name, description, mana cost, then what else it needs (reagents,
## a conduit, a book tier) and why it can't be cast right now.
## A spell's types for its tooltip: its group and how it's cast ("Attack, Projectile").
static func spell_types(spell: SpellData) -> String:
	if spell == null:
		return ""
	var how := {SpellData.Cast.TOOL: "Tool", SpellData.Cast.PROJECTILE: "Projectile",
		SpellData.Cast.TOGGLE: "Concentration", SpellData.Cast.GUST: "Gust", SpellData.Cast.BLINK: "Blink",
		SpellData.Cast.LIGHT: "Summon", SpellData.Cast.BUFF: "Buff", SpellData.Cast.CHARGED: "Charged",
		SpellData.Cast.ZONE: "Zone", SpellData.Cast.WARD: "Ward", SpellData.Cast.SUMMON: "Summon",
		SpellData.Cast.CONJURE: "Conjure", SpellData.Cast.CHAIN: "Chain", SpellData.Cast.RITUAL: "Ritual",
		SpellData.Cast.SENSE: "Sense", SpellData.Cast.GRAB: "Channel"}
	var group := String(SpellData.Group.keys()[spell.group]).capitalize()
	return "%s, %s" % [group, how.get(spell.cast, "")]


static func spell_tooltip(spell: SpellData, c: CharacterData = null) -> String:
	var lines := PackedStringArray([spell.display_name])
	if spell.description != "":
		lines.append(spell.description)
	var mana := PackedStringArray()
	var mm := c.mana_mult(spell.id) if c else 1.0  # Empower: Efficient
	if spell.cast == SpellData.Cast.CHARGED:
		mana.append("%s to %s mana" % [_num(spell.mana_cost * spell.charge_min_mana * mm), _num(spell.mana_cost * mm)])
	elif spell.mana_cost > 0.0:
		mana.append("%s mana" % _num(spell.mana_cost * mm))
	if spell.mana_per_second > 0.0:
		mana.append("%s mana per second" % _num(spell.mana_per_second * mm))
	var off := "  (%d%% less, Empowered)" % roundi((1.0 - mm) * 100.0) if mm < 1.0 else ""
	lines.append("Mana: " + (", ".join(mana) if not mana.is_empty() else "none") + off)
	if c and c.empower.has(spell.id):
		var ranks := PackedStringArray()
		for node in EmpowerNode.for_spell(spell):
			var rk := c.empower_rank(spell.id, node.id)
			if rk > 0:
				ranks.append("%s %d/%d" % [node.display_name, rk, node.max_rank])
		if not ranks.is_empty():
			lines.append("Empowered: " + ", ".join(ranks))
	var needs := PackedStringArray()
	for id: StringName in spell.reagents:
		var it := ItemData.find(id)
		needs.append("%d %s" % [spell.reagents[id], it.display_name if it else String(id)])
	if spell.requires_conduit != &"":
		needs.append("a %s conduit" % String(spell.requires_conduit))
	if spell.tier > 1:
		needs.append("a tier %d book" % spell.tier)
	if not needs.is_empty():
		lines.append("Needs: " + ", ".join(needs))
	if spell.cooldown > 0.0:
		lines.append("Cooldown %s s" % _num(spell.cooldown))
	if c and c.knows(spell.id) and c.cast_problem(spell) != "":
		lines.append("Can't cast now: %s" % c.cast_problem(spell))
	var key := dedicated_key(spell, c)
	if key != "":
		lines.append("Has its own key (%s): no need to put it on a wheel, unless you want to." % key)
	return "\n".join(lines)


## The key a spell already has without a quick slot: R (Mining Spell), Ctrl + R
## (Chopping Spell), F (the Movement spell). Empty for the rest.
static func dedicated_key(spell: SpellData, c: CharacterData = null) -> String:
	match spell.id:
		&"mining_spell":
			return "R"
		&"chopping_spell":
			return "Ctrl + R"
	if c and c.movement_spell == spell.id:
		return "F"
	if spell.cast == SpellData.Cast.TOGGLE and spell.effect in [&"fly", &"levitate"]:
		return "F, in the Movement slot"
	return ""


static func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## What a scroll does, for its tooltip: both buttons, how long it lasts, one use.
static func scroll_lines(item: ItemData, c: CharacterData) -> PackedStringArray:
	var spell := ItemData.find(ItemData.spell_key(item.teaches_spell)) as SpellData
	var out := PackedStringArray()
	if spell == null:
		return out
	var cast_text := "Left click: cast %s once, free (no mana or reagents, no book needed)" % spell.display_name
	match spell.cast:
		SpellData.Cast.TOGGLE:
			var secs := item.scroll_seconds if item.scroll_seconds > 0.0 else 60.0
			cast_text += ". Runs for %d seconds" % roundi(secs)
		SpellData.Cast.TOOL:
			var secs := item.scroll_seconds if item.scroll_seconds > 0.0 else 15.0
			cast_text += ". You can use it for %d seconds" % roundi(secs)
		SpellData.Cast.CHARGED:
			cast_text += ", at full charge"
		SpellData.Cast.RITUAL:
			cast_text += " (you still stand still for %s s)" % String.num(spell.ritual_seconds, 1).trim_suffix(".0")
		_:
			if spell.duration > 0.0 and spell.cast in [SpellData.Cast.BUFF, SpellData.Cast.LIGHT, SpellData.Cast.ZONE,
					SpellData.Cast.WARD, SpellData.Cast.SUMMON, SpellData.Cast.CONJURE, SpellData.Cast.SENSE]:
				cast_text += ". Lasts %s" % _secs_text(spell.duration)
	out.append(cast_text + ".")
	if c and not c.knows(spell.id):
		out.append("Scrolls don't teach. Learn %s from its Spell Page or a Spell Weaving Table." % spell.display_name)
	out.append("One use: the scroll is used up.")
	out.append(spell.display_name + ": " + spell.description)
	return out


static func _secs_text(secs: float) -> String:
	return "%d minutes" % roundi(secs / 60.0) if secs >= 120.0 else "%d seconds" % roundi(secs)


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
