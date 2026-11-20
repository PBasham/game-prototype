class_name SpellWindow
extends HudWindow
## The Spell Index (L): every spell you know, with its tier and what it does. Tabs at
## the top (All, then each SpellData.Group) and a search box (click it and type; Enter
## or Esc stops) narrow the list. Click a spell to pick it up, then click a quick slot
## in the Equipment window (P). Each row says which quick slots hold it. The mouse wheel
## scrolls when the list is long.

const SLOT := Hud.SLOT
const PAD := Hud.PAD
const WIDTH := 236
## One spell per row.
const ROW_H := 24
const TAB_H := 12
## Rows shown before the list scrolls.
@export var rows_shown := 7

enum Part { NONE, SPELL, TAB, SEARCH }

var scroll := 0
## -1 = All, else a SpellData.Group.
var tab := -1
var search := ""
## Typing in the search box (keys go here, not to the game).
var searching := false


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Spell Index")


func known() -> Array[StringName]:
	return hud.world.character.known_spells


## The known spells in the current tab that match the search, in the order learned.
func shown() -> Array[StringName]:
	var out: Array[StringName] = []
	var q := search.strip_edges().to_lower()
	for id in known():
		var spell := ItemData.find(ItemData.spell_key(id)) as SpellData
		if spell == null:
			continue
		if tab >= 0 and spell.group != tab:
			continue
		if q != "" and not (q in spell.display_name.to_lower() or q in spell.description.to_lower()):
			continue
		out.append(id)
	return out


func title_right() -> String:
	return "%d known" % known().size()


func set_searching(on: bool) -> void:
	searching = on
	hud.world.player.typing = on
	queue_redraw()


## A key while searching: letters go in the box. Returns true if it was used.
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
	layout()
	queue_redraw()
	return true


func tab_rect(i: int) -> Rect2:
	# i = -1 (All) .. groups; widths fit their names.
	var font := ThemeDB.fallback_font
	var x := float(PAD)
	for k in range(-1, i):
		x += _tab_w(font, k) + 2
	return Rect2(x, BODY_TOP, _tab_w(font, i), TAB_H)


func _tab_w(font: Font, i: int) -> float:
	var label := "All" if i < 0 else SpellData.GROUP_NAMES[i]
	return font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8


func search_rect() -> Rect2:
	return Rect2(PAD, BODY_TOP + TAB_H + 3, size.x - PAD * 2, 11)


func _list_top() -> float:
	return search_rect().end.y + 4


func layout() -> void:
	var n := clampi(shown().size(), 1, rows_shown)
	size = Vector2(WIDTH, _list_top() + n * ROW_H + PAD - 2)
	scroll = clampi(scroll, 0, maxi(0, shown().size() - rows_shown))


func row_rect(i: int) -> Rect2:
	return Rect2(PAD, _list_top() + (i - scroll) * ROW_H, size.x - PAD * 2, ROW_H - 2)


func hit(local: Vector2) -> Array:
	for i in range(-1, SpellData.GROUP_NAMES.size()):
		if tab_rect(i).has_point(local):
			return [Part.TAB, i]
	if search_rect().has_point(local):
		return [Part.SEARCH, 0]
	var list := shown()
	for i in range(scroll, mini(list.size(), scroll + rows_shown)):
		if row_rect(i).has_point(local):
			return [Part.SPELL, i]
	return [Part.NONE, -1]


## Which quick slots hold a spell, for its row: "Q, Z", "Buff set".
func where(spell_id: StringName) -> String:
	var c := hud.world.character
	var keys := PackedStringArray()
	for slot in CharacterData.all_quick_slots():
		if c.quick_spell(slot) == spell_id:
			var g := CharacterData.slot_group(slot)
			var label := "Buff set" if g == &"buff" else (String(slot) if g == &"keys" else String(g)).to_upper()
			if label == "BUFF SET":
				label = "Buff set"
			if not label in keys:
				keys.append(label)
	return ", ".join(keys)


