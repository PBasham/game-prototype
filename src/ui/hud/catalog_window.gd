class_name CatalogWindow
extends HudWindow
## The Catalog (J, or left click the Catalog book you start with): every item and
## enemy in the game, found ones shown, the rest blacked out so you know there's more.
## Click one to read about it. The Recipes tab takes an item (drop one from the mouse
## on its slot, or "Recipes" on an item's page) and lists every recipe that makes it or
## uses it; recipes you haven't discovered are blacked out, with their station.
## The logic is in Catalog (src/items/catalog.gd).

const SLOT := Hud.SLOT
const STEP := Hud.STEP
const PAD := Hud.PAD
const COLS := 8
const ROWS := 7
const TAB_H := 12
const DETAIL_W := 132
const ROW_H := 20
const RECIPE_ROWS := 8
const TABS: Array[String] = ["Items", "Creatures", "Recipes"]
const SILHOUETTE := Color(0.0, 0.0, 0.0, 0.85)

enum Part { NONE, TAB, CELL, SLOT_PICK, RECIPES_BUTTON, RECIPE, SEARCH, LINK }
## A link's color (an enemy on an item's page, a drop on an enemy's page).
const LINK := Color("9fd4ff")
const DROP_ROW := 18

var tab := 0
var scroll := 0
## The item or enemy whose page is open (Items / Enemies), and the Recipes tab's item.
var picked_item: ItemData
var picked_enemy: EnemyData
var recipe_item: ItemData
## The search box (Items and Enemies): narrows the list to names containing it. Only
## found things match by name, so searching doesn't give away what's still hidden.
var search := ""
## Links drawn on the open page: [Rect2, ItemData or EnemyData]. Rebuilt each draw.
var _links: Array[Array] = []
var searching := false


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Catalog")


func _char() -> CharacterData:
	return hud.world.character if hud and hud.world else null


func title_right() -> String:
	var c := _char()
	match tab:
		0:
			var p := Catalog.item_progress(c)
			return "%d / %d found" % [p.x, p.y]
		1:
			var p := Catalog.enemy_progress(c)
			return "%d / %d found" % [p.x, p.y]
	return ""


func layout() -> void:
	size = Vector2(PAD * 2 + COLS * STEP - Hud.GAP + 8 + DETAIL_W, _top() + ROWS * STEP - Hud.GAP + PAD)


func _top() -> float:
	return BODY_TOP + TAB_H + 4


func tab_rect(i: int) -> Rect2:
	return Rect2(PAD + i * 52, BODY_TOP, 50, TAB_H)


func cell(i: int) -> Rect2:
	var k := i - scroll * COLS
	return Rect2(PAD + (k % COLS) * STEP, _top() + (k / COLS) * STEP, SLOT, SLOT)


func detail_rect() -> Rect2:
	var x := PAD + COLS * STEP - Hud.GAP + 8
	return Rect2(x, _top(), DETAIL_W, ROWS * STEP - Hud.GAP)


func recipes_button_rect() -> Rect2:
	var d := detail_rect()
	return Rect2(d.position.x + 4, d.end.y - 16, 56, 12)


## Recipes tab: the item slot, and recipe rows (making it first, then using it).
func pick_rect() -> Rect2:
	return Rect2(PAD, _top(), SLOT, SLOT)


func recipe_rect(i: int) -> Rect2:
	var k := i - scroll
	return Rect2(PAD, _top() + SLOT + 16 + k * ROW_H, size.x - PAD * 2, ROW_H - 2)


func _list_size() -> int:
	match tab:
		0:
			return _items().size()
		1:
			return _enemies().size()
	return _recipes().size()


## The Items tab's list, narrowed by the search.
func _items() -> Array[ItemData]:
	var q := search.strip_edges().to_lower()
	if q == "":
		return Catalog.all_items()
	var c := _char()
	return Catalog.all_items().filter(func(it: ItemData) -> bool:
		return Catalog.item_found(c, it.id) and q in it.display_name.to_lower())


## The Enemies tab's list, narrowed by the search.
func _enemies() -> Array[EnemyData]:
	var q := search.strip_edges().to_lower()
	if q == "":
		return Catalog.all_enemies()
	var c := _char()
	return Catalog.all_enemies().filter(func(e: EnemyData) -> bool:
		return Catalog.enemy_found(c, e.id) and q in e.display_name.to_lower())


func search_rect() -> Rect2:
	var d := detail_rect()
	return Rect2(d.position.x, BODY_TOP, d.size.x, TAB_H)


