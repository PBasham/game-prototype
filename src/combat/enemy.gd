class_name Enemy
extends CharacterBody2D
## A live enemy (World.request_spawn_enemy). Its type is an EnemyData. Moves with the
## world's collision (blocks and platforms), hurts the player on touch, takes damage
## from weapons and spells (the "damageable" group), shows a health bar once hurt, and
## drops its loot when it dies. Enemies aren't saved: they spawn around the player.
##
## Slime AI: rests, squashes, then hops (toward you when you're within aggro_tiles,
## otherwise in a random direction), and hops right after you hit it.

const TILE := 8.0
## Collision layer bit for enemies (the player doesn't collide with them; touching
## hurts instead).
const LAYER := 4

## Seconds this enemy has been beyond the spawner's despawn distance.
var far_for := 0.0
var data: EnemyData
var world: World
var health := 1.0
var _sprite: Sprite2D
var _halo: GlowHalo
var _wait := 1.0
var _squash := 0.0
var _flash := 0.0
var _since_hit := 99.0
var _was_on_floor := false
## Hop away from this x after being hit (no target: wander).
var _angry := false
## Sideways speed of the current hop (px/s), kept in the air so a wall it touches at
## takeoff doesn't stop it (it slides up the wall and over a low step).
var _hop_vx := 0.0
## Direction it's heading while wandering (-1 or 1).
var _dir := 1.0
## Seconds left in the current slither (0 = not slithering).
var _slither := 0.0
## x where the current move started, and moves in a row that got nowhere.
var _move_from := 0.0
var _stuck := 0


func setup(w: World, d: EnemyData) -> void:
	world = w
	data = d
	health = d.max_health


# --- as your summon (Summon Slime) -------------------------------------------------------

## The spell that summoned it: it fights for you. Not hit by you, not counted as an
## enemy, gone after the spell's duration (`time_left`).
var summon_spell: SpellData
var time_left := 0.0
## Damage per contact hit on an enemy, and its place among your summons.
var summon_damage := 0.0
var slot := 0
## Enemy -> seconds until this summon can hit it again.
var _hit_wait: Dictionary = {}
## Summoned this far from you (tiles), it hops back next to you.
const SUMMON_LEASH_TILES := 40.0
const SUMMON_HIT_EVERY := 0.6


## Sets it up as your summon (call before adding it to the tree).
func setup_summon(w: World, d: EnemyData, spell: SpellData, damage: float) -> void:
	setup(w, d)
	summon_spell = spell
	time_left = spell.duration
	summon_damage = damage


func is_summon() -> bool:
	return summon_spell != null


func _ready() -> void:
	if is_summon():
		add_to_group(&"familiars")  # counted with the other summons, ends when you die
	else:
		add_to_group(&"damageable")
		add_to_group(&"enemies")
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 1 | 2  # world blocks, platforms
	floor_snap_length = 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = data.size
	shape.shape = rect
	shape.position = Vector2(0, -data.size.y * 0.5)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = data.texture
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.modulate = data.tint
	add_child(_sprite)
	_set_frame(0)
	z_index = 1
	_wait = randf_range(data.hop_wait_min, data.hop_wait_max)
	if data.glow_tiles > 0.0:
		radius = data.glow_tiles
		color = data.glow_color
		# It glows: drawn over the lighting so it never looks faded, with a halo that
		# brightens while it charges and shoots.
		_sprite.z_as_relative = false
		_sprite.z_index = 55
		_halo = GlowHalo.make(data.glow_color, 14.0)
		add_child(_halo)
		add_to_group(&"light_sources")


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-data.size.x * 0.5, -data.size.y), data.size)


## Poisoned: loses `dps` health per second for `seconds` (a longer or stronger poison
## replaces a weaker one). Shown as a green tint.
var _poison_dps := 0.0
var _poison_left := 0.0
var _poison_tick := 0.0


func poison(dps: float, seconds: float) -> void:
	if health <= 0.0 or dps <= 0.0 or seconds <= 0.0:
		return
	_poison_dps = maxf(_poison_dps if _poison_left > 0.0 else 0.0, dps)
	_poison_left = maxf(_poison_left, seconds)


func is_poisoned() -> bool:
	return _poison_left > 0.0


## A school's mark (ItemData.School), left by a school weapon's hits: `damage` every
## Schools.MARK_TICK seconds for `seconds`, and that school's spells hit harder
## (Schools.payoff). One mark at a time; a new one replaces it.
var _mark_school := 0
var _mark_left := 0.0
var _mark_damage := 0.0
var _mark_tick := 0.0


