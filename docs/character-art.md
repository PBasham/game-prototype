# Character art and the paper doll

How the character is drawn in game and how to make art for it. The Scholar is drawn as
a **paper doll**: each body layer of `art/Scholar-casual.aseprite` is its own sprite,
and code decides which frame each part shows.

- **Code:** `src/player/doll/` (`paper_doll.gd`, `doll_rig.gd`, `item_motion.gd`,
  `arm_track.gd`, `item_type_data.gd`, `held_item_look.gd`, `character_look.gd`,
  `palette_swap.gdshader`)
- **Item types (hold and attack animations):** `data/item_types/*.tres`
- **Try it:** main menu, **Doll Viewer** (debug builds), or `-- --scene=doll`
- **Tests:** `tests/unit/test_paper_doll.gd`

## The workflow

1. Edit `art/Scholar-casual.aseprite`.
2. Re-import:
   ```
   godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
   ```
3. If you changed or added colors, rebuild the palette (see Colors below):
   ```
   godot --headless --path . --script res://tools/make_character_palette.gd
   ```
4. Open the Doll Viewer to check every pose at once, then play.

Nothing else needs to change: new tags and layers are picked up automatically.

## Layers

Each visible layer becomes a part. The importer skips hidden layers, group layers, and
layers named `backdrop` or `Ref`. Parts draw in the same order as in Aseprite (bottom
layer first).

The **layer name** decides which channel a part belongs to:

| Name contains | Channel | Animates with |
| --- | --- | --- |
| `Leg`, `Foot` | legs | the movement animation |
| `Arm`, `Hand` + `Front` | front arm | the arm mode (below) |
| `Arm`, `Hand` + `Back` | back arm | the arm mode |
| anything else (`Torso`, `Head`) | body | follows the legs' frame |

Each arm must be two layers, `<Front|Back> Arm Upper` and `<Front|Back> Arm Lower`.
That's what lets code bend the elbow. Your file already works this way.

## Tags

Tags name animations. A tag with no prefix applies to every channel; a prefixed tag
applies to one channel and wins over the plain one for that channel.

| Tag | Used for |
| --- | --- |
| `Breath` | Standing still |
| `Jog` | Moving (playback speed follows how fast you move). Plays in reverse when walking backwards while aiming. |
| `Jump` | In the air. Frames are picked from the arc, not a timer (see guide.md, Player animation). |
| `Idle Pose` | Climbing (for now). Its first frame is also the **rest frame** for code-posed arms unless `arms/Rest` exists. |
| `Land` | Optional. Brief landing pose. Without it, code drops the upper body 2 px (`land_dip`). |
| `Stand` | Optional, recommended. **Side-view** standing pose, used when standing still with an item out or while attacking. Without it, the last frame of `Jump` (legs together) is held instead (`stance_fallback_anim` / `stance_fallback_frame` on the Player). |

**Arm tags** (all optional; until they exist, arms are code-posed):

| Tag | When | Notes |
| --- | --- | --- |
| `arms/Rest` | Reference pose for code posing | One frame, arms hanging straight down. Defaults to the first `Idle Pose` frame. |
| `arms/Jog`, `arms/Breath`, ... | Empty hands | Override the arms of that movement animation only. |
| `arms/<type>/<motion>` | That motion for a whole item type | e.g. `arms/sword/Slash`, `arms/crossbow/Hold`, `arms/bow/Draw`. Frames spread across the motion's duration. |
| `arms/<item id>/<motion>` | One specific item | Beats the type's frames. |
| `arms/Hold1H`, `arms/Hold2H`, `arms/Use` | Generic fallbacks | Used by types whose motions name them (tools, swords). |

Similarly `body/<anim>` overrides the torso and head, and `legs/<anim>` the legs.

