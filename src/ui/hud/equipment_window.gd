class_name EquipmentWindow
extends HudWindow
## The Equipment window (P): your character in the middle, armor on the left (head,
## chest, legs), trinkets on the right (three accessory slots), the Book and Conduit
## underneath, your stats on the far right. Below that, a section you can fold away:
## Quick spells (the Q and E wheels, the Z X C keys and the buff set cast by B), and the
## Spell Index (L) button.
##
## Click a slot with an item on the mouse to equip it; click an equipped item to pick it
## up; shift + click (or ctrl + right click) puts it back in the inventory. Quick slots:
## click a spell in the Spell Index, then a slot; click a filled slot to pick its spell
## up; right click empties it. The small corner of a filled slot flips it between
## "cast right away" (a gold bolt) and "put it in your hand" (no bolt).

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
## Room for a row's key label (Q, E) before its slots.
const LABEL_W := 12
## Slots in a row of the Quick spells section (a wheel is 8).
const QUICK_ROW := CharacterData.WHEEL_SIZE
## The corner of a quick slot that flips cast / in hand.
const MODE_SIZE := 7

enum Part { NONE, SLOT, QUICK, MODE, FOLD, INDEX, MOVE }

## Quick spells section shown (click its header to fold it away).
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


func _quick_origin() -> Vector2:
	return Vector2(PAD + LABEL_W, _fold_y() + 26)


## Where a quick slot is: Q wheel (row 1), E wheel (row 2), then Z X C and the buff set
## side by side (row 3).
func quick_rect(slot: StringName) -> Rect2:
	var o := _quick_origin()
	var text := String(slot)
	var col := 0
	var row := 0
	if CharacterData.is_buff_slot(slot):
		row = 2
		col = CharacterData.QUICK_KEYS.size() + int(text.get_slice("_", 1))
		return Rect2(o + Vector2(col * STEP + 14, row * STEP + 8), Vector2(SLOT, SLOT))
	if slot in CharacterData.QUICK_KEYS:
		row = 2
		col = CharacterData.QUICK_KEYS.find(slot)
		return Rect2(o + Vector2(col * STEP, row * STEP + 8), Vector2(SLOT, SLOT))
	row = CharacterData.WHEELS.find(StringName(text.get_slice("_", 0)))
	col = int(text.get_slice("_", 1))
	return Rect2(o + Vector2(col * STEP, row * STEP), Vector2(SLOT, SLOT))


## The Movement slot (row 4): the spell the movement key (F) turns on.
func move_rect() -> Rect2:
	return Rect2(_quick_origin() + Vector2(0, 3 * STEP + 16), Vector2(SLOT, SLOT))


## The corner of a quick slot that flips its mode.
func mode_rect(slot: StringName) -> Rect2:
	var r := quick_rect(slot)
	return Rect2(r.position + Vector2(r.size.x - MODE_SIZE, 0), Vector2(MODE_SIZE, MODE_SIZE))


func layout() -> void:
	var w := _stats_x() + STATS_W + PAD
	var h := _fold_y() + 14 + PAD
	var quick_w := PAD * 2 + LABEL_W + (CharacterData.QUICK_KEYS.size() + CharacterData.BUFF_SET_SIZE) * STEP + 14 - Hud.GAP
	if spells_shown:
		h = move_rect().end.y + PAD
	size = Vector2(maxf(w, quick_w), h)


