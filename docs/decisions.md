# Decision log

Newest first. Each entry: what was decided, why, and what it affects.

## 2026-11-27: Phase 78, recipe banner, coin bag, fewer coins

- **Patrick:** new recipes float at the top middle of the screen for a few seconds and
  fade; the coin bag on the inventory's left edge, a bag icon that opens the pouch; money
  less abundant, and a smaller step from Green to Blue Slimes.
- **Claude:** the bag also shows beside the hotbar (it opens the inventory and pouch);
  several recipes at once share one banner; coins 1 to 3 / 2 to 5 / 10 to 20 Copper.

## 2026-11-27: Phase 77, Catalog Entities

- **Patrick:** rename the Catalog's Creatures tab to Entities, with sub tabs Enemies,
  Bosses, NPCs and Peaceful.
- **Claude:** `EnemyData.catalog_group` (Auto: critters are Peaceful, the rest Enemies)
  ready for bosses and NPCs.

## 2026-11-27: Phase 76, coins

- **Patrick:** copper, silver, gold and platinum coins, and a little collapsible coin
  pouch at the bottom right of the inventory. Took every default in the brief.
- **Claude (brief):** 100 of one make 1 of the next, automatically; slimes and Forest
  Spirits drop them; picked up straight into the pouch (no limit); take them out onto
  the mouse (Shift: all); kept when you die; placeholder art.

## 2026-11-27: Phase 75, Floating Torch

- **Patrick:** a new early spell, Floating Torch: a little torch that floats around you
  and follows you, giving light; ranks for more light, and another for duration whose
  last rank is expensive and lasts forever. Cost maybe 10 torches, paper and Magic
  Essence; most enemies dropping Magic Essence, not guaranteed. Took the brief's
  defaults.
- **Claude:** light 26 (a torch is 32), 5 min, 8 mana; Brighter +5 x3; Kindled +50% x2,
  then endless; learn 10 Torches, 5 Paper, 2 Magic Essence; slimes drop Magic Essence
  1 in 10. The brief had Forest Spirits at 25%, but they already always drop 1 to 2,
  so they stay as they are.

## 2026-11-27: Phase 74, Catalog creatures

- **Patrick:** fish aren't enemies in the Catalog (they're passive).
- **Claude:** the tab is Creatures; hostile ones first, then passive, each page labelled.

## 2026-11-27: Phase 73, Command and the middle mouse slot

- **Patrick:** a way to direct summons at a specific enemy; a Command spell, with the
  middle mouse as another quick slot.
- **Claude:** Command is known from the start and starts on the middle mouse slot; it
  targets the enemy near the cursor until it dies, nothing clears it; a red reticle shows
  the target.

## 2026-11-27: Phase 72, tweaks

- **Patrick:** Shaping Spell on Ctrl + Shift + R; trees drop a little more logs; Summon
  Slime goes into water after underwater enemies, but doesn't target passive animals.
- **Claude:** `tiles_per_log` 6 to 4.5 (3 to 5 Logs); familiars skip critters too, and a
  critter you've hit (angry) is fair game.

## 2026-11-27: Phase 71, station tabs

- **Patrick:** tabs for the crafting stations too, logical ones; recipes crafted by hand
  should be craftable at the Workbench.
- **Claude:** Workbench (Stations, Furniture, Storage, Building, Items), Furnace
  (Smelting, Bottles, Bricks), Anvil (Weapons, Armor); the Campfire is small enough
  without.

## 2026-11-27: Phase 70, recipes behind their key items

- **Patrick:** recipes should be held behind some of their key items.
- **Claude:** every recipe's key items are its inputs except Wood, Log, Stone, Dirt and
  Sand; it shows once you've had any one of them (the existing `unlock_items`).

## 2026-11-27: Phase 69, Upgrade in the title bar

- **Patrick:** put the station's Upgrade option at the top next to "Tier 1", and hovering
  it tells you what it requires.

## 2026-11-27: Phase 68, Catalog drop chances and links

- **Patrick:** show the drop chance of an enemy's items, and make "Dropped by" link to
  the enemy's entry.
- **Claude:** drops are rows (icon, name, count and chance); unseen ones stay "???" but
  show their chance; links go both ways (a drop opens its item page).

## 2026-11-27: Phase 67, the Alchemist's Bench

- **Patrick:** a second version of the alchemy table, a tabletop window with a mixing bowl
  and a vial spot, your ingredients listed on the right to drag and drop, a Mix button and
  a distiller; Kingdom Come Deliverance alchemy, 2D and simplified. A separate station so
  he can test it as its own system. Took every default in the brief.
- **Claude (brief, all taken):** a new station beside the Alchemy Table; mortar (grind),
  3-spot bowl, vial spot, any order; wrong mixes use everything up and make a Murky
  Mixture; a distiller making Strong potions (later cut); Potions
  tab recipes known from the start, others discovered by mixing, a recipe book; the list
  shows only your inventory.
