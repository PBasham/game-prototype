class_name DevConsole
extends CanvasLayer
## Debug builds only: a command console, opened with ` (the ~ key). Type `help`.
## Up / Down walk through earlier commands; Tab completes item and spell names. The log
## scrolls with the mouse wheel or Page Up / Page Down.
##
## Items and spells can be named by id (copper_pickaxe) or by name ("copper pickaxe",
## any case); a unique start of either works too (copper_p).

const HISTORY_MAX := 50
const LINES_SHOWN := 14

var world: World
var open := false

var _panel: PanelContainer
var _log: RichTextLabel
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
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.scroll_active = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 7)
	_log.add_theme_color_override("default_color", Color("d8e0d0"))
	_log.custom_minimum_size = Vector2(630, LINES_SHOWN * 10)
	box.add_child(_log)
	_entry = LineEdit.new()
	_entry.add_theme_font_size_override("font_size", 8)
	_entry.placeholder_text = "command (help for the list)"
	_entry.keep_editing_on_text_submit = true  # stay in the box after Enter
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
		KEY_PAGEUP, KEY_PAGEDOWN:
			var bar := _log.get_v_scroll_bar()
			bar.value += (-1.0 if k.keycode == KEY_PAGEUP else 1.0) * _log.size.y * 0.8
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
	if not open and not DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().size() > 0:
		print("[console] ", line)
	for l in line.split("\n"):
		_lines.append(l)
	while _lines.size() > 500:
		_lines.remove_at(0)
	_log.text = "\n".join(_lines)


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
	_add("page", "page <spell>", "Forget a spell and get its Spell Page (left click it to learn the spell again).", func(a: PackedStringArray) -> void:
		var spell := find_spell(" ".join(a))
		if spell == null:
			return
		_forget(a)
		world.character.inventory.add(StringName("page_" + String(spell.id)), 1)
		_print("Forgot %s; here's its Spell Page." % spell.display_name))
	_add("cast", "cast <spell>", "Cast a spell at the cursor now (no book, mana or cooldown needed).", func(a: PackedStringArray) -> void:
		var spell := find_spell(" ".join(a))
		if spell == null:
			return
		var p := world.player
		match spell.cast:
			SpellData.Cast.TOGGLE:
				p.toggle_concentration(spell)
			SpellData.Cast.TOOL:
				_print("%s is a held beam: ready it and hold the button." % spell.display_name)
				return
			SpellData.Cast.CHARGED:
				var from := p.casting_hand_position()
				var bolt := world.request_spawn_projectile(spell, from, (world.item_user.cursor() - from).normalized(),
					world.item_user._spell_power(), p)
				if bolt:
					bolt.size = 1.8
			_:
				if not world.item_user.cast(spell):
					return
		_print("Cast %s." % spell.display_name))
	_add("quick", "quick <slot> <spell>", "Put a known spell in a quick slot: q1..q8, e1..e8, z, x, c, buff1..buff6 (learns it if needed). \"quick <slot> none\" empties it.", func(a: PackedStringArray) -> void:
		if a.size() < 2:
			_print("Usage: quick <slot> <spell>")
			return
		var slot := _quick_slot(a[0])
		if slot == &"":
			_print("Slots: q1..q8, e1..e8, z, x, c, buff1..buff6.")
			return
		var c := world.character
		if a[1] == "none":
			c.set_quick(slot, &"")
			_print("%s emptied." % a[0])
			return
		var spell := find_spell(" ".join(a.slice(1)))
		if spell == null:
			return
		c.learn_spell(spell.id)
		if c.set_quick(slot, spell.id):
			_print("%s: %s (%s)." % [a[0], spell.display_name, "casts right away" if c.quick_casts(slot) else "in hand"])
		else:
			_print("Only Buff spells go in the buff set."))
	_add("bush", "bush [young]", "Grow a ripe berry bush (full grown, or young) on the grass under the cursor.", func(a: PackedStringArray) -> void:
		var t := world.world_to_tile(world.item_user.cursor())
		for g: Vector2i in [t, t + Vector2i.DOWN, t + Vector2i(0, 2)]:
			if world.data.get_block(g.x, g.y) == world.blocks.index_of(&"grass") and world.data.get_block(g.x, g.y - 1) == WorldData.AIR \
					and world.plants.plant_at(g) == null:
				var young := a.size() > 0 and a[0] == "young"
				var bush := world.plants._add(world.wrap_tile(g), PlantLayer.Kind.BUSH,
					PlantLayer.BUSH_YOUNG if young else PlantLayer.BUSH_GROWN)
				if young:
					bush.health = world.plants._days(world.plants.bush_grow_min_days)
					world.plants._young.append(world.wrap_tile(g))
				_print("A berry bush at %d, %d." % [g.x, g.y])
				return
		_print("Needs open grass under the cursor."))
	_add("time", "time [hour | day | night | dusk | dawn | speed <x>]", "Show or set the time of day (24 minute days).", _time)
	_add("summon", "summon <enemy> [count]", "Spawn enemies at the cursor (green_slime).", func(a: PackedStringArray) -> void:
		if a.is_empty() or not Registry.has_def(&"enemies", StringName(a[0])):
			_print("Enemies: %s" % ", ".join(_enemy_ids()))
			return
		var n := int(a[1]) if a.size() > 1 and a[1].is_valid_int() else 1
		for i in n:
			world.request_spawn_enemy(Registry.get_def(&"enemies", StringName(a[0])) as EnemyData,
				world.item_user.cursor() + Vector2(i * 12, 0))
		_print("Summoned %d %s." % [n, a[0]]))
	_add("peaceful", "peaceful", "Toggle enemy spawning.", func(_a: PackedStringArray) -> void:
		world.spawner.peaceful = not world.spawner.peaceful
		_print("Enemies spawn: %s." % ("no" if world.spawner.peaceful else "yes")))
	_add("butcher", "butcher", "Kill every enemy (they drop their loot).", func(_a: PackedStringArray) -> void:
		var n := world.enemy_count()
		for e in world.enemies():
			e.kill()
		_print("Killed %d." % n))
	_add("spawns", "spawns", "Show the spawn table here, the rate and the cap.", func(_a: PackedStringArray) -> void:
		var t := world.spawner.table_here()
		if t == null:
			_print("Nothing spawns here (no spawn table for this biome and depth).")
			return
		var night := world.spawner.is_night()
		var chance := world.spawner.spawn_chance(t, 1.0)
		_print("%s, %s: %d of %d enemies, %.0f%% chance per second (about every %.1f s)%s." % [
			t.display_name, "night" if night else "day", world.enemy_count(), t.cap(night), chance * 100.0,
			1.0 / chance if chance > 0.0 else INF, ", peaceful" if world.spawner.peaceful else ""])
		_print("  This session: %d spawned, %d found no spot." % [world.spawner.spawned_total, world.spawner.failed_total])
		var total := 0.0
		for e in t.entries:
			if e.allowed(night, world):
				total += e.weight
		for e in t.entries:
			if e.enemy == null:
				continue
			if e.allowed(night, world):
				_print("  %s: %.0f%%" % [e.enemy.display_name, e.weight / total * 100.0])
			else:
				var why: PackedStringArray = []
				if not (e.night if night else e.day):
					why.append("not at this time of day")
				for c in e.conditions:
					if c and not c.met(world):
						why.append(c.describe(world))
				_print("  %s: locked, %s" % [e.enemy.display_name, ", ".join(why)]))
	_add("kills", "kills", "Enemies slain in this world.", func(_a: PackedStringArray) -> void:
		if world.kills.is_empty():
			_print("Nothing slain yet.")
		for id in world.kills:
			_print("  %s: %d" % [id, world.kills[id]]))
	_add("god", "god", "Toggle taking no damage.", func(_a: PackedStringArray) -> void:
		world.player.invincible = not world.player.invincible
		_print("No damage: %s." % ("on" if world.player.invincible else "off")))
	_add("hurt", "hurt <amount>", "Take damage (to test health, dying and the magic bag).", func(a: PackedStringArray) -> void:
		var was := world.player.invincible
		world.player.invincible = false
		world.player.reset_hurt_cooldown()
		world.player.take_damage(float(a[0]) if a.size() > 0 and a[0].is_valid_float() else 10.0, &"console")
		world.player.invincible = was
		_print("Health %d." % roundi(world.player.health)))
	_add("kill", "kill", "Die (drops the magic bag, respawns at the spawn).", func(_a: PackedStringArray) -> void:
		world.player.invincible = false
		world.player.reset_hurt_cooldown()
		world.player.take_damage(world.player.health + 1.0, &"console"))
	_add("heal", "heal", "Full health and hunger.", func(_a: PackedStringArray) -> void:
		world.player.health = world.player.max_health
		world.player.hunger = world.player.max_hunger
		_print("Healed."))
	_add("hunger", "hunger <0..100>", "Set hunger (0 = starving).", func(a: PackedStringArray) -> void:
		if a.size() > 0 and a[0].is_valid_float():
			world.player.hunger = clampf(float(a[0]), 0.0, world.player.max_hunger)
		_print("Hunger %d." % roundi(world.player.hunger)))
	_add("color", "color <group> <hex|reset>", "Recolor the character: skin, hair, tunic, trim, pants, leather (saved).", _color)
	_add("equip", "equip <item>", "Equip armor, an accessory, a book or a conduit (no item needed).", _equip)
	_add("clear", "clear", "Empty the inventory.", func(_a: PackedStringArray) -> void:
		for i in world.character.inventory.size:
			world.character.inventory.clear(i)
		world.character.inventory.changed.emit()
		_print("Inventory emptied."))
	_add("devkit", "devkit", "Tools, blocks, torches, all spells and the dev test items.", func(_a: PackedStringArray) -> void:
		world.character.give_dev_kit()
		_print("Dev kit given."))
	_add("creative", "creative", "Open the Dev items window (also F7): every item, take as many as you like.", func(_a: PackedStringArray) -> void:
		world.hud.toggle_dev_items()
		_print("Dev items window %s." % ("open" if world.hud.dev_items_open else "closed")))
	_add("books", "books", "Give the tier 1, 2 and 3 spellbooks.", func(_a: PackedStringArray) -> void:
		for t in range(1, 4):
			world.character.inventory.add(StringName("spellbook_t%d" % t), 1)
		_print("Gave the tier 1, 2 and 3 test books."))
	_add("infinite", "infinite", "Toggle infinite items: placing, eating and throwing use nothing up.", func(_a: PackedStringArray) -> void:
		world.infinite_items = not world.infinite_items
		_print("Infinite items %s." % ("on" if world.infinite_items else "off")))
	_add("freecraft", "freecraft", "Toggle free crafting: no materials (or max mana) needed, nothing used up.", func(_a: PackedStringArray) -> void:
		world.free_crafting = not world.free_crafting
		if world.hud:
			world.hud._recipe_key = ""
		_print("Free crafting %s." % ("on" if world.free_crafting else "off")))
	_add("mana", "mana", "Toggle infinite mana.", func(_a: PackedStringArray) -> void:
		world.player.infinite_mana = not world.player.infinite_mana
		world.player.mana = world.player.max_mana
		_print("Infinite mana %s." % ("on" if world.player.infinite_mana else "off")))
	_add("tp", "tp <x> <y> | tp spawn", "Teleport to a tile (feet), or the world's spawn.", _tp)
	_add("pos", "pos", "Your tile position.", func(_a: PackedStringArray) -> void:
		var t := world.wrap_tile(world.world_to_tile(world.player.global_position))
		_print("tile %d, %d" % [t.x, t.y]))
	_add("grow", "grow", "Grow every sapling into a tree now.", func(_a: PackedStringArray) -> void:
		_print("%d saplings growing." % world.plants.grow_all()))
	_add("pickups", "pickups [days]", "Count loose sticks, rocks and flint in the loaded area; with days, let that much time pass for them (off screen).", func(a: PackedStringArray) -> void:
		if a.size() > 0:
			var before := world.forage.regrown_total
			world.forage.regrow_for_days(float(a[0]))
			_print("%d came back." % (world.forage.regrown_total - before))
		_print("%d loose pickups loaded on %d floor tiles; %d came back this session." % [
			world.forage.loaded_count(), world.forage.floor_tile_count(), world.forage.regrown_total]))
	_add("regen", "regen", "Regenerate the world from forest.tres (same as F6).", func(_a: PackedStringArray) -> void:
		world.regenerate())
	_add("fill", "fill <block|air> <w> <h>", "Fill a box with a block (front layer) at the cursor.", func(a: PackedStringArray) -> void:
		_fill(a, false))
	_add("fillwall", "fillwall <wall|air> <w> <h>", "Fill a box with a background wall at the cursor.", func(a: PackedStringArray) -> void:
		_fill(a, true))
	_add("cursor", "cursor <dx> <dy> | cursor off", "Pin the cursor to a tile offset from your feet (for scripted building), or let it follow the mouse again.", _cursor)
	_add("dig", "dig <w> <h>", "Clear a box of blocks (keeps walls) centered on the cursor.", _dig)
	_add("place", "place <object>", "Place a tile object (torch, rope, workbench, chest...) at the cursor, no item needed.", _place)
	_add("forage", "forage <type>", "Put a forageable (stick, rock, field_mushroom, red_cap, duskcap, glowcap) on the ground under the cursor.", func(a: PackedStringArray) -> void:
		var def := Registry.get_def(&"forage", StringName(" ".join(a))) as ForageData
		if def == null:
			_print("No forageable %s." % " ".join(a))
			return
		var t := world.world_to_tile(world.item_user.cursor())
		for dy in 12:  # down to the first ground with air above
			var g := t + Vector2i(0, dy)
			if world.is_solid(g) and not world.is_solid(g + Vector2i.UP):
				world.forage._add(world.wrap_tile(g), def)
				_print("%s placed." % def.display_name)
				return
		_print("No ground under the cursor."))
	_add("display", "display <item>", "Put an item on display at the cursor (a floor, table top or shelf), no item needed.", func(a: PackedStringArray) -> void:
		var id := StringName(_norm(" ".join(a)))
		var t := world.world_to_tile(world.item_user.cursor())
		if ItemData.find(id) == null:
			_print("No item %s." % " ".join(a))
		elif world.request_place_display(t, id):
			_print("%s on display." % ItemData.find(id).display_name)
		else:
			_print("Can't display that there (needs a free spot on a floor, table or shelf; small items only)."))
	_add("use", "use", "Use what's at the cursor (like a right click: open a station, chest or door).", func(_a: PackedStringArray) -> void:
		_print("Used." if world.try_interact_at(world.item_user.cursor(), world.player) else "Nothing to use there (or too far)."))
	_add("dummy", "dummy | dummy clear", "Spawn a training dummy at the cursor (to test damage spells).", _dummy)
	_add("ready", "ready <spell>", "Take the spellbook out with this spell.", func(a: PackedStringArray) -> void:
		var spell := find_spell(" ".join(a))
		if spell:
			world.player.ready_spell(spell.id)
			_print("Ready: %s." % spell.display_name))
	_add("reach", "reach", "Toggle unlimited reach for mining, chopping and placing.", func(_a: PackedStringArray) -> void:
		world.item_user.infinite_reach = not world.item_user.infinite_reach
		_print("Unlimited reach %s." % ("on" if world.item_user.infinite_reach else "off")))
	_add("fly", "fly", "Toggle flying (same as casting Fly).", func(_a: PackedStringArray) -> void:
		var spell := ItemData.find(&"spell:fly") as SpellData
		world.player.toggle_concentration(spell)
		_print("Flying." if world.player.is_flying() else "Not flying."))
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
	_print("Learned %s." % spell.display_name)


