class_name DevItemsWindow
extends HudWindow
## Dev builds: every item in the game, like a creative menu (F7, or console `creative`).
## Tabs by kind and a search box narrow the grid. Left click puts a full stack on the
## mouse (click again to add another stack's worth, up to a stack); right click puts one;
## shift + click sends a full stack straight to your inventory. Nothing else changes (no
## flying or god mode): it's just the menu.

const SLOT := Hud.SLOT
const STEP := Hud.STEP
const PAD := Hud.PAD
const COLS := 10
const TAB_H := 12
## Rows shown before the grid scrolls.
@export var rows_shown := 6

enum Part { NONE, ITEM, TAB, SEARCH }

## Tab name -> the kinds it shows (empty = all).
const TABS: Array = [
	["All", []],
	["Blocks", [ItemData.Kind.BLOCK, ItemData.Kind.WALL, ItemData.Kind.SEED]],
	["Furniture", [ItemData.Kind.FURNITURE]],
	["Tools", [ItemData.Kind.TOOL, ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY]],
	["Magic", [ItemData.Kind.BOOK, ItemData.Kind.CONDUIT, ItemData.Kind.TOME, ItemData.Kind.SCROLL, ItemData.Kind.PAGE]],
	["Food", [ItemData.Kind.FOOD]],
	["Materials", [ItemData.Kind.MATERIAL]],
]

var tab := 0
var search := ""
var searching := false
var scroll := 0
var _all: Array[ItemData] = []


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Dev items")


## Every item (data/items and the runtime dev items), not spells, by name.
func all_items() -> Array[ItemData]:
	if _all.is_empty():
		var seen := {}
		for d in Registry.get_all(&"items"):
			var it := d as ItemData
			if it and not it.is_spell() and not seen.has(it.id):
				seen[it.id] = true
				_all.append(it)
		for it in ItemData.runtime_items():
			if not it.is_spell() and not seen.has(it.id):
				seen[it.id] = true
				_all.append(it)
		_all.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	return _all


func shown() -> Array[ItemData]:
	var kinds: Array = TABS[tab][1]
	var q := search.strip_edges().to_lower()
	var out: Array[ItemData] = []
	for it in all_items():
		if not kinds.is_empty() and not it.kind in kinds:
			continue
		if q != "" and not (q in it.display_name.to_lower() or q in String(it.id)):
			continue
		out.append(it)
	return out


func title_right() -> String:
	return "%d items" % shown().size()


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


func tab_rect(i: int) -> Rect2:
	var font := ThemeDB.fallback_font
	var x := float(PAD)
	for k in i:
		x += _tab_w(font, k) + 2
	return Rect2(x, BODY_TOP, _tab_w(font, i), TAB_H)


func _tab_w(font: Font, i: int) -> float:
	return font.get_string_size(String(TABS[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8


func search_rect() -> Rect2:
	return Rect2(PAD, BODY_TOP + TAB_H + 3, size.x - PAD * 2, 11)


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
			var it: ItemData = shown()[h[1]]
			var stack := maxi(it.max_stack, 1)
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed:
				var left := hud.world.character.inventory.add(it.id, stack)
				if left > 0:
					EventBus.debug_message.emit("No room for more %s" % it.display_name)
			elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				hud.give_cursor(it.id, stack if mb.button_index == MOUSE_BUTTON_LEFT else 1)


func tooltip_at(local: Vector2) -> Array:
	var h := hit(local)
	if h[0] == Part.ITEM:
		return [shown()[h[1]], "Click: a stack on the mouse. Right click: one. Shift + click: into your inventory."]
	return [null, ""]
