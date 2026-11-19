# Decision log

Newest first. Each entry: what was decided, why, and what it affects.



## 2026-11-18: Phase 8, spell types (branch phase-08-spell-types)

- **Every spell type in the list goes in:** timed buff, charged, zone, ward, summon,
  conjure, imbue, reactive, chain, ritual, sense (plus the existing instant, channeled,
  concentration, companion and placed). One example spell each; Patrick confirms the
  examples first.
- **Gel Cushion** (timed buff): saves you from one fall that would hurt, else lasts 2
  minutes. 10 mana + 5 Slime per cast; the scroll takes 20 Slime. Shows "*squish*" and a
  splat when used; a sound hook for later.
- **Reagents:** any spell can use up items per cast.
- **Later:** an option (an empowerment) to recast a buff automatically when it runs out
  or gets used.
- **One spell per new type, approved:** Arcane Bolt (charged), Healing Circle (zone),
  Spark Ward (ward), Familiar (summon), Conjure Platform (conjure), Arcane Edge (imbue),
  Barrier (reactive), Chain Spark (chain), Recall (ritual), Seek Ore (sense). All tier 1,
  learned from scrolls.
- **Scrolls, one use:** left click casts the spell once free (no mana, reagents, book or
  tier; concentration 60 s, held beams 15 s, bolts at full charge), right click learns
  it. Fizzled casts keep the scroll.
- **The book matters but doesn't gatekeep:** known spells outside the book can be cast
  (from the hotbar) unfocused: 1.5x mana and cooldown, no book bonus; the book's tier
  limit still applies.
- **Known spells vs the book:** known spells are your library; the book holds the active
  ones (a quick slot loadout). "Copy from your book" means copy from known spells.
- **Scroll economy (built now):** learning a scroll costs extra (at a Spell Weaving Table,
  bars by tier); the table has a **Craft** tab (known spells cost half the materials) and
  a **Copy** tab (any known spell onto a Blank Scroll, including spells that can't be
  crafted; needs a max mana pool of 100 / 200 / 300 by tier, nothing drained so making
  several isn't a wait); scroll casts share the spell's cooldown. Plain scroll recipes stay
  until a loot pool.
- **Scroll economy (for Magic progression, decided):**
  - Found scrolls are plain (base spell, no modifiers).
  - Copying (the Copy tab) comes in two kinds: an **empowered copy** carrying your book's
    modifiers for that spell, which can only be cast, never learned; or a **base copy**
    (plain, learnable). Modifiers can never be learned from anyone's scroll.
  - Copy cost grows with the spell and its modifiers, from cheap to complex materials.
  - Scrolls with different modifiers don't stack; identical ones do (items will need
    per-stack data for this).
  - Sharing copies with friends is part of the point (multiplayer).
  - Spell sources vary per spell: craftable from the start, needs a higher tier table,
    found only, or drop only.
- **Tomes (for Magic progression):** reusable, still cost mana, work apart from the book,
  and have their own modifiers you can enchant (e.g. extra damage). Some spells only
  found in chests in hard places. Work in progress.
- **Placeholder sounds:** synthesized, through one `Sounds` autoload fed by
  `EventBus.sound_requested`; Patrick's real files replace them by name.

## 2026-11-18: Phase 7, combat, equipment, beds (not playtested yet)

- **First enemy:** Green Slime. Hops, light damage (6), 20 health, drops 1 to 2 Slime.
  Enemies are data (`data/enemies/`) so more can be added without code.
- **Spawning:** chance based like Terraria (random gaps, piles up to a cap), per biome
  and layer spawn tables with weighted enemies (rarer = smaller weight). Forest surface:
  one every 12 s by day, 6 s at night on average, caps 4 / 7, catch-up when few are
  around. Off screen, never indoors, despawn when far.
