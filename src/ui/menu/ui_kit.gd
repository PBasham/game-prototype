class_name UiKit
extends RefCounted
## Small helpers so every menu looks the same. The look itself is UiSkin (its Theme is
## set on the root window by the Game autoload).

const TEXT := UiSkin.TEXT
const DIM := UiSkin.DIM
const GOLD := UiSkin.GOLD


static func label(text: String, size: int = 10, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, on_press: Callable, width: float = 140.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 20)
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(on_press)
	return b


## A centered dark panel with a vertical box inside; returns the box.
static func panel(parent: Node, min_width: float = 180.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UiSkin.theme()
	parent.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.box("panel", 12.0))
	p.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	p.add_child(box)
	return box


static func line_edit(placeholder: String, text: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(140, 18)
	e.add_theme_font_size_override("font_size", 10)
	return e


## A label on the left, a control on the right.
static func row(caption: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(caption, 10, DIM)
	l.custom_minimum_size = Vector2(44, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h
