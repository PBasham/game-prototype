# Character art and the paper doll

How the character is drawn in game and how to make art for it. The Scholar is drawn as
a **paper doll**: each body layer of `art/Scholar-casual.aseprite` is its own sprite,
and code decides which frame each part shows.

- **Code:** `src/player/doll/` (`paper_doll.gd`, `doll_rig.gd`, `character_look.gd`,
  `held_item_look.gd`, `palette_swap.gdshader`)
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

**Arm tags** (all optional; until they exist, arms are code-posed):

| Tag | When | Notes |
| --- | --- | --- |
| `arms/Rest` | Reference pose for code posing | One frame, arms hanging straight down. Defaults to the first `Idle Pose` frame. |
| `arms/Jog`, `arms/Breath`, ... | Empty hands | Override the arms of that movement animation only. |
| `arms/Hold1H` | Holding a one-handed item | One frame (or a short loop). Front hand where the item's grip goes. |
| `arms/Hold2H` | Holding a two-handed item | Both hands on the item. |
| `arms/Use` | Swinging a tool or weapon | Frames are spread across the swing (`use_time` on the item): first frame = wind-up, last = follow-through. |

Similarly `body/<anim>` overrides the torso and head, and `legs/<anim>` the legs.

**What to draw for an arm tag:** draw only the arm layers on those frames (the other
layers can be anything; they're ignored for arm tags). Keep the shoulder where it is in
the rest frame.

## Arm modes

| Mode | When | Drawn tag | Without the tag |
| --- | --- | --- | --- |
| Swing | Empty hands, or item put away | (the movement animation) | |
| Hold | Item held, not in use | `arms/Hold1H` / `arms/Hold2H` | Code bends the arm so the hand sits at `one_hand_reach` / `two_hand_reach` from the shoulder |
| Use | Clicking a SWING item | `arms/Use` | Code swings the straight arm from `swing_from` to `swing_to` (item settings) |
| Aim | AIM items, or holding click with an AIM-use item | (always code) | Both arms rotate around the shoulder to point at the cursor; with a two-handed item the back hand goes to the second grip |

The **Doll Viewer** shows every mode twice: the top row uses drawn frames where they
exist ("no art" otherwise), the bottom row is always code-posed, so you can compare.

## Joints (pivots)

Code needs the shoulder, elbow and hand of each arm. They're **measured** from the rest
frame: shoulder = top of the upper arm, elbow = bottom of the upper arm, hand = bottom
of the lower arm. If a measurement looks off (an arm rotating around the wrong point),
add a layer named **`Pivots`** and put single pixels in these exact colors on the rest
frame:

| Color | Joint |
| --- | --- |
| `#ff0000` | front shoulder |
| `#ff8000` | front hand |
| `#0000ff` | back shoulder |
| `#0080ff` | back hand |
| `#00ff00` | neck (reserved) |

The Pivots layer is never drawn.

## Items

Each item has a `HeldItemLook` (`held_item_look.gd`):

| Setting | What |
| --- | --- |
| `texture` | Drawn pointing **up and to the right**, handle at the bottom left (like an inventory icon) |
| `grip` | Pixel the front hand holds |
| `grip2` | Pixel the back hand holds (two-handed) |
| `hold_style` | `ONE_HAND`, `TWO_HAND`, or `AIM` (arms follow the cursor while held) |
| `use_style` | `SWING` (click swings), `AIM` (click aims), `NONE` |
| `stow_style` | Where it goes when put away (H): `BACK`, `HIP`, `HIDDEN` |
| `hold_angle` | Angle while just held (0 = forward, -90 = straight up) |
| `use_time`, `swing_from`, `swing_to` | Swing length and arc |
| `face_cursor` | Face the cursor while held (AIM items always do; using always does) |

Where stowed items sit is on the PaperDoll: `stow_back_offset/angle`,
`stow_hip_offset/angle`.

**Facing and walking backwards:** while aiming or using, the character faces the
cursor. Moving the other way plays the legs in reverse at `backpedal_speed` (0.8) of
normal speed. Both are on the Player.

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