- **Terraria's spawn numbers (Patrick):** forest surface 10 s average and 5 max by day,
  6 s and 6 max at night (Terraria's 1/600 and 1/360 per tick). Slimes wander by day, so
  this doesn't swarm you. Never inside the view, even zoomed out (`view_margin_tiles`).
- **Slimes move like Terraria's (Patrick):** by day on the surface an unhurt slime wanders
  and ignores you; at night, underground or once hit it chases. Each hop is a random
  height; now and then it slithers instead, stepping up 1-tile ledges.
- **Forage node (Patrick):** sticks, rocks and flint moved out of the Plants node into
  their own `Forage` node, with types as data (`data/forage/`, ForageData) so new
  forageables (mushrooms) are a file. Older saves move their loose items over on load.
  Breakable-but-walkable things like Terraria's crystal shards are a later brief.
- **One Wood, no flint (Patrick):** like Terraria, Wood is the only wood item: trees
  (5 to 9) and ground sticks give it, it places the plank block, and every recipe uses
  it. Wood Planks and Sticks are gone; flint is gone too (stone tools are 3 stone + 2
  wood). Torches: 2 wood, or wood + slime. Old saves load sticks and planks as Wood,
  flint as Stone. Logs (a raw form that splits into wood) can come back if they get a
  reason. Later: other woods per biome, and Reinforced Wood (iron + wood, a block and a
  back wall, for higher stations and tools) once iron exists; needs a brief.
- **Fists hurt:** a punch does 3 damage (Patrick).
- **Lighter back walls:** `wall_shade` 0.62 to 0.75 (Patrick: plank walls too dark).
- **Rocks give Stone (Patrick):** the Rock item only made the Hand Hammer, so a loose
  rock now gives 1 Stone (the sprite stays a rock). The Rock item and the Workbench's
  Stone into Rocks recipe are gone; older saves load Rock items as Stone.
- **Hover outline:** a soft pulsing outline on anything right click / E would use, in reach.
- **Craft amount:** [-] [n] [+] Craft; Shift = 10, Ctrl = as many as you can up to a
  stack. Replaces the Craft / x10 / All buttons.
- **Open doors:** any visible part of the swung face can be clicked.
- **Stone Pickaxe 2x2:** 1x1 blocks were too small; every pickaxe can toggle down to 1x1
  (Ctrl + wheel).
- **Spawning while travelling (Patrick's playtest):** spawns favor the side you're moving
  toward, enemies get 6 s grace before despawning, and slimes notice you from 64 tiles
  (beyond the spawn distance) so they come to you.
- **More sticks:** bare grass gets pickups too (Patrick saw none in a new world).
- **Loose pickups everywhere:** any exposed grass, dirt or stone can have one, by place: sticks only on surface grass, rocks and flint on surface ground and cave floors at any depth (Patrick).
- **Loose pickups come back:** random ticks over the loaded area (about one item per 32
  floor tiles every 2.5 days), never on screen or indoors, with a crowding brake and up to
  3 days of catch-up for areas you were away from. Chosen over a per-chunk timer so items
  don't restock evenly chunk by chunk (Patrick).
- **Farming (later phase):** crops grow on fixed timers (3 days means 3 days), paused
  when a condition fails (not watered). Not random ticks (Patrick).
- **Second enemy:** Blue Slime, rare (about 11%), tougher, and only after the first Green
  Slime is slain in the world. Slimes are fine (many games use them).
- **Spawn conditions:** per entry, all must be met. First kind: kills of an enemy in this
  world (kills saved per world). More kinds as content needs them.
- **Biomes and layers:** forest enemies spawn only on the forest surface (20 tiles below
  the natural surface at most). Underground and other biomes spawn nothing for now.
- **Max health from gear doesn't refill health;** regen does.
- **Armor is drawn on the character** as placeholder overlays generated from the body
  parts (Patrick: "feel free"); the real ones are hand-drawn later. Accessories aren't
  drawn.
- **Window positions** reset when you quit (fine for now).
- **Spells added:** Levitate, Hyper Drill (tier 3), Air Push, Blink, Light Orb, Mend.
  Fly is faster (34) with a Shift boost (x2 speed, x4 mana), to become an empowerment
  later. Light Orb is a timed cast, not concentration, so it works alongside Fly or
  Levitate; Mend is concentration.
- **Armor placeholders are solid plates** shaped from the body parts; the helmet leaves
  the eye line clear. The helmet angles up (deep at the back, above the eyes at the front).
- **Wisp:** a separate light spell you steer with the cursor and leave in place.
- **Spell controls on trial:** movement key (F), double jump, book number keys, R + number
  quick cast, right click off-hand (off by default). Each is a setting; Patrick picks
  which to keep after playing. Movement spells still need to be in the book.
- **Learning spells:** scrolls from a Spell Weaving Table (paper, blank scroll plus copper
  by tier). Placeholder; Patrick isn't sold on it yet.
- **Melee:** swords hit everything in a box in front, on the swing's impact frame.
- **Defense:** enemy damage reduced by half the player's defense, minimum 1.
- **Equipment:** head, chest, legs, 3 accessories. Stats only, nothing drawn on the
  character yet. Its own window (P), opened in the middle and draggable, per Patrick:
  character preview in the middle, armor left, trinkets right, book and conduit below,
  stats, a foldable Equipped spells section.
- **Spells out of the inventory:** a Spell Index window (L) lists known spells; the
  Equipment window shows the book's slots.
- **Beds:** set the spawn point any time; sleep only at night with no enemies within 20
  tiles. Sleeping skips to morning, grows plants, drains hunger.
- **Slime use for now:** torches (slime + stick).

## Future phase (to be defined): Housing

Beyond beds: what makes a valid house, NPCs moving in, fewer spawns near your base.
To be defined in detail.

## Future phase (to be defined): Bosses

Bosses and tier progression (summoned when conditions are met, per the foundations).
When and how is open.

## Later

- New biomes, ores and enemies: after playtesting what exists.
- Multiplayer: tested later (the code is host-authoritative already).

## Future phase (to be defined): Farming

Held off by Patrick until it is needed. Ideas so far: crops, and transplanting bushes
with special tools. Needs a design brief.

## Future phase (to be defined): Magic progression

Patrick wants to be closely involved in designing this. Ideas so far:

- A **spell crafting table** with two tabs: **Create** and **Empower**.
- **Empower** lists every known spell. Crystals or other materials empower a spell
  through a small **node tree** you work down.
- Example nodes: reduce mana cost, increase power, increase fly speed, increase
  levitation speed.
- A **levitation spell**: fast, fluid movement but only floats about 5 blocks above the
  ground.
- **Usage goals** as another source of power, e.g. "kill X enemies" with a spell raises
  its damage.

## 2026-11-18: Day and night clock, door sizes

- A day is 24 real minutes (15 day, 9 night). Growth is in in-game days: saplings 1 to
  2, young bushes 2 to 3, berries back in 2 to 3. Hunger lasts 1.5 days. Health regen
  0.5/s.
- Doors are sized to the Scholar: closed is a thick slab edge on in the doorway, open
  shows the door's face 3 tiles wide, starting at its hinge (the doorway's edge).
- Light doesn't go through walls: sunlight still soaks down into the ground (0.1 per
  block) but stops going sideways or up into blocks (0.5) and can't come out of a block
  into a walled room or cave. Torches lose 10 times more through blocks than air, and
  closed doors block light.