func mark(school: int, damage: float, seconds: float) -> void:
	if health <= 0.0 or school == 0 or seconds <= 0.0:
		return
	if _mark_school != school:
		_mark_tick = 0.0
	_mark_school = school
	_mark_damage = damage
	_mark_left = maxf(_mark_left if _mark_school == school else 0.0, seconds)


func is_marked(school: int) -> bool:
	return _mark_left > 0.0 and _mark_school == school


func _tick_mark(delta: float) -> void:
	if _mark_left <= 0.0:
		return
	_mark_left -= delta
	_mark_tick += delta
	if _mark_tick >= Schools.MARK_TICK and _mark_damage > 0.0:
		_mark_tick -= Schools.MARK_TICK
		health -= _mark_damage
		FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-4, 4), -data.size.y - 6),
			str(roundi(_mark_damage)), Schools.color(_mark_school))
		if health <= 0.0:
			_die()


func _tick_poison(delta: float) -> void:
	if _poison_left <= 0.0:
		return
	_poison_left -= delta
	_poison_tick += delta
	if _poison_tick >= 1.0:
		_poison_tick -= 1.0
		var amount := _poison_dps
		health -= amount
		FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-4, 4), -data.size.y - 6),
			str(roundi(amount)), Color("9be36b"))
		if health <= 0.0:
			_die()


func take_damage(amount: float, from: Node) -> void:
	EventBus.sound_requested.emit(&"enemy_hit", global_position)
	if health <= 0.0:
		return
	amount = maxf(1.0, amount - data.defense * 0.5)
	health -= amount
	_flash = 0.12
	_since_hit = 0.0
	_angry = from != null
	FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-4, 4), -data.size.y - 6),
		str(roundi(amount)), Color("ffd27a"))
	if health <= 0.0:
		_die()


## Pushed away from `from` (px position) at `strength` tiles/s. `stagger`: its hop or
## slither is cut short and it starts over (weapons). Without (fists): only a sideways
## push, and it carries on with what it was doing.
func knock_back(from: Vector2, strength: float, stagger: bool = true) -> void:
	var k := strength * (1.0 - data.knockback_resist)
	if k <= 0.0:
		return
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = 1.0
	if not stagger:
		velocity.x += dir * k * TILE
		if _hop_vx != 0.0:
			_hop_vx += dir * k * 0.5 * TILE
		return
	velocity = Vector2(dir * k * TILE, -k * 0.6 * TILE)
	_hop_vx = 0.0
	_slither = 0.0
	_wait = 0.25  # hop again soon


## Dies now, dropping its loot (dev console `butcher`).
func kill() -> void:
	if health <= 0.0:
		return
	health = 0.0
	_die()


