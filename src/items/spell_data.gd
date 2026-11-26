class_name SpellData
extends ItemData
## A spell (data/spells/<id>.tres). Spells are learned by the character, put in quick
## slots (the Q and E wheels, Z X C, the buff set on B) and cast from there, or from a
## tome. The equipped book and conduit multiply every spell's strength (spell_power)
## and reach (spell_reach_bonus); the book's tier limit still applies.
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
##   BUFF        a timed effect on you (`effect`, for `duration` seconds), shown as an
##               icon by the health panel. Casting again refreshes it. Effects:
##               &"gel_cushion" (the next fall that would hurt doesn't; then it ends),
##               &"arcane_edge" (melee damage x `melee_mult`), &"barrier" (reactive:
##               when a hit would take you under `trigger_health`, a shield of
##               `shield_amount` pops for `shield_seconds`; then it ends).
##   CHARGED     hold to charge (up to `charge_seconds`), let go to fire a bolt; damage,
##               size and mana grow with the charge (Arcane Bolt).
##   ZONE        a circle at the cursor (`zone_tiles`) for `duration`; heals you by
##               `heal_per_second` while you stand in it (Healing Circle).
##   WARD        a rune on the ground under the cursor for `duration`; the first enemy
##               to touch it takes `damage` and `knockback` (Spark Ward). Up to
##               `max_active`.
##   SUMMON      a familiar that follows you for `duration` and shoots the nearest enemy
##               within `summon_tiles` every `summon_interval` s for `damage` (Familiar).
##   CONJURE     a platform `conjure_tiles` wide at the cursor for `duration` (Conjure
##               Platform). Only in open air; drops nothing.
##   CHAIN       a bolt shoots toward the cursor (out to reach); the first thing it touches
##               is hit, then it jumps up to
##               `chain_jumps` more within `chain_tiles`, losing `chain_falloff` each jump.
##   RITUAL      stand still for `ritual_seconds` (moving or getting hurt cancels it), then
##               it happens: Recall (&"recall" effect) sends you to your bed or the world
##               spawn. Mana is spent when it completes.
##   SENSE       shows `sense_block` tiles within `sense_tiles` through everything, for
##               `duration` seconds (Seek Ore).
##   GRAB        held like a beam: a portal opens at the cursor (out to reach) and pulls
##               loose items within `grab_tiles` of it into a second portal at your
##               hand (Tele Grab). Mana per second while held.
##   LIGHT       a floating light for `duration` seconds: follows you (Light Orb), or with
##               `light_placed` you steer it while the button is held and it stays where
##               you let go (Wisp).
##
## Casting animation: the "spell" item type (book in the back hand, the front hand
## channels at the cursor). Its Channel motion (0.3 s) is the time between casts.

enum Cast { TOOL, PROJECTILE, TOGGLE, GUST, BLINK, LIGHT, BUFF, CHARGED, ZONE, WARD, SUMMON, CONJURE,
	CHAIN, RITUAL, SENSE, GRAB }

## Spell Index tabs.
enum Group { TOOLS, MOVEMENT, ATTACK, DEFENSE, LIGHT }
const GROUP_NAMES: Array[String] = ["Tools", "Movement", "Attack", "Defense", "Light"]

@export var cast := Cast.TOOL
@export var group := Group.ATTACK
## Listed in the Spell Weaving Table's Spells tab for its learn_cost. Off for spells you
## can only learn from a scroll you find: they show up there while you carry one.
@export var learnable_at_table := true
## Its "Learn" recipe at the table stays hidden until you've had one of these items
## (Summon Forest Spirit: its Spell Page). Empty = always shown.
@export var learn_unlock_items: Array[StringName] = []
## Reading its Spell Page doesn't teach it: take the page to the Spell Weaving Table
## (its learn_cost includes the page). The page's tooltip says so.
@export var page_needs_table := false
## From a quick slot (Q/E wheels, Z X C): 0 = by cast (see casts_from_quick_slot),
## 1 = cast right away, 2 = put it in your hand. The player can flip it per slot.
@export_enum("By cast", "Cast right away", "Put in hand") var quick_default := 0
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
## Readied jump spells (effect air_step or bound): turned on like Fly, but they cost
## nothing until you press Jump in the air; then they spend mana_cost once, and the
## landing after can't hurt you. One per jump (it re-arms when you land).
## air_step: a second jump (air_jump_power times a normal one), with air_control_mult
## faster steering and air_speed_mult more top speed until you land.
@export var air_jump_power := 1.0
@export var air_control_mult := 1.8
@export var air_speed_mult := 1.15
## bound: a long leap forward in an arc (leap_speed tiles/s ahead, rising leap_height
## tiles under normal gravity, wherever in the air you press it), the momentum kept
## until you land (steer against it to slow down).
@export var leap_speed := 48.0
@export var leap_height := 4.0
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

@export_group("Charged (Arcane Bolt)")
## Seconds to full charge. Damage, bolt size and mana go from the `charge_min_*` share
## (at a tap) to full (`damage`, `mana_cost`) at a full charge.
@export var charge_seconds := 1.5
@export var charge_min_damage := 0.2
@export var charge_min_mana := 0.27