- Doors only open where the door has room to swing (no blocks or objects there).
- Background walls are drawn darker and greyer than blocks.

## 2026-11-17: Phase 6, health, hunger and dying

- Health 100, regenerates 1/s after 5 s unhurt. Fall damage after 25 tiles, 5 per tile.
- Hunger 100, 1 point per 20 s, running twice as fast; spells (Fly too) never drain
  it. At 0: no regen and 1 damage every 3 s.
- Berry bushes on the grass (first food): berries +10 hunger, +2 health.
- Dying: respawn at the world spawn after 3 s, full bars. Items go into a magic bag
  (Valheim tombstone idea, Terraria tombstone physics), saved with the world.
- World options: Hunger on / off, On death: magic bag / keep items.
- Doors are Starbound style: separate closed and open images, same 1x8 footprint;
  closed shows the door edge on, open shows its face.
- Wild berry bushes are slow and stingy (1 to 3 berries, 72 to 120 minutes to regrow,
  same to grow up) so farming is worth it later.
- Berry bushes have a young (small, no berries) and a full grown (bigger, berries)
  stage; young ones grow up. Planned: crops, and transplanting bushes with special
  tools.

## 2026-11-17: Phase 6, house review

- Health, mana and hunger bars bottom left (mana moved from under the hotbar). Health
  and hunger are display only until their briefs (combat, food).
- Doors open to 2x8 with the panel swung away from the player (Terraria style), or the
  other way when that side is blocked. New closed door art.
- Drops are drawn by item size (by kind, or `drop_size`); grass pickups are bigger and
  sized like the thing.
- The anvil stays 3x3.

## 2026-11-17: Phase 6, characters and UI

- Character select and creation moved up (was Phase 7). Menu: Play, character page,
  world page. Any character plays any world. Each character is its own save file.
- Character creation: name, hairstyle, a color per palette group (swatches plus hue,
  saturation, lightness sliders), Randomize, live doll preview. No difficulty modes yet.