func _die() -> void:
	world.record_kill(data.id)
	EventBus.sound_requested.emit(&"enemy_die", global_position)
	var drops := LootDrop.roll(data.loot)
	if world.character:
		world.character.note_kill(data.id, drops.keys())  # the Catalog
	for item_id: StringName in drops:
		world.request_spawn_drop(item_id, drops[item_id], global_position + Vector2(0, -data.size.y * 0.5),
			Vector2(randf_range(-3, 3), -6) * TILE)
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -data.size.y - 10), "*pop*", Color("9ae88a"))
	if radius > 0.0 and world and world.lights:
		world.lights.mark_dirty()  # its light goes with it
	queue_free()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if radius > 0.0 and world and world.lights:
		# A glowing enemy (the Forest Spirit): relight when it reaches a new tile, so its
		# light follows it (the light map only recomputes when told to).
		var lt := Vector2i((light_point() * 4.0).floor())  # every quarter tile: it glides
		if lt != _light_at:
			_light_at = lt
			world.lights.mark_dirty()
	_tick_poison(delta)
	_tick_mark(delta)
	_since_hit += delta
	_squash = maxf(_squash - delta, 0.0)
	var wet := data.swims and _in_water()
	if is_summon() and _summon_dive(delta):
		move_and_slide()
		_summon_tick(delta)
		_update_look()
		queue_redraw()
		return
	_floating = data.floats and world.voxels != null \
		and world.voxels.liquid_at(global_position + Vector2(0.0, -data.size.y * 0.35))
	if _floating and velocity.y > -data.float_rise * TILE * 1.5:
		# Afloat: pushed up while more than a third under, bobbing at the surface.
		var deep := world.voxels.liquid_at(global_position + Vector2(0.0, -data.size.y * 0.75))
		var bob := sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 1.2 * TILE
		var target := -data.float_rise * TILE if deep else -data.float_rise * 0.3 * TILE + bob
		# Splashing down is stopped hard by the water; rising back up is gentler.
		velocity.y = move_toward(velocity.y, target, (450.0 if velocity.y > target else 40.0) * TILE * delta)
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * TILE * delta) if _hop_vx == 0.0 else velocity.x
	elif not wet and not data.flies:
		velocity.y = minf(velocity.y + data.gravity * TILE * delta, 90.0 * TILE)
	match data.ai:
		EnemyData.AI.SLIME:
			_slime(delta)
		EnemyData.AI.SPIRIT:
			_spirit(delta)
		EnemyData.AI.CRAB:
			_crab(delta)
		EnemyData.AI.FISH:
			_fish(delta, wet)
		EnemyData.AI.FIREFLY:
			_firefly(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash = 0.15  # landed
	_was_on_floor = is_on_floor()
	if is_summon():
		_summon_tick(delta)
	else:
		_touch_player()
	_update_look()
	queue_redraw()


func _slime(delta: float) -> void:
	if not is_on_floor() and not _floating:
		if _hop_vx != 0.0:
			velocity.x = _hop_vx
		return
	if velocity.y >= 0.0 and _hop_vx != 0.0:
		_hop_vx = 0.0  # landed
		_moved()
	if is_summon():
		_summon_move(delta)
		return
	if _slither > 0.0:
		_slither -= delta
		velocity.x = _dir * data.slither_speed * TILE
		_step_up()
		if _slither <= 0.0:
			_moved()
		return
	velocity.x = move_toward(velocity.x, 0.0, 60.0 * TILE * delta)
	_wait -= delta
	if _wait < 0.18 and _wait + delta >= 0.18:
		_squash = 0.18  # gathering itself before the hop
	if _wait > 0.0:
		return
	_wait = randf_range(data.hop_wait_min, data.hop_wait_max)
	_move_from = global_position.x
	var target := _target_dir()
	if target != 0.0:
		_dir = target
	elif _stuck >= 2 or randf() < data.turn_chance:
		_dir = -_dir
		_stuck = 0
	if randf() < data.slither_chance and _stuck == 0:
		_slither = randf_range(data.slither_seconds_min, data.slither_seconds_max)
		return
	# A big hop when the last moves got nowhere (a wall in the way), else random.
	var height := data.hop_tiles if _stuck > 0 else randf_range(data.hop_tiles_min, data.hop_tiles)
	var launch := sqrt(2.0 * data.gravity * TILE * height * TILE)
	velocity = Vector2(_dir * data.hop_speed * TILE, -launch)
	_hop_vx = velocity.x
	EventBus.sound_requested.emit(&"slime_hop", global_position)


## -1 or 1 toward the player if it's chasing them, 0 if it's wandering. A summon goes
## after the nearest enemy, or back toward you when none is near.
func _target_dir() -> float:
	if is_summon():
		return _summon_dir()
	var p := world.player
	if p == null or p.dead:
		return 0.0
	var chasing := _angry or not data.wander_by_day or (world.spawner and world.spawner.is_night())
	if data.harmless_until_hit:
		chasing = _angry
	if not chasing and world.generator:
		var tile := world.world_to_tile(global_position)
		chasing = tile.y > world.generator.surface_at(tile.x) + 20  # underground
	if not chasing:
		return 0.0
	var dx := _wrapped_dx(p.global_position.x)
	if absf(dx) > data.aggro_tiles * TILE or dx == 0.0:
		return 0.0
	if absf(p.global_position.y - global_position.y) > data.aggro_tiles_vertical * TILE:
		return 0.0
	return signf(dx)


## A hop or slither ended: count it as stuck if it got less than a tile.
func _moved() -> void:
	_stuck = _stuck + 1 if absf(global_position.x - _move_from) < TILE else 0


## While slithering into a 1-tile ledge: pop up onto it if there's room.
func _step_up() -> void:
	var ahead := Vector2(_dir * 2.0, 0.0)
	if not test_move(global_transform, ahead):
		return
	var up := global_transform.translated(Vector2(0.0, -TILE - 0.5))
	if test_move(global_transform, Vector2(0.0, -TILE - 0.5)) or test_move(up, ahead):
		return
	global_position.y -= TILE + 0.5


# --- Crab ------------------------------------------------------------------------

## Scuttles sideways a little, stops, looks about, scuttles again. Once hit, it comes
## after you and pinches (its contact damage).
func _crab(delta: float) -> void:
	if not is_on_floor():
		return
	_wait -= delta
	if _slither > 0.0:
		_slither -= delta
		var target := _target_dir()
		if target != 0.0:
			_dir = target
		velocity.x = _dir * data.scuttle_speed * TILE * (1.5 if _angry else 1.0)
		_step_up()
		if absf(get_real_velocity().x) < 1.0 and _slither < 0.3:
			_dir = -_dir  # a wall: the other way next time
		if _slither <= 0.0:
			_wait = randf_range(data.rest_seconds_min, data.rest_seconds_max) * (0.3 if _angry else 1.0)
		return
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * TILE * delta)
	if _wait > 0.0:
		return
	if randf() < data.turn_chance:
		_dir = -_dir
	_slither = randf_range(data.scuttle_seconds_min, data.scuttle_seconds_max)