func set_searching(on: bool) -> void:
	searching = on
	if hud and hud.world and hud.world.player:
		hud.world.player.typing = on
	queue_redraw()


## A key while the search box is active (Hud routes keys here). True if used.
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


## [recipe, "makes" or "uses"] for the Recipes tab's item.
func _recipes() -> Array[Array]:
	var out: Array[Array] = []
	if recipe_item == null:
		return out
	for r in Catalog.recipes_making(recipe_item.id):
		out.append([r, "makes"])
	for r in Catalog.recipes_using(recipe_item.id):
		out.append([r, "uses"])
	return out


func hit(local: Vector2) -> Array:
	for i in TABS.size():
		if tab_rect(i).has_point(local):
			return [Part.TAB, i]
	if tab != 2 and search_rect().has_point(local):
		return [Part.SEARCH, 0]
	if tab != 2:
		for i in _links.size():
			if (_links[i][0] as Rect2).has_point(local):
				return [Part.LINK, i]
	if tab == 2:
		if pick_rect().has_point(local):
			return [Part.SLOT_PICK, 0]
		var list := _recipes()
		for i in range(scroll, mini(list.size(), scroll + RECIPE_ROWS)):
			if recipe_rect(i).has_point(local):
				return [Part.RECIPE, i]
		return [Part.NONE, -1]
	if recipes_button_rect().has_point(local) and tab == 0 and picked_item and Catalog.item_found(_char(), picked_item.id):
		return [Part.RECIPES_BUTTON, 0]
	for i in range(scroll * COLS, mini(_list_size(), (scroll + ROWS) * COLS)):
		if cell(i).has_point(local):
			return [Part.CELL, i]
	return [Part.NONE, -1]


# --- drawing --------------------------------------------------------------------------

func draw_body(font: Font) -> void:
	var h := hit(get_local_mouse_position()) if hovered() else [Part.NONE, -1]
	var hot_link: Variant = _links[h[1]][1] if h[0] == Part.LINK else null
	_links.clear()
	for i in TABS.size():
		var state := UiSkin.Btn.PRESSED if tab == i else (UiSkin.Btn.HOT if h[0] == Part.TAB and h[1] == i else UiSkin.Btn.NORMAL)
		UiSkin.button(self, tab_rect(i), TABS[i], state)
	if tab != 2:
		var sr := search_rect()
		UiSkin.slot(self, sr, UiSkin.SlotLook.SELECTED if searching else (UiSkin.SlotLook.HOT if h[0] == Part.SEARCH else UiSkin.SlotLook.NORMAL))
		var blink := searching and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0
		var text := search + ("_" if blink else "")
		if search == "" and not searching:
			text = "Search..."
		draw_string(font, sr.position + Vector2(3, 9), text, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 6, 6,
			UiSkin.TEXT if search != "" or searching else UiSkin.DIM)
	match tab:
		0:
			_draw_items(font, h, hot_link)
		1:
			_draw_enemies(font, h, hot_link)
		2:
			_draw_recipes(font, h)


