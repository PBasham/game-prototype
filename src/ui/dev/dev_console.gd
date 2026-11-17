class_name DevConsole
extends CanvasLayer
## Debug builds only: a command console, opened with ` (the ~ key). Type `help`.
## Up / Down walk through earlier commands; Tab completes item and spell names.
##
## Items and spells can be named by id (copper_pickaxe) or by name ("copper pickaxe",
## any case); a unique start of either works too (copper_p).

const HISTORY_MAX := 50
const LINES_SHOWN := 14

var world: World
var open := false

var _panel: PanelContainer
var _log: Label
var _entry: LineEdit
var _lines: PackedStringArray = []
var _history: PackedStringArray = []
var _history_at := 0
## name -> [Callable(args: PackedStringArray) -> void, usage, help]
var _commands: Dictionary[String, Array] = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.9)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(0, 0)
	_panel.custom_minimum_size = Vector2(640, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 7)
	_log.add_theme_color_override("font_color", Color("d8e0d0"))
	_log.custom_minimum_size = Vector2(630, LINES_SHOWN * 9)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(_log)
	_entry = LineEdit.new()
	_entry.add_theme_font_size_override("font_size", 8)
	_entry.placeholder_text = "command (help for the list)"
	_entry.text_submitted.connect(_on_submit)
	_entry.gui_input.connect(_on_input_key)
	box.add_child(_entry)
	_panel.visible = false
	_register()
	_print("Dev console. Type help.")


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_QUOTELEFT:
		set_open(not open)
		get_viewport().set_input_as_handled()
	elif open and k and k.pressed and k.physical_keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
	open = value
	_panel.visible = open
	world.player.typing = open
	if open:
		_entry.clear()
		_entry.grab_focus.call_deferred()
	else:
		_entry.release_focus()


func _on_input_key(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_UP:
			_history_at = maxi(_history_at - 1, 0)
			if _history_at < _history.size():
				_entry.text = _history[_history_at]
				_entry.caret_column = _entry.text.length()
			_entry.accept_event()
		KEY_DOWN:
			_history_at = mini(_history_at + 1, _history.size())
			_entry.text = _history[_history_at] if _history_at < _history.size() else ""
			_entry.caret_column = _entry.text.length()
			_entry.accept_event()
		KEY_TAB:
			_complete()
			_entry.accept_event()


func _on_submit(text: String) -> void:
	_entry.clear()
	text = text.strip_edges()
	if text.is_empty():
		return
	_history.append(text)
	if _history.size() > HISTORY_MAX:
		_history.remove_at(0)
	_history_at = _history.size()
	_print("> " + text)
	run(text)


## Runs one command line. Returns false if the command doesn't exist.
func run(text: String) -> bool:
	var parts := text.split(" ", false)
	if parts.is_empty():
		return false
	var cmd := parts[0].to_lower()
	if not _commands.has(cmd):
		_print("Unknown command '%s'. Type help." % cmd)
		return false
	(_commands[cmd][0] as Callable).call(parts.slice(1))
	return true


func _print(line: String) -> void:
	for l in line.split("\n"):
		_lines.append(l)
	while _lines.size() > 200:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines.slice(maxi(_lines.size() - LINES_SHOWN, 0)))


func _add(cmd_name: String, usage: String, help_text: String, fn: Callable) -> void:
	_commands[cmd_name] = [fn, usage, help_text]


# --- commands --------------------------------------------------------------------------