**What to draw for an arm tag:** draw only the arm layers on those frames (the other
layers can be anything; they're ignored for arm tags). Keep the shoulder where it is in
the rest frame.

## Arms: natural, holding, attacking

The arms follow the movement animation unless a **motion** is playing:

- **Holding** an item plays its type's `hold` motion (looped).
- **Attacking/using** plays one of its type's `attacks` (see Item types below).

A motion plays **hand-drawn frames** if the art has them, else **code poses** the arms
from the motion's curves. The doll looks for drawn frames in this order, and uses the
first tag that exists (frames are spread across the motion):

1. `arms/<item id>/<motion name>`, for one specific item, e.g. `arms/frostbrand/Slash`
2. `arms/<item type>/<motion name>`, for every item of a type, e.g. `arms/crossbow/Hold`,
   `arms/sword/Slash`, `arms/dagger/Stab`
3. `arms/<drawn_tag>`, a generic fallback set on the motion (`Hold1H`, `Hold2H`, `Use`)

So you can draw one generic one-handed hold, then a special crossbow hold, then a unique
pose for one legendary sword, and each overrides the one before only where it applies.
Draw only the arm layers on those frames and keep the shoulder where it is in the rest
frame.

The **Doll Viewer** shows every placeholder item held (top row) and its whole attack
combo on a loop (bottom row), plus unarmed punches. **Code posing: forced** switches to
code posing everywhere, to compare once you've drawn some poses. The line under the
buttons lists the arm tags your art has.

### Why a side-view stance

`Breath` and `Idle Pose` are drawn in a **3/4 view**: the shoulders are far apart and
the back shoulder sits behind the torso. Arms posed in front of the body (holding a
two-handed weapon, aiming) can't look right from there: the back arm ends up hidden
behind the torso. `Jog` and `Jump` are side views, where they work. So whenever an item
is out or you're attacking, standing still uses a side-view stance instead of Breath.
Draw a `Stand` tag (side view, can be a slow breathing loop) to replace the borrowed
Jump frame. With empty hands you keep the 3/4 idle.

## Joints (pivots)

Code needs the shoulder, elbow and hand of each arm.

- **Shoulders are measured in every frame**: the end of that frame's upper arm farthest
  from the lower arm (so a swung or raised arm still finds its shoulder). Posed arms
  attach where the body actually is in each pose.
- **Elbow and hand** come from the rest frame: elbow = bottom of the upper arm,
  hand = bottom of the lower arm. They define the arm's bone lengths.
- **The elbow always bends the same way** (clockwise of the shoulder-to-hand line on a
  right-facing character): below the arm for a forward reach, behind it for a downward
  one, in front when raised.

If a measurement looks off (an arm rotating around the wrong point), add a layer named
**`Pivots`** and put single pixels in these exact colors (shoulders on any frame where
they're wrong, hands on the rest frame):

| Color | Joint |
| --- | --- |
| `#ff0000` | front shoulder |
| `#ff8000` | front hand |
| `#0000ff` | back shoulder |
| `#0080ff` | back hand |
| `#00ff00` | neck (reserved) |

The Pivots layer is never drawn.

## Items and item types

An item's look (`HeldItemLook`, `held_item_look.gd`):

| Setting | What |
| --- | --- |
| `id` | For item-specific drawn frames (`arms/<id>/...`) |
| `texture` | Drawn pointing **up and to the right**, handle at the bottom left (like an inventory icon) |
| `type` | Item type id: how it's held and its attacks (below) |
| `grip` | Pixel the holding hand holds |
| `grip2` | Pixel the other hand holds (two-handed items, or a bow's string) |
| `hold_override`, `attacks_override` | This item only: replace the type's hold or attacks |

**Item types** live in `data/item_types/<id>.tres` (`ItemTypeData`). Open one in the
Inspector to edit it:

| Setting | What |
| --- | --- |
| `held_in` | `FRONT` or `BACK` hand (a spell book sits in the back hand so the front hand can cast) |
| `hold` | The holding motion |
| `attacks` | The attack chain. Clicking again within `combo_window` seconds after one ends plays the next; holding the button keeps going (`repeat_while_held`). One attack = no combo. |
| `stow_style` | Where it goes when put away (H): `BACK`, `HIP`, `HIDDEN` |
| `two_handed` | The other hand holds `grip2` |

Each **motion** (`ItemMotion`) has:

| Setting | What |
| --- | --- |
| `name` | Used for drawn tags (`Slash`, `Fire`, `Hold`) |
| `duration` | Seconds (hold motions loop over it) |
| `aims` | Angles are relative to the direction of the cursor, and the body faces it |
| `front`, `back` | One `ArmTrack` per arm (below) |
| `item_angle_mode`, `item_angle` | The item points along the holding arm (`ARM`), at the cursor (`AIM`), or at a fixed angle (`FIXED`), plus the `item_angle` curve in degrees |
| `lunge` | Pixels the upper body leans forward over the motion (into a stab) |
| `drawn_tag` | Generic drawn fallback (`Hold1H`, `Hold2H`, `Use`) |

Each **arm track** (`ArmTrack`) is one of:

- `NATURAL`: the arm follows the movement animation.
- `POSE`: `angle` (degrees: 0 = forward, -90 = up, 90 = down, 180 = behind) and `reach`
  (hand distance from the shoulder: 1 = straight arm, 0.5 = elbow well bent) over the
  motion.
- `GRIP`: the hand holds the item's `grip2`, pulled back along the item by `pull`
  pixels (that's the bow draw).

All of these are **curves**: in the Inspector, click a curve to open the curve editor
and drag points. The x axis is time through the motion (0 = start, 1 = end).

**Placeholder types** (from `tools/make_item_types.gd`):

| Type | Hold | Attacks (combo) | Put away |
| --- | --- | --- | --- |
| tool | one hand | Swing (overhead to forward) | back |
| big_tool | both hands | Slam | back |
| dagger | one hand, low | Stab, Stab2, Slash | hip |
| sword | one hand | Slash, Backslash, Thrust | hip |
| greatsword | both hands | Overhead, Rising | back |
| wand | aims | Flick | hidden |
| spell_book | back hand, upright | Cast (front palm pushes at the cursor) | hip |
| crossbow | aims, one arm | Fire (recoil) | hip |
| bow | aims, back hand on the string | Draw (pull back, release) | back |
| unarmed | (empty hands) | Jab, Cross, Uppercut | |

Empty hands use the **unarmed** type: clicking punches (jab, cross, uppercut combo).
`unarmed_attacks` on the Player turns it off; the debug brush (B) also takes over
empty-hand clicks while it's on.

To regenerate the defaults: `godot --headless --path . --script res://tools/make_item_types.gd -- --force`
(this overwrites your edits; without `--force` existing files are kept).

Where stowed items sit is on the PaperDoll: `stow_back_offset/angle`,
`stow_hip_offset/angle`.

**Facing and walking backwards:** while attacking, or holding something that aims, the
character faces the cursor. Moving the other way plays the legs in reverse at
`backpedal_speed` (0.8) of normal speed. Both are on the Player.

## Colors

Recoloring uses a **palette swap**: every color in the art belongs to a group, and the
look says what each group becomes.

- `assets/sprites/scholar_palette.tres` lists the groups: `skin`, `tunic`, `pants`,
  `leather` (boots, belt), `trim`, `hair`. It's generated by
  `tools/make_character_palette.gd`, which guesses each color's group from its hue and
  layer. Open the .tres to fix anything it got wrong.
- A `CharacterLook` (default: `assets/sprites/scholar_look.tres`) sets a target color
  per group. Every shade in the group moves onto the target, keeping its lightness and
  saturation relative to the group's middle shade, so shading survives.
- Colors not in any group are never changed. Keep each group's colors unique (don't use
  the same exact color for skin and boots).
- **Doll Viewer: Colors** randomizes a look to check it.

## Hair, helmets, armor

- **Hair** is a sprite on the head: `CharacterLook.hair` (texture, facing right) placed
  at the head's top-left plus `hair_offset`. It moves with the head and takes the
  `hair` color group. The current one (`assets/sprites/hair/short.png`) is a
  placeholder.
- **Armor and clothing** use `PaperDoll.add_overlay(part, texture)`: a texture laid out
  like one row of the parts sheet (one 44x64 cell per frame), drawn right over that
  part and following its frames and code poses. For example, a chest piece is an
  overlay on `Torso`, sleeves are overlays on the arm layers, pants on the leg layers.
  No armor exists yet; the slots and equipment come with items.

**Why this saves art:** the torso and head barely change between frames, so a helmet or
chest piece needs only the few frames those parts have. Pants follow the legs. Sleeves
follow the arm poses.