# --- Fish ------------------------------------------------------------------------

## A slime afloat on water (it can hop from there like from the ground).
var _floating := false
var _heading := Vector2.RIGHT
var _turn_left := 0.0


func _in_water() -> bool:
	return world.voxels != null and world.voxels.liquid_at(global_position + Vector2(0.0, -data.size.y * 0.5))


## Swims about in water, turning now and then and at the water's edge, and darts away
## from you. Out of water it flops.
func _fish(delta: float, wet: bool) -> void:
	if not wet:
		_slither = 0.0
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * TILE * delta)
			_wait -= delta
			if _wait <= 0.0:
				_wait = randf_range(0.4, 1.0)
				velocity = Vector2(randf_range(-3.0, 3.0), -randf_range(6.0, 12.0)) * TILE  # a flop
		return
	_turn_left -= delta
	var speed := data.swim_speed
	var p := world.player
	var away := Vector2.ZERO
	if p and not p.dead:
		var to_me := Vector2(_wrapped_dx(p.global_position.x) * -1.0, global_position.y - p.chest().y)
		if to_me.length() < data.flee_tiles * TILE:
			away = to_me.normalized()
	if away != Vector2.ZERO:
		_heading = away
		speed = data.flee_speed
		_turn_left = 0.6
	elif _turn_left <= 0.0:
		_turn_left = randf_range(data.turn_seconds_min, data.turn_seconds_max)
		_heading = Vector2(signf(randf() - 0.5), randf_range(-0.35, 0.35)).normalized()
	# Stay in the water: turn back before leaving it (sideways, or out the top).
	var ahead := global_position + Vector2(_heading.x * (data.size.x * 0.5 + 3.0), -data.size.y * 0.5 + _heading.y * 4.0)
	if not world.voxels.liquid_at(ahead):
		if not world.voxels.liquid_at(ahead + Vector2(0.0, 4.0)):
			_heading.x = -_heading.x
		_heading.y = absf(_heading.y) * 0.5  # back down from the surface
		_turn_left = minf(_turn_left, 0.8)
	velocity = velocity.lerp(_heading * speed * TILE, clampf(delta * 4.0, 0.0, 1.0))
	if get_slide_collision_count() > 0:
		_heading.x = -_heading.x
	if absf(velocity.x) > 1.0:
		_dir = signf(velocity.x)


# --- Firefly ---------------------------------------------------------------------

var _home := Vector2.INF
var _drift_to := Vector2.INF


## Drifts about near where it appeared, now and then picking a new spot, blinking.
func _firefly(delta: float) -> void:
	if _home == Vector2.INF:
		_home = global_position
	_turn_left -= delta
	if _drift_to == Vector2.INF or _turn_left <= 0.0 or global_position.distance_to(_drift_to) < 2.0 \
			or get_slide_collision_count() > 0:
		_turn_left = randf_range(1.0, 3.0)
		var r := data.drift_tiles * TILE
		_drift_to = _home + Vector2(randf_range(-r, r), randf_range(-r * 0.5, r * 0.5))
	var to := _drift_to - global_position
	var want := to.normalized() * data.drift_speed * TILE if to.length() > 1.0 else Vector2.ZERO
	want.y += sin(Time.get_ticks_msec() * 0.003 + get_instance_id()) * 3.0  # a little flutter
	velocity = velocity.lerp(want, clampf(delta * 2.0, 0.0, 1.0))
	if absf(velocity.x) > 1.0:
		_dir = signf(velocity.x)


## How bright a firefly's blink is now (0 to 1).
func blink() -> float:
	var t := fmod(Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 997) * 0.37, data.blink_seconds) / data.blink_seconds
	return clampf(sin(t * PI) * 1.4, 0.15, 1.0)


