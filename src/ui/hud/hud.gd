class_name Hud
extends CanvasLayer
## The in-world HUD: the hotbar (top left), the inventory panel (E), the item held on
## the mouse, tooltips, and pickup notes. Placeholder look until real UI art exists.
##
## Inventory panel: 4 rows of 10, the top row is the hotbar.
##   Left click: pick up a stack / put it down / swap / merge.
##   Right click: pick up half, or put one down from the stack on the mouse.
##   Shift + left click: move a stack between the hotbar and the rest.
##   Click outside the panel with a stack on the mouse: throw it.

const SLOT := 20
const GAP := 2
const MARGIN := Vector2(6, 6)
const BG := Color(0.07, 0.08, 0.1, 0.78)
const BG_HOT := Color(0.12, 0.13, 0.16, 0.88)
const EDGE := Color(1, 1, 1, 0.12)
const SELECTED := Color("f2d27a")
const TEXT := Color("f2ead8")
const DIM := Color("a8a090")

var world: World
var open := false
## Stack held on the mouse (inventory open).
var cursor_id: StringName = &""
var cursor_count := 0

var _grid: Grid
var _name_label: Label
var _tooltip: PanelContainer
var _tooltip_text: Label
var _notes: VBoxContainer


## Draws the slots and handles clicks on them.
class Grid extends Control:
	var hud: Hud

	func _draw() -> void:
		hud.draw_grid(self)

	func _gui_input(event: InputEvent) -> void:
		hud.grid_input(event)


func _ready() -> void:
	layer = 20
	_grid = Grid.new()
	_grid.hud = self
	_grid.position = MARGIN
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_grid)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 8)
	_name_label.add_theme_color_override("font_color", TEXT)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	add_child(_name_label)
	_tooltip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	style.set_content_margin_all(4)
	style.set_corner_radius_all(2)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text = Label.new()
	_tooltip_text.add_theme_font_size_override("font_size", 8)
	_tooltip_text.add_theme_color_override("font_color", TEXT)
	_tooltip.add_child(_tooltip_text)
	_tooltip.visible = false
	add_child(_tooltip)
	_notes = VBoxContainer.new()
	_notes.position = Vector2(6, 300)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notes)
	EventBus.item_picked_up.connect(_on_picked_up)
	world.character.inventory.changed.connect(_grid.queue_redraw)
	world.player.selection_changed.connect(func(_s: int) -> void: _grid.queue_redraw())
	_layout()


func _input(event: InputEvent) -> void:
	if open and event.is_action_pressed("ui_cancel"):
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# A click on the world with a stack on the mouse throws it.
	var mb := event as InputEventMouseButton
	if open and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and cursor_count > 0:
		_throw_cursor()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Polled (not _input) so scripted runs can tap it too.
	if Input.is_action_just_pressed("inventory") and not world.get_tree().paused:
		set_open(not open)
	var p := world.player
	var over := _grid.get_global_rect().has_point(_grid.get_global_mouse_position())
	p.input_blocked = over or cursor_count > 0 or world.get_tree().paused
	_update_tooltip(over)
	var item := p.held_item
	_name_label.text = item.display_name if item else ""
	if cursor_count > 0:
		_grid.queue_redraw()


func set_open(value: bool) -> void:
	open = value
	if not open and cursor_count > 0:
		var left := world.character.inventory.add(cursor_id, cursor_count)
		cursor_count = left
		if left > 0:
			_throw_cursor()
		_clear_cursor()
	_layout()


func _layout() -> void:
	var rows := 4 if open else 1
	_grid.size = Vector2(10 * (SLOT + GAP) - GAP, rows * (SLOT + GAP) - GAP)
	_name_label.position = MARGIN + Vector2(0, _grid.size.y + 2)
	_grid.queue_redraw()


func slot_at(local: Vector2) -> int:
	var col := floori(local.x / (SLOT + GAP))
	var row := floori(local.y / (SLOT + GAP))
	if col < 0 or col >= 10 or row < 0 or row >= (4 if open else 1):
		return -1
	if fposmod(local.x, SLOT + GAP) > SLOT or fposmod(local.y, SLOT + GAP) > SLOT:
		return -1
	return row * 10 + col


func draw_grid(g: Control) -> void:
	var inv := world.character.inventory
	var font := ThemeDB.fallback_font
	var rows := 4 if open else 1
	for i in rows * 10:
		var r := Rect2(Vector2((i % 10) * (SLOT + GAP), (i / 10) * (SLOT + GAP)), Vector2(SLOT, SLOT))
		g.draw_rect(r, BG_HOT if i < Inventory.HOTBAR else BG)
		g.draw_rect(r, SELECTED if i == world.player.selected else EDGE, false, 1.0)
		var item := inv.item(i)
		if item and item.icon:
			g.draw_texture_rect(item.icon, Rect2(r.position + Vector2(2, 2), Vector2(16, 16)), false)
			if inv.counts[i] > 1:
				_draw_count(g, font, r, inv.counts[i])
		if i < Inventory.HOTBAR:
			g.draw_string(font, r.position + Vector2(2, 7), str((i + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DIM)
	if cursor_count > 0:
		var item := ItemData.find(cursor_id)
		var m := g.get_local_mouse_position()
		if item and item.icon:
			g.draw_texture_rect(item.icon, Rect2(m + Vector2(2, 2), Vector2(16, 16)), false)
		if cursor_count > 1:
			_draw_count(g, font, Rect2(m, Vector2(SLOT, SLOT)), cursor_count)


func _draw_count(g: Control, font: Font, r: Rect2, n: int) -> void:
	var text := str(n)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var at := r.position + Vector2(SLOT - w - 1, SLOT - 2)
	g.draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0, 0, 0, 0.8))
	g.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, TEXT)