func _register() -> void:
	_add("help", "help", "This list.", func(_a: PackedStringArray) -> void:
		for c: String in _commands:
			_print("  %-28s %s" % [_commands[c][1], _commands[c][2]]))
	_add("give", "give <item> [count]", "Put items in your inventory (extra drops at your feet).", _give)
	_add("spawn", "spawn <item> [count]", "Drop items into the world at the cursor.", _spawn)
	_add("items", "items [filter]", "List item ids.", func(a: PackedStringArray) -> void:
		_list(_all_items(), " ".join(a)))
	_add("spells", "spells [filter]", "List spell ids.", func(a: PackedStringArray) -> void:
		_list(_all_spells(), " ".join(a)))
	_add("learn", "learn <spell>", "Learn a spell (it also goes in a free book slot).", _learn)
	_add("forget", "forget <spell>", "Forget a spell.", _forget)
	_add("equip", "equip <book or conduit>", "Equip a book or conduit (no item needed).", _equip)
	_add("clear", "clear", "Empty the inventory.", func(_a: PackedStringArray) -> void:
		for i in Inventory.SIZE:
			world.character.inventory.clear(i)
		world.character.inventory.changed.emit()
		_print("Inventory emptied."))
	_add("kit", "kit", "Give the starting kit again.", func(_a: PackedStringArray) -> void:
		for e: Array in CharacterData.STARTING_KIT:
			world.character.inventory.add(e[0], e[1])
		_print("Starting kit given."))
	_add("tp", "tp <x> <y> | tp spawn", "Teleport to a tile (feet), or the world's spawn.", _tp)
	_add("pos", "pos", "Your tile position.", func(_a: PackedStringArray) -> void:
		var t := world.wrap_tile(world.world_to_tile(world.player.global_position))
		_print("tile %d, %d" % [t.x, t.y]))
	_add("grow", "grow", "Grow every sapling into a tree now.", func(_a: PackedStringArray) -> void:
		_print("%d saplings growing." % world.plants.grow_all()))
	_add("regen", "regen", "Regenerate the world from forest.tres (same as F6).", func(_a: PackedStringArray) -> void:
		world.regenerate())
	_add("cls", "cls", "Clear this log.", func(_a: PackedStringArray) -> void:
		_lines.clear()
		_log.text = "")


func _give(a: PackedStringArray) -> void:
	var parsed := _name_and_count(a)
	var item := find_item(parsed[0])
	if item == null:
		return
	var count := clampi(parsed[1], 1, 99999)
	var left := world.character.inventory.add(_key(item), count)
	if left > 0:
		world.request_spawn_drop(_key(item), left, world.player.chest(), Vector2.ZERO, true)
	_print("Gave %d %s%s." % [count, item.display_name, " (%d dropped, no room)" % left if left > 0 else ""])


func _spawn(a: PackedStringArray) -> void:
	var parsed := _name_and_count(a)
	var item := find_item(parsed[0])
	if item == null:
		return
	var at := world.item_user.cursor()
	var count := clampi(parsed[1], 1, 99999)
	var cap := maxi(item.max_stack, 1)
	while count > 0:
		var n := mini(count, cap)
		world.request_spawn_drop(_key(item), n, at, Vector2(randf_range(-1, 1), -2) * World.TILE)
		count -= n
	_print("Spawned %s %s." % [parsed[1], item.display_name])


func _learn(a: PackedStringArray) -> void:
	var spell := find_spell(" ".join(a))
	if spell == null:
		return
	var c := world.character
	c.learn_spell(spell.id)
	if not c.in_book(spell.id):
		var loadout := c.book_loadout()
		var free := loadout.find(&"")
		if free >= 0:
			c.put_in_book(free, spell.id)
	_print("Learned %s%s." % [spell.display_name, "" if c.in_book(spell.id) else " (book full)"])


func _forget(a: PackedStringArray) -> void:
	var spell := find_spell(" ".join(a))
	if spell == null:
		return
	var c := world.character
	var at := c.book_spells.find(spell.id)
	if at >= 0:
		c.put_in_book(at, &"")
	c.known_spells.erase(spell.id)
	c.magic_changed.emit()
	_print("Forgot %s." % spell.display_name)


func _equip(a: PackedStringArray) -> void:
	var item := find_item(" ".join(a))
	if item == null:
		return
	for slot: StringName in [CharacterData.SLOT_BOOK, CharacterData.SLOT_CONDUIT]:
		if CharacterData.fits(slot, item):
			world.character.equip(slot, item.id)
			_print("Equipped %s." % item.display_name)
			return
	_print("%s isn't a book or a conduit." % item.display_name)