## "q3" -> &"q_2", "z" -> &"z", "buff1" -> &"buff_0"; &"" if it's not a slot.
static func _quick_slot(text: String) -> StringName:
	text = text.to_lower()
	if text in ["z", "x", "c"]:
		return StringName(text)
	for prefix: String in ["buff", "q", "e"]:
		if text.begins_with(prefix) and text.substr(prefix.length()).is_valid_int():
			var n := int(text.substr(prefix.length()))
			var most := CharacterData.BUFF_SET_SIZE if prefix == "buff" else CharacterData.WHEEL_SIZE
			if n >= 1 and n <= most:
				return StringName("%s_%d" % [prefix, n - 1])
	return &""


func _forget(a: PackedStringArray) -> void:
	var spell := find_spell(" ".join(a))
	if spell == null:
		return
	var c := world.character
	for slot: StringName in c.quick.keys():
		if c.quick[slot] == spell.id:
			c.set_quick(slot, &"")
	c.known_spells.erase(spell.id)
	c.magic_changed.emit()
	_print("Forgot %s." % spell.display_name)


func _enemy_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for d in Registry.get_all(&"enemies"):
		out.append(String(d.id))
	return out


func _time(a: PackedStringArray) -> void:
	var c := world.clock
	if a.size() >= 2 and a[0] == "speed" and a[1].is_valid_float():
		c.speed = float(a[1])
		_print("Time runs x%s." % a[1])
		return
	if a.size() >= 1:
		var named := {"day": 8.0, "noon": 12.0, "dusk": c.sunset_hour, "night": 23.0, "dawn": c.sunrise_hour}
		if named.has(a[0]):
			c.set_hour(named[a[0]])
		elif a[0].is_valid_float():
			c.set_hour(float(a[0]))
		else:
			_print("Usage: time [hour | day | noon | dusk | night | dawn | speed <x>]")
			return
	_print(c.label())