func grid_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var slot := slot_at(mb.position)
	if slot < 0:
		return
	_grid.accept_event()
	if not open:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			world.player.select_slot(slot)  # hotbar click selects
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed:
		_quick_move(slot)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		click_slot(slot)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		right_click_slot(slot)
	_grid.queue_redraw()


## Left click with the panel open: pick up, put down, merge or swap.
func click_slot(slot: int) -> void:
	var inv := world.character.inventory
	if cursor_count == 0:
		if not inv.is_empty(slot):
			cursor_id = inv.ids[slot]
			cursor_count = inv.counts[slot]
			inv.set_slot(slot, &"", 0)
		return
	if inv.is_empty(slot):
		inv.set_slot(slot, cursor_id, cursor_count)
		_clear_cursor()
	elif inv.ids[slot] == cursor_id:
		var cap := Inventory.max_stack(cursor_id)
		var n := mini(cursor_count, cap - inv.counts[slot])
		inv.set_slot(slot, cursor_id, inv.counts[slot] + n)
		cursor_count -= n
		if cursor_count <= 0:
			_clear_cursor()
	else:
		var id := inv.ids[slot]
		var count := inv.counts[slot]
		inv.set_slot(slot, cursor_id, cursor_count)
		cursor_id = id
		cursor_count = count


## Right click: take half (empty mouse) or put one down.
func right_click_slot(slot: int) -> void:
	var inv := world.character.inventory
	if cursor_count == 0:
		if inv.is_empty(slot):
			return
		var half := ceili(inv.counts[slot] / 2.0)
		cursor_id = inv.ids[slot]
		cursor_count = inv.take(slot, half)
		return
	if inv.is_empty(slot) or (inv.ids[slot] == cursor_id and inv.counts[slot] < Inventory.max_stack(cursor_id)):
		inv.set_slot(slot, cursor_id, (0 if inv.is_empty(slot) else inv.counts[slot]) + 1)
		cursor_count -= 1
		if cursor_count <= 0:
			_clear_cursor()


## Shift + click: hotbar <-> the rest of the inventory.
func _quick_move(slot: int) -> void:
	var inv := world.character.inventory
	if inv.is_empty(slot):
		return
	var to_hotbar := slot >= Inventory.HOTBAR
	var id := inv.ids[slot]
	var n := inv.counts[slot]
	var lo := 0 if to_hotbar else Inventory.HOTBAR
	var hi := Inventory.HOTBAR if to_hotbar else Inventory.SIZE
	var cap := Inventory.max_stack(id)
	for pass_i in 2:  # first top up matching stacks, then empty slots
		for i in range(lo, hi):
			if n <= 0:
				break
			if pass_i == 0 and inv.ids[i] == id and inv.counts[i] < cap:
				var k := mini(n, cap - inv.counts[i])
				inv.set_slot(i, id, inv.counts[i] + k)
				n -= k
			elif pass_i == 1 and inv.is_empty(i):
				var k := mini(n, cap)
				inv.set_slot(i, id, k)
				n -= k
	inv.set_slot(slot, id if n > 0 else &"", n)


func _throw_cursor() -> void:
	var p := world.player
	var dir := 1.0 if p.get_global_mouse_position().x >= p.global_position.x else -1.0
	world.request_spawn_drop(cursor_id, cursor_count, p.chest() + Vector2(dir * 10.0, 0),
		Vector2(dir * p.throw_speed * World.TILE, -6.0 * World.TILE), true)
	_clear_cursor()


func _clear_cursor() -> void:
	cursor_id = &""
	cursor_count = 0
	_grid.queue_redraw()


func _update_tooltip(over: bool) -> void:
	var slot := slot_at(_grid.get_local_mouse_position()) if over and cursor_count == 0 else -1
	var item := world.character.inventory.item(slot) if slot >= 0 else null
	_tooltip.visible = item != null
	if item == null:
		return
	_tooltip_text.text = tooltip_for(item)
	_tooltip.reset_size()
	_tooltip.position = _grid.get_global_mouse_position() + Vector2(10, 8)


static func tooltip_for(item: ItemData) -> String:
	var lines := PackedStringArray([item.display_name])
	if item.mining_damage > 0.0:
		var area: String = str(item.mining_area) if item.mining_area_max <= item.mining_area \
			else "%d to %d" % [item.mining_area, item.mining_area_max]
		lines.append("%s mining %s, area %s" % [str(item.mining_damage),
			"per second" if item.beam else "per hit", area])
	if item.axe_damage > 0.0:
		lines.append("%s chopping per hit" % str(item.axe_damage))
	if item.reach_tiles > 0.0 and (item.mining_damage > 0.0 or item.axe_damage > 0.0):
		lines.append("Reach %s tiles" % str(item.reach_tiles))
	if item.description != "":
		lines.append(item.description)
	return "\n".join(lines)


func _on_picked_up(item_id: StringName, count: int) -> void:
	var item := ItemData.find(item_id)
	var l := Label.new()
	l.text = "+%d %s" % [count, item.display_name if item else String(item_id)]
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_notes.add_child(l)
	_notes.position.y = 344 - _notes.get_child_count() * 12
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		l.queue_free()
		_notes.position.y = 344 - (_notes.get_child_count() - 1) * 12)
