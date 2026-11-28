class_name UiSkin
extends RefCounted
## The look of every window, slot and button. Phase 91: "dark arcane", deep navy panels
## with gold trim, blue glows and gem corners, at DETAIL art pixels per UI pixel
## (placeholder art from tools/make_ui_art_hd.py in assets/ui/; the old 1x art was
## tools/make_ui_art.gd). Replace any file with real art of the same size (or change its
## margins below, in art pixels).
##
## Two ways to use it: the HUD draws with panel() / slot() / button() / title() on a
## CanvasItem; menus built from Controls use theme().

const DIR := "res://assets/ui/"
const TEXT := Color("eef2fa")
const DIM := Color("93a0bd")
## Text on title strips.
const INK := Color("f2dc9a")
## Dark text on parchment (the Alchemist's Bench recipe book).
const PARCHMENT_INK := Color("3a2618")
const GOLD := Color("f0cf6c")
const BAD := Color("ff8a7a")
const GOOD := Color("9ad48a")
## Art pixels per UI pixel (the art is drawn at this scale for detail).
const DETAIL := 3

## file -> nine-slice margin (art px from each edge).
const MARGINS := {
	"panel": 24, "title": 18, "slot": 12, "slot_hot": 12, "slot_selected": 12, "slot_magic": 12,
	"button": 15, "button_hot": 15, "button_pressed": 15, "button_disabled": 15,
	"row_hot": 9, "field": 12,
}

static var _boxes: Dictionary[String, StyleBox] = {}
static var _theme: Theme


## A nine-slice style box for an assets/ui file ("panel", "slot", ...).
static func box(file_name: String, content_margin: float = -1.0) -> StyleBox:
	var key := "%s:%s" % [file_name, content_margin]
	if _boxes.has(key):
		return _boxes[key]
	var sb := UiNineSlice.new()
	sb.texture = load(DIR + file_name + ".png") as Texture2D
	var m: int = MARGINS.get(file_name, 12)
	sb.margin = m
	sb.detail = DETAIL
	var cm := float(m) / DETAIL if content_margin < 0.0 else content_margin
	sb.content_margin_left = cm
	sb.content_margin_top = cm
	sb.content_margin_right = cm
	sb.content_margin_bottom = cm
	_boxes[key] = sb
	return sb


static func panel(ci: CanvasItem, r: Rect2) -> void:
	box("panel").draw(ci.get_canvas_item(), r)


## A parchment title strip with ink text (left aligned; `right_text` right aligned).
static func title(ci: CanvasItem, r: Rect2, text: String, right_text: String = "") -> void:
	box("title").draw(ci.get_canvas_item(), r)
	var font := ThemeDB.fallback_font
	ci.draw_string(font, r.position + Vector2(5, r.size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 8, INK)
	if right_text != "":
		var w := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		ci.draw_string(font, Vector2(r.end.x - w - 5, r.end.y - 4), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
			Color(INK, 0.75))


enum SlotLook { NORMAL, HOT, SELECTED, MAGIC }


static func slot(ci: CanvasItem, r: Rect2, kind: SlotLook = SlotLook.NORMAL) -> void:
	var file_name: String = ["slot", "slot_hot", "slot_selected", "slot_magic"][kind]
	box(file_name).draw(ci.get_canvas_item(), r)


enum Btn { NORMAL, HOT, PRESSED, DISABLED }


## A drawn button with centered text.
static func button(ci: CanvasItem, r: Rect2, text: String, state: Btn = Btn.NORMAL) -> void:
	var file_name: String = ["button", "button_hot", "button_pressed", "button_disabled"][state]
	box(file_name).draw(ci.get_canvas_item(), r)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var color := TEXT if state != Btn.DISABLED else Color(DIM, 0.6)
	ci.draw_string(font, Vector2(r.get_center().x - w * 0.5, r.position.y + r.size.y * 0.5 + 3), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)


static func row_highlight(ci: CanvasItem, r: Rect2) -> void:
	box("row_hot").draw(ci.get_canvas_item(), r)


## A Godot Theme with the same look, for menus built from Controls.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 10
	t.set_stylebox("panel", "PanelContainer", box("panel", 10.0))
	t.set_stylebox("panel", "Panel", box("panel", 10.0))
	for type: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box("button", 4.0))
		t.set_stylebox("hover", type, box("button_hot", 4.0))
		t.set_stylebox("pressed", type, box("button_pressed", 4.0))
		t.set_stylebox("disabled", type, box("button_disabled", 4.0))
		t.set_stylebox("focus", type, _focus())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, Color(DIM, 0.6))
	t.set_stylebox("normal", "LineEdit", box("field", 4.0))
	t.set_stylebox("focus", "LineEdit", _focus())
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(DIM, 0.6))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PopupMenu", box("panel", 6.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", box("row_hot", 2.0))
	t.set_stylebox("slider", "HSlider", box("field", 2.0))
	t.set_stylebox("grabber_area", "HSlider", box("button", 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box("button_hot", 2.0))
	var tip := box("panel", 5.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t


static func _focus() -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.set_border_width_all(1)
	f.border_color = Color(GOLD, 0.7)
	return f