func _color(a: PackedStringArray) -> void:
	if a.size() < 2:
		_print("Usage: color <skin|hair|tunic|trim|pants|leather> <hex like 3a7a3a, or reset>")
		return
	var c := world.character
	if a[1] == "reset":
		c.colors.erase(StringName(a[0]))
	elif Color.html_is_valid(a[1]):
		c.colors[StringName(a[0])] = Color.html(a[1])
	else:
		_print("Not a color: %s" % a[1])
		return
	world.player.look = c.make_look()
	_print("%s is now %s." % [a[0], a[1]])


func _equip(a: PackedStringArray) -> void:
	var item := find_item(" ".join(a))
	if item == null:
		return
	var c := world.character
	var target: StringName = &""
	for slot: StringName in CharacterData.ALL_SLOTS:
		if CharacterData.fits(slot, item) and (target == &"" or (c.equipment[target] != &"" and c.equipment[slot] == &"")):
			target = slot
	if target == &"":
		_print("%s can't be equipped." % item.display_name)
		return
	c.equip(target, item.id)
	_print("Equipped %s." % item.display_name)


func _fill(a: PackedStringArray, wall: bool) -> void:
	if a.size() != 3 or not a[1].is_valid_int() or not a[2].is_valid_int():
		_print("Usage: fill%s <id|air> <w> <h>" % ("wall" if wall else ""))
		return
	var types := world.walls if wall else world.blocks
	var id := 0 if a[0] == "air" else types.index_of(StringName(_norm(a[0])))
	if id < 0:
		_print("No %s called '%s'." % ["wall" if wall else "block", a[0]])
		return
	var size := Vector2i(clampi(int(a[1]), 1, 64), clampi(int(a[2]), 1, 64))
	var start := world.world_to_tile(world.item_user.cursor()) - size / 2
	for y in size.y:
		for x in size.x:
			if wall:
				world.request_set_wall(start + Vector2i(x, y), id)
			else:
				world.request_set_block(start + Vector2i(x, y), id)
	_print("Filled %dx%d with %s." % [size.x, size.y, a[0]])


