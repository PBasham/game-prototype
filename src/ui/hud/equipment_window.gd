class_name EquipmentWindow
extends HudWindow
## The Equipment window (P): your character in the middle, armor on the left (head,
## chest, legs), trinkets on the right (three accessory slots), the Book and Conduit
## underneath, your stats on the far right. Below that, a section you can fold away:
## Equipped spells (the book's slots), and the Spell Index (L) button.
##
## Click a slot with an item on the mouse to equip it; click an equipped item to pick it
## up; shift + click (or ctrl + right click) puts it back in the inventory. Book slots
## work like before: click a spell from the Spell Index, then a book slot; right click
## empties one.

const SLOT := Hud.SLOT
const STEP := Hud.STEP
const PAD := Hud.PAD
## The character preview box, between the armor and trinket columns.
const DOLL_W := 60
## Tall enough for the whole character (the doll is about 76 px).
const DOLL_H := 82
## The slot columns are centered on the character box.
const COLUMN_TOP := BODY_TOP + (DOLL_H - (3 * STEP - Hud.GAP)) / 2
## Width of the stats column.
const STATS_W := 96
## Book slots per row in the Equipped spells section.
const BOOK_ROW := 10

enum Part { NONE, SLOT, BOOK, FOLD, INDEX }

## Equipped spells section shown (click its header to fold it away).
var spells_shown := true

var _doll: PaperDoll
var _doll_box: SubViewportContainer


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Equipment")


func _ready() -> void:
	_doll_box = SubViewportContainer.new()
	_doll_box.stretch = true
	_doll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doll_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_doll_box.position = doll_rect().position + Vector2(1, 1)
	_doll_box.size = doll_rect().size - Vector2(2, 2)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(_doll_box.size)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_doll_box.add_child(vp)
	_doll = PaperDoll.new()
	vp.add_child(_doll)
	_doll.setup(DollRig.load_from(Player.SHEET), load(Player.PALETTE) as CharacterPalette)
	_doll.position = Vector2(vp.size.x * 0.5, vp.size.y - 2)
	_doll.play(&"Breath")
	add_child(_doll_box)
	refresh_look()


## Matches the preview to the character's colors and armor.
func refresh_look() -> void:
	if _doll and hud.world and hud.world.character:
		_doll.look = hud.world.character.make_look()
		_doll.wear(hud.world.character.worn_items())


# --- layout ------------------------------------------------------------------------------

func doll_rect() -> Rect2:
	return Rect2(PAD + SLOT + 6, BODY_TOP, DOLL_W, DOLL_H)


## Slot `i` of CharacterData.ALL_SLOTS: armor left, accessories right, book and conduit
## under the character.
func slot_rect(i: int) -> Rect2:
	var d := doll_rect()
	var slot_id := CharacterData.ALL_SLOTS[i]
	if slot_id in [CharacterData.SLOT_HEAD, CharacterData.SLOT_CHEST, CharacterData.SLOT_LEGS]:
		return Rect2(PAD, COLUMN_TOP + i * STEP, SLOT, SLOT)
	if slot_id in CharacterData.SLOT_ACCESSORIES:
		var k := CharacterData.SLOT_ACCESSORIES.find(slot_id)
		return Rect2(d.end.x + 6, COLUMN_TOP + k * STEP, SLOT, SLOT)
	var k := 0 if slot_id == CharacterData.SLOT_BOOK else 1
	var x := d.position.x + (d.size.x - (2 * STEP - Hud.GAP)) * 0.5
	return Rect2(x + k * STEP, d.end.y + 4, SLOT, SLOT)


func _stats_x() -> float:
	return doll_rect().end.x + 6 + SLOT + 10


## Top of the Equipped spells header.
func _fold_y() -> float:
	return doll_rect().end.y + 4 + SLOT + 8


func fold_rect() -> Rect2:
	return Rect2(PAD, _fold_y(), 110, 12)


func index_button_rect() -> Rect2:
	return Rect2(size.x - PAD - 84, _fold_y() - 2, 84, 15)


func _book_origin() -> Vector2:
	return Vector2(PAD, _fold_y() + 26)


func book_rect(i: int) -> Rect2:
	return Rect2(_book_origin() + Vector2((i % BOOK_ROW) * STEP, (i / BOOK_ROW) * STEP), Vector2(SLOT, SLOT))


func layout() -> void:
	var w := _stats_x() + STATS_W + PAD
	var h := _fold_y() + 14 + PAD
	if spells_shown:
		var n := hud.world.character.book_slot_count()
		h = _book_origin().y + maxi(1, ceili(n / float(BOOK_ROW))) * STEP - Hud.GAP + PAD
	size = Vector2(maxf(w, PAD * 2 + BOOK_ROW * STEP - Hud.GAP), h)


func hit(local: Vector2) -> Array:
	for i in CharacterData.ALL_SLOTS.size():
		if slot_rect(i).has_point(local):
			return [Part.SLOT, i]
	if index_button_rect().has_point(local):
		return [Part.INDEX, 0]
	if fold_rect().has_point(local):
		return [Part.FOLD, 0]
	if spells_shown:
		for i in hud.world.character.book_slot_count():
			if book_rect(i).has_point(local):
				return [Part.BOOK, i]
	return [Part.NONE, -1]


# --- drawing -----------------------------------------------------------------------------

func title_right() -> String:
	return "Defense %d" % hud.world.player.defense


