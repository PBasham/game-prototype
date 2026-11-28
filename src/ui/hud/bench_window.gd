class_name BenchWindow
extends HudWindow
## The Alchemist's Bench window (Phase 67): a tabletop with a mortar, a mixing bowl and a
## bottle stand, your ingredients on the right. Drag an ingredient onto a piece (Shift:
## all of it) or right click it to put it where it fits; right click something on the
## table to take one back. The pieces that take what you're dragging light up, the brew
## in the bowl takes the colors of what's in it, and the card under the bowl shows what
## Mix will make. The rules are AlchemyBench.

const W := 344
const H := 212
const TABLE := Rect2(Hud.PAD, BODY_TOP + 2, 226, H - BODY_TOP - Hud.PAD - 2)
const LIST := Rect2(Hud.PAD + 230, BODY_TOP + 2, W - Hud.PAD * 2 - 230, H - BODY_TOP - Hud.PAD - 2)
const ROW := 18
## The pieces (window coordinates): where their art sits and where drops land.
const MORTAR := Rect2(12, 50, 48, 38)
const BOWL := Rect2(66, 44, 94, 46)
const STAND := Rect2(178, 40, 36, 46)
const GRIND_BTN := Rect2(14, 104, 44, 13)
## The bottom: what Mix makes, the Mix button, a hint line.
const RESULT := Rect2(66, 128, 26, 26)
const MIX_BTN := Rect2(172, 130, 48, 22)
const BOOK_BTN := Rect2(LIST.position.x + 4, LIST.end.y - 17, LIST.size.x - 8, 13)
const HINT_Y := 176.0
const ART := {"table": preload("res://assets/ui/bench_table.png"),
	"mortar": preload("res://assets/ui/bench_mortar.png"),
	"bowl": preload("res://assets/ui/bench_bowl.png"),
	"stand": preload("res://assets/ui/bench_stand.png")}
## The bowl's hollow (where the brew shows), in window coordinates.
const BREW := Rect2(BOWL.position.x + 6, BOWL.position.y + 4, BOWL.size.x - 12, 16)
const EMPTY_BREW := Color(0.15, 0.18, 0.22)
## The anchor of a bench opened with no bench there (dev console `station alchemists_bench`).
const VIRTUAL := Vector2i(-1000000, -1000000)

## The open bench's anchor tile, or World.NO_TILE.
var anchor := World.NO_TILE
var virtual: bool:
	get:
		return anchor == VIRTUAL
var bench := AlchemyBench.new()
var book_open := false
## The line under the table: a tip, or what just happened.
var note := ""
var _scroll := 0
var _book_scroll := 0
## What's being dragged: {"from": "list"/"bowl"/"mortar"/"vial", "id", "count",
## "ground", "spot"}, or empty.
var _drag: Dictionary = {}
var _grind_anim := 0.0
var _mix_anim := 0.0
## Item id -> its icon's average color (the brew's tint).
var _tints: Dictionary[StringName, Color] = {}


func _init(owner_hud: Hud) -> void:
	super(owner_hud, "Alchemist's Bench")


func layout() -> void:
	size = Vector2(W, H)


func _inv() -> Inventory:
	return hud.world.character.inventory


## Opens on a bench: an empty table.
func open_on(tile: Vector2i) -> void:
	if anchor != tile:
		bench.clear()
		book_open = false
		note = ""
	anchor = tile


## Where bowl spot i's ingredient floats in the brew.
func bowl_slot(i: int) -> Rect2:
	return Rect2(BREW.position.x + 10 + i * 26, BREW.position.y - 3, 20, 20)


func _mortar_slot() -> Rect2:
	return Rect2(MORTAR.position.x + 12, MORTAR.position.y + 2, 18, 18)


func _vial_slot() -> Rect2:
	return Rect2(STAND.position.x + 6, STAND.position.y - 6, 24, 24)


# --- drawing ------------------------------------------------------------------------------