func _tp(a: PackedStringArray) -> void:
	var tile: Vector2i
	if a.size() == 1 and a[0] == "spawn":
		tile = world.generator.spawn_tile()
	elif a.size() == 2 and a[0].is_valid_int() and a[1].is_valid_int():
		tile = Vector2i(int(a[0]), int(a[1]))
	else:
		_print("Usage: tp <x> <y> | tp spawn")
		return
	var pos := world.tile_to_world(tile) + Vector2(World.TILE * 0.5, 0)
	world.renderer.load_all_now(pos)
	world.teleport_player(pos)
	_print("Teleported to %d, %d." % [tile.x, tile.y])


# --- lookups ---------------------------------------------------------------------------

## [name text, count]: a trailing number is the count (default 1).
func _name_and_count(a: PackedStringArray) -> Array:
	var count := 1
	var words := a
	if a.size() > 1 and a[a.size() - 1].is_valid_int():
		count = int(a[a.size() - 1])
		words = a.slice(0, a.size() - 1)
	return [" ".join(words), count]


func _all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in Registry.get_all(&"items"):
		out.append(d as ItemData)
	for item: ItemData in ItemData._runtime.values():
		if not item.is_spell():
			out.append(item)
	return out


func _all_spells() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for d in Registry.get_all(&"spells"):
		out.append(d as ItemData)
	for item: ItemData in ItemData._runtime.values():
		if item.is_spell():
			out.append(item)
	return out


## The inventory id (spells are "spell:<id>").
func _key(item: ItemData) -> StringName:
	return ItemData.spell_key(item.id) if item.is_spell() else item.id


static func _norm(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


## By id or name, exact first, then a unique start. Prints why when it fails.
func find_item(text: String) -> ItemData:
	return _find(_all_items() + _all_spells(), text, "item")


func find_spell(text: String) -> SpellData:
	return _find(_all_spells(), text, "spell") as SpellData


func _find(pool: Array[ItemData], text: String, what: String) -> ItemData:
	var key := _norm(text)
	if key.is_empty():
		_print("Which %s? (%ss lists them)" % [what, what])
		return null
	for item in pool:
		if _norm(String(item.id)) == key or _norm(item.display_name) == key:
			return item
	var matches: Array[ItemData] = []
	for item in pool:
		if _norm(String(item.id)).begins_with(key) or _norm(item.display_name).begins_with(key):
			matches.append(item)
	if matches.size() == 1:
		return matches[0]
	if matches.is_empty():
		_print("No %s called '%s'." % [what, text])
	else:
		var ids := PackedStringArray()
		for m in matches:
			ids.append(String(m.id))
		_print("'%s' could be: %s" % [text, ", ".join(ids)])
	return null


func _list(pool: Array[ItemData], filter: String) -> void:
	var f := _norm(filter)
	var rows := PackedStringArray()
	for item in pool:
		if f.is_empty() or _norm(String(item.id)).contains(f) or _norm(item.display_name).contains(f):
			rows.append("  %-22s %s" % [item.id, item.display_name])
	rows.sort()
	_print("\n".join(rows) if not rows.is_empty() else "  (none)")


## Tab: completes the last word as a command (first word) or an item / spell id.
func _complete() -> void:
	var text := _entry.text
	var parts := text.split(" ")
	var last := parts[parts.size() - 1].to_lower()
	var options := PackedStringArray()
	if parts.size() == 1:
		for c: String in _commands:
			if c.begins_with(last):
				options.append(c)
	else:
		var pool := _all_spells() if parts[0] in ["learn", "forget"] else _all_items() + _all_spells()
		for item in pool:
			if String(item.id).begins_with(last):
				options.append(String(item.id))
	if options.size() == 1:
		parts[parts.size() - 1] = options[0]
		_entry.text = " ".join(parts) + " "
		_entry.caret_column = _entry.text.length()
	elif options.size() > 1:
		_print("  " + "  ".join(options))