@export_group("Zone, ward, summon, conjure")
## Zone radius (tiles).
@export var zone_tiles := 5.0
## Spells made at the cursor (zones, wards, familiars, platforms) need a clear line from
## you to it: no casting through walls or closed doors. An upgrade could turn it off.
@export var needs_sight := true
## Zones, wards and familiars you can have out at once (a new one replaces the oldest).
## Healing Circle is 1, so casting it again moves it instead of stacking the healing.
@export var max_active := 3
## Familiar: shots every this many seconds, at enemies within this many tiles.
@export var summon_interval := 1.0
## A summon drawn from a sprite sheet instead of the little orb (Summon Forest Spirit: the Forest
## Spirit's 3 frames: idle, charging, shooting), and how long it charges before each
## shot (sparks close in; 0 = shoots right away).
@export var summon_texture: Texture2D
@export var summon_frame_size := Vector2i(24, 24)
## Tints the summon's art (the summoned Forest Spirit leans a little teal, so you can
## tell yours apart).
@export var summon_tint := Color.WHITE
## A little gold cross over your summon: it's yours.
@export var summon_marker := false
## A melee summon: an enemy that fights for you (Summon Slime) instead of a floating
## orb. One per Evolve empower rank (rank 0 = the first): Green, then Blue Slime, and
## more as slimes are added. It hops after enemies and hits on contact for `damage`
## (times its contact damage over the first one's: a Blue Slime hits harder).
@export var summon_enemy_ranks: Array[StringName] = []

@export_group("Phantom tool (gathering spells)")
## A beam spell with this draws a see-through tool at the target that swings, and the
## mining or chopping lands once per swing (`phantom_swing_time`) instead of smoothly.
@export var phantom_texture: Texture2D
## Seconds per swing: the tool appears, strikes and fades in this time.
@export var phantom_swing_time := 0.3
## When in the swing (0 to 1) it lands: the hit happens here.
@export_range(0.3, 1.0) var phantom_impact := 0.8
## How it swings (PhantomTool.Style): ARC (a crescent streak), ECHO (afterimages),
## COMET (drops from above, spinning).
@export var phantom_style := 0
## Where the grip and the striking point are in the tool's art (fractions of its size):
## the pick's point, the axe's edge. The strike lands that point on the middle of the
## target.
@export var phantom_grip := Vector2(0.08, 0.92)
@export var phantom_tip := Vector2(0.88, 0.48)
## The tool's glow by rank: `gather_rank` picks one (the Empower Power node raises it),
## so copper and iron ranks show their metal.
@export var phantom_tints: Array[Color] = []
@export var gather_rank := 0
## Melee summon: seconds between hops while it has an enemy (no random waits), and how
## close (tiles) it gets before it slides straight into the enemy instead of hopping.
@export var summon_hop_wait := 0.35
@export var summon_ram_tiles := 2.5
## Melee summon: sideways speed of an aimed hop is capped at the slime's hop speed
## times this, so it can land on enemies a bit further off.
@export var summon_hop_reach := 1.6
@export var summon_charge := 0.0
@export var summon_tiles := 15.0
## Conjure Platform: width in tiles.
@export var conjure_tiles := 6

@export_group("Imbue and reactive")
## Arcane Edge: melee damage multiplier.
@export var melee_mult := 1.5
## Barrier: pops when a hit would leave you under this share of max health, giving a
## shield that soaks this much damage for this many seconds.
@export var trigger_health := 0.25
@export var shield_amount := 30.0
@export var shield_seconds := 10.0

@export_group("Chain, ritual, sense")
## Chain Spark: extra jumps, how far each jump reaches (tiles), damage lost per jump.
@export var chain_jumps := 3
@export var chain_tiles := 6.0
@export var chain_falloff := 0.2
## Ritual: seconds standing still.
@export var ritual_seconds := 3.0
## Seek Ore: which block to show, and how far (tiles).
@export var sense_block: StringName = &"copper_ore"
@export var sense_tiles := 30.0

@export_group("Grab (Tele Grab)")
## How close to the portal (tiles) loose items are pulled in, and how fast they fly to
## it (tiles per second).
@export var grab_tiles := 3.0
@export var grab_pull_speed := 18.0

@export_group("Blink")
## Farthest teleport, in tiles.
@export var blink_tiles := 12.0

@export_group("Light")
## Light Orb and Wisp: light radius (tiles) and color. `duration`: seconds a light or a
## BUFF lasts.
@export var light_radius := 36.0
@export var light_color := Color(1.0, 0.92, 0.75)
@export var duration := 180.0
## Wisp: hold the button to steer the light with the cursor, let go to leave it there
## (instead of following you). Up to `light_max` at once; the oldest goes first.
@export var light_placed := false
@export var light_max := 3

@export_group("Mana")
## Mana per cast, and per second while a beam is held or a concentration spell is on.
@export var mana_cost := 0.0
@export var mana_per_second := 0.0
## Items used up by each cast (item id to count), e.g. Gel Cushion: 5 Slime. It can't be
## cast without them.
@export var reagents: Dictionary[StringName, int] = {}
## Learning it from a scroll (right click, at a Spell Weaving Table) also uses these.
@export var learn_cost: Dictionary[StringName, int] = {}
@export_group("")


func is_spell() -> bool:
	return true


## From a quick slot by default: true = cast right away (buffs, blinks, wards and the
## like, aimed at the cursor), false = put it in your hand (things you aim and hold:
## tools, bolts, charged and chained bolts, steered lights).
func casts_from_quick_slot() -> bool:
	if quick_default != 0:
		return quick_default == 1
	match cast:
		Cast.TOOL, Cast.PROJECTILE, Cast.CHARGED, Cast.CHAIN:
			return false
		Cast.LIGHT:
			return not light_placed
	return true


## Whether it can be your movement spell (the Movement slot): a movement toggle you
## stay in (Fly, Levitate).
func fits_movement_slot() -> bool:
	return cast == Cast.TOGGLE and group == Group.MOVEMENT


## Whether it can go in the buff set (B): Buff spells only: a timed effect on you (buffs, a following
## light, a familiar).
func fits_buff_set() -> bool:
	return cast == Cast.BUFF  # only buffs (Patrick)