func draw_body(font: Font) -> void:
	var m := get_local_mouse_position()
	draw_texture_rect(ART["table"], TABLE, false)
	if book_open:
		_draw_book(font)
	else:
		_draw_table(font, m)
	_draw_list(font, m)
	UiSkin.button(self, BOOK_BTN, "Close recipes" if book_open else "Recipes", _btn(BOOK_BTN, m, true))
	if not _drag.is_empty():
		var it := ItemData.find(_drag["id"])
		if it and it.icon:
			draw_texture_rect(it.icon, Rect2(m - Vector2(8, 8), Vector2(16, 16)), false)


func _draw_table(font: Font, m: Vector2) -> void:
	var dragged: StringName = _drag.get("id", &"")
	# Glow behind the pieces that take what's being dragged.
	for piece: Rect2 in [MORTAR, BOWL, STAND]:
		if dragged != &"" and _takes(piece, dragged):
			var hot := piece.grow(3).has_point(m)
			_glow(piece.grow(2), UiSkin.GOLD if hot else Color(UiSkin.GOLD, 0.45))
	# The mortar, shaking while it grinds.
	var shake := Vector2(sin(_grind_anim * 40.0) * 1.5, 0) if _grind_anim > 0.0 else Vector2.ZERO
	_art("mortar", MORTAR, shake)
	if not bench.mortar.is_empty():
		_icon_in(font, _mortar_slot().position + shake, bench.mortar, 14)
	UiSkin.button(self, GRIND_BTN, "Grind", _btn(GRIND_BTN, m, not bench.mortar.is_empty() and not bool(bench.mortar["ground"])))
	# The bowl and the brew in it.
	_art("bowl", BOWL, Vector2.ZERO)
	var brew := _brew_color()
	if _mix_anim > 0.0:
		brew = brew.lerp(Color.WHITE, _mix_anim * 0.6)
	draw_set_transform(BREW.get_center(), 0.0, Vector2(1.0, BREW.size.y / BREW.size.x))
	draw_circle(Vector2.ZERO, BREW.size.x * 0.5, brew)
	draw_circle(Vector2(-BREW.size.x * 0.18, -BREW.size.x * 0.1), BREW.size.x * 0.14, brew.lightened(0.18))
	draw_set_transform(Vector2.ZERO)
	for i in AlchemyBench.BOWL_SPOTS:
		if not bench.bowl[i].is_empty():
			var bob := Vector2(0, sin(Time.get_ticks_msec() * 0.003 + i * 2.0))
			_icon_in(font, bowl_slot(i).position + bob, bench.bowl[i], 16)
	_caption(font, Vector2(BOWL.get_center().x, BOWL.end.y + 2), "Mix up to 3 ingredients")
	# The bottle on its stand (a faint outline when there's none).
	_art("stand", STAND, Vector2.ZERO)
	var vr := _vial_slot()
	if bench.vial != &"":
		var it := ItemData.find(bench.vial)
		if it and it.icon:
			draw_texture_rect(it.icon, vr, false)
	else:
		draw_rect(vr.grow(-3), Color(1, 1, 1, 0.08))
		draw_rect(vr.grow(-3), Color(UiSkin.DIM, 0.5), false, 1.0)
		_centered(font, vr.get_center() + Vector2(0, 3), "+", 9, UiSkin.DIM)
	_caption(font, Vector2(STAND.get_center().x, STAND.end.y + 2), "Bottle")
	# Arrows: mortar -> bowl -> bottle.
	_arrow(Vector2(MORTAR.end.x + 1, BOWL.position.y + 14))
	_arrow(Vector2(BOWL.end.x + 4, BOWL.position.y + 14))
	_draw_result(font, m)