func draw_body(font: Font) -> void:
	var h := hit(get_local_mouse_position()) if hovered() else [Part.NONE, -1]
	for i in range(-1, SpellData.GROUP_NAMES.size()):
		var label := "All" if i < 0 else SpellData.GROUP_NAMES[i]
		var state := UiSkin.Btn.PRESSED if tab == i else (UiSkin.Btn.HOT if h[0] == Part.TAB and h[1] == i else UiSkin.Btn.NORMAL)
		UiSkin.button(self, tab_rect(i), label, state)
	var sr := search_rect()
	UiSkin.slot(self, sr, UiSkin.SlotLook.SELECTED if searching else (UiSkin.SlotLook.HOT if h[0] == Part.SEARCH else UiSkin.SlotLook.NORMAL))
	var blink := searching and fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0
	var text := search + ("_" if blink else "")
	if search == "" and not searching:
		text = "Search..."
	draw_string(font, sr.position + Vector2(3, 8), text, HORIZONTAL_ALIGNMENT_LEFT, sr.size.x - 6, 6,
		UiSkin.TEXT if search != "" or searching else UiSkin.DIM)
	var list := shown()
	if known().is_empty():
		draw_string(font, Vector2(PAD, _list_top() + 9), "You don't know any spells yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	elif list.is_empty():
		draw_string(font, Vector2(PAD, _list_top() + 9), "No spells match.", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	for i in range(scroll, mini(list.size(), scroll + rows_shown)):
		var r := row_rect(i)
		var hot: bool = h[0] == Part.SPELL and h[1] == i
		if hot:
			draw_rect(r, Color(1, 1, 1, 0.07))
		var spell := ItemData.find(ItemData.spell_key(list[i])) as SpellData
		var on := where(list[i])
		var slot_r := Rect2(r.position + Vector2(0, 1), Vector2(SLOT, SLOT))
		UiSkin.slot(self, slot_r, UiSkin.SlotLook.SELECTED if on != "" else UiSkin.SlotLook.MAGIC)
		if spell == null:
			continue
		if spell.icon:
			draw_texture_rect(spell.icon, Rect2(slot_r.position + Vector2(2, 2), Vector2(16, 16)), false)
		var x := slot_r.end.x + 5
		var right := "Tier %d" % spell.tier
		if on != "":
			right = "On " + on + "   " + right
		var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(font, Vector2(r.end.x - rw, r.position.y + 9), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
			UiSkin.GOOD if on != "" else UiSkin.DIM)
		draw_string(font, Vector2(x, r.position.y + 9), spell.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
		var desc := _fit(font, spell.description.replace("\n", " "), r.end.x - x, 6)
		draw_string(font, Vector2(x, r.position.y + 18), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)
	# Scroll marks.
	if scroll > 0:
		draw_string(font, Vector2(size.x - PAD - 6, _list_top() - 2), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	if scroll + rows_shown < list.size():
		draw_string(font, Vector2(size.x - PAD - 6, size.y - 2), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)


## `text` cut to fit `width` px, with "..." when cut.
static func _fit(font: Font, text: String, width: float, font_size: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var s := text
	while s.length() > 1 and font.get_string_size(s + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "..."


func body_click(mb: InputEventMouseButton) -> void:
	if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var most := maxi(0, shown().size() - rows_shown)
		scroll = clampi(scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var h := hit(mb.position)
	if h[0] != Part.SEARCH and searching:
		set_searching(false)
	match h[0]:
		Part.TAB:
			tab = h[1]
			scroll = 0
			layout()
		Part.SEARCH:
			set_searching(not searching)
		Part.SPELL:
			hud.click_known_spell(shown()[h[1]])


func tooltip_at(local: Vector2) -> Array:
	var h := hit(local)
	if h[0] == Part.SPELL:
		return [ItemData.find(ItemData.spell_key(shown()[h[1]])), ""]
	return [null, ""]