## A Bug Net swing: gone, its catch item in your bag (or dropped at your feet if full).
func catch(by: Player) -> bool:
	if data.catch_item == &"" or health <= 0.0:
		return false
	health = 0.0
	var left := by.character.inventory.add(data.catch_item, 1) if by and by.character else 1
	if left > 0:
		world.request_spawn_drop(data.catch_item, left, global_position, Vector2.ZERO)
	EventBus.sound_requested.emit(&"item_pickup", global_position)
	if world.character:
		world.character.note_kill(data.id, [data.catch_item])  # the Catalog
	if radius > 0.0 and world.lights:
		world.lights.mark_dirty()
	queue_free()
	return true


# --- Forest Spirit ------------------------------------------------------------------

enum SpiritState { DART, CHARGE, SHOT }
var _state := SpiritState.DART
var _state_left := 0.0
var _goal := Vector2.INF
var _aim := Vector2.ZERO
## Light it gives off (the "light_sources" group: the light map picks it up).
var radius := 0.0
var color := Color.WHITE
var _light_at := Vector2i(-1000000, 0)


## Darts to a spot near you (or wanders), stops and charges for a second, then shoots.
func _spirit(delta: float) -> void:
	velocity.y -= data.gravity * TILE * delta  # floats: undo the gravity added above
	_state_left -= delta
	var p := world.player
	var hunting := p != null and not p.dead and _player_in_range(data.aggro_tiles)
	match _state:
		SpiritState.DART:
			if _goal == Vector2.INF or _state_left <= 0.0:
				if _goal != Vector2.INF and hunting and _player_in_range(data.shot_tiles) and _sees_player():
					_state = SpiritState.CHARGE
					_state_left = data.charge_seconds
					EventBus.sound_requested.emit(&"bolt_charge", global_position)
				else:
					_pick_goal(hunting)
					_state_left = randf_range(data.dart_seconds_min, data.dart_seconds_max)
			var to := _goal - global_position if _goal != Vector2.INF else Vector2.ZERO
			var want := to.limit_length(data.dart_speed * TILE) if to.length() > 2.0 else Vector2.ZERO
			if to.length() < 24.0:
				want *= to.length() / 24.0  # ease in
			velocity = velocity.move_toward(want, data.dart_speed * TILE * 4.0 * delta)
		SpiritState.CHARGE:
			velocity = velocity.move_toward(Vector2.ZERO, data.dart_speed * TILE * 6.0 * delta)
			if p:
				_aim = Vector2(global_position.x + _wrapped_dx(p.chest().x), p.chest().y)
			if _state_left <= 0.0:
				_shoot()
				_state = SpiritState.SHOT
				_state_left = 0.35
		SpiritState.SHOT:
			velocity = velocity.move_toward(Vector2.ZERO, data.dart_speed * TILE * 6.0 * delta)
			if _state_left <= 0.0:
				_state = SpiritState.DART
				_goal = Vector2.INF


## Where its light comes from (the light map reads this).
## Where its light is, in tiles (fractional), for a smooth moving light.
func light_point() -> Vector2:
	return (global_position + Vector2(0, -data.size.y * 0.5)) / World.TILE


func light_tile() -> Vector2i:
	return world.world_to_tile(global_position + Vector2(0, -data.size.y * 0.5))


func _player_in_range(tiles: float) -> bool:
	var p := world.player
	return absf(_wrapped_dx(p.chest().x)) <= tiles * TILE and absf(p.chest().y - global_position.y) <= tiles * TILE


func _sees_player() -> bool:
	var p := world.player
	var at := Vector2(global_position.x + _wrapped_dx(p.chest().x), p.chest().y)
	return world.line_clear(global_position + Vector2(0, -data.size.y * 0.5), at)


## A new spot to dart to: beside you at a hovering height (hunting), or nearby.
func _pick_goal(hunting: bool) -> void:
	var x: float
	if hunting:
		var p := world.player
		var px := global_position.x + _wrapped_dx(p.chest().x)
		var side := -1.0 if randf() < 0.5 else 1.0
		x = px + side * randf_range(data.keep_tiles_min, data.keep_tiles_max) * TILE
	else:
		x = global_position.x + randf_range(-10.0, 10.0) * TILE
	var ground := _ground_below(Vector2(x, global_position.y - 6.0 * TILE))
	var up := randf_range(3.0, maxf(data.float_tiles, 3.5))
	_goal = Vector2(x, ground - up * TILE)


## World y (px) of the ground under a point (searching up to 40 tiles down).
func _ground_below(at: Vector2) -> float:
	var t := world.world_to_tile(at)
	for dy in 40:
		if world.is_solid(t + Vector2i(0, dy)):
			return (t.y + dy) * TILE
	return at.y + 10.0 * TILE