func _draw_items(font: Font, h: Array, hot_link: Variant) -> void:
	var c := _char()
	var items := _items()
	for i in range(scroll * COLS, mini(items.size(), (scroll + ROWS) * COLS)):
		var r := cell(i)
		var it := items[i]
		var sel := picked_item == it
		UiSkin.slot(self, r, UiSkin.SlotLook.SELECTED if sel else (UiSkin.SlotLook.HOT if h[0] == Part.CELL and h[1] == i else UiSkin.SlotLook.NORMAL))
		_icon(r, it, Catalog.item_found(c, it.id))
	_scroll_marks(font, items.size(), COLS, ROWS)
	var d := detail_rect()
	UiSkin.slot(self, d, UiSkin.SlotLook.NORMAL)
	if picked_item == null:
		_text(font, d.position + Vector2(5, 12), "Click an item to read about it.", d.size.x - 10, UiSkin.DIM)
		return
	var it := picked_item
	if not Catalog.item_found(c, it.id):
		_icon(Rect2(d.position + Vector2(4, 4), Vector2(SLOT, SLOT)), it, false)
		_text(font, d.position + Vector2(26, 15), "???", d.size.x - 30, UiSkin.TEXT)
		_text(font, d.position + Vector2(5, 34), "Not found yet.", d.size.x - 10, UiSkin.DIM)
		return
	_icon(Rect2(d.position + Vector2(4, 4), Vector2(SLOT, SLOT)), it, true)
	_text(font, d.position + Vector2(26, 15), it.display_name, d.size.x - 30, UiSkin.GOLD)
	var y := _text(font, d.position + Vector2(5, 34), it.description, d.size.x - 10, UiSkin.TEXT, 5)
	var lines: Array[String] = []
	var makes := Catalog.recipes_making(it.id)
	if not makes.is_empty():
		var where: Array[String] = []
		for r in makes:
			var s := Catalog.station_name(r.station) if Catalog.recipe_known(c, r) else "???"
			if not s in where:
				where.append(s)
		lines.append("Made at: " + ", ".join(where))
	var uses := Catalog.recipes_using(it.id)
	if not uses.is_empty():
		lines.append("Used in %d recipe%s" % [uses.size(), "" if uses.size() == 1 else "s"])
	for line in lines:
		y = _text(font, Vector2(d.position.x + 5, y + 3), line, d.size.x - 10, UiSkin.DIM, 2)
	# Dropped by: each enemy a link to its page, with its drop chance.
	var drops := Catalog.dropped_by(c, it.id)
	if not drops.is_empty():
		y = _text(font, Vector2(d.position.x + 5, y + 3), "Dropped by:", d.size.x - 10, UiSkin.DIM)
		for e in drops:
			if y + 10 > recipes_button_rect().position.y:
				break
			var l := Catalog.loot_line(e, it.id)
			var label := e.display_name + ("  (%s)" % Catalog.loot_text(l) if l else "")
			y = _link(font, Vector2(d.position.x + 9, y + 1), label, e, hot_link == e)
	if not makes.is_empty() or not uses.is_empty():
		UiSkin.button(self, recipes_button_rect(), "Recipes", UiSkin.Btn.HOT if h[0] == Part.RECIPES_BUTTON else UiSkin.Btn.NORMAL)