func hit(local: Vector2) -> Array:
	for i in CharacterData.ALL_SLOTS.size():
		if slot_rect(i).has_point(local):
			return [Part.SLOT, i]
	if index_button_rect().has_point(local):
		return [Part.INDEX, 0]
	if fold_rect().has_point(local):
		return [Part.FOLD, 0]
	if spells_shown:
		var c := hud.world.character
		if move_rect().has_point(local):
			return [Part.MOVE, 0]
		for slot in CharacterData.all_quick_slots():
			if quick_rect(slot).has_point(local):
				if mode_rect(slot).has_point(local) and c.quick_spell(slot) != &"" \
						and not CharacterData.is_buff_slot(slot):
					return [Part.MODE, slot]
				return [Part.QUICK, slot]
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
	draw_string(font, fr.position + Vector2(10, 9), "Quick spells", HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
		UiSkin.TEXT if fold_hot else UiSkin.GOLD)
	var spells_open := hud.spells_open
	UiSkin.button(self, index_button_rect(), "Spell Index (L)",
		UiSkin.Btn.PRESSED if spells_open else (UiSkin.Btn.HOT if h[0] == Part.INDEX else UiSkin.Btn.NORMAL))
	if not spells_shown:
		return
	var book := c.book()
	var book_line := "%s: x%s power, up to tier %d.  Bolt = casts right away." % [
		book.display_name if book else "Spellbook", str(book.spell_power if book else 1.0), c.max_spell_tier()]
	draw_string(font, Vector2(PAD, _fold_y() + 22), book_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.DIM)
	var o := _quick_origin()
	draw_string(font, Vector2(PAD, o.y + 12), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	draw_string(font, Vector2(PAD, o.y + STEP + 12), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	for i in CharacterData.QUICK_KEYS.size():
		var k := CharacterData.QUICK_KEYS[i]
		var lbl := Hud.quick_key_label(k)
		var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(font, o + Vector2(i * STEP + (SLOT - lw) * 0.5, 2 * STEP + 6), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.GOLD)
	draw_string(font, o + Vector2(CharacterData.QUICK_KEYS.size() * STEP + 14, 2 * STEP + 6), "Buff set (B): casts them all", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 6, UiSkin.GOLD)
	# The Movement slot: empty shows the default (Fly, else Levitate) faded.
	var mr := move_rect()
	draw_string(font, mr.position + Vector2(0, -3), "Movement spell (F)", HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
		UiSkin.GOLD)
	UiSkin.slot(self, mr, UiSkin.SlotLook.HOT if h[0] == Part.MOVE else UiSkin.SlotLook.MAGIC)
	var move_id := hud.world.player.movement_spell_id()
	var move := ItemData.find(ItemData.spell_key(move_id)) if move_id != &"" else null
	if move:
		hud._draw_item(self, font, mr, move, 1, 1.0 if c.movement_spell == move_id else 0.4)
	for slot in CharacterData.all_quick_slots():
		var r := quick_rect(slot)
		var hot: bool = h[0] in [Part.QUICK, Part.MODE] and h[1] == slot
		var id := c.quick_spell(slot)
		var shortcut := ItemData.find(c.quick_item(slot)) if c.quick_item(slot) != &"" else null
		UiSkin.slot(self, r, UiSkin.SlotLook.HOT if hot else (UiSkin.SlotLook.NORMAL if shortcut else UiSkin.SlotLook.MAGIC))
		if shortcut:
			var n := c.inventory.count_of(shortcut.id)
			hud._draw_item(self, font, r, shortcut, n, 1.0 if n > 0 else 0.35)
			continue
		var spell := ItemData.find(ItemData.spell_key(id)) if id != &"" else null
		if spell == null:
			continue
		hud._draw_item(self, font, r, spell, 1)
		if CharacterData.is_buff_slot(slot):
			continue
		if c.quick_casts(slot):
			hud._draw_cast_mark(self, r)
		elif h[0] == Part.MODE and h[1] == slot:
			draw_rect(mode_rect(slot), Color(UiSkin.GOLD, 0.35))


## Your defense and every non-zero stat bonus from equipment, one per line.
func stat_lines() -> Array[String]:
	var p := hud.world.player
	var lines: Array[String] = ["Defense %d" % p.defense]
	for k: StringName in CharacterData.STATS:
		var v := p.stat(k)
		if v != 0.0:
			lines.append(Hud.stat_text(k, v))
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
		Part.QUICK:
			if left:
				hud.click_quick_slot(h[1])
			elif right:
				hud.world.character.set_quick(h[1], &"")
		Part.MODE:
			if left:
				hud.world.character.toggle_quick_mode(h[1])
		Part.MOVE:
			if left:
				hud.click_movement_slot()
			elif right:
				hud.world.character.set_movement_spell(&"")
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
		Part.MOVE:
			var id := hud.world.player.movement_spell_id()
			var spell := ItemData.find(ItemData.spell_key(id)) as SpellData if id != &"" else null
			var how := "Chosen here. Right click: back to the default." if c.movement_spell != &"" \
				else "Default (Fly, else Levitate). Click a movement spell from the Spell Index, then here."
			return [null, ("%s\n" % spell.display_name if spell else "No movement spell known.\n") + how]
		Part.QUICK, Part.MODE:
			var slot: StringName = h[1]
			var item_id := c.quick_item(slot)
			if item_id != &"":
				var it := ItemData.find(item_id)
				return [it, "%s: shortcut (you have %d). Food is used right away; anything else goes in your hand. Right click clears." % [
					Player.quick_label(slot), c.inventory.count_of(item_id)]]
			var s := c.quick_spell(slot)
			var spell := ItemData.find(ItemData.spell_key(s)) as SpellData if s != &"" else null
			if spell == null:
				return [null, "%s: empty. Click a spell in the Spell Index (L), then here.%s" % [Player.quick_label(slot).capitalize(),
					" Or any item from your inventory." if slot in CharacterData.QUICK_KEYS else ""]]
			var how := "Casts right away" if c.quick_casts(slot) else "Goes in your hand (left click casts)"
			if not CharacterData.is_buff_slot(slot):
				how += ". Click the top right corner to change."
			return [spell, how]
	return [null, ""]