func _shoot() -> void:
	var from := global_position + Vector2(0, -data.size.y * 0.5)
	var dir := (_aim - from).normalized() if _aim != from else Vector2.LEFT
	var shot := EnemyShot.new()
	shot.setup(world, dir * data.shot_speed * TILE, data.shot_damage, data.shot_tiles * TILE, data.knockback, data.glow_color)
	shot.position = from
	world.effects.add_child(shot)
	EventBus.sound_requested.emit(&"bolt_fire", from)


func _wrapped_dx(x: float) -> float:
	var dx := x - global_position.x
	var w := world.data.width * TILE
	return dx - roundf(dx / w) * w


func _touch_player() -> void:
	var p := world.player
	if p == null or p.dead or health <= 0.0 or (data.harmless_until_hit and not _angry):
		return
	var body := p.body_rect()
	body.position.x = global_position.x + _wrapped_dx(body.position.x + body.size.x * 0.5) - body.size.x * 0.5
	if hit_rect().intersects(body):
		p.take_damage(data.contact_damage, &"enemy", global_position, data.knockback)


func _set_frame(i: int) -> void:
	var f := data.frame_size
	_sprite.region_rect = Rect2(i * f.x, 0, f.x, f.y)
	_sprite.position = Vector2(-f.x * 0.5, -f.y)


func _update_look() -> void:
	if data.ai == EnemyData.AI.SPIRIT:
		_set_frame(1 if _state == SpiritState.CHARGE else (2 if _state == SpiritState.SHOT else 0))
		var bob := sin(Time.get_ticks_msec() * 0.006 + get_instance_id()) * 0.06
		_sprite.scale = Vector2(1.0 + bob, 1.0 - bob)
		var f2 := data.frame_size
		_sprite.position = Vector2(-f2.x * 0.5 * _sprite.scale.x, -f2.y * 0.5 * _sprite.scale.y - data.size.y * 0.5)
		_sprite.modulate = data.tint if _flash <= 0.0 else Color(2.0, 2.0, 2.0)
		if _flash <= 0.0 and _poison_left > 0.0:
			_sprite.modulate = data.tint * Color(0.7, 1.15, 0.6)
		_tint_mark()
		if _halo:
			_halo.position = Vector2(0, -data.size.y * 0.5)
			var k := 0.0
			if _state == SpiritState.CHARGE:
				k = 1.0 - clampf(_state_left / maxf(data.charge_seconds, 0.01), 0.0, 1.0)
			elif _state == SpiritState.SHOT:
				k = 1.0
			_halo.strength = k
		return
	if data.ai == EnemyData.AI.CRAB or data.ai == EnemyData.AI.FISH:
		_critter_look()
		return
	if data.ai == EnemyData.AI.FIREFLY:
		var b := blink()
		_set_frame(0 if b > 0.5 else 1)
		_sprite.scale = Vector2(-1.0 if _dir < 0.0 else 1.0, 1.0)
		var f := data.frame_size
		_sprite.position = Vector2(-f.x * 0.5 * _sprite.scale.x, -f.y)
		_sprite.modulate = Color(1, 1, 1, 0.5 + 0.5 * b) if _flash <= 0.0 else Color(2, 2, 2)
		if _halo:
			_halo.position = Vector2(0, -data.size.y * 0.5)
			_halo.strength = b
		return
	if not is_on_floor() and not _floating:
		_set_frame(2)
		_sprite.scale = Vector2(0.92, 1.1)
	elif _squash > 0.0:
		_set_frame(1)
		_sprite.scale = Vector2(1.12, 0.85)
	elif _slither > 0.0:
		_set_frame(0)
		var w := sin(Time.get_ticks_msec() * 0.025) * 0.07
		_sprite.scale = Vector2(1.06 + w, 0.94 - w)  # a wobbling slither
	else:
		_set_frame(0)
		var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 0.03
		_sprite.scale = Vector2(breathe, 2.0 - breathe)
	# Keep the feet on the ground when squashing.
	var f := data.frame_size
	_sprite.position = Vector2(-f.x * 0.5 * _sprite.scale.x, -f.y * _sprite.scale.y)
	_sprite.modulate = data.tint if _flash <= 0.0 else Color(2.0, 2.0, 2.0)
	if _flash <= 0.0 and _poison_left > 0.0:
		_sprite.modulate = data.tint * Color(0.7, 1.15, 0.6)  # poisoned: green
	_tint_mark()


