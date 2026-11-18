class_name HudWindow
extends Control
## A movable HUD window: a UiSkin panel with a title bar and a close button. Drag the
## title bar to move it. It opens where `show_at` says the first time, then keeps the
## spot you dragged it to until you quit. Subclasses draw the body and handle its clicks.

## Height of the title bar area; the body starts below it.
const BODY_TOP := 22

signal close_pressed

var hud: Hud
var title := ""
## Has been shown (and so has a position).
var placed := false
## Has been dragged by the player (other windows then leave its spot alone).
var moved := false
var _dragging := false
var _grab := Vector2.ZERO


func _init(owner_hud: Hud, window_title: String) -> void:
	hud = owner_hud
	title = window_title
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Sizes the window (subclasses override `layout`), places it at `default_pos` the first
## time, and keeps its title bar on screen.
func show_at(default_pos: Vector2) -> void:
	layout()
	if not placed:
		position = default_pos.floor()
		placed = true
	keep_on_screen()
	visible = true


func keep_on_screen() -> void:
	var view := hud._view_size()
	position = Vector2(clampf(position.x, 0.0, maxf(0.0, view.x - size.x)),
		clampf(position.y, 0.0, maxf(0.0, view.y - BODY_TOP)))


## The middle of the screen for a window of this size.
func centered() -> Vector2:
	layout()
	return (hud._view_size() - size) * 0.5


func close_rect() -> Rect2:
	return Rect2(size.x - 19, 6, 12, 10)


func title_rect() -> Rect2:
	return Rect2(0, 0, size.x, BODY_TOP - 2)


func hovered() -> bool:
	return hud._over_pane() == self


# --- for subclasses ----------------------------------------------------------------------

func layout() -> void:
	pass


func title_right() -> String:
	return ""


func draw_body(_font: Font) -> void:
	pass


## A mouse button pressed in the body (not the title bar or close button).
func body_click(_mb: InputEventMouseButton) -> void:
	pass


## [ItemData or null, text shown when there's no item] for the tooltip.
func tooltip_at(_local: Vector2) -> Array:
	return [null, ""]


# --- drawing and input -------------------------------------------------------------------

func _draw() -> void:
	var font := ThemeDB.fallback_font
	UiSkin.panel(self, Rect2(Vector2.ZERO, size))
	UiSkin.title(self, Rect2(4, 4, size.x - 24, Hud.TITLE_H), title, title_right())
	var hot := hovered() and close_rect().has_point(get_local_mouse_position())
	UiSkin.button(self, close_rect(), "x", UiSkin.Btn.HOT if hot else UiSkin.Btn.NORMAL)
	draw_body(font)
	hud._draw_cursor_stack(self)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		position += motion.position - _grab
		moved = true
		keep_on_screen()
		accept_event()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if not mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
		return
	accept_event()
	if mb.button_index == MOUSE_BUTTON_LEFT and close_rect().has_point(mb.position):
		_dragging = false
		close_pressed.emit()
	elif mb.button_index == MOUSE_BUTTON_LEFT and title_rect().has_point(mb.position):
		_dragging = true
		_grab = mb.position
	else:
		body_click(mb)
	hud._redraw()
