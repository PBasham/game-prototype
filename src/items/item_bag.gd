class_name ItemBag
extends Node2D
## A magic bag holding a character's items after they died (world option DeathDrop.BAG,
## like Valheim's tombstone). It's tossed up where they fell, then falls, bounces and
## settles like a Terraria tombstone. Right click or E opens it (a window like a chest,
## with Take all). It vanishes once empty. Saved with the world.

const TEXTURE := "res://assets/objects/magic_bag.png"

## Tiles/s² pulling it down.
@export var gravity := 120.0
## Share of the downward speed kept when it hits the ground (0 = no bounce).
@export var bounce := 0.35
## Below this landing speed (tiles/s) it stops bouncing and settles.
@export var settle_speed := 4.0
## Sideways slow-down on the ground (tiles/s²).
@export var ground_friction := 30.0

var world: World
var inventory: Inventory
## Whose items these were (shown as the window title).
var owner_name := ""
var velocity := Vector2.ZERO
var resting := false
var _sprite: Sprite2D
var _time := 0.0


## `vel` in px/s.
func setup(w: World, inv: Inventory, who: String, vel: Vector2) -> void:
	world = w
	inventory = inv
	owner_name = who
	velocity = vel


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"item_bags")
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEXTURE) as Texture2D
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)
	z_index = 2
	inventory.changed.connect(_on_changed)


func _on_changed() -> void:
	if inventory.is_all_empty():
		queue_free()


func _physics_process(delta: float) -> void:
	_time += delta
	# A soft magical pulse.
	var glow := 0.85 + 0.15 * sin(_time * 3.0)
	_sprite.modulate = Color(glow + 0.1, glow, 1.0)
	if resting:
		return
	const TILE := World.TILE
	velocity.y = minf(velocity.y + gravity * TILE * delta, 90.0 * TILE)
	var grounded := world.collision_at(global_position + Vector2(0, 1)) != TileDef.Collision.NONE and velocity.y >= 0.0
	if grounded:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * TILE * delta)
	var next := global_position + velocity * delta
	# Sideways: bounce off solid blocks.
	if world.collision_at(Vector2(next.x + signf(velocity.x) * 5.0, global_position.y - 3.0)) == TileDef.Collision.SOLID:
		velocity.x = -velocity.x * 0.3
		next.x = global_position.x
	# Down: land on blocks and platforms, bouncing until it's slow enough.
	if velocity.y > 0.0:
		var c := world.collision_at(next)
		var was_above := floori(global_position.y / TILE) < floori(next.y / TILE)
		if c == TileDef.Collision.SOLID or (c == TileDef.Collision.PLATFORM and was_above):
			next.y = floorf(next.y / TILE) * TILE
			if velocity.y > settle_speed * TILE:
				velocity.y = -velocity.y * bounce
				velocity.x *= 0.6
			else:
				velocity = Vector2.ZERO
				resting = true
	elif world.collision_at(next + Vector2(0, -11.0)) == TileDef.Collision.SOLID:
		velocity.y = 0.0  # bumped its head
		next.y = global_position.y
	global_position = next


func interact_rect() -> Rect2:
	return Rect2(global_position + Vector2(-7, -13), Vector2(14, 14))


func interact(_who: Player) -> void:
	world.bag_opened.emit(self)


func to_dict() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y, "owner": owner_name, "items": inventory.to_dict()}


static func from_dict(w: World, d: Dictionary) -> ItemBag:
	var inv := Inventory.new()
	inv.from_dict(d.get("items", {}))
	var bag := ItemBag.new()
	bag.setup(w, inv, str(d.get("owner", "")), Vector2.ZERO)
	bag.position = Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
	bag.resting = true  # it had settled (the ground there may not be loaded yet)
	return bag