- **Patrick (follow-up):** keep it intuitive and easy to use; only the mortar, the mixing
  bowl and a slot for the bottle, and a nicer looking window. The distiller and the
  Strong potions are gone; the window was redrawn (plank tabletop, a glazed bowl whose
  brew takes the ingredients' colors, a bottle stand), pieces light up while dragging,
  and a card shows what Mix will make (known recipes only, "Unknown mix" otherwise).

## 2026-11-27: Phase 66, Water Breathing

- **Patrick:** an air bubble meter when you're underwater; Water Breathing potions.
- **Claude (agreed brief):** 20 s of breath, a breath row on the status panel, Water
  Breathing from a bottle of water + 2 Kelp in each bottle (2, 4, 6, 8 minutes by size),
  kelp mineable for Kelp (regrows in a day: Claude's default).

## 2026-11-27: Phase 65, Abyssal Stone and the endless sea

- **Patrick:** the ocean's water never runs out; a very hard stone nobody can ever break
  keeps players from opening the ocean to the rest of the world, its top at sea level.
- **Claude (agreed brief):** an Abyssal Stone shell under both beaches down to the world
  floor, its top 2 rows above sea level under 3 tiles of sand; open sea touching water
  refills near the player; untouched generated water isn't saved and is dropped far away.
- **Patrick (follow-up):** the Abyssal Stone outside the sand with the same curve, the
  outside layer of the ocean biome on the sides; the ocean a fifth of the world, not a
  quarter. Now a layer under the beach sand, rising at the beach's end, and a wall down
  each side of the Deep.

## 2026-11-27: Phase 64, the deep ocean

- **Patrick:** the ocean a lot larger and significantly deeper; the middle opens into a
  drop-off far down to an underwater cave system, with room for a large Leviathan-type
  boss, scenes and enemies later; the ocean bottom goes all the way to the bottom of the map.
- **Claude (agreed brief):** 25% of the world wide (later 20%), upper floor to 150 deep, a 50 to 80
  wide chasm to an empty 140 x 70 arena at the bottom, flooded caves under the whole
  ocean, 4 empty scene caverns, sunlight 24 tiles down.
- **Patrick (follow-up):** the upper ocean a bit deeper; the chasm not straight down but
  curvy and jagged in parts. Now 220 deep, and the chasm winds (big bends and kinks),
  swells and narrows, with jagged stretches.

## 2026-11-27: Phase 63, water on the map

- **Patrick:** start with the water on the map.
- **Claude:** map cells half full of voxel water draw blue.

## 2026-11-27: Phase 62, fireflies

- **Patrick:** fireflies in the Dark Forest, catchable with a net, make a lamp with them.
- **Claude (defaults):** fireflies are critters (day and night, up to 10), drift and
  blink with a small green light; the Bug Net (Workbench, 4 Wood, 6 Rope) is a melee
  swing that catches them; the Firefly Lamp (Workbench, Glass Bottle + 3 Fireflies) is a
  torch-like light, also held.

## 2026-11-27: Phase 61, water fixes, critters, torches on trees

- **Patrick:** the character should be behind the water layer; slimes float and bob on
  water; peaceful creatures get a different entity cap; fish in water; placing sand stops
  working after a bit; place torches on trees.
- **Claude:** water drawn over everything that moves; slimes float; critters on their own
  cap and clock per spawn table, fish added to the forest table (ponds); loose sand cells
  count as something to build against; torches hang on bare trunk (60% of the height,
  pines 1 tile wide, darkwood 3) and drop when the tree falls.

## 2026-11-27: Phase 60, dark caves

- **Patrick:** caves are too bright this far down.
- **Claude:** daylight crossing cave air (over 4 tiles under the natural ground) fades 14%
  a tile instead of 3.5% (`LightMap.cave_air_decay` 0.86), so it no longer seeps through
  whole cave systems from their entrances. Torch light unchanged.

## 2026-11-27: Phase 59, turn log walls

- **Patrick:** can't make a log back wall vertical.
- **Claude:** log walls get a "turned" step in the Shaping Spell's wall cycle (shape bit
  6, flips the upright look like turned log blocks); dev console `wallshape`.

## 2026-11-27: Phase 58, drops in the ground

- **Patrick:** a chopped tree dropped wood below ground; it should be stopped by the ground.
- **Claude:** every drop made inside solid ground moves up onto it; a resting drop covered
  by a block comes up too.

## 2026-11-27: Phase 57, Storm Axes leap

- **Patrick:** make the leap on the storm axes much farther.
- **Claude:** `skill_leap_speed` 26 to 48 and `skill_leap_height` 3.5 to 7: about 18
  tiles instead of 8.

## 2026-11-27: Phase 56, sea life

- **Patrick:** add some flora and some fish, small crabs on the beach you can kill and cook
  into crab legs.
- **Claude (defaults):** crabs and fish leave you alone until hit (crabs then pinch for 3);
  fish swim, flee and flop on land; both drop raw food cooked at a campfire (Crab Legs,
  Cooked Fish; raw isn't edible); an ocean spawn table, fish only in water; flora is
  decoration (dune grass, seagrass, kelp) from the generator, nothing to harvest yet.

## 2026-11-27: Phase 55, ocean and ponds

- **Patrick:** in addition to some ponds, an ocean biome: sand, hard sand and water,
  lots of it; make a first version.
- **Claude:** one ocean on the far side from spawn (12% of the width, 80 tiles deep,
  shelves near the shores), 45 tile beaches that never dip below sea level, sand 6 deep
  then Hard Sand 14 (a static block and wall), a rock crust before caves; ponds on flat
  ground with sand beds. Generated water fills the voxel layer at rest, once per chunk.
  No ocean enemies or plants yet.

## 2026-11-27: Phase 54, water: swimming, breath, thirst, bottles, Siphon, barrels

- **Patrick:** go with the brief's defaults; the player can swim in the water.
- **Claude (the brief's defaults):** swim at half submerged; 10 s of breath then 2
  damage a second; thirst empties in a day, parched like starving, a world option;
  bottles of water by hand from any empty bottle plus water around you, barrels or the
  Siphon, 15 thirst a tile of water, the bottle comes back; Siphon 32 cells a second,
  holds 16 tiles; barrels hold 25 and 60 tiles (capacity now in voxel cells).

## 2026-11-27: Phase 53, Sand Bricks counted like sand

- **Patrick:** mining a bitten brick should give the quantity it actually has, not a
  brick for half. Leave wall shaping as it is for now.
- **Claude:** Sand Bricks are counted per cell like sand: 16 a tile (`place_units`,
  `drop_count`), the recipe makes 16, refilling takes the missing ones.

## 2026-11-27: Phase 52, voxels: falling sand, water, Sand Bricks, Bomb

- **Patrick:** start the voxel style with sand and water, plus a Sand Brick that doesn't
  fall to test voxels on a static block (placed and broken whole, a bomb to test partial
  breaking, replacing a broken tile replaces the whole tile, sand counted in much higher
  numbers so placing a block takes several). Voxels on static blocks only for Sand Bricks.
- **Claude (defaults, said go ahead):** 4x4 cells a tile; cells only in air tiles; a
  sand block falls apart only when nothing whole holds it up; 16 grains a block (Glass
  16 Sand, Sand Bricks 16 Sand at the Workbench); a bitten brick tile is fixed with one
  brick and mines into a brick if half is left; the Bomb is a test item with no recipe;
  water has no effects or carrying yet (Siphon Liquid and thirst come next); piles stay
  loose (`solidify_piles` off) so they look even.

## 2026-11-27: Phase 51, Shaping Spell, placing reach

- **Patrick:** a hammer-like tool that shapes blocks into slopes, halves and rotations,
  and turns logs on an extra click; as a Shaping Spell you spawn with, maybe Alt + R;
  keep the automatic upright snapping for a single line; any placeable block; Empower:
  range. Placing reach should follow the Mining Spell.
- **Claude:** one shape byte per tile (block 3 bits, log turn 1 bit, wall 2 bits),
  stepped by click (Shift steps back); walls only get halves; collision via TileSet
  alternatives. Placing reach dropped from the book's 12 to the Mining Spell's 8 (plus
  Empower and conduit), as asked.

## 2026-11-26: Phase 50, break dust, Glow Potion

- **Patrick:** a small dust cloud in the block's colors when it breaks; a Glow Potion
  from a flask and a Glowcap. Claude: 4 minutes, 18 tiles of soft cyan light, no
  sickness, a sparkle badge.

## 2026-11-26: Phase 49, plank section, Tele Grab forage

- **Patrick:** board ends looked funny in the rack: boards now lie flat in a left
  section. Tele Grab should pick up forageables: they come loose as items in its pull.

## 2026-11-26: Phase 48, Lumber Rack, storage capacity

- **Patrick:** the Lumber Rack should show Darkwood purple and be bigger. It's 5x4 now,
  drawn as a colored heap (`PILE`) with its front posts over it.
- **Patrick:** how should display storage justify its space? Claude: hold at least what
  chests would in the same space (about 4.4 stacks a tile); stacks a slot set to match.

## 2026-11-26: Phase 47, bookshelves, fuller spots, right click fix

- **Patrick:** a bigger Bookshelf (the old one is the Small Bookshelf), bottom half a
  cupboard, books only on show, one book each; shelf spots should fill with the stack;
  Creative search matched ids ("bookcase"); right clicking a far shelf mined behind it.

## 2026-11-26: Phase 46, shelf spots, Creative tabs, wall pantry rack

- **Patrick:** cabinets didn't fill up; each slot should be a section of the shelf and
  the window should look like the shelves. Claude: slots per shelf (Potion Cabinet 4 x 3
  = 12, Large 5 x 4 = 20, Shelf 4, pantries 2 x 4); the window lays them out like the
  shelves.
- **Patrick:** special storage has to beat a chest (40 slots). Claude: 4 stacks a slot
  (`container_stack_mult`) on the potion cabinets and pantries: the Large Potion Cabinet
  holds 2,400 potions to a chest's 1,200, in about the same footprint as two chests.
- **Patrick:** retire the display Shelf; the Potion Shelf becomes the Shelf (anything).
  Pantry Rack goes on a wall too. Creative: Food becomes Consumables, more tabs. A
  stowed torch stops lighting you.

## 2026-11-26: Phase 45, liquid barrels, Siphon Liquid, nets, shelf spacing

- **Patrick:** Liquid Barrels should open (a gauge window, empty until liquids); add a
  Siphon Liquid spell now (does nothing yet, Empower Reach and Area); a tap on the wooden
  barrel; the small net a little wider (4x2), a Long net (2x5), thicker net ropes; a full
  cabinet should fill its shelves, spaced evenly.

## 2026-11-26: Phase 44, log ends, upright log walls, no_los

- **Patrick:** log ends need a defining line and rounding on both sides; log walls in a
  single column should stand upright too; a dev command to turn off line of sight
  (`no_los`, for your own actions only).

## 2026-11-26: Phase 43, station command

- **Patrick:** a dev command `station [name] [tier]`. It opens that station's crafting
  window with no station placed (no reach check, no Upgrade row). `crafttab` only picks a
  tab and row in a window already open.

## 2026-11-26: Phase 42, dev commands, logs, wall brightness

- **Patrick:** dev commands `instant_placement`, `instant_break`, `no_drop`. Done.
- **Patrick:** a log placed in a single column should stand upright; log walls should
  have rounded ends like the blocks. Done in the terrain shader.
- **Patrick:** blocks and their walls were hard to tell apart. Measured: walls came out
  0.38 (dirt, stone) to 0.86 (clay) as bright as their blocks. Every wall is now evened
  out to 0.6 of its block (`ChunkRenderer.wall_block_ratio`).

## 2026-11-26: Phase 41, the Empower tree

- **Patrick:** each spell once; a node tree on the right, nodes as pixel circles with
  icons, some locked behind others; descriptions just say what it does; an Area node for
  Mining; placing area follows the Mining Spell (the book no longer sets it; its build
  reach still does); summons get Limit (2 ranks); a reaching hand for Reach.
- **Claude:** Power no longer grows the area: Area does (3 ranks: 3x3, 4x4, 5x5). The
  tree lays itself out from `requires` / `requires_any`. Efficient hangs from Potency
  where a spell has Potency. Saves with old Power ranks keep them; dev kit gets Area 2/3.

## 2026-11-26: Phase 40, sand block, denser reinforced wood

- **Patrick:** Sand is a block and a back wall. Done (atlas row 20, `data/walls/sand_wall.tres`).
- **Patrick:** Reinforced Wood's pattern should be denser. Straps every 16 px (2 blocks)
  instead of 32, rivets every 8 px.

## 2026-11-26: Phase 39, freecraft empowers, stat tooltips

- **Patrick:** `freecraft` should cover Empower too. Done (`CharacterData.empower_problem`
  and `buy_empower` take `free`).
- **Patrick:** tooltips should just show stats. Mining and Chopping: a short description,
  then one stat per line; "Has its own key (R): ..." is now "Key: R"; the "Empower it with
  bars" sentences are gone.

## 2026-11-26: Phase 38, shelf fit

- **Patrick:** bottle caps went through the shelf above; the Pantry Rack's back was see-through.
  Tall shelf items are shrunk to the room under the next shelf; the rack has a solid back.

## 2026-11-26: Phase 37, storage, filled bottles, torch, ropes, Catalog search

- **Patrick:** filled bottles, bigger = stronger, glass stronger than clay. Claude: clay
  x1, 1.5, 2 by size, glass x1.3 on top; sickness x1, 1.35, 1.7 by size. Names "Glass
  Flask of Healing".
- **Patrick:** Pantry Rack and Food Pantry, Bookshelf (books, scrolls, pages), Barrel,
  Crate, three Hanging Nets (3x2, 2x3, 6x4) that hang by rope from a block above, and
  Liquid Barrels now (wooden and iron, both need iron, the iron one holds more).
- **Patrick:** torch held out in hand lights around you; ropes side by side connect;
  clicking a rope adds to its bottom; Catalog search; infinity sign for infinite stacks.
- **Patrick:** bottles behind the cabinet glass (`front_frame`), hip book on the hip
  behind the hand, glass continuous, blocks and walls of the same stone read apart
  (blocks x1.12, a soft shadow on walls by built blocks), holding right click to place
  walls no longer lets go over tiles where nothing goes.

## 2026-11-26: Phase 36, fixes

- **Patrick:** a few placed Dark Forest Stone shouldn't flip the biome. Biome share is now
  counted against at least 60% of the box (`biome_min_ground`).
- **Patrick:** background too dark, even with torches. Walls get 40% of daylight above
  ground (`walled_sky`), `wall_shade` 1.0 and built walls x1.35, torch falloff curved
  (`source_curve` 0.6).
- **Patrick:** Clay places as a wall; Glass is a block and a wall too (see-through,
  lets light through). Clay patches making clay walls in generation: undecided, not done.
- **Patrick:** shelf bottles too small, large ones square, glass offset, poison flask
  shape. Claude: shelves draw each item's icon at half size instead of procedural bottles.
- **Patrick:** "Potion Bookcase" renamed Large Potion Cabinet (id kept: `potion_bookcase`).
- **Patrick:** no way to take one from a stack. Right click now takes one (hold repeats,
  speeding up), Shift + right click takes half, like Terraria.

## 2026-11-26: Phase 35, bottles, glass, potion furniture

- **Patrick:** the Potion Cabinet's bottles should be clay, not glass; add 2 more clay
  sizes and 3 glass sizes, each with its own shelf look; a slightly bigger cabinet, a
  bookcase-sized one and a shelf, stackable. The cabinet needs glass (not clay flasks);
  add Sand and Glass (1 Sand = 1 Glass). Big bottles take 2 shelf spaces, heights relative.
- **Claude:** names Clay Bottle (regular), Clay Jug (large), Glass Vial, Glass Bottle,
  Glass Flask; the old thin Clay Flask stays. Shelf space counts in spots, large = 2.
  Stacking via `flat_top` on chests, tables, desks, racks and the potion furniture. Sand
  is Creative-only until a sand biome is designed. Console `freeplace` added on request.

## 2026-11-26: Phase 34, Creative window, quit confirmation

- **Patrick:** F7 is a creative mode window, not "Dev items"; add Dev and Test tabs and
  an Enemy tab to spawn enemies. Claude: Dev = the dev cheat items, Test = placeholder
  held items, test books and the test spells; enemies spawn in front of you.
- **Patrick:** Quit asks first ("Quit without saving?"). Quitting used to save on the
  way out; now the choice is Save & Quit or Quit without saving.

## 2026-11-26: Phase 33, the hovering tool

- **Patrick:** keep every phantom animation, but the tool should hover near you like a
  summon and get pulled into the animation when used.

## 2026-11-26: Phase 32, dev things kept in saves

- **Patrick:** after Save & Quit his Q and E spells reset and the Mining v2+ test spells
  were gone. Dev spells and items were left out of saves on purpose, and registered only
  when the world started (after the character loaded). Now debug builds keep them and
  register them before a character loads; release builds still leave them out.

## 2026-11-26: Phase 31, fixes

- **Patrick:** Air Step and Bound seemed gone: they weren't in the dev kit's spell list,
  so `devkit` now teaches every spell.
- **Patrick:** "Already known" on Spell Pages for known spells; a click with a spell on
  the mouse mustn't use the hand; tooltips narrower with smaller text, like Terraria's,
  never off screen.

## 2026-11-26: Phase 30, book poses

- **Patrick:** the book on the hip when it isn't in hand; liked a mix where the spell
  decides. Claude's rule, which Patrick approved: hip by default; HAND spells put it in
  the back hand (quick casts too, a weapon staying in the front hand); FLOAT spells
  (big beams, charged casts) float it in front with both hands pushing; HIP spells
  (buffs, heals) leave it on the hip, glowing, with a gesture.

## 2026-11-25: Phase 26, phantom swings

- **Patrick:** an illuminated blue target box instead of the white one; every tick the
  tool comes into existence, swings fast with a streak and its own light, aimed at the
  middle of the area. Options welcome, several tools to compare.
- **Patrick (clarified):** the hover should illuminate like Starbound's mining cursor.
  Claude made it a real light at the cursor plus a glow on each targeted block. Then
  Patrick: no outline on the hover area, just the glow.
- Claude made three styles (Arc, Echo, Comet) as test spells and a console switch; Arc
  is the default until Patrick picks.

## 2026-11-25: Phase 25, weapons and schools

- **Patrick:** two playstyles, pure magic and weapons with magic imbued and amplified;
  build both and remove one later if it doesn't fit. Builds lean on schools (a fire
  build: fire spells plus gear that raises fire), never locked in.
- **Patrick:** Dual Storm Axes: left click swings and leaves a shock (a few ticks of
  damage), right click leaps and slams for an area attack, holding them amplifies Storm
  spells. Maybe the axes cast a spell one day (not built).
- Claude's model: a weapon's hits mark enemies for its school and that school's spells
  hit marked enemies 25% harder, so the weapon sets up and the spell finishes (Patrick
  didn't want a dagger that just casts Spark). Schools: Storm, Arcane, Air, Spirit,
  Life, assigned to the existing spells. The Storm Charm (+15% Storm) shows gear builds.

## 2026-11-25: Phase 24, tools are spells

- **Patrick:** no pickaxes or axes. Everyone starts with Mining I, Chopping I and a Copper
  Dagger. The ore grind ranks the spells up through Empower (copper bars, then iron),
  like Terraria's pickaxe ladder moved into the spellbook. Ores also still make gear.
- **Patrick:** a phantom pickaxe or axe swings at the block each tick, glowing per rank.
- **Patrick:** gathering is free (no mana). Dropping mana altogether is undecided.
- **Patrick:** sticks and rocks stay as pickups but gate nothing; no stone weapons or
  tools; flint is gone. Claude also removed the Hand Hammer (it gated the Workbench).
- **Patrick:** more spell tiers for variety, e.g. iron Power makes mining 4x4 and
  stronger, with Reach as its own node. Claude added Potency, Arc, Distance and Lasting.
- Claude's choices: Mining I power 30 (copper, not iron), area 2, reach 8; Power +10
  power, +1 area, +30% speed per rank; hits land once per 0.3 s swing.

## 2026-11-21: Phase 23, the Catalog

- **Patrick:** a Catalog book showing every block and enemy you've found, with a slot to
  put an item in and see its recipes (unknown ones blacked out). You start with it, no
  crafting.
- Claude's defaults Patrick OK'd: J (C was taken by a quick slot), Items, Enemies and
  Recipes tabs, silhouettes with found counts, unknown recipes show their station.
  An enemy is found once killed; its drops appear as you get them from it.
- **Patrick:** it's a panel, not a book item: J or a Catalog button in the inventory.
- **Patrick:** your summoned slime doesn't hop at random: aimed hops at the enemy, and it
  slides into it up close.

## 2026-11-21: Phase 22, summons

- **Patrick:** a summonable enemy's rare core shows its summon recipe and goes into it;
  its Spell Page stays as a rarer direct drop (and maybe chest loot underground later).
- **Patrick:** Summon Slime is melee; Empower changes it through the slime variants
  (Green, then Blue; more as slimes are added). Claude's defaults he OK'd: Slime Core 1
  in 40, page 1 in 100, learn 1 core + 20 Slime + 5 Magic Essence, summons share one
  limit. Evolve cost (15 Slime + 6 Magic Essence) is Claude's pick.
- Spirit Core is now called Forest Spirit Core (id still `spirit_core`).
- Ideas noted, not built: boots or greaves, maybe a cape (Patrick undecided).

## 2026-11-21: Phase 21, Dark Forest ground, biomes, bricks, Pendant

- **Patrick:** real blocks for the Dark Forest (Dark Forest Dirt and Stone, plus walls
  and its grass), not a tint; biomes run to the bottom of the world like Terraria's,
  with curvy, random edges; which biome you're in is counted from nearby blocks.
- **Patrick:** colors: black with a hint of blue (option 1), but background walls not
  too dark; dark blue-black grass.
- Tiles got a ground `kind` so biome versions act like dirt, grass and stone everywhere
  (grass spread, trees, forage, cave floors) without special cases.
- **Patrick:** bricks from stone, any stone to its own brick (2 stone, Furnace, like
  Terraria's Gray Brick).
- **Patrick:** Forest Spirit Pendant: +1 summon, +20% summon damage. How you get it was
  Claude's default: Spell Weaving Table, 1 Spirit Core + 10 Magic Essence; **Patrick:**
  plus 10 Iron Bars. One of each accessory at a time; health and mana show current/total.
- **Patrick:** no clay in the Dark Forest; spirits always glow, brighter when shooting
  (drawn over the lighting, GlowHalo). **Patrick:** your summoned spirit: a slight hue shift (a little teal) and the gold cross
  on top; upgrades may change its color later. Summon Forest
  Spirit's own learning cost (page + core + essence) left as it was until Patrick decides.
- **Patrick:** "Call Spirit" renamed Summon Forest Spirit (id still `call_spirit`);
  your summoned spirit is tinted darker blue.
- Fixes: trees need level ground under the trunk; glowing enemies relight as they move,
  and moving lights glide (shared between tiles, light map fades); holding casts again
  (spells past the combo window, quick keys).

## 2026-11-21: Phase 20, 3D body prototype

- Bound fix: the leap's rise was a fixed 20 tiles/s, which the jump's strong gravity
  ate in about a tile ("moves an inch up"). Now `leap_height` (6 tiles) sets the rise
  from wherever it's pressed, worked out from the jump's gravity.
- **Patrick:** Bound should push farther and faster, mostly sideways: 48 tiles/s ahead
  (was 30) and a lower 4 tile rise. Steering back still slows it.

- **Patrick:** go with the brief's defaults: live 3D (route B) rendered on its own
  pixel canvas, placeholder until his Blender model, Scholar sized, 3 shading bands with
  a light trim and no dark outline, palette colors from the look, existing 2D items on
  the hand, stepped 12 fps vs smooth as a switch, console only for now.
- The PaperDoll keeps all the pose logic (hands, items, feet) and the 3D body follows
  it (`joints_override`, `pose_state`), so items, attacks and emotes needed no new code.
- The placeholder is a mannequin built in code (no download, nothing to license).
- **Patrick:** the code-made looks (blocky, soft, round, fit) didn't work for him; he'll
  model the character in Blender. The game loads a rigged glTF (`style model`, the
  default 3D style) and turns its bones to the doll's targets, so he models and rigs but
  doesn't animate. Rigify bone names, materials named by color group. The 2D Scholar
  stays the default body; the code-made styles stay as switches.
- **Patrick:** more detail than 1x. `detail` renders 1 to 4 pixels per art pixel;
  default 2, the detailed art size used by terrain and icons.
- Colors: Compatibility and Forward+ treat 3D colors differently; `color_space` "auto"
  picks per renderer, untested on Forward+ (only Compatibility runs here).

## 2026-11-21: Phase 19, doll render test

- **Patrick:** do all three: 2x art (scaled up accurately, Scale2x smoothed base to
  refine), the character on its own pixel grid, hand-drawn key poses plus code motion,
  each switchable from the console to compare. All are switches (`doll` command), off by
  default, so today's look is unchanged until Patrick picks.
- 2x is drawn at half size, so the Scholar stays ~3 by 8 tiles; doll math stays in
  original art pixels. Overlays (hair, armor) are doubled with the same steps as the sheet.
- RotSprite is approximated (4x Scale2x, shrunk with nearest), not the full algorithm.
- Hand-drawn poses: a `Sit` / `SitFloor` tag wins over the code pose for the legs.
- Two random tests were made steadier (more tries, a longer wait).

## 2026-11-21: Phase 18, emotes, chat and a chair

- **Patrick:** go deeper on the rig with sitting (a chair and the floor), triggered from a
  Terraria-like chat (/sit). Added /wave and /cheer as the first other emotes, said lines
  show over your head, and a Wooden Chair (4 wood, 2x3) you sit on with right click.
  The chair is new content Patrick asked for.

## 2026-11-21: Phase 17, leg rig test

- **Legs posed in code (Patrick: "start testing"):** two-bone IK legs like the arms, as
  a switch (`PaperDoll.leg_mode`: DRAWN default, PLANTED, POSED) so both can be compared
  in game. PLANTED keeps the drawn run and only plants standing feet; POSED is a fully
  code-made walk. Which becomes the default is Patrick's call after testing.

## 2026-11-21: Phase 16, jump spells, Empower, world map, darkwood

- **Readied jump spells (Patrick):** Air Step (double jump, better air control) and
  Bound (forward leap in an arc). They sit in the concentration slot like Fly but cost
  nothing until the trigger: Jump in the air spends mana once; that landing takes no
  fall damage. "Readied" is the name for this kind (Patrick left the term to Claude).
- **World map (bare bones, Patrick):** key N (M is quick mana). Reveals within 48
  tiles of you, terrain colors from the textures, saved as a picture. Pins, trees,
  chests and teleporting are later.
- **Block stacks (Patrick):** every block item stacks to 9999 (was 999). Special storage
  had its own cap; the Lumber Rack now holds full stacks (Patrick), 10 of them, of any
  logs or wood. Its look stays the log pile frames for now (Patrick); a per-kind look
  (`FillLook.PILE`) is in the code, unused.
- **Darkwood Log (Patrick):** the Dark Log is the Darkwood Log and builds a darkwood log
  block and wall, like the Log.
- **Darkwood and stations (Patrick):** darkwood upgrades the Workbench to the
  Darkwood Workbench (tier 2, 20 Darkwood + 3 Iron Bars), which makes Reinforced Wood
  and Reinforced Darkwood (both for now; one may go later).
- **Empower (bare bones, Patrick):** one first node on every spell's tree, Efficient
  (-5% mana per rank, 5 ranks). Paid in Magic Essence (2 x rank) by default; tree
  nodes are data so more can be added with `requires`.

## 2026-11-20: Dark Forest is one big region

- **Patrick:** big biomes (Dark Forest, like Terraria's jungle or corruption) are one
  large region, not several patches; smaller ones (a desert later) may repeat. Default
  `dark_forest_patches` 1, a quarter of the world, 0.3 of the world from spawn. Worlds
  may need to grow as biomes are added.

## 2026-11-20: Phase 15, satchel, trash and the Forest Spirit's uses

- **Inventory (Patrick, moonweave v4 approved):** the satchel look in code
  (`SatchelLook`), placeholders until real art.
- **Trash slot (Patrick, like Terraria):** one slot, keeps the last thing trashed.
- **Tree Seed is now "Sapling"** (Patrick: regular trees drop saplings too); id unchanged.
- **Discovered recipes (Patrick: "yes, good"):** `RecipeData.unlock_items`; only new
  recipes use it so far (existing ones stay known from the start).
- **Call Spirit (Patrick):** first Spirit Core reveals the scroll; a rare Spell Page,
  plus Essence and a Core at the table, teaches it for good. It fights for you like the
  Familiar. Player summons never drop loot.
- **Two spells at once:** Patrick's own idea for later (concentrating on two), noted.

## 2026-11-20: Phase 14, Dark Forest

- **Size (Patrick):** biomes scale with the world: 25% of its width (raised from 15%,
  Patrick: the world wraps, so it should be bigger) in patches of about 640 tiles
  (Small 3, Medium 4, Large 5), never within 300 tiles of spawn.
- **Darkwood (Patrick: "sounds great"):** Dark Logs from darkwood trees, 1 = 4 Darkwood,
  a block and back wall for now. Station upgrades maybe later. Darkwood trees drop
  Darkwood Saplings (Patrick) that grow darkwood trees.
- **Forest Spirit (Patrick):** darts, stops, charges 1 s, shoots for 15. Drops Magic
  Essence and a rare Spirit Core. What they're for (a summoning scroll, found recipes)
  waits on Patrick's answer to the brief.

## 2026-11-20: Phase 13, Tele Grab

- **Tele Grab (Patrick's idea, name temporary):** held like a beam (Fly stays a toggle).
  A portal at the cursor (25 tiles, needs sight) pulls loose items within 3 tiles into
  a portal at your hand, 3 mana a second. New cast type GRAB. The "no sight needed"
  option is the existing `needs_sight` flag, waiting for the upgrade system. Holding two
  concentration spells is dropped (not in the plan).

## 2026-11-20: Phase 12, home and storage

- **Special storage (Patrick's idea and concept):** Lumber Rack (wood and logs, 10 x 100)
  and Potion Cabinet (potions, coatings, flasks, 10 stacks). Names picked by Claude;
  Patrick liked them. The rack fills in 10% steps with staggered rows filled a layer at a time (no pyramid top); the
  cabinet only shows bottles of the colors actually inside.
- **Wrapped positions (bug, Patrick: no hit sounds, no slimes):** the player's x isn't
  wrapped, so west of x = 0 new slimes, drops and the hit sound were made a whole world
  away. `World.near_player_x` now moves spawned enemies and drops to the copy next to
  the player; the hit sound plays where the tile is drawn.
- **Right click priority (Patrick):** anything outlined (pickups, ripe bushes,
  furniture) beats the held item's back layer action.
- **Berry kinds (Patrick):** raspberry and blueberry bushes besides the plain berry bush.
  They differ in food value (raspberries fill, blueberries heal) and each cooks into a
  buff food (Raspberry Compote: Mending, regen; Blueberry Mash: Light Step, speed). No
  brief needed (Patrick). Kinds are data (`data/bushes`), saved as `kind * 2 + grown`
  so old worlds keep their bushes. The plain berry bush stays as the common one.

## 2026-11-20: Playtest fixes on phase-11-spell-controls

- **Dug-out rock lit like daylight (bug, Patrick):** air with no back wall counted as
  open sky anywhere, so mining wall-less rock lit everything you dug with a hard line
  where your digging stopped. Now open sky only counts above the natural ground
  (`LightMap.sky_depth_tiles`, 0); below that, light only spreads in.
- **Right click (Patrick):** a held block, pickaxe or mining spell does its back layer
  action first when it has one at the cursor. Usable furniture under the cursor still
  wins (so a pickaxe can't mine the wall behind your chest); pickups and bushes don't.
- **Fists don't stun-lock (Patrick):** punches keep a light push but no stagger
  (`ItemData.staggers`). A "chance to stun" could come later from skills.
- **Punching with the item put away, take 2 (Patrick):** the punch animation list only
  allowed empty hands, so H then click still did nothing; fixed (tested with real
  input this time). Pressing the current hotbar number takes a put-away item back out.
- **Spell Weaving Table (Patrick):** tabs Spells | Scrolls | Copy. Spells: learn any
  spell you don't know for its learn cost, no scroll needed. Scrolls: one-use casts
  only (right click learning removed: it needed a right click near, but not on, the
  table, so it looked broken).
- **Taller tunnels (Patrick):** `tunnel_width` 24 (was 18), `tunnel_taper` 0.8 (was 0.6),
  surface entrances 10 to 13 wide (were 7 to 10, the tightest shallow spots). Room to
  hop (3x11) went from 64% to 77% of cave floors (seed 42). New chunks only.
- **Craft preview (Patrick):** while Shift or Ctrl is held, the amount box and the costs
  show what a click would craft and spend; costs are always multiplied by the amount.
- **Slimes in caves at night (Patrick asked):** they chased you by distance sideways
  only, so surface slimes homed in on you from above and dropped into caves. Now they
  only sense you within 16 tiles up or down (`aggro_tiles_vertical`) and despawn 50
  tiles up or down (`despawn_tiles_vertical`; Terraria spawns at most 47 up or down).
  Surface spawns still happen while you're less than 20 tiles down, like Terraria's
  surface layer reaching into shallow caves.
- **Fists usable (Patrick):** punching works with the held item put away (H; it didn't),
  and pickups skip an empty slot in your hand unless nothing else has room.
- **Found scrolls teach again, at the table (Patrick):** carrying a scroll of a spell
  you don't know makes the Spells tab offer Learn for just that scroll. Spells marked
  `learnable_at_table = false` (loot-only ones, say a Magma Bomb later) can only be
  learned this way.
- **Spell Weaving Table filters (Patrick):** group buttons and search, like the Spell
  Index, on all three tabs.
- **Phase 11 wrap-up batch (Patrick, Nov 20):** coating per weapon (slot data),
  coating on Z X C coats the held weapon, coating shown under the hotbar; right click
  puts things on tables and shelves from the mouse, with a preview; window clicks don't
  leak into the world; `infinite` dev toggle; Tier 1 to 3 Spellbooks are real items
  (`give spellbook_t2`); no grass or stone bumps on wood next to them (natural blocks
  round only into open tiles by natural neighbors); spells and Chain Spark stop at walls
  and doors; cursor spells need sight; furniture placing doesn't turn you; a cancelled
  ritual has no cooldown; spell tooltips show types and tier; buff set = Buff spells
  only; Levitate height stays where you leave it; dying ends buffs and summons and the
  On death options grew (drop everything incl. armor, inventory, outside the hotbar,
  keep, permadeath ghost); berry bushes need 3 tiles; ground beyond the light map is
  lit roughly (sky above ground, dark below) so nothing flashes bright; the sun's glow
  fades at its edges; loose items merge and cap at 400; tunnels break into runs;
  chests: Quick stack, Rename, names on hover; wall torches come down with right click;
  spawns blocked in a small ring around beds and campfires (plus built walls, as
  before); the Scribe's Desk takes the scrolls, the Spell Weaving Table keeps learning.
- **Jumping up through a hole (Patrick):** the jump got your feet just under the floor
  above, and the body is wider than the hole's edge, so you slid back down (a platform
  in the hole worked because landing on it lifts you a few pixels). In the air, pushing
  into a ledge up to 12 px above your feet now lifts you onto it.
- **Poison Coating goes on weapons (Patrick):** right click a weapon with it on the
  mouse; 10 hits, no timer; a badge on the weapon. New clay vial art with green wax and
  a drop badge; the Poison Flask is a round clay ball with a green wax band and a skull
  badge. The dummy can be poisoned.
- **Come back where you stood (Patrick):** each character's spot per world is saved;
  if it's blocked when you return, you start at your bed (or the world spawn) so you
  can't teleport into a sealed room. Dying clears it.
- **Spellbooks for testing** are `spellbook_t1` / `t2` / `t3` (`books` gives all three).
- **Food and potions: left click** (Patrick), on the hotbar or the mouse.
- **Furniture faces the way you placed it (Patrick):** placed facing left = mirrored.
- **Dev items window (Patrick):** F7 / `creative`, every item, a stack per click. Not a
  creative mode (no flying or god mode); a creative character could come later.
- **Test books:** `books` gives tier 1, 2 and 3 test books (dev builds). The Basic
  Spellbook stays tier 1 (it casts tier 1 spells).
- **Food and potions:** left or right click (Patrick found left click missing).
- **Concentration shown** under the held spell: icon and name.
- **Mushroom icons** are the 9x8 ground sprite on 16x16 (they read too big).
- **Mouse stack is used (Patrick):** with the inventory open, any item on the mouse is
  held and used over the world (left click); right click throws the stack.
- **Food and potions on right click (Patrick).**
- **Tooltips say what changes (Patrick):** conduits show "Spell power x1.25", "+4 spell
  reach" (their kind on the right), and any item's stats show as modifier lines.
- **Spell in hand:** icon and name under the hotbar.
- **Speckled edges in shadow (bug, Patrick):** some blocks at cave edges looked like a
  checkerboard. With detailed art the terrain shader reads its noise texture every half
  pixel, which lands on texel edges, and some GPUs pick either side there. The noise is
  now read per world pixel (texelFetch), like before detailed art. I couldn't see it on
  the software renderer, so this is the likely cause, not a confirmed one.
- **Crafting from chests (Patrick):** inventory first, then chests within 12 tiles,
  closest first. Dev `freecraft` makes crafting free.
- **Swings in the air (bug, Patrick):** flying above a slime still hit it (the swing
  reaches 3 tiles below your feet for downhill enemies). Off the ground it stops at
  your feet now.
- **Healing Circle doesn't stack (Patrick):** one at a time; casting again moves it.
  Later an upgrade could allow 2 (`max_active`, also used by wards and familiars).
- **Book tooltip (Patrick):** Name | Tier, Spell power, modifiers. "Holds 4 spells" is
  gone (books don't hold spells since Phase 11).
- **Quick panel tooltips (Patrick):** hover Q E Z X C for the spell's info.
- **Spell Pages and scrolls (Patrick):** pages teach, scrolls cast. A Spell Page (found;
  console `page <spell>` for now) teaches its spell for good on left click. Scrolls never
  teach. The Spell Weaving Table has Spells | Scrolls: the Scrolls tab scribes only
  spells you know, at full cost (`World.scribe_cost_mult` 1.0, for a skill later), with
  the max mana gate by tier; no 50% known-spell discount and no Copy tab. Why: rare
  spells stay valuable (find the page, learn it, scribe scrolls for friends), and scroll
  costs will be each spell's own materials, which keeps scrolls from being free.
- **Double jump:** stays removed; F is the movement spell (Patrick).
- **Mouse stack placing, take 2 (Patrick):** blocks, platforms and ropes were limited
  by the selected hotbar slot's count (0 on an empty slot), so only furniture placed.
- **Craft amount resets (Patrick)** after crafting, on another recipe and on opening.
- **Z X C take items (Patrick):** a shortcut to any item. Food is used right away;
  anything else goes in your hand, from the backpack too.
- **Movement slot (Patrick):** pick the F spell in the Equipment window
  instead of "the last one used".
- **Wheel picks don't cast (Patrick):** picking a cast-right-away spell on a wheel makes
  it the tap spell; tap to cast.
- **Quick panel:** key letters above the squares instead of over the icons.
- **No melee through walls (bug, Patrick):** the swing box ignored terrain, so a sword
  hit a slime through a closed door. Hits now need a clear line (blocks and closed doors
  stop it).
- **Magic bag over furniture (Patrick):** clicking a bag that landed on a workbench opened
  the workbench. Interactable nodes (the bag) now come first, and the hover outline
  shows the bag.
- **Ending buffs (Patrick):** right click a buff, summon or light in the buff row to end
  it. Not potion sickness (that would skip its wait) or auras.
- **Placing from the mouse stack (Patrick):** with the inventory open, a placeable
  stack on the mouse is held and placed like a hotbar item instead of being thrown.

## 2026-11-19: Phase 11, spell controls (branch phase-11-spell-controls)

- **Quick slots instead of the book's slots (Patrick):** spells go on two wheels (Q and
  E, 8 each; hold to pick, tap for the last pick), three keys (Z, X, C) and a buff set
  (B, casts all of them at once). Not on the hotbar any more.
- **Cast or in hand, per slot (Patrick):** a toggle on each slot; the default comes from
  the spell (things you aim and hold go in hand, the rest cast right away).
- **Books (Patrick):** they keep their job: power for every spell you cast and the tier
  limit. No more "unfocused" penalty; `spell_slots` is unused.
- **R = Mining Spell, Ctrl + R = Chopping Spell, F = movement (Patrick).** Number keys
  for book slots, R + number quick cast, the off-hand spell and double jump to fly are
  gone, and so is the Settings "Spell controls" page.
- **No keyboard throw or interact for now (Patrick):** Q and E became the wheels. The walk
  toggle moved from C to Caps Lock (C is a quick key) and the debug brush from B to F4.
- **Spell Index:** tabs by a new `SpellData.group` (Tools, Movement, Attack, Defense,
  Light) and a search box. Spell tooltips: name, description, mana, needs.
- **Chain Spark (Patrick):** shoots toward the cursor and can miss, instead of needing a
  target under the cursor.
- **Timers:** Familiar, Light Orb and Wisps show in the buff row (Wisps with a count).

## 2026-11-19: Phase 10, detailed art (branch phase-10-hires-art)

- **More detail, same game (Patrick):** blocks stay 8 world pixels and everything that
  plays (physics, reach, camera, how much world you see) stays the same. Art may be drawn
  at 2 art pixels per world pixel (16 per block, 32x32 icons), shown at the same size.
  Normal and detailed art mix, so things get redrawn one at a time.
- **16 per block, not 12 (Patrick asked):** 12 is only crisp at 1080p; 16 is crisp at
  1440p and 4K, doubles today's art cleanly, and is the common size. At 1080p it's 1.5
  screen pixels per art pixel, which Patrick found fine on the squeezed icons.
- **Dirt and stone look the same (Patrick):** regenerated at 2x with the same recipes
  and layout, only the edges and details are 1 art pixel. The concept that redesigned
  them was rejected.
- **Stations at 2x (Patrick):** every crafting station redrawn at 2x detail, same
  footprint and look (the old art scaled up, then grain, grit and 1 pixel edges added).
- **Items on display (Patrick, my defaults):** any small item can be set down on a floor,
  table top or shelf (right click), one per tile, decoration only, right click to take
  it back. Not on stations (Patrick). New Table (4x3) and Shelf (3x1, on a back wall).
- **Flasks:** the starter tier is the thin clay vial (32x32, wax seal, glaze band).
  The contents badge moved out of the art into the inventory slot (top right, because
  the count is bottom right), so the bottle looks clean in hand and on the ground.
  Glass and bigger bottles are concepts for later tiers.

## 2026-11-19: Food and alchemy (on phase-09-underground)

- **Campfire cooks (Patrick):** right click it. Cooked food beats raw; the stew needs a
  Wooden Bowl and gives Well Fed.
- **Clay flasks (Patrick):** potions come in clay flasks fired from Clay, a new block in
  patches near the surface like Terraria's. Sand, falling sand, hardened sand and glass
  vials wait for a desert biome phase. No slime flask.
- **Alchemy Table with tabs (Patrick):** Potions, Coatings, Flasks.
- **Telling flasks apart (Patrick's idea, kept):** each filled flask has its own glaze
  color plus a small badge in the icon's bottom right corner. Baked into the icon rather
  than drawn by the UI, so it also shows on the held item, drops and tooltips.
- **Potion sickness:** like Terraria's, so potions can't be chained; healing 30 s,
  mana 10 s, separate groups.
- **Starter strength (Patrick):** these are the lowest tier, so they were halved: Healing
  Potion +30, Mana Potion +40, coating 10 hits at 2 per second, flask cloud 4x3 at 2 per
  second. A Clay Flask takes 2 Clay. Empty flasks stay used up for now (returning them
  after drinking is an option later).
- **Poison:** Duskcaps make a melee coating and a thrown flask that leaves a
  cloud. Placeholder numbers, easy to tweak in the item files.

## 2026-11-19: Phase 9, underground

- **Lighting like Terraria (Patrick):** light multiplies per tile (0.965 through air,
  0.8 through blocks: Terraria's 0.91 and 0.56 scaled to our smaller tiles), no
  minimum brightness, so unlit caves are black and sunlight dies a few blocks down.
  Light radii raised to match (torch 32, Light Orb 36, furnace 16).
- **Campfire (Patrick):** a stationary light bigger than a torch (radius 48) and Cozy
  (+1.5 health per second) within 12 tiles. Hand: 5 Wood + 3 Stone. Torches still need
  slime (slimes are on the surface, so it's not a blocker).
- **Roomier caves (Patrick):** `tunnel_width` 13 to 18, and tunnels taper to 60% before
  ending instead of to nothing (`tunnel_taper`). Scholar-fit floor share went from 64 to
  75% to 79 to 83% (`tools/cave_fit.gd`). Some tight bits stay on purpose.
- **Mining power (Patrick):** each block has a minimum pickaxe power; a strong enough
  but weaker pickaxe is just slower. Iron ore needs 35, so stone and copper pickaxes mine
  it (slowly).
- **Iron (Patrick):** deeper than copper (from 40 tiles down, 2% per cell rising to 10%
  by 250), stone only. Iron Bar, Iron Pickaxe, Axe, Sword, Helmet, Chestplate, Greaves at
  the furnace and anvil. Placeholder art is the copper art recolored.
- **Mushrooms (Patrick):** Field Mushroom (food), Red Cap (potions later), Duskcap
  (underground, poisons later), Glowcap (underground, glows, mana potions later).
  Potions, coatings, flasks and cooking are later briefs.

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
- **Logs and Wood, no flint (Patrick):** trees drop Logs by size (one per 6 tiles of height: 2, 3 or 4); 1 Log = 4 Wood by
  hand, and a Log places as a log cabin block and back wall. Wood (the renamed planks)
  places the plank block and is the wood in every recipe; ground sticks give 1 Wood.
  Wood Planks and Sticks are gone; flint is gone too (stone tools are 3 stone + 2 wood).
  Torches need slime (1 slime + 1 wood = 5). Old saves load sticks and planks as Wood,
  flint as Stone. Later: other woods per biome, and Reinforced Wood (iron + wood, a block and a
  back wall, for higher stations and tools) once iron exists; needs a brief.
- **Fists hurt:** a punch does 3 damage (Patrick).
- **Hitting downhill (Patrick):** swings reach 3 tiles below your feet (Terraria's arc);
  punches aim at the cursor (up to 60 degrees), arm included.
- **Lighter back walls:** `wall_shade` 0.62 to 0.75 (Patrick: plank walls too dark).
- **Rocks give Stone (Patrick):** the Rock item only made the Hand Hammer, so a loose
  rock now gives 1 Stone (the sprite stays a rock). The Rock item and the Workbench's
  Stone into Rocks recipe are gone; older saves load Rock items as Stone.
- **Hover outline:** a soft pulsing outline on anything right click / E would use, in reach.
- **Craft amount:** [-] [n] [+] Craft; Shift = 10, Ctrl = as many as you can up to a
  stack. Replaces the Craft / x10 / All buttons.
- **Open doors:** any visible part of the swung face can be clicked.
- **Log cabin look (Patrick, style B2, placeholder):** rounded horizontal logs; where a run
  ends, the log sticks out 2 px with rounded tips (`overhang_px`, drawn by the terrain
  shader, no collision). Back wall: the same logs, darker.
- **Build against doors (Patrick):** a door anchors blocks (next to it, on top) and back
  walls (next to, on top, behind), open or closed (`anchors_building` on ObjectDef).
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