func draw_body(font: Font) -> void:
	var c := hud.world.character
	var h := hit(get_local_mouse_position()) if hovered() else [Part.NONE, -1]
	# Character box (the preview is a child drawn on top).
	UiSkin.slot(self, doll_rect(), UiSkin.SlotLook.NORMAL)
	# Equipment slots.
	for i in CharacterData.ALL_SLOTS.size():
		var r := slot_rect(i)
		var slot_id := CharacterData.ALL_SLOTS[i]
		var magic := slot_id in [CharacterData.SLOT_BOOK, CharacterData.SLOT_CONDUIT]
		var hot: bool = h[0] == Part.SLOT and h[1] == i
		UiSkin.slot(self, r, UiSkin.SlotLook.HOT if hot else (UiSkin.SlotLook.MAGIC if magic else UiSkin.SlotLook.NORMAL))
		var id: StringName = c.equipment[slot_id]
		var item := ItemData.find(id) if id != &"" else null
		if item:
			hud._draw_item(self, font, r, item, 1)
		elif slot_id == CharacterData.SLOT_BOOK and c.book() and c.book().icon:
			draw_texture_rect(c.book().icon, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false, Color(1, 1, 1, 0.4))
		else:
			var label: String = Hud.EQUIP_LABELS[i]
			var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
			draw_string(font, r.position + Vector2((SLOT - lw) * 0.5, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5,
				Color(UiSkin.DIM, 0.55))
	# Stats.
	var at := Vector2(_stats_x(), BODY_TOP + 7)
	draw_string(font, at, "Stats", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	var lines := stat_lines()
	for i in lines.size():
		draw_string(font, at + Vector2(0, 10 + i * 9), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.TEXT)
	# Equipped spells header: a fold arrow and the Spell Index button.
	var fr := fold_rect()
	var tip := fr.position + Vector2(3, 6)
	var arrow := PackedVector2Array([tip + Vector2(-3, -2), tip + Vector2(3, -2), tip + Vector2(0, 2)]) if spells_shown \
		else PackedVector2Array([tip + Vector2(-2, -3), tip + Vector2(2, 0), tip + Vector2(-2, 3)])
	var fold_hot: bool = h[0] == Part.FOLD
	draw_colored_polygon(arrow, UiSkin.TEXT if fold_hot else UiSkin.GOLD)
	draw_string(font, fr.position + Vector2(10, 9), "Equipped spells", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		UiSkin.TEXT if fold_hot else UiSkin.GOLD)
	var spells_open := hud.spells_open
	UiSkin.button(self, index_button_rect(), "Spell Index (L)",
		UiSkin.Btn.PRESSED if spells_open else (UiSkin.Btn.HOT if h[0] == Part.INDEX else UiSkin.Btn.NORMAL))
	if not spells_shown:
		return
	var book := c.book()
	var book_line := "%s, %d slots" % [book.display_name if book else "Spellbook", c.book_slot_count()]
	draw_string(font, Vector2(PAD, _fold_y() + 22), book_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	var loadout := c.book_loadout()
	for i in loadout.size():
		var r := book_rect(i)
		var hot: bool = h[0] == Part.BOOK and h[1] == i
		UiSkin.slot(self, r, UiSkin.SlotLook.HOT if hot else UiSkin.SlotLook.MAGIC)
		var spell := ItemData.find(ItemData.spell_key(loadout[i])) if loadout[i] != &"" else null
		if spell:
			hud._draw_item(self, font, r, spell, 1)


## Your defense and every non-zero stat bonus from equipment, one per line.
func stat_lines() -> Array[String]:
	var p := hud.world.player
	var lines: Array[String] = ["Defense %d" % p.defense]
	var names := {&"max_health": "Max health", &"max_mana": "Max mana", &"mana_regen": "Mana regen",
		&"move_speed": "Speed", &"jump": "Jump", &"melee_damage": "Melee damage",
		&"magic_damage": "Magic damage", &"mining_speed": "Mining speed"}
	for k: StringName in CharacterData.STATS:
		var v := p.stat(k)
		if v == 0.0:
			continue
		if k in [&"max_health", &"max_mana", &"mana_regen"]:
			lines.append("%s %+d" % [names[k], roundi(v)])
		else:
			lines.append("%s %+d%%" % [names[k], roundi(v * 100.0)])
	return lines


# --- input -------------------------------------------------------------------------------

func body_click(mb: InputEventMouseButton) -> void:
	var h := hit(mb.position)
	var left := mb.button_index == MOUSE_BUTTON_LEFT
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	match h[0]:
		Part.SLOT:
			var slot_id: StringName = CharacterData.ALL_SLOTS[h[1]]
			if (right and mb.ctrl_pressed) or (left and mb.shift_pressed):
				hud.quick_unequip(slot_id)
			elif left:
				hud.click_equipment(slot_id)
		Part.BOOK:
			if left:
				hud.click_book_slot(h[1])
			elif right:
				hud.world.character.put_in_book(h[1], &"")
		Part.FOLD:
			if left:
				spells_shown = not spells_shown
				layout()
				keep_on_screen()
		Part.INDEX:
			if left:
				hud.toggle_spells()


func tooltip_at(local: Vector2) -> Array:
	var c := hud.world.character
	var h := hit(local)
	match h[0]:
		Part.SLOT:
			var slot_id: StringName = CharacterData.ALL_SLOTS[h[1]]
			var id: StringName = c.equipment[slot_id]
			var item := ItemData.find(id) if id != &"" else (c.book() if slot_id == CharacterData.SLOT_BOOK else null)
			return [item, "" if item else Hud.EQUIP_NAMES[h[1]]]
		Part.BOOK:
			var s: StringName = c.book_loadout()[h[1]]
			return [ItemData.find(ItemData.spell_key(s)) if s != &"" else null, ""]
	return [null, ""]
