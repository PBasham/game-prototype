class_name SpellData
extends ItemData
## A spell (data/spells/<id>.tres). Spells are learned by the character, put into the
## equipped spellbook's slots, and cast with the book out (R), from the spell wheel
## (hold R), a hotbar shortcut, or a tome. The book and conduit multiply their strength
## (spell_power) and reach (spell_reach_bonus).
##
## How a spell works is `cast`:
##   TOOL        works on the world like a tool, with ItemData's fields: mining
##               (mining_damage) or chopping (axe_damage), as a beam while held (`beam`)
##               or once per cast. Left click: front layer; right click: back layer.
##   PROJECTILE  fires a projectile at the cursor that hurts what it hits (`damage`).
##   TOGGLE      a concentration spell: a click turns its effect on or off (`effect`:
##               &"fly", &"levitate", &"mend"). Only one is active at a time.
##   GUST        a push in a cone toward the cursor (Air Push): shoves and hurts what's
##               in it; in the air it pushes you back a little.
##   BLINK       teleports you toward the cursor, up to `blink_tiles`, to the farthest
##               spot you fit.
##   LIGHT       a floating light that follows you for `duration` seconds (Light Orb).
##
## Casting animation: the "spell" item type (book in the back hand, the front hand
## channels at the cursor). Its Channel motion (0.3 s) is the time between casts.

enum Cast { TOOL, PROJECTILE, TOGGLE, GUST, BLINK, LIGHT }

@export var cast := Cast.TOOL
## How powerful the spell is. The equipped book's max_spell_tier must be at least this.
@export var tier := 1
## Needs an equipped conduit of this type (empty = any or none).
@export var requires_conduit: StringName = &""
## Seconds before it can be cast again (0 = only the casting animation limits it).
@export var cooldown := 0.0

@export_group("Projectile")
## Damage dealt on a hit (times spell power).
@export var damage := 0.0
## Tiles per second.
@export var projectile_speed := 40.0
## Tiles it flies before fizzling.
@export var projectile_range := 20.0
@export var projectile_color := Color(1.0, 0.9, 0.4)

@export_group("Toggle (concentration)")
## What the spell does while it's on: &"fly", &"levitate" or &"mend".
@export var effect: StringName = &""
## Fly and Levitate: tiles per second.
@export var move_speed := 0.0
## Fly: holding the run key (Shift) while moving multiplies the speed by this (1 = no
## boost) and the mana per second by boost_mana_mult. An empowerment later; on for now.
@export var boost_speed_mult := 1.0
@export var boost_mana_mult := 1.0
## Levitate: tiles above the ground it hovers at.
@export var hover_tiles := 5.0
## Mend: health per second while on (times spell power).
@export var heal_per_second := 0.0

@export_group("Gust (Air Push)")
## Tiles the cone reaches, and its half angle in degrees.
@export var gust_tiles := 8.0
@export var gust_angle := 35.0
## Push on what it hits (tiles/s), and the push back on you while airborne.
@export var gust_push := 24.0
@export var gust_recoil := 12.0

@export_group("Blink")
## Farthest teleport, in tiles.
@export var blink_tiles := 12.0

@export_group("Light")
## Light Orb: light radius (tiles), color and how long it lasts (seconds).
@export var light_radius := 10.0
@export var light_color := Color(1.0, 0.92, 0.75)
@export var duration := 180.0

@export_group("Mana")
## Mana per cast, and per second while a beam is held or a concentration spell is on.
@export var mana_cost := 0.0
@export var mana_per_second := 0.0
@export_group("")


func is_spell() -> bool:
	return true