## Crabs: two walking frames while scuttling (frame 0 resting). Fish: two swimming
## frames, frame 2 flopping out of water; faces where it's going.
func _critter_look() -> void:
	var t := Time.get_ticks_msec()
	var f := data.frame_size
	_sprite.scale = Vector2.ONE
	if data.ai == EnemyData.AI.CRAB:
		_set_frame((1 + (t / 90) % 2) if _slither > 0.0 else 0)
	else:
		var wet := _in_water()
		_set_frame((t / 160) % 2 if wet else 2)
		_sprite.scale.x = -1.0 if _dir < 0.0 else 1.0
		_sprite.rotation = clampf(velocity.y / maxf(absf(velocity.x) + 30.0, 1.0), -0.5, 0.5) * _sprite.scale.x if wet else 0.0
	_sprite.position = Vector2(-f.x * 0.5 * _sprite.scale.x, -f.y)
	_sprite.modulate = data.tint if _flash <= 0.0 else Color(2.0, 2.0, 2.0)
	if _flash <= 0.0 and _poison_left > 0.0:
		_sprite.modulate = data.tint * Color(0.7, 1.15, 0.6)
	_tint_mark()


## Marked: flickers toward its school's color (Storm: a crackling blue).
func _tint_mark() -> void:
	if _flash > 0.0 or _mark_left <= 0.0:
		return
	var k := 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.04)
	_sprite.modulate = _sprite.modulate.lerp(Schools.color(_mark_school) * 1.4, k)


func _draw() -> void:
	# A Forest Spirit charging: sparks closing in on it.
	if data.ai == EnemyData.AI.SPIRIT and _state == SpiritState.CHARGE:
		var k := 1.0 - clampf(_state_left / maxf(data.charge_seconds, 0.01), 0.0, 1.0)
		var mid := Vector2(0, -data.size.y * 0.5)
		var r := lerpf(16.0, 7.0, k)
		var spin := Time.get_ticks_msec() * 0.004
		for i in 8:
			draw_circle(mid + Vector2.from_angle(spin + i * TAU / 8.0) * r, 1.0, Color(0.85, 0.95, 1.0, 0.4 + 0.6 * k))
	# The Command spell's target: a red reticle over it.
	if not is_summon() and world and world.summon_target == self:
		var at := Vector2(0, -data.size.y - 9.0)
		var red := Color(0.95, 0.38, 0.3, 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008))
		draw_arc(at, 3.5, 0.0, TAU, 12, red, 1.0)
		for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(at + d * 4.5, at + d * 6.5, red, 1.0)
	# Yours: a small gold cross over it.
	if is_summon():
		if summon_spell.summon_marker:
			var top := Vector2(0, -data.size.y - 5.0)
			var gold := Color(1.0, 0.86, 0.45, clampf(time_left / 3.0, 0.0, 1.0))
			draw_rect(Rect2(top + Vector2(-0.5, -2.5), Vector2(1, 5)), gold)
			draw_rect(Rect2(top + Vector2(-2.5, -0.5), Vector2(5, 1)), gold)
		return
	# Health bar once hurt (fades after a while).
	if health >= data.max_health or _since_hit > 6.0:
		return
	var w := maxf(data.size.x, 16.0)
	var y := -data.size.y - 6.0
	draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 4), Color(0, 0, 0, 0.6))
	var k := clampf(health / data.max_health, 0.0, 1.0)
	var c := Color("d83a3a").lerp(Color("6ad04a"), k)
	draw_rect(Rect2(-w * 0.5, y, w * k, 2), c)


# --- summon behavior --------------------------------------------------------------------

func _summon_target() -> Enemy:
	# Commanded (the Command spell): that one, while it's within reach of you.
	var told := world.commanded_target()
	if told and absf(_wrapped_dx(told.global_position.x)) + absf(told.global_position.y - global_position.y) \
			< SUMMON_LEASH_TILES * TILE:
		return told
	var best: Enemy = null
	var best_d := summon_spell.summon_tiles * TILE
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e.is_queued_for_deletion() or e.health <= 0.0 or not e.summon_should_attack():
			continue
		var d := absf(_wrapped_dx(e.global_position.x)) + absf(e.global_position.y - global_position.y) * 0.5
		if d < best_d:
			best_d = d
			best = e
	return best


## True when your summons go for this enemy: not other summons, and not critters (fish,
## crabs, fireflies) unless they've turned on you.
func summon_should_attack() -> bool:
	return not is_summon() and not (data.is_critter() and not _angry)