## The card at the bottom: what Mix makes, and the Mix button.
func _draw_result(font: Font, m: Vector2) -> void:
	var card := Rect2(TABLE.position.x + 8, RESULT.position.y - 4, TABLE.size.x - 16, RESULT.size.y + 8)
	draw_rect(card, Color(0.08, 0.05, 0.03, 0.55))
	draw_rect(card, Color(UiSkin.GOLD, 0.35), false, 1.0)
	var r := Rect2(card.position + Vector2(6, 4), RESULT.size)
	UiSkin.slot(self, r)
	var out := bench.preview(hud.world.character)
	var title := ""
	var sub := ""
	if out == &"":
		title = "Nothing to mix yet"
		sub = bench.mix_problem() + "."
	elif out == &"?":
		_centered(font, r.get_center() + Vector2(0, 4), "?", 12, UiSkin.GOLD)
		title = "Unknown mix"
		sub = "It may work, or go murky."
	else:
		var it := ItemData.find(out)
		if it and it.icon:
			draw_texture_rect(it.icon, Rect2(r.position + Vector2(5, 5), Vector2(16, 16)), false)
		title = it.display_name if it else String(out)
		sub = "Ready to mix."
	var text_w := MIX_BTN.position.x - r.position.x - 36
	draw_string(font, r.position + Vector2(32, 10), title, HORIZONTAL_ALIGNMENT_LEFT, text_w, 8, UiSkin.TEXT)
	draw_string(font, r.position + Vector2(32, 21), sub, HORIZONTAL_ALIGNMENT_LEFT, text_w, 6, UiSkin.DIM)
	UiSkin.button(self, MIX_BTN, "Mix", _btn(MIX_BTN, m, out != &""))
	var hint := note if note != "" else "Drag ingredients onto the table. Right click one to add it, right click the table to take it back."
	draw_multiline_string(font, Vector2(TABLE.position.x + 8, HINT_Y), hint, HORIZONTAL_ALIGNMENT_LEFT,
		TABLE.size.x - 16, 6, 2, Color(UiSkin.TEXT, 0.85))


func _btn(r: Rect2, m: Vector2, enabled: bool) -> UiSkin.Btn:
	if not enabled:
		return UiSkin.Btn.DISABLED
	return UiSkin.Btn.HOT if r.has_point(m) else UiSkin.Btn.NORMAL


## A piece's art (2 art pixels per HUD pixel), at the bottom middle of `r`.
func _art(key: String, r: Rect2, off: Vector2) -> void:
	var tex: Texture2D = ART[key]
	var s := tex.get_size() * 0.5
	draw_texture_rect(tex, Rect2(r.position + Vector2((r.size.x - s.x) * 0.5, r.size.y - s.y) + off, s), false)


func _glow(r: Rect2, c: Color) -> void:
	draw_rect(r, Color(c, c.a * 0.18))
	draw_rect(r, c, false, 1.0)


func _caption(font: Font, top_middle: Vector2, text: String) -> void:
	_centered(font, top_middle + Vector2(0, 7), text, 6, Color(UiSkin.TEXT, 0.7))


func _centered(font: Font, at: Vector2, text: String, size_: int, c: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_).x
	draw_string(font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, c)


func _arrow(at: Vector2) -> void:
	var c := Color(UiSkin.GOLD, 0.6)
	draw_line(at, at + Vector2(4, 3), c, 1.0)
	draw_line(at + Vector2(4, 3), at + Vector2(0, 6), c, 1.0)