- Crafting and chests are separate windows on the right side of the screen, apart from
  the inventory. Hand crafting opens with K (C is walk), or the Craft button.
- Crafting window: list on the left, selected recipe details on the right, Craft / x10
  / All buttons. Chests get Take all and Deposit all.
- Stations scaled to the Scholar: Workbench 5x4 (hip height), Furnace 4x5, Anvil 3x3 on
  a stump, Chest 3x3. Doors stay 1x8.
- UI look: Scholar theme (leather, wood, brass, parchment), nine-slice placeholder art
  in assets/ui from tools/make_ui_art.gd, drawn by UiSkin.
- Inventory size is data (the character's inventory size), so a smaller start and
  upgradeable bags later only change a number. Bags get a brief when we get there.
- Fixed the paper doll's palette swap shader squaring the art's colors.

## 2026-11-17: Phase 5, crafting

- Crafting is Starbound / Minecraft style: each station has its own recipe list; hand
  recipes show when no station is open. Recipes are data (`data/recipes`).
- Stations: Workbench, Furnace, Copper Anvil. Stations can be upgraded in place to
  higher tiers (framework only, nothing upgrades yet). Alchemy and enchanting stations
  come later with briefs.
- Early game: sticks, rocks and flint lie on the grass; trees drop sticks; stone
  sometimes drops flint. A Hand Hammer (kept, not used up) is needed for the Workbench
  and for breaking stone into rocks. Stone pickaxe and axe. Bare hands break nothing.
- New characters start with nothing (lost memory). `devkit` gives the old kit.
- Mana: 100, regen 15/s after 1 s. Fly 10/s, Mining 4/s, Chopping 3/s, Spark 2.
  Console `mana` for infinite.
- Spell tiers vs book `max_spell_tier`.
- Furniture: multi-tile objects (chest 40 slots, doors 1x8 that open and close).
  Doors may be resized if the character size changes.
- Later, magic progression phase (brief first): spell tiers vs books, runes that lower
  mana costs, combo spells with toggles (like Terraria wrenches), gem upgrade trees per
  spell. Possibly dedicated pickaxe and axe slots.

## 2026-11-17: Phase 4 closing fixes

- Torches are 2 tiles tall. Materials don't swing when clicked. Thrown items stop when
  they land. Console keeps the cursor in the box after Enter.
- Movement: stepping up ignores platforms; climbing rope goes through platforms; falling
  lands on a platform the tucked-up feet are already over; on slopes the body is drawn
  for the higher foot.

## 2026-11-17: Roadmap after Phase 4

- Next: crafting (recipes as data, crafting window, stations, chests, first real
  content), with a basic mana bar (regenerates; spells cost it; Fly drains it) and a dev
  console command for infinite mana. Design brief first.
- Then: equipment panel (armor, trinkets, stats), enemies / health / combat feel,
  character creation and select.
- Doors get resized later if the character size changes; fine to build them now.
- Possible later: dedicated tool slots for the pickaxe and axe (they aren't weapons), so
  they don't take hotbar space.

## 2026-11-17: Playtest round 3

- Holding Down + Jump keeps dropping through platforms.
- Character size vs blocks (8 tiles tall, doors 8 to 9 tiles): **undecided**. Options:
  shrink to about 6 tiles (redrawn at about 48 px, not scaled), keep 8 and build tall,
  or 16 px tiles (big rework).
- Feet on slopes: the sprite follows the smooth slope over 1-tile steps instead of
  lagging behind the body (the lag made feet sink uphill and float downhill). No
  per-leg IK for now.
- Grass under a solid block becomes dirt; grass blades aren't drawn into rooms (built
  back walls).
- Pickup notes add up per item. Dev console: `reach`, `fill`, `fillwall`.

## 2026-11-17: Objects layer, torches, colored light, new spells

- A third tile layer for objects (rope, torches; chests and doors later). Rope moved
  there, so it can hang through platforms.
- Torches: on a block (below or beside) or a back wall, not inside solid blocks; pop off
  when unsupported. 20 in the starting kit. Placeholder art.
- Lighting is colored (RGB) so torches are warm.
- Spells get a cast type: TOOL (mining, chopping), PROJECTILE (Spark), TOGGLE
  (concentration: Fly, infinite until mana exists). Chopping Spell, Fly and Spark are
  starting spells. Mana fields exist on spells but do nothing yet.
- Dev-only training dummy to test damage.
- Open question (Patrick): tools, spells, or both for mining and chopping. Both exist
  for now.

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