func _draw_enemies(font: Font, h: Array, hot_link: Variant) -> void:
	var c := _char()
	var list := _enemies()
	for i in range(scroll * COLS, mini(list.size(), (scroll + ROWS) * COLS)):
		var r := cell(i)
		var e := list[i]
		UiSkin.slot(self, r, UiSkin.SlotLook.SELECTED if picked_enemy == e else (UiSkin.SlotLook.HOT if h[0] == Part.CELL and h[1] == i else UiSkin.SlotLook.NORMAL))
		_enemy_icon(r.grow(-1), e, Catalog.enemy_found(c, e.id))
	_scroll_marks(font, list.size(), COLS, ROWS)
	var d := detail_rect()
	UiSkin.slot(self, d, UiSkin.SlotLook.NORMAL)
	if picked_enemy == null:
		_text(font, d.position + Vector2(5, 12), "Click a creature to read about it. Slay one to fill in its page.", d.size.x - 10, UiSkin.DIM)
		return
	var e := picked_enemy
	var found := Catalog.enemy_found(c, e.id)
	_enemy_icon(Rect2(d.position + Vector2(4, 4), Vector2(28, 22)), e, found)
	if not found:
		_text(font, d.position + Vector2(36, 15), "???", d.size.x - 40, UiSkin.TEXT)
		_text(font, d.position + Vector2(5, 34), "Not slain yet.", d.size.x - 10, UiSkin.DIM)
		return
	_text(font, d.position + Vector2(36, 15), e.display_name, d.size.x - 40, UiSkin.GOLD)
	# Hostile or passive (critters only fight back once you've hit them).
	var kind := "Passive" if e.is_critter() else "Hostile"
	_text(font, d.position + Vector2(36, 24), kind, d.size.x - 40, UiSkin.GOOD if e.is_critter() else UiSkin.BAD)
	var y := _text(font, d.position + Vector2(5, 34), e.description, d.size.x - 10, UiSkin.TEXT, 4)
	var stats := "Health %d   Damage %d" % [roundi(e.max_health), roundi(e.contact_damage)]
	if e.defense > 0:
		stats += "   Defense %d" % e.defense
	y = _text(font, Vector2(d.position.x + 5, y + 3), stats, d.size.x - 10, UiSkin.TEXT)
	y = _text(font, Vector2(d.position.x + 5, y + 1), "Slain: %d" % int(c.slain.get(e.id, 0)), d.size.x - 10, UiSkin.DIM)
	y = _text(font, Vector2(d.position.x + 5, y + 3), "Drops:", d.size.x - 10, UiSkin.DIM)
	# One row per drop: its icon, its name (a link to its page once seen), how many and
	# the chance. Unseen drops stay blacked out, but their chance shows.
	y -= 6
	for pair in Catalog.drops_of(c, e):
		if y + DROP_ROW > d.end.y:
			break
		var it: ItemData = pair[0]
		var seen: bool = pair[1]
		var l := Catalog.loot_line(e, it.id)
		var r := Rect2(d.position.x + 5, y, 16, 16)
		_icon(r, it, seen)
		var chance := Catalog.loot_text(l) if l else ""
		var cw := font.get_string_size(chance, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(font, Vector2(d.end.x - cw - 5, y + 11), chance, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)
		var name_w := d.size.x - 30 - cw - 8
		if seen:
			_link(font, Vector2(r.end.x + 4, y + 5), it.display_name, it, hot_link == it, name_w, 6)
		else:
			draw_string(font, Vector2(r.end.x + 4, y + 11), "???", HORIZONTAL_ALIGNMENT_LEFT, name_w, 6, UiSkin.DIM)
		y += DROP_ROW


func _draw_recipes(font: Font, h: Array) -> void:
	var c := _char()
	var pr := pick_rect()
	UiSkin.slot(self, pr, UiSkin.SlotLook.HOT if h[0] == Part.SLOT_PICK else UiSkin.SlotLook.SELECTED)
	if recipe_item:
		_icon(pr, recipe_item, true)
		_text(font, pr.position + Vector2(SLOT + 6, 12), recipe_item.display_name, 200, UiSkin.GOLD)
	else:
		_text(font, pr.position + Vector2(SLOT + 6, 8), "Drop an item here (or use Recipes on its page)", size.x - SLOT - PAD * 2 - 8, UiSkin.DIM)
		return
	var list := _recipes()
	if list.is_empty():
		_text(font, Vector2(PAD, pr.end.y + 12), "Not made or used in any recipe.", size.x - PAD * 2, UiSkin.DIM)
		return
	var hidden := list.filter(func(e: Array) -> bool: return not Catalog.recipe_known(c, e[0])).size()
	_text(font, Vector2(PAD, pr.end.y + 10), "%d recipe%s%s" % [list.size(), "" if list.size() == 1 else "s",
		"" if hidden == 0 else " (%d not discovered yet)" % hidden], size.x - PAD * 2, UiSkin.DIM)
	for i in range(scroll, mini(list.size(), scroll + RECIPE_ROWS)):
		var rr := recipe_rect(i)
		var r: RecipeData = list[i][0]
		var known := Catalog.recipe_known(c, r)
		UiSkin.slot(self, rr, UiSkin.SlotLook.HOT if h[0] == Part.RECIPE and h[1] == i else UiSkin.SlotLook.NORMAL)
		var out := ItemData.find(r.output)
		var icon_r := Rect2(rr.position + Vector2(1, 0), Vector2(SLOT, SLOT))
		if out:
			_icon(icon_r, out, known)
		var label := (out.display_name if out else String(r.output)) if known else "???"
		if known and r.output_count > 1:
			label += " x%d" % r.output_count
		_text(font, rr.position + Vector2(SLOT + 4, 8), label, 96, UiSkin.TEXT if known else UiSkin.DIM)
		_text(font, rr.position + Vector2(SLOT + 4, 16), Catalog.station_name(r.station), 96, UiSkin.DIM)
		# Ingredients, right side.
		var x := rr.end.x - 4
		for id: StringName in r.inputs:
			var item := ItemData.find(id)
			x -= 16
			if item == null or x < rr.position.x + SLOT + 100:
				break
			var ir := Rect2(x, rr.position.y + 1, 16, 16)
			if item.icon:
				draw_texture_rect(item.icon, ir, false, Color.WHITE if known else SILHOUETTE)
			if known:
				_count(font, ir, int(r.inputs[id]))
			x -= 3
	_scroll_marks(font, list.size(), 1, RECIPE_ROWS)


## A clickable line (link color, underlined when hovered); remembers where it is for
## clicks. Returns the y below it.
func _link(font: Font, at: Vector2, text: String, target: Variant, hot: bool, width: float = -1.0,
		font_size: int = 7) -> float:
	var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, width if width > 0.0 else INF)
	draw_string(font, at + Vector2(0, font_size), text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, UiSkin.TEXT if hot else LINK)
	if hot:
		draw_line(at + Vector2(0, font_size + 2), at + Vector2(w, font_size + 2), UiSkin.TEXT, 1.0)
	_links.append([Rect2(at - Vector2(1, 1), Vector2(w + 2, font_size + 4)), target])
	return at.y + font_size + 3