## An ingredient on the table: its icon, how many, and a gold speck when it's ground.
func _icon_in(font: Font, at: Vector2, s: Dictionary, px: int) -> void:
	var it := ItemData.find(s["id"])
	if it and it.icon:
		draw_texture_rect(it.icon, Rect2(at, Vector2(px, px)), false)
	var n := int(s["count"])
	if n > 1:
		var text := str(n)
		draw_string(font, at + Vector2(px - 3, px + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0, 0, 0, 0.8))
		draw_string(font, at + Vector2(px - 4, px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.TEXT)
	if bool(s.get("ground", false)):
		draw_rect(Rect2(at + Vector2(-1, -1), Vector2(3, 3)), UiSkin.GOLD)


## The brew: the colors of what's in the bowl, mixed by how much.
func _brew_color() -> Color:
	var total := 0
	var c := Color(0, 0, 0)
	for s in bench.bowl:
		if s.is_empty():
			continue
		var n := int(s["count"])
		var t := _tint(s["id"])
		c += Color(t.r * n, t.g * n, t.b * n)
		total += n
	if total == 0:
		return EMPTY_BREW
	c = Color(c.r / total, c.g / total, c.b / total)
	return EMPTY_BREW.lerp(c, 0.75)


func _tint(id: StringName) -> Color:
	if _tints.has(id):
		return _tints[id]
	var c := Color(0.5, 0.5, 0.5)
	var it := ItemData.find(id)
	if it and it.icon:
		var img := it.icon.get_image()
		var sum := Color(0, 0, 0)
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.5:
					sum += Color(p.r, p.g, p.b)
					n += 1
		if n > 0:
			c = Color(sum.r / n, sum.g / n, sum.b / n)
	_tints[id] = c
	return c


func _draw_list(font: Font, m: Vector2) -> void:
	draw_rect(LIST, Color(0.08, 0.05, 0.03, 0.85))
	draw_rect(LIST, Color(UiSkin.GOLD, 0.35), false, 1.0)
	draw_string(font, LIST.position + Vector2(6, 11), "Ingredients", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiSkin.GOLD)
	var items := AlchemyBench.shelf(_inv())
	var top := LIST.position.y + 16
	var shown := _rows_shown()
	_scroll = clampi(_scroll, 0, maxi(items.size() - shown, 0))
	for i in range(_scroll, mini(items.size(), _scroll + shown)):
		var r := Rect2(LIST.position.x + 3, top + (i - _scroll) * ROW, LIST.size.x - 6, ROW - 2)
		var id := items[i]
		var it := ItemData.find(id)
		var left := bench.available(_inv(), id)
		draw_rect(r, Color(1, 1, 1, 0.1 if r.has_point(m) and left > 0 else 0.04))
		if it and it.icon:
			draw_texture_rect(it.icon, Rect2(r.position + Vector2(1, 0), Vector2(16, 16)), false,
				Color(1, 1, 1, 1.0 if left > 0 else 0.35))
		draw_string(font, r.position + Vector2(19, 10), it.display_name if it else String(id), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 38, 6, UiSkin.TEXT if left > 0 else UiSkin.DIM)
		var n := str(left)
		var w := font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		var pill := Rect2(r.end.x - w - 7, r.position.y + 4, w + 5, 9)
		draw_rect(pill, Color(0, 0, 0, 0.45))
		draw_string(font, pill.position + Vector2(2.5, 7), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiSkin.GOLD if left > 0 else UiSkin.DIM)
	if items.size() > shown:
		var track := Rect2(LIST.end.x - 3, top, 2, shown * ROW)
		draw_rect(Rect2(track.position + Vector2(0, track.size.y * _scroll / items.size()),
			Vector2(2, track.size.y * shown / items.size())), Color(UiSkin.GOLD, 0.6))
	if items.is_empty():
		draw_multiline_string(font, LIST.position + Vector2(6, 26), "Bottles and alchemy ingredients you carry show up here.",
			HORIZONTAL_ALIGNMENT_LEFT, LIST.size.x - 12, 6, 2, UiSkin.DIM)


func _rows_shown() -> int:
	return int((BOOK_BTN.position.y - LIST.position.y - 18) / ROW)


## The recipe book: every recipe you know, on parchment over the table.
func _draw_book(font: Font) -> void:
	var page := TABLE.grow(-6)
	draw_rect(page, Color("eadfbf"))
	draw_rect(page.grow(-2), Color("8a5c34"), false, 1.0)
	draw_string(font, page.position + Vector2(8, 13), "Recipes you know", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiSkin.INK)
	var lines := book_lines()
	var per := int((page.size.y - 24) / 10.0)
	_book_scroll = clampi(_book_scroll, 0, maxi(lines.size() - per, 0))
	for i in range(_book_scroll, mini(lines.size(), _book_scroll + per)):
		draw_string(font, page.position + Vector2(8, 25 + (i - _book_scroll) * 10), lines[i], HORIZONTAL_ALIGNMENT_LEFT,
			page.size.x - 16, 6, UiSkin.INK)


## One line per known recipe: "Mana Potion: Clay Flask + 2 ground Glowcap".
func book_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var c := hud.world.character
	for r in AlchemyBench.recipes():
		if AlchemyBench.knows(c, r):
			out.append(_recipe_line(r))
	return out


static func _recipe_line(r: RecipeData) -> String:
	var parts := PackedStringArray()
	var bottle := ""
	for id: StringName in r.inputs:
		var it := ItemData.find(id)
		var name := it.display_name if it else String(id)
		if AlchemyBench.is_vessel(id):
			bottle = name
			continue
		var n: int = r.inputs[id]
		var what := ("ground " if id in r.bench_ground else "") + name
		parts.append("%d %s" % [n, what] if n > 1 else what)
	var out := ItemData.find(r.output)
	return "%s: %s + %s" % [out.display_name if out else String(r.output), bottle, " + ".join(parts)]


# --- input --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_grind_anim = maxf(_grind_anim - delta, 0.0)
	_mix_anim = maxf(_mix_anim - delta * 2.0, 0.0)
	queue_redraw()  # the brew bobs


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _drag.is_empty():
		drop(mb.position, Input.is_key_pressed(KEY_SHIFT))
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var d := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		if book_open and TABLE.has_point(mb.position):
			_book_scroll += d
		else:
			_scroll += d
		accept_event()
		return
	super(event)


func body_click(mb: InputEventMouseButton) -> void:
	var p := mb.position
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if BOOK_BTN.has_point(p):
			book_open = not book_open
		elif book_open and TABLE.has_point(p):
			return
		elif GRIND_BTN.has_point(p):
			do_grind()
		elif MIX_BTN.has_point(p):
			do_mix()
		else:
			_start_drag(p)
	elif mb.button_index == MOUSE_BUTTON_RIGHT and not book_open:
		_right_click(p)


## True when the piece `piece` takes `id` (mortar and bowl: ingredients; stand: bottles).
func _takes(piece: Rect2, id: StringName) -> bool:
	if piece == STAND:
		return AlchemyBench.is_vessel(id)
	return AlchemyBench.is_ingredient(id)


## The list row under `p`, or &"".
func list_item_at(p: Vector2) -> StringName:
	var top := LIST.position.y + 16
	if not LIST.has_point(p) or p.y < top:
		return &""
	var i := int((p.y - top) / ROW) + _scroll
	var items := AlchemyBench.shelf(_inv())
	return items[i] if i >= 0 and i < items.size() and i < _scroll + _rows_shown() else &""


func _start_drag(p: Vector2) -> void:
	var id := list_item_at(p)
	if id != &"":
		if bench.available(_inv(), id) > 0:
			_drag = {"from": "list", "id": id}
		return
	for i in AlchemyBench.BOWL_SPOTS:
		if bowl_slot(i).grow(2).has_point(p) and not bench.bowl[i].is_empty():
			_drag = bench.bowl[i].duplicate()
			_drag["from"] = "bowl"
			_drag["spot"] = i
			bench.bowl[i] = {}
			return
	if MORTAR.has_point(p) and not bench.mortar.is_empty():
		_drag = {"from": "mortar", "id": bench.mortar["id"]}
	elif STAND.grow(4).has_point(p) and bench.vial != &"":
		_drag = {"from": "vial", "id": bench.vial}


## Lets go of what's dragged at `p` (Shift: everything you have of it, from the list).
func drop(p: Vector2, all: bool = false) -> void:
	var d := _drag
	_drag = {}
	var from: String = d["from"]
	var id: StringName = d["id"]
	var spot := -1
	for i in AlchemyBench.BOWL_SPOTS:
		if bowl_slot(i).grow(3).has_point(p):
			spot = i
	if from == "bowl":
		# Dropped back in the bowl: into that spot (or its own); anywhere else, back to you.
		if spot < 0 and BOWL.grow(3).has_point(p):
			spot = int(d["spot"])
		if spot >= 0:
			var there := bench.bowl[spot]
			if there.is_empty():
				bench.bowl[spot] = {"id": id, "count": d["count"], "ground": d["ground"]}
			elif there["id"] == id and there["ground"] == d["ground"]:
				there["count"] = int(there["count"]) + int(d["count"])
			else:
				bench.bowl[int(d["spot"])] = {"id": id, "count": d["count"], "ground": d["ground"]}
		return
	if from == "mortar":
		if BOWL.grow(3).has_point(p):
			if not bench.mortar_to_bowl(spot):
				note = "The bowl has no room for that."
		elif not MORTAR.grow(3).has_point(p):
			bench.mortar = {}
		return
	if from == "vial":
		if not STAND.grow(4).has_point(p):
			bench.vial = &""
		return
	# From the list.
	var times := maxi(bench.available(_inv(), id), 1) if all else 1
	for t in times:
		if not place(id, p, spot):
			if t == 0 and TABLE.has_point(p):
				var it := ItemData.find(id)
				note = "%s goes %s." % [it.display_name if it else String(id),
					"on the bottle stand" if AlchemyBench.is_vessel(id) else "in the mortar or the bowl"]
			break


## Puts one `id` where `p` is on the table. False if it doesn't go there.
func place(id: StringName, p: Vector2, spot: int = -1) -> bool:
	var inv := _inv()
	if spot >= 0 or BOWL.grow(3).has_point(p):
		if spot < 0:
			spot = bench.bowl_spot_for(id)
		return bench.add_to_bowl(inv, spot, id)
	if MORTAR.grow(3).has_point(p):
		return bench.add_to_mortar(inv, id)
	if STAND.grow(4).has_point(p):
		return bench.set_vial(inv, id)
	return false


## Right click: a list item goes where it fits; something on the table comes off (one).
func _right_click(p: Vector2) -> void:
	var inv := _inv()
	var id := list_item_at(p)
	if id != &"":
		if AlchemyBench.is_vessel(id):
			bench.set_vial(inv, id)
		else:
			bench.add_to_bowl(inv, bench.bowl_spot_for(id), id)
		return
	for i in AlchemyBench.BOWL_SPOTS:
		if bowl_slot(i).grow(2).has_point(p):
			bench.take_from_bowl(i)
			return
	if MORTAR.has_point(p) and not bench.mortar.is_empty():
		bench.mortar["count"] = int(bench.mortar["count"]) - 1
		if int(bench.mortar["count"]) <= 0:
			bench.mortar = {}
	elif STAND.grow(4).has_point(p):
		bench.vial = &""


func do_grind() -> void:
	if bench.grind():
		_grind_anim = 0.4
		note = "Ground %s. Drag it into the bowl." % ItemData.find(bench.mortar["id"]).display_name
		EventBus.sound_requested.emit(&"mine_hit", Vector2.INF)


func do_mix() -> void:
	var problem := bench.mix_problem()
	if problem != "":
		note = problem + "."
		return
	var r := bench.mix(_inv(), hud.world.character)
	if int(r.get("left", 0)) > 0:
		hud.world.request_spawn_drop(r["item"], int(r["left"]), hud.world.player.chest(), Vector2.ZERO, true)
	_mix_anim = 1.0
	var it := ItemData.find(r["item"])
	if r["recipe"] == null:
		note = "It went murky. That mix wasn't a recipe (some ingredients need grinding first)."
		EventBus.sound_requested.emit(&"splash", Vector2.INF)
	elif r["new"]:
		note = "New recipe: %s! It's in your recipes now." % it.display_name
		hud.show_new_recipe(it.display_name)
		EventBus.sound_requested.emit(&"learn_spell", Vector2.INF)
	else:
		note = "Made %s." % it.display_name
		EventBus.sound_requested.emit(&"craft", Vector2.INF)
	EventBus.item_picked_up.emit(r["item"], int(r["count"]))


func tooltip_at(local: Vector2) -> Array:
	if book_open:
		return [null, ""]
	var id := list_item_at(local)
	if id != &"":
		return [ItemData.find(id), ""]
	for i in AlchemyBench.BOWL_SPOTS:
		if bowl_slot(i).has_point(local) and not bench.bowl[i].is_empty():
			var s := bench.bowl[i]
			var name := ItemData.find(s["id"]).display_name
			return [null, ("Ground " + name if bool(s["ground"]) else name) + " x%d (right click: take one back)" % int(s["count"])]
	if STAND.grow(4).has_point(local):
		if bench.vial != &"":
			return [ItemData.find(bench.vial), ""]
		return [null, "Bottle: an empty bottle (or a bottle of water) for the potion"]
	if MORTAR.has_point(local):
		if bench.mortar.is_empty():
			return [null, "Mortar: drop an ingredient in, press Grind, then drag it to the bowl"]
		var name := ItemData.find(bench.mortar["id"]).display_name
		return [null, ("Ground " if bool(bench.mortar["ground"]) else "") + name + " x%d" % int(bench.mortar["count"])]
	return [null, ""]
