class_name Familiar
extends Node2D
## The Familiar spell: a little orb that floats behind your shoulder for `duration` and
## shoots a bolt at the nearest enemy within `summon_tiles` every `summon_interval`
## seconds. One at a time; casting again replaces it.

## Where it floats, relative to the player's feet (x flips with facing).
@export var offset := Vector2(-16.0, -58.0)
@export var follow := 5.0

var world: World
var spell: SpellData
var power := 1.0
var time_left := 60.0
var _cooldown := 0.5
## Charging up a shot (summon_charge): time left, and at whom.
var _charge_left := -1.0
var _charge_target: Enemy
var _shot_flash := 0.0


func setup(w: World, s: SpellData, spell_power: float) -> void:
	world = w
	spell = s
	power = spell_power
	time_left = s.duration
	global_position = _target()
	z_index = 25
	add_to_group(&"familiars")


func _target() -> Vector2:
	var p := world.player
	return p.global_position + Vector2(offset.x * p.facing, offset.y + sin(Time.get_ticks_msec() * 0.004) * 2.0)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	global_position = global_position.lerp(_target(), minf(follow * delta, 1.0))
	_cooldown -= delta
	_shot_flash = maxf(_shot_flash - delta, 0.0)
	if _charge_left >= 0.0:
		_charge_left -= delta
		if _charge_left < 0.0:
			if is_instance_valid(_charge_target) and not _charge_target.is_queued_for_deletion():
				_shoot(_charge_target)
			_charge_target = null
	elif _cooldown <= 0.0:
		var target := nearest_enemy()
		if target:
			_cooldown = spell.summon_interval
			if spell.summon_charge > 0.0:
				_charge_left = spell.summon_charge
				_charge_target = target
			else:
				_shoot(target)
	queue_redraw()


func _shoot(target: Enemy) -> void:
	var dir := (target.hit_rect().get_center() - global_position).normalized()
	world.request_spawn_projectile(spell, global_position, dir, power, world.player)
	EventBus.sound_requested.emit(&"familiar_shot", global_position)
	_shot_flash = 0.3


## The nearest enemy within range, or null.
func nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := spell.summon_tiles * World.TILE
	for e in world.enemies():
		var d := e.hit_rect().get_center().distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	var c := spell.projectile_color
	var fade := clampf(time_left / 3.0, 0.0, 1.0)
	if spell.summon_texture:
		var fs := Vector2(spell.summon_frame_size)
		var frame := 1 if _charge_left >= 0.0 else (2 if _shot_flash > 0.0 else 0)
		draw_texture_rect_region(spell.summon_texture, Rect2(-fs * 0.5, fs),
			Rect2(Vector2(frame * fs.x, 0), fs), Color(1, 1, 1, fade))
		if _charge_left >= 0.0:
			var k := 1.0 - clampf(_charge_left / spell.summon_charge, 0.0, 1.0)
			var spin := Time.get_ticks_msec() * 0.004
			for i in 8:
				draw_circle(Vector2.from_angle(spin + i * TAU / 8.0) * lerpf(16.0, 7.0, k), 1.0,
					Color(0.85, 0.95, 1.0, (0.4 + 0.6 * k) * fade))
		return
	draw_circle(Vector2.ZERO, 4.0, Color(c, 0.25 * fade))
	draw_circle(Vector2.ZERO, 2.2, Color(c.lightened(0.3), fade))
	# Two little eyes, looking where you face.
	var f := float(world.player.facing) if world and world.player else 1.0
	draw_rect(Rect2(Vector2(0.5 * f - 1.0, -1.0), Vector2(1, 1)), Color(0.1, 0.05, 0.2, fade))
	draw_rect(Rect2(Vector2(0.5 * f + 0.5, -1.0), Vector2(1, 1)), Color(0.1, 0.05, 0.2, fade))