func _icon(r: Rect2, it: ItemData, found: bool) -> void:
	if it.icon == null:
		return
	var at := Rect2(r.position + (r.size - Vector2(16, 16)) * 0.5, Vector2(16, 16))
	draw_texture_rect(it.icon, at, false, Color.WHITE if found else SILHOUETTE)


## The enemy's first frame, fitted into `r`.
func _enemy_icon(r: Rect2, e: EnemyData, found: bool) -> void:
	if e.texture == null:
		return
	var f := Vector2(e.frame_size)
	var k := minf(r.size.x / f.x, r.size.y / f.y)
	var dst := Rect2(r.position + (r.size - f * k) * 0.5, f * k)
	draw_texture_rect_region(e.texture, dst, Rect2(Vector2.ZERO, f), (e.tint if found else SILHOUETTE))


func _count(font: Font, r: Rect2, n: int) -> void:
	if n <= 1:
		return
	var s := str(n)
	draw_string(font, r.end - Vector2(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x, 0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)


## Wrapped text; returns the y below it.
func _text(font: Font, at: Vector2, text: String, width: float, color: Color, max_lines: int = -1) -> float:
	draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width, 7, max_lines, color)
	var lines := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 7, max_lines).y
	return at.y + lines


func _scroll_marks(font: Font, total: int, cols: int, rows_shown: int) -> void:
	var rows := ceili(total / float(cols))
	if scroll > 0:
		draw_string(font, Vector2(PAD + cols * STEP - 2, _top() - 1), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	if scroll + rows_shown < rows:
		draw_string(font, Vector2(PAD + cols * STEP - 2, size.y - 2), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)


# --- input --------------------------------------------------------------------------

func body_click(mb: InputEventMouseButton) -> void:
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var cols := 1 if tab == 2 else COLS
		var shown := RECIPE_ROWS if tab == 2 else ROWS
		var rows := ceili(_list_size() / float(cols))
		scroll = clampi(scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, rows - shown))
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and not (mb.button_index == MOUSE_BUTTON_RIGHT and tab == 2):
		return
	var h := hit(mb.position)
	if h[0] != Part.SEARCH and searching:
		set_searching(false)
	match h[0]:
		Part.TAB:
			tab = h[1]
			scroll = 0
		Part.SEARCH:
			set_searching(not searching)
		Part.CELL:
			if tab == 0:
				picked_item = _items()[h[1]]
			else:
				picked_enemy = _enemies()[h[1]]
		Part.RECIPES_BUTTON:
			show_recipes(picked_item)
		Part.LINK:
			follow(_links[h[1]][1])
		Part.SLOT_PICK:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				recipe_item = null
			elif hud.cursor_count > 0:
				var it := ItemData.find(hud.cursor_id)
				if it and not it.is_spell():
					recipe_item = it
			scroll = 0
		Part.RECIPE:
			# A known recipe's result: look up that item's recipes in turn.
			var r: RecipeData = _recipes()[h[1]][0]
			if Catalog.recipe_known(_char(), r) and ItemData.find(r.output):
				show_recipes(ItemData.find(r.output))
	queue_redraw()


## Opens an enemy's or an item's page (a link on another page).
func follow(target: Variant) -> void:
	if target is EnemyData:
		picked_enemy = target
		tab = 1
	elif target is ItemData:
		picked_item = target
		tab = 0
	scroll = 0
	_links.clear()
	queue_redraw()


## Opens the Recipes tab on an item.
func show_recipes(it: ItemData) -> void:
	recipe_item = it
	tab = 2
	scroll = 0
	queue_redraw()


func tooltip_at(local: Vector2) -> Array:
	var h := hit(local)
	var c := _char()
	if h[0] == Part.CELL and tab == 0:
		var it: ItemData = _items()[h[1]]
		return [it, ""] if Catalog.item_found(c, it.id) else [null, "Not found yet"]
	if h[0] == Part.RECIPE:
		var r: RecipeData = _recipes()[h[1]][0]
		if not Catalog.recipe_known(c, r):
			return [null, "Not discovered yet: find what reveals it (made at %s)" % Catalog.station_name(r.station)]
		return [ItemData.find(r.output), ""]
	if h[0] == Part.SLOT_PICK:
		return [null, "Drop an item from the mouse here. Right click: clear."]
	if h[0] == Part.LINK:
		var t: Variant = _links[h[1]][1]
		return [null, "Open %s's page" % (t as EnemyData).display_name] if t is EnemyData else [t, ""]
	return [null, ""]