## Under water after an enemy: swims straight at it (no floating, no gravity). False
## when there's nothing in the water to go after (then it floats and hops as usual).
func _summon_dive(delta: float) -> bool:
	var target := _summon_target()
	if target == null or world.voxels == null:
		return false
	var mid := global_position + Vector2(0.0, -data.size.y * 0.5)
	var their := target.global_position + Vector2(0.0, -target.data.size.y * 0.5)
	var me_wet := world.voxels.liquid_at(mid)
	var them_wet := world.voxels.liquid_at(their)
	if not them_wet or not (me_wet or their.y > mid.y + TILE):
		return false
	if not me_wet and not _floating:
		return false  # on dry land: hop over to the water first
	var to := Vector2(_wrapped_dx(their.x), their.y - mid.y)
	var want := to.normalized() * summon_spell.summon_swim_speed * TILE
	velocity = velocity.move_toward(want, 40.0 * TILE * delta)
	_hop_vx = 0.0
	_dir = signf(to.x) if to.x != 0.0 else _dir
	return true


func _summon_dir() -> float:
	var target := _summon_target()
	if target:
		return signf(_wrapped_dx(target.global_position.x))
	var p := world.player
	if p == null or p.dead:
		return 0.0
	# Stay near you: a few tiles behind, by your side.
	var want := p.global_position.x - p.facing * (3.0 + slot * 2.5) * TILE
	var dx := _wrapped_dx(want)
	return signf(dx) if absf(dx) > 2.0 * TILE else 0.0


## Your slime on the ground: no random hops. With an enemy near it hops to land on it
## (aimed from the gap), or slides straight into it when close; otherwise it follows you.
func _summon_move(delta: float) -> void:
	var target := _summon_target()
	var dx := 0.0
	var dy := 0.0  # > 0: the target is above
	if target:
		dx = _wrapped_dx(target.global_position.x)
		dy = global_position.y - target.global_position.y
		_dir = signf(dx) if dx != 0.0 else _dir
		if absf(dx) < summon_spell.summon_ram_tiles * TILE and dy < TILE * 2.0:
			velocity.x = _dir * data.slither_speed * 2.0 * TILE  # into it
			_step_up()
			_wait = minf(_wait, summon_spell.summon_hop_wait)
			return
	else:
		var dir := _summon_dir()
		if dir == 0.0:
			velocity.x = move_toward(velocity.x, 0.0, 60.0 * TILE * delta)
			return  # next to you: rest
		_dir = dir
		var p := world.player
		dx = _wrapped_dx(p.global_position.x)
		dy = global_position.y - p.global_position.y
	velocity.x = move_toward(velocity.x, 0.0, 60.0 * TILE * delta)
	_wait -= delta
	if _wait < 0.12 and _wait + delta >= 0.12:
		_squash = 0.12
	if _wait > 0.0:
		return
	_wait = summon_spell.summon_hop_wait if target else data.hop_wait_min
	_move_from = global_position.x
	# High enough to clear the gap upward (and walls, once stuck), then the sideways
	# speed that lands it on the spot.
	var g := data.gravity * TILE
	var height := clampf(dy / TILE + 1.5, data.hop_tiles_min, data.hop_tiles * 1.5)
	if _stuck > 0:
		height = maxf(height, data.hop_tiles)
	var launch := sqrt(2.0 * g * height * TILE)
	var t_up := launch / g
	var fall := maxf(height * TILE - dy, 0.0)
	var t := t_up + sqrt(2.0 * fall / g)
	var max_vx := data.hop_speed * summon_spell.summon_hop_reach * TILE
	var vx := clampf(dx / maxf(t, 0.05), -max_vx, max_vx)
	if absf(vx) < data.hop_speed * 0.4 * TILE:
		vx = _dir * data.hop_speed * 0.4 * TILE
	velocity = Vector2(vx, -launch)
	_hop_vx = vx
	EventBus.sound_requested.emit(&"slime_hop", global_position)


func _summon_tick(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -data.size.y - 6), "*pop*", Color("9ae88a"))
		queue_free()
		return
	var p := world.player
	if p and not p.dead and absf(_wrapped_dx(p.global_position.x)) + absf(p.global_position.y - global_position.y) > SUMMON_LEASH_TILES * TILE:
		global_position = p.global_position + Vector2(-p.facing * 2.0 * TILE, -TILE)  # caught up
		velocity = Vector2.ZERO
	for e: Variant in _hit_wait.keys():
		_hit_wait[e] = float(_hit_wait[e]) - delta
		if _hit_wait[e] <= 0.0 or not is_instance_valid(e):
			_hit_wait.erase(e)
	var me := hit_rect()
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e.health <= 0.0 or _hit_wait.has(e):
			continue
		var r := e.hit_rect()
		r.position.x = global_position.x + _wrapped_dx(r.position.x + r.size.x * 0.5) - r.size.x * 0.5
		if me.intersects(r):
			e.take_damage(summon_damage, self)
			e.knock_back(global_position, data.knockback * 0.6)
			_hit_wait[e] = SUMMON_HIT_EVERY
