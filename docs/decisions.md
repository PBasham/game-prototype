# Decision log

Newest first. Each entry: what was decided, why, and what it affects.

## 2026-11-17: Playtest round (Phase 4)

- Placing is near instant (12 a second held), like Starbound.
- Platforms and rope place one at a time; a square / horizontal / vertical placing
  shape toggle is planned for later.
- Blocks a tree stands on can't be mined (no more popping trees by digging under).
- Ctrl + right click equips books and conduits, swapping with the equipped one.
- Down + Jump drops through one platform at a time.
- Dev console on ` for debug builds.
- The integer-division GDScript warning is turned off project-wide (tile math divides
  ints on purpose); other editor warnings were fixed.
- Ropes on their own layer and torches: brief sent, waiting on Patrick.

## 2026-11-17: Spellbook as the matter manipulator

- Tap R takes the spellbook out (last spell used), tap again goes back to the hotbar;
  hold R for the spell wheel.
- Building uses the book's stats: placing reach `build_reach_tiles` (12) and one area
  setting shared with spells, up to `build_area_max` (3). Pickaxes keep their own.
- Drops: magnet measured from the player's body (drops at the feet were never picked
  up), and a drop that loses the player slows down instead of sliding off at flying
  speed (ore was ending up 20+ tiles away).

## 2026-11-17: Front/back layers and magic (Phase 4, second pass)

- **Starbound-style layers:** one item per material; left click = front layer, right
  click = back layer, for placing and mining. Back walls can be mined behind blocks.
  Mined walls drop their block. No hammer; the Wood Wall item is gone. Walls keep their
  own textures so front and back can look different later.
- **Keys:** inventory I / Tab, interact E. Right click interacts when there's
  something interactable under the cursor, otherwise it's the back layer.
- **Spellbook is part of the character:** an equipment slot; empty = Basic Spellbook
  (4 slots). Books can add slots and spell power. One loadout per character, kept
  across book swaps.
- **Conduit:** an equipment slot. Boosts spells (power, reach); some spells require a
  conduit type. Swapping is done in the inventory for now (a quicker swap can come
  later if it's a hassle).
- **Casting:** spell wheel (hold R) and hotbar shortcuts, both. Only spells in the book
  can be cast; tomes cast their own spell without a book slot.
- **Mining Spell** is now a spell (data/spells), not an item. No mana yet.
- No real books, conduits or tomes yet (content needs a brief); debug builds have
  dev-only ones to test with.

## 2026-11-17: Phase 4, items and mining

- **Hotbar** top left (Terraria), 10 slots; **inventory** 40 slots (top row = hotbar),
  opened with E. Stacks: 999 for blocks and materials, 1 for tools.
- **Left click places** (Terraria-style); right click is kept for interacting.
- **Mining:** blocks have health and a crack overlay, heal after 5 s. The copper
  pickaxe mines 2x2 per hit at 10 tiles; any item can have mining damage.
- **Mining spell:** a beam while held, stats as data, area toggle with Ctrl + wheel
  (1x1 to 3x3), slightly weaker than the pickaxe, no mana yet. In the starting kit for
  now; later it's the first crafted spell.
- **Placing** needs something to touch (a block, or a wall behind) unless the item is
  `free_place`. Walls are placed without a tool and removed with a hammer.
- **Indicators** like Starbound: white/red target box, ghost blocks, the beam, a range
  ring that fades in near the edge of reach.
- **Trees** wiggle when hit, fall over and break into wood plus at least one seed;
  seeds grow into trees on grass. Grass spreads to dirt; cutting flowers can drop grass
  seeds; wood becomes planks when crafting exists.
- **Character file** separate from worlds, one automatic default character until
  character select (Phase 7).
- Axe reach raised from 6 to 10 tiles after the first screenshot: 6 couldn't reach a
  trunk next to you once measured from the chest.

## 2026-11-17: Spell book hold

Patrick picked option C: the back hand holds the book still, forearm out, in front at
waist height, the same while running, jumping and casting.

## 2026-11-17: Holding uses the drawn arm; no borrowed stance

- Patrick: the 3/4 Breath idle is the standing pose; the borrowed landing frame is gone.
  A `Stand` tag replaces Breath only if he draws one.
- Melee weapons, tools and the book are held in the drawn arm (the item rides in the
  hand), so picking something up doesn't change the arm. Aiming items still pose.
- Switching between drawn and code-posed arms blends over 0.07 s.
- The paper doll has physics interpolation off (parts drawn between stale positions).

## 2026-11-17: Movement animation fixes

- Step down up to 1 tile without falling (floor snap), mirror of the step-up.
- Steps move the body a tile per tick; the sprite eases over 0.06 s so stairs look smooth.
- Falling animation needs 0.08 s off the ground (or a jump), so bumps don't flicker.
- Pushing into a wall is standing still (velocity flickered between 0 and 3 t/s).
- Shoulders: farthest point of the upper arm from the lower arm, per frame.

## 2026-11-17: Arm fixes, side-view stance

- Code-posed arms attach at shoulders measured per frame (the 3/4 idle and the side-view
  run have very different shoulder positions; using the idle's put arms on the wrong
  side in runs and jumps).
- The elbow always bends clockwise of the shoulder-to-hand line; choosing by direction
  made it flip when the arm passed vertical.
- Standing with an item out or attacking uses a side-view stance (`Stand` tag, fallback
  the last Jump frame): the 3/4 idle hides the back arm behind the torso.

## 2026-11-17: Item types and attack animations

- **Item types** (`data/item_types/`) define how items are held and their attacks;
  items point at a type and can override. Drawn frames are looked up per item, then
  per type, then generic, then code posing.
- **Attacks are motions** (arm angle/reach curves per arm, item angle, lunge), edited as
  curves in the Inspector. Placeholder attacks per type: stab combos, slash combos,
  slams, wand flick, crossbow recoil, bow draw, book cast.
- **Combos:** clicking again within `combo_window` after an attack plays the next one in
  the chain; holding keeps going.
- **Unarmed:** empty hands punch (jab, cross, uppercut combo), per Patrick. The debug
  brush moved behind a toggle (B) so it doesn't fight with punching.
- **Spell book** is held in the back hand; the front hand casts.
- **One-handed aiming** moves only the front arm.

## 2026-11-17: Phase 3, character rig (paper doll)

Inserted before mining, because mining is where arm poses matter. Mining and items
move to Phase 4.

- **Paper doll** (Starbound style): each body layer is its own sprite. Legs carry
  the animation; torso and head follow; arms have modes (swing, hold, use, aim).
  Armor and clothes become overlays on single parts, so they need few frames.
- **Aim: free rotation** of the arm sprites around the shoulder (no pre-drawn angles).
- **Hold and use poses: hand-drawn** (`arms/Hold1H`, `arms/Hold2H`, `arms/Use`), with
  code-posed two-bone arms as the fallback until they exist. The Doll Viewer shows both
  so Patrick can compare.
- **Facing:** face the cursor while aiming or using; moving the other way walks
  backwards (legs reversed) at 80% speed (`backpedal_speed`).
- **Put away (H):** each item says where it goes: back, hip or hidden.
- **Customization:** palette swap by color group + hairstyle sprite, one placeholder
  hairstyle. Character creation screen comes with character saves.
- **Armor sleeves:** hand-drawn (not auto-generated from masks).
- **Aseprite layout:** one file; tag prefixes (`arms/`, `legs/`, `body/`) target one
  channel, plain tags apply to all.

## 2026-11-17: Phase 2, forest world generation and the main menu

Brief answered "defaults" on every point:

- **Terrain:** rolling hills (about ±20 tiles), a few big hills (up to 50), rare
  cliffs 6 to 12 tall. Between Terraria's flat forest and Starbound's drama.
- **Spawn:** flat 60 wide, no cave entrances or shallow caves within 40 tiles; spawn
  column 200 so the wrap seam is a short walk.
- **Test course:** removed from real worlds; dev-only "Test Course" world (menu in
  debug builds, `--world=course`).
- **Layers:** dirt 15 to 30 deep over stone with pockets of each in the other; stone to
  the bottom (underground layers later); bottom row can't be dug.
- **Caves:** surface entrances every 400 to 800 tiles, winding tunnels, caverns more
  common with depth. Medium density. Sized for the Scholar (8 tall, 3 wide): tunnels
  about 13 tall, entrances 7 to 10 wide. The first draft used Terraria-sized caves,
  which were crawl spaces at our scale.
- **Copper:** blobs of 4 to 10 tiles, from 6 deep, more common down to 150.
- **Surface:** tree groves with clearings, flowers in the clearings, no trees on steep
  slopes.
- **Generation stays per chunk** from the seed (instant, threaded). Lakes and
  structures will use a precomputed feature map later.
- **Settings are data** (`data/worldgen/forest.tres`) because Patrick will tune
  generation himself. "Amount" settings are calibrated against the noise so they mean
  what they say. F6 regenerates in game; `tools/preview_world.gd` renders maps.
- **Main menu** with New World (name, size, seed), Load World, Test Course, Quit. Esc
  pause menu. Seeds can be words.
- **World saves:** only player-edited chunks, with tile id palettes. Tradeoff: changing
  generation settings changes unedited parts of old worlds. Fine for development;
  revisit before release.
- **Workflow:** Claude Code never pushes (Patrick reviews and pushes). Cloud sessions
  push phase branches only when Patrick asks.

## 2026-11-13: Smooth motion and no streaming hitches

- **Physics interpolation on** (60 Hz physics). Playtest on a high refresh monitor
  showed constant stutter without it. Teleports must use `World.teleport_player()`.
- **World streaming and lighting on worker threads.** Measured on Patrick's PC: the
  light rebuild took about 106 ms on the main thread each time chunks loaded (84 frames
  over 50 ms in a 2.5 minute run); chunk generate about 7 ms and render about 6 ms each.
  Now generation, chunk builds and lighting run on `WorkerThreadPool`; the main thread
  applies results (under 1 ms per chunk). Chose threads over relighting only new
  chunks (still a main-thread spike) and over GPU light spread (more work; revisit if
  torches make lighting heavier).

## 2026-11-13: Look, scale and forest focus

- **Tile size: 8 px.** Patrick's Scholar is 24x63 px, so he's about 3 tiles wide and
  8 tall. Small blocks allow detailed builds. View is 640x360 shown at 3x.
- **World sizes** scaled from Terraria's for that player size: Small 6400x2048,
  Medium 9600x2816, Large 12800x3584 tiles.
- **Terrain look: style V5**, drawn by a terrain shader per pixel: smoothed silhouettes,
  noisy boundaries between materials, lit rims and soft shadows, grass on top.
  **No dark outlines** on anything; transitions use texture.
- **Scope: forest only, copper only** until each next biome/ore is designed with Patrick.
  Other made-up content was removed.
- **Lighting moved up from Phase 7** (basic version): sunlight fades a few blocks into
  the ground, caves are dark with a faint ambient floor.
- **Movement:** walk 10 / jog 18 (default) / run 28 tiles/s, jump about 11 tiles
  (less floaty: apex 0.36 s, faster fall), partial air control (holding back mid-jump
  slows you and lets you drift back a little), 2-tile auto step-up, fall damage past
  50 tiles.
- **Art pipeline:** Patrick's Aseprite files are imported by `tools/import_aseprite.gd`;
  terrain and backdrop are generated by `tools/generate_tiles.gd --export=game`.

## 2026-11-12: Phase 1 movement and world

- **Pace:** jog by default, hold Shift to run, C toggles walking. Jog 9, run 14,
  walk 5 tiles/s.
- **Air control:** reduced (0.35 s to full speed in the air vs 0.10 s on the ground);
  Patrick may want less still.
- **Player size:** Starbound-like height on Terraria-size tiles: 32x64 sprite,
  24x60 collision (about 1.5 x 3.75 tiles).
- **Jump:** about 5.5 tiles, variable height, coyote time and jump buffer.
- **Auto step-up** over 1-tile ledges; **fall damage** past 25 tiles (10 per tile).
- **Platforms:** one-way, Down + Jump drops through. **Ropes:** Up/Down to climb.
- **Tile art format:** 16 edge masks x 3 variants per material row, rough edges where
  a block touches air. Three generated styles to choose from (rough, soft, crumbly).
- **World storage:** 32x32 chunks generated on demand; world wraps horizontally.

## 2026-11-12: Project foundations

- **Engine:** Godot 4.7.2 stable, GDScript with static typing. Fast iteration, best docs,
  exports everywhere. 3.x is maintenance-only.
- **Platform:** PC, Steam release.
- **Multiplayer:** yes, later. Built host-authoritative from day one (docs/architecture.md)
  so it can be added without a rewrite.
- **Tile size:** 16 px (revisit before real art if needed).
- **World:** Terraria-like size presets, wrapping horizontally like Starbound.
- **Progression:** tiers unlocked by bosses; details later.
- **Death penalty:** like Terraria / Starbound (lose part of currency, keep items);
  harder modes later.
- **Hunger:** slow drain, Well Fed buff, starving deals light damage over time; can be
  turned off per world.
- **Characters and worlds:** saved separately.
- **Bosses:** summoned when conditions are met (item, biome, depth, time, area),
  defined per boss as data.
- **Testing:** GUT, run headless in GitHub Actions on every push.
