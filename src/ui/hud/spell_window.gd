class_name SpellWindow
extends HudWindow
## The Spell Index (L): every spell you know, with its tier and what it does. Click a
## spell to pick it up, then click a book slot (Equipped spells, in the Equipment
## window) or a hotbar slot. Spells already in your book are marked. The mouse wheel
## scrolls when the list is long.

const SLOT := Hud.SLOT
const PAD := Hud.PAD
const WIDTH := 236
## One spell per row.
const ROW_H := 24
## Rows shown before the list scrolls.
@export var rows_shown := 7

enum Part { NONE, SPELL }

var scroll := 0


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Spell Index")


func known() -> Array[StringName]:
	return hud.world.character.known_spells


func title_right() -> String:
	return "%d known" % known().size()


func _list_top() -> float:
	return BODY_TOP + 12


func layout() -> void:
	var n := clampi(known().size(), 1, rows_shown)
	size = Vector2(WIDTH, _list_top() + n * ROW_H + PAD - 2)
	scroll = clampi(scroll, 0, maxi(0, known().size() - rows_shown))


func row_rect(i: int) -> Rect2:
	return Rect2(PAD, _list_top() + (i - scroll) * ROW_H, size.x - PAD * 2, ROW_H - 2)


func hit(local: Vector2) -> Array:
	var list := known()
	for i in range(scroll, mini(list.size(), scroll + rows_shown)):
		if row_rect(i).has_point(local):
			return [Part.SPELL, i]
	return [Part.NONE, -1]


func draw_body(font: Font) -> void:
	var c := hud.world.character
	var list := known()
	var hint := "Click a spell, then a book or hotbar slot." if not list.is_empty() else "You don't know any spells yet."
	draw_string(font, Vector2(PAD, BODY_TOP + 6), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	var h := hit(get_local_mouse_position()) if hovered() else [Part.NONE, -1]
	for i in range(scroll, mini(list.size(), scroll + rows_shown)):
		var r := row_rect(i)
		var hot: bool = h[0] == Part.SPELL and h[1] == i
		if hot:
			draw_rect(r, Color(1, 1, 1, 0.07))
		var spell := ItemData.find(ItemData.spell_key(list[i]))
		var in_book := c.in_book(list[i])
		var sr := Rect2(r.position + Vector2(0, 1), Vector2(SLOT, SLOT))
		UiSkin.slot(self, sr, UiSkin.SlotLook.SELECTED if in_book else UiSkin.SlotLook.MAGIC)
		if spell == null:
			continue
		if spell.icon:
			draw_texture_rect(spell.icon, Rect2(sr.position + Vector2(2, 2), Vector2(16, 16)), false)
		var x := sr.end.x + 5
		var right := "Tier %d" % _tier(list[i])
		if in_book:
			right = "In book   " + right
		var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(font, Vector2(r.end.x - rw, r.position.y + 9), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
			UiSkin.GOOD if in_book else UiSkin.DIM)
		draw_string(font, Vector2(x, r.position.y + 9), spell.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
		var desc := _fit(font, spell.description.replace("\n", " "), r.end.x - x, 6)
		draw_string(font, Vector2(x, r.position.y + 18), desc, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)
	# Scroll marks.
	if scroll > 0:
		draw_string(font, Vector2(size.x - PAD - 6, _list_top() - 2), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	if scroll + rows_shown < list.size():
		draw_string(font, Vector2(size.x - PAD - 6, size.y - 2), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)


func _tier(spell_id: StringName) -> int:
	var d := ItemData.find(ItemData.spell_key(spell_id)) as SpellData
	return d.tier if d else 1


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
		var most := maxi(0, known().size() - rows_shown)
		scroll = clampi(scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, most)
		return
	var h := hit(mb.position)
	if h[0] == Part.SPELL and mb.button_index == MOUSE_BUTTON_LEFT:
		hud.click_known_spell(h[1])


func tooltip_at(local: Vector2) -> Array:
	var h := hit(local)
	if h[0] == Part.SPELL:
		return [ItemData.find(ItemData.spell_key(known()[h[1]])), ""]
	return [null, ""]
