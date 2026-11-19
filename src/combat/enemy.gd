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


func setup(w: World, d: EnemyData) -> void:
	world = w
	data = d
	health = d.max_health


func _ready() -> void:
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


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-data.size.x * 0.5, -data.size.y), data.size)


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


## Pushed away from `from` (px position) at `strength` tiles/s.
func knock_back(from: Vector2, strength: float) -> void:
	var k := strength * (1.0 - data.knockback_resist)
	if k <= 0.0:
		return
	var dir := signf(global_position.x - from.x)
	velocity = Vector2((dir if dir != 0.0 else 1.0) * k * TILE, -k * 0.6 * TILE)
	_hop_vx = 0.0
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
	for item_id: StringName in drops:
		world.request_spawn_drop(item_id, drops[item_id], global_position + Vector2(0, -data.size.y * 0.5),
			Vector2(randf_range(-3, 3), -6) * TILE)
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -data.size.y - 10), "*pop*", Color("9ae88a"))
	queue_free()


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_since_hit += delta
	_squash = maxf(_squash - delta, 0.0)
	velocity.y = minf(velocity.y + data.gravity * TILE * delta, 90.0 * TILE)
	match data.ai:
		EnemyData.AI.SLIME:
			_slime(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_squash = 0.15  # landed
	_was_on_floor = is_on_floor()
	_touch_player()
	_update_look()
	queue_redraw()


func _slime(delta: float) -> void:
	if not is_on_floor():
		if _hop_vx != 0.0:
			velocity.x = _hop_vx
		return
	if velocity.y >= 0.0:
		_hop_vx = 0.0  # landed
	velocity.x = move_toward(velocity.x, 0.0, 60.0 * TILE * delta)
	_wait -= delta
	if _wait < 0.18 and _wait + delta >= 0.18:
		_squash = 0.18  # gathering itself before the hop
	if _wait > 0.0:
		return
	var dir := float([-1, 1].pick_random())
	var p := world.player
	if p and not p.dead:
		var dx := _wrapped_dx(p.global_position.x)
		if absf(dx) <= data.aggro_tiles * TILE or _angry:
			dir = signf(dx) if dx != 0.0 else dir
	var launch := sqrt(2.0 * data.gravity * TILE * data.hop_tiles * TILE)
	velocity = Vector2(dir * data.hop_speed * TILE, -launch)
	_hop_vx = velocity.x
	EventBus.sound_requested.emit(&"slime_hop", global_position)
	_wait = randf_range(data.hop_wait_min, data.hop_wait_max)


func _wrapped_dx(x: float) -> float:
	var dx := x - global_position.x
	var w := world.data.width * TILE
	return dx - roundf(dx / w) * w


func _touch_player() -> void:
	var p := world.player
	if p == null or p.dead or health <= 0.0:
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
	if not is_on_floor():
		_set_frame(2)
		_sprite.scale = Vector2(0.92, 1.1)
	elif _squash > 0.0:
		_set_frame(1)
		_sprite.scale = Vector2(1.12, 0.85)
	else:
		_set_frame(0)
		var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.004 + get_instance_id()) * 0.03
		_sprite.scale = Vector2(breathe, 2.0 - breathe)
	# Keep the feet on the ground when squashing.
	var f := data.frame_size
	_sprite.position = Vector2(-f.x * 0.5 * _sprite.scale.x, -f.y * _sprite.scale.y)
	_sprite.modulate = data.tint if _flash <= 0.0 else Color(2.0, 2.0, 2.0)


func _draw() -> void:
	# Health bar once hurt (fades after a while).
	if health >= data.max_health or _since_hit > 6.0:
		return
	var w := maxf(data.size.x, 16.0)
	var y := -data.size.y - 6.0
	draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 4), Color(0, 0, 0, 0.6))
	var k := clampf(health / data.max_health, 0.0, 1.0)
	var c := Color("d83a3a").lerp(Color("6ad04a"), k)
	draw_rect(Rect2(-w * 0.5, y, w * k, 2), c)