func _cursor(a: PackedStringArray) -> void:
	if a.size() == 1 and a[0] == "off":
		world.item_user.cursor_override = Vector2.INF
		_print("Cursor follows the mouse.")
		return
	if a.size() != 2 or not a[0].is_valid_int() or not a[1].is_valid_int():
		_print("Usage: cursor <dx> <dy> (tiles from your feet) | cursor off")
		return
	var t := world.world_to_tile(world.player.global_position) + Vector2i(int(a[0]), int(a[1]))
	world.item_user.cursor_override = world.tile_to_world(t) + Vector2(World.TILE, World.TILE) * 0.5
	_print("Cursor at %d, %d." % [t.x, t.y])


func _dig(a: PackedStringArray) -> void:
	if a.size() != 2 or not a[0].is_valid_int() or not a[1].is_valid_int():
		_print("Usage: dig <w> <h>")
		return
	var size := Vector2i(clampi(int(a[0]), 1, 64), clampi(int(a[1]), 1, 64))
	var c := world.world_to_tile(world.item_user.cursor())
	var start := c - size / 2
	for y in size.y:
		for x in size.x:
			world.request_set_block(start + Vector2i(x, y), WorldData.AIR)
	_print("Dug %dx%d." % [size.x, size.y])


func _place(a: PackedStringArray) -> void:
	var id := world.objects.index_of(StringName(_norm(" ".join(a))))
	if id <= 0:
		_print("No object called '%s'. Objects: %s" % [" ".join(a), ", ".join(_object_ids())])
		return
	var t := world.world_to_tile(world.item_user.cursor())
	var def := world.objects.def(id) as ObjectDef
	if def.style == ObjectDef.Style.FURNITURE:
		t.x -= (def.width_tiles - 1) / 2  # the cursor is its bottom middle
	if not world.request_place_object(t, id):
		_print("Can't place %s there (needs room%s)." % [def.display_name, " and a floor" if def.needs_floor else ""])
		return
	_print("Placed %s at %d, %d." % [world.objects.id_of(id), t.x, t.y])


func _object_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, world.objects.size()):
		if not (world.objects.def(i) as ObjectDef).filler:
			out.append(String(world.objects.id_of(i)))
	return out


func _dummy(a: PackedStringArray) -> void:
	if a.size() == 1 and a[0] == "clear":
		for n in world.effects.get_children():
			if n is DevDummy:
				n.queue_free()
		_print("Dummies removed.")
		return
	var d := DevDummy.new()
	# Stand it on the ground under the cursor.
	var t := world.world_to_tile(world.item_user.cursor())
	for i in 40:
		if world.is_solid(t + Vector2i(0, 1)):
			break
		t.y += 1
	d.position = Vector2((t.x + 0.5) * World.TILE, (t.y + 1) * World.TILE)
	world.effects.add_child(d)
	_print("Dummy at %d, %d. Cast Spark at it." % [t.x, t.y])


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
