class_name BreakDust
extends CPUParticles2D
## A small puff of dust where a block or wall breaks, in the block's colors (World
## spawns one in `_damage_tile`). Frees itself when done.

## How many specks, how long they live (s), and how far they drift (px per second).
const SPECKS := 14
const LIFE := 0.55
const SPEED := 22.0


static func spawn(parent: Node, at: Vector2, color: Color) -> BreakDust:
	var d := BreakDust.new()
	d.position = at
	d.amount = SPECKS
	d.lifetime = LIFE
	d.one_shot = true
	d.explosiveness = 0.9
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2(World.TILE * 0.5, World.TILE * 0.5)
	d.direction = Vector2(0, -1)
	d.spread = 70.0
	d.initial_velocity_min = SPEED * 0.4
	d.initial_velocity_max = SPEED
	d.gravity = Vector2(0, 40)
	d.damping_min = 20.0
	d.damping_max = 40.0
	d.scale_amount_min = 1.0
	d.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.15), 0.9))
	ramp.set_color(1, Color(color.darkened(0.2), 0.0))
	d.color_ramp = ramp
	d.color = Color.WHITE
	parent.add_child(d)
	d.emitting = true
	d.finished.connect(d.queue_free)
	return d
