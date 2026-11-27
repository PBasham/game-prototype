# Playtest checklist: Phases 5 to 11

Check out `phase-11-spell-controls`: each phase branch is built on the one before, so it
contains main plus Phases 5 to 10 and is the only branch to test. Phases 5 to 7 haven't
been fully playtested yet. Numbers are first
guesses; the docs listed say where each tunable lives.

## Handy console commands (the ~ key)

| Command | For |
|---|---|
| `devkit` | Tools, blocks, all spells (and quick slots filled to try) |
| `god`, `mana`, `heal` | Survive while testing |
| `time 21` / `time 12` | Jump to night or noon |
| `summon green_slime 3`, `summon blue_slime` | Enemies at the cursor |
| `peaceful`, `butcher`, `spawns`, `kills` | Control and inspect spawning |
| `quick z levitate` | Put a spell in a quick slot (q1..q8, e1..e8, z, x, c, buff1..buff6) |
| `equip dev grimoire` | A tier 3 book for Hyper Drill |
| `give copper bar 30`, `place bed`, `use` | Items, furniture, right click at the cursor |

## Phase 5: crafting (crafting.md)

- [ ] Start from nothing: sticks (Wood) and rocks (Stone) from the ground; Hand Hammer, stone tools.
- [ ] Workbench, furnace, anvil: recipes show, crafting amounts work.
- [ ] Chests hold items and save; doors open, close and block.
- [ ] Mana drains while casting and refills.

## Phase 6: characters, UI, survival (survival.md, crafting.md)

- [ ] New character page, colors, hairstyle; picking a character and a world.
- [ ] Crafting (K) and chest windows on the right; UI looks right.
- [ ] Health, mana, hunger panel bottom left; the clock.
- [ ] Day and night (24 minute days); light stops at walls and closed doors.
- [ ] Hunger drains slowly; berries and berry bushes (2 to 3 days to regrow).
- [ ] Dying drops the magic bag; world options (hunger off, keep items).

## Phase 7: combat, equipment, beds, spells (combat.md, items-and-mining.md)

**Enemies and spawning**
- [ ] Slimes feel right: hop height, timing, damage, readable at night.
- [ ] Spawn pace by day (about every 10 s, 5 max) and night (about every 6 s, 6 max), never inside your view even zoomed out.
- [ ] No Blue Slimes until you've killed a Green one; then about 1 in 9.
- [ ] Nothing spawns underground (more than 20 tiles below the surface) or indoors.
- [ ] Enemies far away (90 tiles) despawn.

**Fighting and gear**
- [ ] Wooden and Copper Swords: reach and when the hit lands.
- [ ] Copper armor: defense lowers damage; it looks right on the character (helmet,
  chestplate, greaves).
- [ ] Equipment window (P): character preview, slots, stats, folding Quick spells,
  dragging it around.

**Beds**
- [ ] Right click by day sets the spawn point; at night you sleep to morning.
- [ ] Can't sleep with an enemy near; break the bed and die: back at world spawn.

**Spells**
- [ ] Fly is faster; Shift boosts (and drains mana fast).
- [ ] Levitate: hovers about 5 tiles up, follows the ground, glides; Down lowers you.
- [ ] Hyper Drill (needs the Dev Grimoire): big round hole, heavy mana.
- [ ] Air Push shoves slimes; pushes you back in the air.
- [ ] Blink: goes toward the cursor, never into blocks.
- [ ] Light Orb follows you; Wisp: hold to steer, let go to leave it (3 max).
- [ ] Mend heals while on.

**Spell controls:** replaced in Phase 11 (Q/E wheels, Z X C, B, R).

**Scrolls**
- [ ] Paper, Blank Scroll (needs Slime), Spell Weaving Table at the Workbench.
- [ ] Scroll recipes at the table; left click a scroll casts it once (learning is the Spells tab now).

## Phase 8: spell types and sound (branch phase-08-spell-types, on top of Phase 7)

`cast <spell>` in the console casts any spell at the cursor for free.

- [ ] Gel Cushion: needs 5 Slime; saves one bad fall (squish), else 2 minutes.
- [ ] Arcane Bolt: tap vs full charge.
- [ ] Healing Circle heals inside only; Spark Ward zaps the first slime on it.
- [ ] Familiar shoots slimes; Conjure Platform holds you, Down + Jump drops through, fades.
- [ ] Arcane Edge: sword hits harder; Barrier pops when you get low.
- [ ] Chain Spark jumps between slimes; Recall: stand still 3 s, moving cancels.
- [ ] Seek Ore underground at night.
- [ ] Sounds: anything too loud, annoying or missing?

**Phase 9: underground**
- [ ] Caves with no light are black; torches, the campfire and glowcaps light them.
      Sunlight fades a few blocks into the ground. Too dark or too bright?
- [ ] Campfire (5 wood + 3 stone): big warm light, Cozy buff nearby, gone when you leave.
- [ ] Caves roomier: most tunnels walkable, a few tight bits left.
- [ ] Iron ore appears from about 40 tiles down, more deeper; stone and copper pickaxes
      mine it slowly; iron bars, tools, sword and armor craft and work.
- [ ] Mushrooms: field and red caps on the surface and in caves, duskcaps and glowcaps
      only in caves; field mushroom and red cap are edible. `forage glowcap` places one.

**Food and alchemy**
- [ ] Clay patches just under the grass; dig some, fire Clay Flasks at the furnace (2 Clay each).
- [ ] Campfire right click opens Cooking: roasted berries, cooked mushroom, stew (needs a bowl).
- [ ] Stew gives Well Fed (faster, more regen) for 5 minutes.
- [ ] Alchemy Table tabs: Potions, Coatings, Flasks. Can you tell flasks apart at a glance?
- [ ] Healing / Mana Potions work, and you can't chug a second one until the sickness ends.
- [ ] Poison Coating: sword hits poison slimes (green numbers). Poison Flask throws, shatters, cloud.

**Phase 10: detailed art (branch phase-10-hires-art)**
- [ ] Dirt, stone, their walls and clay look like before, just finer. Anything off?
- [ ] Healing / Mana Potion and Clay Flask: thin clay vials in the slot, hand and on
      the ground; badge in the slot's top right corner.
- [ ] Try a 1440p window if you can: detailed art is exactly 2 screen pixels there.
- [ ] Stations (workbench, furnace, anvil, campfire, alchemy and spell weaving tables)
      look like before, with wood grain and finer edges.
- [ ] Table and Shelf (workbench). Hold a potion, mushroom or bar and right click the
      floor, table top or shelf to display it; right click to take it back. Not on
      stations. Breaking the table drops what's on it.

**Phase 11: spell controls (branch phase-11-spell-controls, on top of Phase 10)**
- [ ] Hold Q (or E): the wheel opens; let go on a spell. Tap Q: the same spell again.
- [ ] The panel beside the hotbar shows Q, E, Z, X, C; the gold bolt = casts right away.
- [ ] Equipment (P), Quick spells: drag spells in from the Spell Index; click a slot's
      top right corner to flip cast / in hand. Do the defaults feel right?
- [ ] Z, X, C each cast or equip their spell.
- [ ] B casts the buff set (dev kit: Arcane Edge, Barrier, Gel Cushion). Out of mana:
      it says which didn't go off.
- [ ] R = Mining Spell in hand, Ctrl + R = Chopping Spell; again puts it away.
- [ ] Spell Index: tabs and search (typing there doesn't move you or open wheels).
- [ ] Tooltips: name, description, mana, needs.
- [ ] Chain Spark fires at nothing (and misses); hits chain as before.
- [ ] Familiar, Light Orb and Wisps show a timer in the buff row; Wisps show 2/3.
- [ ] No keyboard throw (Q) or interact (E) any more; walk toggle is Caps Lock;
      the debug brush moved to F4.

**Fixes from your Phase 11 testing**
- [ ] Digging down underground: no bright area with a hard line any more.
- [ ] Right click with blocks, a pickaxe or the Mining Spell does the back wall first;
      doors, chests and stations still open.
- [ ] Punches push slimes a little but don't stop their hops.
- [ ] H (put away) then punch works (fixed again); pressing that slot's number takes it
      back out; picking things up leaves an empty hand empty.
- [ ] Spell Weaving Table: Spells tab (learn for copper bars, no scroll), Scrolls, Copy.
- [ ] New caves (F6 or unexplored areas): tunnels tall enough to walk and hop through.
- [ ] Craft window: hold Shift or Ctrl, the amount and costs change to match.
- [ ] Night in a cave: slimes on the surface above stay up there (and despawn when far).
- [ ] Inventory open, sword or pickaxe on the mouse: left click swings / mines; right
      click throws the stack.
- [ ] Food and potions: left click eats / drinks (right click doesn't).
- [ ] Coat one of two wooden swords: only that one is coated (badge, tooltip, under the
      hotbar); Z/X/C with a coating coats the held weapon.
- [ ] Inventory open, potion on the mouse over a shelf: preview, right click puts it there.
- [ ] Click a window's x: the hotbar item isn't used.
- [ ] `infinite`, `give spellbook_t1` (no "(dev)").
- [ ] Wood next to grass or stone: no green or gray bump on top.
- [ ] Chain Spark and projectiles stop at walls and closed doors; Healing Circle through a
      wall: "Out of sight".
- [ ] Place a bed facing left: you don't turn, it stays as the preview showed.
- [ ] Recall, then move: no cooldown.
- [ ] Spell tooltip: types small beside the name, tier top right. Buff set takes Buff
      spells only.
- [ ] Levitate: down lowers you and you stay there; up goes back up.
- [ ] Die: buffs, Light Orb, familiars end. New world On death options; permadeath
      character shows as a ghost.
- [ ] `bush` needs 3 tiles of grass apart.
- [ ] Move fast / zoom out at night: no bright ground at the edges.
- [ ] Sunrise: no straight edge on the glow.
- [ ] Dig a long line: items merge on the ground, no big lag.
- [ ] New world (or F6): tunnels in pieces of different lengths.
- [ ] Chest: Quick stack, Rename, name on hover. Right click a wall torch: it comes down.
- [ ] Sleep area: no spawns within ~14 tiles of a bed or ~12 of a campfire.
- [ ] Scribe's Desk (workbench) makes scrolls; the Spell Weaving Table only learns.
- [ ] Jump up through a hole in a floor (no platform): you step onto the floor.
- [ ] Poison Coating on the mouse, right click a sword: badge on the sword, tooltip hits
      left, 10 poisoned hits. Dummy shows green numbers.
- [ ] New Poison Coating vial and round Poison Flask art.
- [ ] Leave a world and come back: you're where you stood. Wall yourself in a box,
      leave and come back: you're at your bed / spawn.
- [ ] `give spellbook_t2` works.
- [ ] Place a bed / workbench facing left: it's mirrored (and stays so after reload).
- [ ] F7 (or `creative`): Creative window; tabs, search, click for a stack.
- [ ] `books`: tier 1 / 2 / 3 test books.
- [ ] Concentrating (Fly): its icon and name under the held item.
- [ ] Mushrooms look small in the inventory and hand.
- [ ] Dev Focus tooltip: just the changes, "Focus" on the right.
- [ ] Spell in hand: icon and name under the hotbar.
- [ ] Cave edges in shadow: no checkerboard blocks.
- [ ] Crafting with materials in a nearby chest (within 12 tiles): inventory used first.
- [ ] Console `freecraft`: craft anything with no materials; again turns it off.
- [ ] Flying or jumping over a slime: a sword can't hit it far below you.
- [ ] Healing Circle: casting again moves it (no stacking).
- [ ] Book tooltip: name and Tier on top, Spell power, modifiers. No "Holds 4 spells".
- [ ] Hover Q E Z X C beside the hotbar: full spell tooltip.
- [ ] Spell Weaving Table: Spells | Scrolls; group buttons and search filter both.
- [ ] Scrolls tab only lists spells you know, at full cost, with the max mana gate.
- [ ] Spell Pages: `page fly` in the console, left click the page: you know Fly again.
      Scrolls never teach.
- [ ] Inventory open, pick up blocks / a wall / a chest / a sapling: over the world they
      show the placement preview and click to place from the mouse stack; non-placeables
      still throw.
- [ ] Mouse stack: blocks, platforms and ropes place too (even with an empty hotbar slot).
- [ ] Craft amount goes back to 1 after crafting / another recipe / reopening.
- [ ] Z X C: put an item there (click the slot with it on the mouse). Food eats, a block or
      station goes in hand (from the backpack too).
- [ ] Equipment window Movement slot: put Levitate there; F uses it.
- [ ] Picking a cast-right-away spell on a wheel doesn't cast it; tapping does.
- [ ] Quick panel: key letters above the squares.
- [ ] Swords and punches don't hit through closed doors or walls; still hit downhill.
- [ ] A magic bag on top of a workbench: right click opens the bag (and it's outlined).
- [ ] Right click a buff (Arcane Edge, Familiar, Wisps) in the buff row: it ends.
      Potion sickness and Cozy don't.

**Phase 12: home and storage (branch phase-12-home-storage)**
- [ ] Lumber Rack (workbench: 25 wood + 4 logs): only wood and logs go in, 10 stacks of
      100 (1,000). The pile grows a full staggered layer at a time, every 10%.
- [ ] Potion Cabinet (workbench: 20 wood + 2 copper bars + 2 clay flasks): only potions,
      coatings and flasks, 10 stacks. The shelves fill with bottles the color of what's
      inside (red healing, blue mana, green poison).
- [ ] Their windows show "used / total" and a fill bar; Shift+click and Deposit all skip
      what doesn't fit.
- [ ] `stock <item> [count]` puts items in the chest you have open.
- [ ] New world: raspberry (pink) and blueberry (blue) bushes among the red ones.
      `bush raspberry` / `bush blueberry` in the console.
- [ ] Hits on blocks make their sound again (it was lost west of spawn).
- [ ] Slimes spawn everywhere again, including far left of spawn.
- [ ] Pickaxe in hand, right click an outlined stick or rock in front of a back wall:
      you pick it up (the wall stays).
- [ ] Lumber Rack: logs in staggered rows, filling a full layer at a time.
- [ ] Raspberries fill more (+14), blueberries heal more (+4 health).
- [ ] Campfire: Raspberry Compote (4 + a bowl, Mending: +1 health/s for 4 min) and
      Blueberry Mash (4 + a bowl, Light Step: +15% speed for 4 min).

**Playtest fixes (your notes)**
- [ ] Sticks and rocks on grass, cliffs and cave floors; they come back over time
      (`pickups 10` then walk a bit), never on screen or indoors.
- [ ] Slimes: wander past you by day, chase at night or once hit; random hop sizes,
      slithers up 1-block steps, no more hopping in place.
- [ ] Spawn pace feels right (Terraria numbers), nothing pops in on screen when zoomed out.
- [ ] Hover outline on doors, chests, stations, beds, sticks, ripe bushes.
- [ ] Open doors close from any part of the face.
- [ ] Craft row: [-] [n] [+] Craft, typing a number, Shift = 10, Ctrl = a stack.
- [ ] Stone Pickaxe 2x2, Ctrl + wheel to 1x1.
- [ ] Trees drop Logs; 1 Log = 4 Wood; Logs build a log cabin (block and back wall);
      torches need slime; no flint (stone tools are stone + wood). Old saves convert.
- [ ] Punching a slime hurts it; punches aim at the cursor (a slime downhill); sword swings reach downhill.

**Phase 13: Tele Grab (branch phase-13-tele-grab)**
- [ ] Learn Tele Grab at the Spell Weaving Table. Hold left click: a violet portal at the
      cursor (out to 25 tiles), items near it fly in and pop out at your hand.
- [ ] Portal is red and nothing happens when there's a wall between you and it.
- [ ] Costs 3 mana a second; stops when you're out.
- [ ] Mine a far wall with the Mining Spell, then Tele Grab the ore.

**Fixes from your Phase 12 notes**
- [ ] Place a chest, Lumber Rack or Potion Cabinet: no error (the hover name tooltip
      crashed with no window under the mouse).
- [ ] Mining Spell, Chopping Spell, Fly / Levitate tooltips: "Has its own key".
- [ ] Creative window (F7): click 1, Shift 10, Ctrl a stack, right click an infinite stack
      (place or eat from it forever; its tooltip says so).
- [ ] Air Push: no hits through walls; stronger push; aim down on the ground: a gust jump.

**Phase 14: Dark Forest (branch phase-14-dark-forest)**
- [ ] New world: the Dark Forest (one big region since Phase 15). `tp` there or walk.
- [ ] Darkwood trees drop Darkwood Saplings; planted, they grow darkwood trees.
      The map preview shows them as purple trees.
- [ ] Tall darkwood trees close together, dark trunks backdrop, half the daylight; the
      edge fades in and out.
- [ ] Chop a darkwood tree: Darkwood Logs; 1 Darkwood Log = 4 Darkwood (by hand); Darkwood
      builds blocks and back walls.
- [ ] Forest Spirits: dart about, stop, charge (sparks) for 1 s, shoot (15 damage).
      Walls block their shots; they don't shoot what they can't see.
- [ ] They drop Magic Essence, and a Spirit Core now and then. `summon forest_spirit`.

**Phase 15: satchel, trash, discovered recipes, Call Spirit (branch phase-15-satchel-spirits)**
- [ ] The inventory is the blue cloth satchel: darker toward the middle, no cell lines,
      knot and crystal on the right when open.
- [ ] Trash (bin, bottom right): drop a stack on it, or Ctrl + click a slot. Click it
      with an empty mouse to take the last one back.
- [ ] New world: one big Dark Forest (a quarter of the world) on one side of spawn,
      about 1,900 tiles away on Small. The map preview shows it.
- [ ] Pine trees drop "Sapling" (was Tree Seed).
- [ ] Kill Forest Spirits until a Spirit Core drops: "New recipe: Scroll: Call Spirit";
      it's at the Scribe's Desk (Blank Scroll + 3 Essence + 1 Core).
- [ ] The scroll calls a Forest Spirit that charges (sparks) and shoots enemies, 90 s.
- [ ] `give page_call_spirit`: reading it says to use the table; "Learn: Call Spirit"
      appears at the Spell Weaving Table (page + 5 Essence + 1 Core).

**Phase 16: jump spells, Empower, world map, darkwood (branch phase-16-moves-map-empower)**
- [ ] Air Step (Movement slot, F): free while on; Jump in the air = a second jump with
      snappier steering; 8 mana; the landing doesn't hurt even from high up.
- [ ] Bound: Jump in the air = a long forward leap in an arc; 12 mana; safe landing.
- [ ] Each works once per time in the air, and re-arms when you land.
- [ ] Spell Weaving Table: Learn and Empower tabs. Empower: "Spark: Efficient 1/5" for
      2 Magic Essence; the tooltip's mana goes down 5% per rank.
- [ ] N opens the world map: what you've seen fills in as you walk; wheel zooms, drag
      pans, N or Esc closes. Save, quit, come back: still explored.
- [ ] Workbench: Upgrade (20 Darkwood + 3 Iron Bars) turns it into a Darkwood Workbench;
      it makes Reinforced Wood and Reinforced Darkwood (4 + 1 Iron Bar), sturdy blocks
      and walls.
- [ ] Blocks stack to 9999.
- [ ] Lumber Rack: takes any logs and wood in full stacks (10 of them); the log pile
      grows as stacks fill (5 full stacks = half).
- [ ] Darkwood Log (from darkwood trees) places a darkwood log block; right click a wall.

**Phase 17: leg rig test (branch phase-17-leg-rig)**
- [ ] Console `legs planted`: stand on a slope or a step: each foot on its own ground,
      the lower one reaching down. Running: your frames, nudged onto the ground.
- [ ] `legs posed`: walk, run, jump with a code-made gait. Compare with `legs drawn`.
- [ ] Tune live: Remote, Player > Doll, the "Legs (rig test)" exports.

**Phase 18: emotes, chat, chair (branch phase-18-sit-emotes-chat)**
- [ ] Enter opens the chat; type hello, Enter: it's in the log and over your head.
- [ ] /sit sits on the floor; /wave; /cheer; /stand; /emotes lists them. Walk to stand up.
- [ ] Workbench: Wooden Chair (4 wood). Right click it: you sit facing away from the
      back, thighs level. Place it facing left: you sit facing left.
- [ ] While typing, WASD, I, K and the rest don't do anything in the game.

**Phase 19: doll render test (branch phase-19-doll-render)**
- [ ] Console `doll grid on`, then compare `art 1x`, `art 2x`, `art 2x_smooth`,
      `turn rotsprite`. Look at arms swinging a tool, legs on a chair (`place chair`,
      right click it) and `/sit`. `doll grid off art 1x turn basic` is how it was.
- [ ] `doll squash on`: jump and land. `doll sway on`: run and stop, watch the hair.
- [ ] `doll blend off`: hands snap between poses instead of sliding.
- [ ] Which combination to keep as the default (and what to drop) is your call.
- [ ] Optional: draw a `Sit` frame in Aseprite, reimport, rerun `tools/upscale_doll.py`.

**Phase 20: 3D body prototype (branch phase-20-3d-body)**
- [ ] Console `body 3d`. Walk, run, jump, swing tools, cast, `/sit`, `/wave`, `/cheer`,
      sit on a chair. `body doll` to compare with the Scholar.
- [ ] **Colors first:** does the 3D body's blue match the world's look? If it's too
      dark or washed out, try `body colors as_is`, `srgb`, `linear` and note which.
- [ ] `body step 12` vs `body smooth`: hand-drawn feel or fluid?
- [ ] `body detail 1` to `4` (2 is the default, the detailed art size).
- [ ] `body bands 2` vs `3`, `body trim 0`, `body turn 0` / `30`.
- [ ] `body style model` (the default): the rigged placeholder posed by its bones.
- [ ] Your own model: follow [3d-character.md](3d-character.md), export to
      `assets/body3d/scholar.glb`, `body 3d`.

**Phase 21: Dark Forest ground and more (branch phase-21-dark-forest-blocks)**
New worlds only for the ground (old chunks keep their blocks). `tp dark` gets you there.
- [ ] Dark Forest Dirt, Stone, Grass and walls under the Dark Forest, down to the bottom,
      with wobbly, mixed edges. Are the colors right (`tools/make_dark_forest_terrain.py`)?
- [ ] The dark backdrop and Forest Spirits follow the ground you're in: dig out of it,
      or build a Dark Forest Stone room in the normal forest.
- [ ] Grass spreads onto Dark Forest Dirt as blue-black grass; seeds work on it.
- [ ] Stone Bricks and Dark Forest Stone Bricks at a Furnace (2 stone each).
- [ ] Forest Spirit Pendant (Spell Weaving Table: 1 Spirit Core, 10 Magic Essence, 10 Iron Bars):
      two summoned spirits, hitting 20% harder. Yours are darker blue.
- [ ] Spirit lights glide smoothly; Light Orb too.
- [ ] Hold the mouse button with Chain Spark in hand, or hold its quick key: keeps casting.
- [ ] Bound: 48 tiles/s ahead, a low arc; pull back to slow down.
- [ ] No trees hanging over drops; trunks lean a little, some mirrored.
- [ ] Health and mana show current/total (108/120). Only one of each accessory.
- [ ] Forest Spirits (wild and yours) always glow, brighter while charging and shooting.
- [ ] No clay under the Dark Forest.

**Phase 22: summons (branch phase-22-summons)**
- [ ] A Forest Spirit Core shows Learn: Summon Forest Spirit (core + 5 Magic Essence);
      its Spell Page teaches it on a left click, anywhere.
- [ ] Slimes rarely drop a Slime Core (1 in 40) or Spell Page: Summon Slime (1 in 100).
      `give slime_core` to test quickly.
- [ ] Summon Slime: your slime (gold cross) goes straight for enemies (aimed hops, slides
      into them up close) and hits them, stays
      near you otherwise. Evolve at the Empower tab: it's a Blue Slime next cast.
- [ ] With the Pendant: a slime and a spirit together.

**Phase 54: water: swimming, breath, thirst, bottles, Siphon, barrels (branch phase-54-water)**
- [ ] Dig a deep pit, `water 6 10` into it, jump in: you swim (W or Space up, S down,
      slow sinking). Jump with your head out to climb out. Falling into water doesn't hurt.
- [ ] Head under water: bubbles over your head count down 10 s, then you drown slowly.
- [ ] New world option Thirst. The blue bar drains in about a day; at 0 it hurts.
- [ ] Standing in or next to water (or with water in the Siphon, or a barrel nearby):
      craft an empty bottle into a bottle of water by hand. Drink it: thirst up, the
      empty bottle back. Bigger bottles take and give more.
- [ ] Siphon Liquid: hold left click on water to draw it up ("Water x / 256"), right
      click to pour. Aim at a Liquid Barrel to fill or empty it; right click the barrel
      to see how full. Break a full barrel: the water spills.

**Phase 53: Sand Bricks counted like sand (branch phase-53-brick-grains)**
- [ ] Workbench: 16 Sand = 16 Sand Bricks; a block or wall takes 16, mining one gives 16.
- [ ] Bomb a Sand Bricks wall, mine a bitten tile: you get exactly the bricks left in it.
- [ ] Refill a bitten tile: it takes only the missing bricks.

**Phase 52: voxels: falling sand, water, Sand Bricks, Bomb (branch phase-52-voxels)**
- [ ] Place sand in the air (or dig out under a sand block): it falls apart into grains
      and piles at 45 degrees. `fill sand 6 4` high up drops a big pile.
- [ ] Walk on a pile: you step up its slope. Mine it: one Sand per grain.
- [ ] Sand counts in grains: a block takes 16. Topping up a part-full pile tile only
      takes what's missing.
- [ ] `water 3 3` in a dug-out pit: it falls and levels out. Sand dropped in sinks.
- [ ] Workbench: 16 Sand = 1 Sand Bricks. They don't fall. Throw a Bomb (`give bomb`) at
      a Sand Bricks wall: a round bite, the rest stays. Place a brick on a bitten tile:
      whole again. Mine a bitten tile: a brick back if half or more was left.
- [ ] Bombs break other blocks in the blast whole (with drops) and hurt you up close.
- [ ] Leave and reload: piles, water and bitten bricks are still there.
- [ ] Glass now takes 16 Sand.

**Phase 51: Shaping Spell, placing reach (branch phase-51-shaping)**
- [ ] Alt + R takes the Shaping Spell (everyone has it, old characters too). Click a
      placed block: bottom half, top half, then four slopes, back to full. Shift + click
      steps back. Right click: the wall goes full, bottom half, top half.
- [ ] Logs get one more step, "turned": a single log column lies sideways, a row stands up.
- [ ] You walk up slopes and can stand in the open half of a half block.
- [ ] Shapes are still there after leaving and loading the world.
- [ ] Placing blocks reaches as far as the Mining Spell (8, more with Empower Reach), not 12.
- [ ] Empower: Reach now lists the Shaping Spell. Dev console `shapes` builds a showcase.

**Phase 50: break dust, Glow Potion (branch phase-50-dust-glow)**
- [ ] Breaking a block or wall puffs a small dust cloud in its colors.
- [ ] Alchemy Table: Glow Potion (Clay Flask + 1 Glowcap): you glow for 4 minutes, hands free.

**Phase 49: plank section, Tele Grab forage (branch phase-49-plank-section)**
- [ ] Lumber Rack: boards lie flat in the left part, log ends on the right.
- [ ] Tele Grab pulls in sticks, rocks and mushrooms lying in its pull.

**Phase 48: Lumber Rack, storage capacity (branch phase-48-lumber-rack)**
- [ ] Lumber Rack is 5x4; logs and boards heap in their own colors (Darkwood purple) behind its front posts. Old placed racks: pick up and place again.
- [ ] Potion cabinets hold 6 stacks a slot (180 potions), Pantry Rack and bookshelves 5, Food Pantry 4, Shelf 2.

**Phase 47: bookshelves, fuller spots, right click fix (branch phase-47-bookshelves)**
- [ ] Bookshelf (4x6, 3 shelves over a cupboard) and Small Bookshelf (3x4): one spine per book; scrolls and paper don't show.
- [ ] Shelf spots fill up with overlapping bottles as the stack grows (one item: one; two or more: two or more).
- [ ] Creative search "book" no longer finds the Large Potion Cabinet (names only).
- [ ] Right clicking furniture that's too far away says "Too far away" instead of mining behind it.

**Phase 46: shelf spots, Creative tabs, wall pantry rack (branch phase-46-shelf-slots)**
- [ ] Potion cabinets, the Shelf and pantries: each slot is its own spot on a shelf; the window shows the slots as shelves (top shelf first) with planks.
- [ ] A cabinet slot holds 120 potions (4 stacks); a spot fills up with bottles as its stack fills.
- [ ] The Potion Shelf is now the Shelf (anything goes); the old display Shelf can't be crafted any more.
- [ ] Pantry Rack goes on a floor or a back wall.
- [ ] Creative tabs: Blocks, Furniture, Stations, Storage, Weapons, Armor, Magic, Consumables (food, potions, coatings, throwables), Materials.
- [ ] A torch put away (stowed) stops lighting you.

**Phase 45: liquid barrels, Siphon Liquid, nets, shelf spacing (branch phase-45-liquid-nets)**
- [ ] Right click a Liquid Barrel: a window with its gauge (empty, 0 / 1,000 or 2,500). The wooden one has a tap too.
- [ ] Spell Weaving Table: learn Siphon Liquid (does nothing yet); its Empower tree has Reach and Area.
- [ ] Small Hanging Net is 4 wide; new Long Hanging Net (2x5); net ropes as thick as placed rope.
- [ ] A full potion cabinet fills every shelf, bottles spread evenly.

**Phase 44: log ends, upright log walls, no_los (branch phase-44-log-ends)**
- [ ] Log rows end in rounded tips with a dark edge line on both sides (blocks and log walls).
- [ ] A single column of log walls stands upright like the blocks.
- [ ] Console `no_los`: spells and melee reach through blocks.

**Phase 43: station command (branch phase-43-station-cmd)**
- [ ] Console `station` lists stations; `station furnace` opens the Furnace window anywhere; `station workbench 2` the Darkwood Workbench; `station off` closes it.

**Phase 42: dev commands, logs, wall brightness (branch phase-42-dev-logs)**
- [ ] Console `instant_placement`, `instant_break`, `no_drop` toggle as named.
- [ ] A single column of logs stands upright; a run of log walls ends in rounded tips.
- [ ] Back walls are one clear step darker than their blocks for every material (dirt and stone caves are a bit brighter than before, clay and sand walls darker).

**Phase 41: the Empower tree (branch phase-41-empower-tree)**
- [ ] Spell Weaving Table > Empower: each spell once. Click one: a tree of round nodes with icons; locked ones dim with a padlock until the node above has a rank.
- [ ] Click a node: name, rank, what it does, "Max area 2 -> 3", cost, Empower. No "copper bars, then iron" text.
- [ ] Mining: Power, then Area (3x3, 4x4, 5x5) and Reach. Placing blocks goes as big as Mining's area.
- [ ] Summons: Lasting, then Evolve (Summon Slime) and Limit (one more out at a time, 2 ranks).
- [ ] Damage spells: Potency, then Efficient (and Arc on Chain Spark).
- [ ] Console `crafttab <tab> [row|name]` picks a crafting tab and row.

**Phase 40: sand, reinforced wood (branch phase-40-sand-reinforced)**
- [ ] Sand places as a block and (right click) a Sand Wall.
- [ ] Reinforced Wood and Reinforced Darkwood (block and wall): a strap every 2 blocks, rivets every block.

**Phase 39: freecraft empowers, stat tooltips (branch phase-39-empower-free)**
- [ ] With `freecraft` on, Empower ranks cost nothing.
- [ ] Mining and Chopping tooltips: a short line, then stats one per line (power, speed, area, reach) and "Key: R".

**Phase 38: shelf fit (branch phase-38-shelf-fit)**
- [ ] Big bottles no longer poke through the shelf above. The Pantry Rack has a solid back.

**Phase 37: storage, filled bottles, torch, ropes, Catalog search (branch phase-37-storage-potions)**
- [ ] Alchemy Table, Potions tab: Healing and Mana in every bottle (Clay Bottle / Jug, Glass Vial / Bottle / Flask), from the empty bottle and herbs. Bigger heals more; glass more than clay; bigger means longer sickness.
- [ ] Pantry Rack and Food Pantry: food only, shown on the shelves. Bookshelf: books as spines, scrolls and paper in the drawer.
- [ ] Barrel and Crate hold anything; things stand on them.
- [ ] Hanging Nets (Small 3x2, 2x3, Large 6x4) only go under a block, hang by rope, and show what's inside behind the mesh.
- [ ] Liquid Barrel and Iron Liquid Barrel place (both need iron; nothing to put in them yet).
- [ ] Potion cabinets: bottles behind the glass doors.
- [ ] Hold a torch: held out in front, lights the ground and walls around you at night.
- [ ] Ropes side by side join; clicking a rope with rope adds to its bottom.
- [ ] Catalog: Search box (Items, Enemies) finds found things by name.
- [ ] Creative infinite stack shows an infinity sign, not 9999.
- [ ] The hip book sits on the hip behind your hand.
- [ ] Holding right click to place walls doesn't let go when you drag over a tile that already has one.
- [ ] Brick blocks stand out from brick walls (lighter, a soft shadow on the wall). Glass looks like one continuous pane.

**Phase 36: fixes (branch phase-36-fixes)**
- [ ] A few Dark Forest blocks up in the air no longer turn the biome dark; a big build or the real Dark Forest still does.
- [ ] Back walls are brighter, room walls especially; torches light a room well at night.
- [ ] Clay: right click places a Clay Wall. Glass: left click a see-through block (walls and sky show through, light passes), right click a Glass Wall.
- [ ] Shelf bottles are about twice as big, round where the icon is round, the Poison Flask its own shape, glass not offset.
- [ ] Potion Bookcase is now called Large Potion Cabinet.
- [ ] Right click a stack: one onto the mouse; hold it to keep taking, faster. Shift + right click: half.

**Phase 35: bottles, glass, potion furniture (branch phase-35-bottles-glass)**
- [ ] Creative window: Sand, Glass, Clay Bottle, Clay Jug, Glass Vial, Glass Bottle, Glass Flask, Potion Bookcase, Potion Shelf.
- [ ] Furnace: 1 Sand makes 1 Glass; the bottles from Glass and Clay.
- [ ] Potion Cabinet is 3x5 with glass doors and needs 4 Glass; old saves: pick old cabinets up and place them again.
- [ ] Fill a cabinet: potions show as clay bottles (colored band and seal), glass bottles show their liquid; Clay Jugs and Glass Flasks take two spots.
- [ ] Stand a cabinet on a cabinet (also on chests, tables, Lumber Racks); the bottom one won't come up until the top one is gone.
- [ ] Potion Bookcase (4x6) and Potion Shelf (3x2, needs a back wall) fill the same way.
- [ ] Console `freeplace`: blocks and walls go in mid air.

**Phase 34: Creative window, quit confirmation (branch phase-34-creative-window)**
- [ ] F7 opens the **Creative** window (not "Dev items"); the tabs wrap onto two rows.
- [ ] Dev tab: Dev Grimoire, Dev Focus, Dev Ring, Dev Tome. Test tab: placeholder held items, test books, Mining v2+ (click one, drop it on a quick slot).
- [ ] Enemies tab: click spawns one in front of you, Shift + click 5.
- [ ] Pause > Quit Game asks: Save & Quit, Quit without saving, Cancel.

**Phase 33: the hovering tool (branch phase-33-phantom-hover)**
- [ ] With Mining or Chopping in hand, the phantom tool floats behind your shoulder, bobbing, and follows you.
- [ ] Mining pulls it from there into the swing (all styles and Mining v2 to v8); letting go, it drifts back.
- [ ] With anything else in hand it's gone.

**Phase 32: dev things kept in saves (branch phase-32-keep-dev-spells)**
- [ ] With the dev kit, put Mining v2 to v8 on your Q and E wheels, Save & Quit, come back: they're all still there, on the same slots, with the dev items.

**Phase 31: fixes (branch phase-31-devkit-all-spells)**
- [ ] `devkit` teaches every spell, Air Step and Bound included.
- [ ] Spell Pages for spells you know say "Already known".
- [ ] With a spell dragged onto the mouse, clicking in the world doesn't swing or cast what's in your hand.
- [ ] Tooltips wrap into a narrow box with smaller text and stay on screen at the edges.

**Phase 30: book poses (branch phase-30-book-poses)**
- [ ] With a weapon or nothing in hand, the spellbook hangs on your hip.
- [ ] Readying Spark, Air Push or Mining puts the book in your back hand; the hip is empty.
- [ ] Quick casting Spark (Z) with the Dual Storm Axes out: one axe stays in the front hand, the book thrusts out from the back hand, then returns to the hip.
- [ ] Chain Spark (or Arcane Bolt): the book floats in front of your chest, both hands push.
- [ ] Barrier, Mend, Levitate: the book stays on the hip and glows while you gesture.

**Phase 26: phantom swings (branch phase-26-phantom-swings)**
- [ ] Holding Mining or Chopping lights up the blocks under the cursor (Starbound style): a blue glow on each block (no outline) and real light that shows them in the dark. Red box where it can't work.
- [ ] Each swing the tool appears, strikes the middle of the box fast with a streak and a flash, and fades.
- [ ] Compare Mining with the dev kit's Mining v2 to v8 (spell window, then a quick slot), or console `phantom echo` / `phantom comet` / `phantom arc`.
- [ ] Underground it lights up the dark around the strike.

**Phase 25: weapons and schools (branch phase-25-weapons-schools)**
- [ ] Spell tooltips name the school ("Storm spell"); the Dual Storm Axes and Storm Charm tooltips explain themselves.
- [ ] Console `hold dual_storm_axes`: one axe in each hand; chops alternate hands, the third crosses both.
- [ ] Axe hits leave slimes shocked (blue flicker, small damage ticks for 3 s).
- [ ] Spark and Chain Spark do 25% more to shocked enemies; holding the axes adds 20% to Storm spells, quick casting included.
- [ ] Right click with the axes: leap toward the cursor and slam down, hitting and shocking everything near where you land; 5 s cooldown, no fall damage.
- [ ] Storm Charm (+15% Storm damage) stacks with the axes.

**Phase 24: tools are spells (branch phase-24-gathering-spells)**
- [ ] A new character has the Copper Dagger in slot 1 and knows Mining and Chopping (R, Ctrl + R); no pickaxes or axes anywhere.
- [ ] Mining and Chopping cost no mana (tooltip says "Mana: Free").
- [ ] Holding them conjures a glowing phantom pickaxe or axe that winds up and strikes; blocks crack on each strike. Visible underground too.
- [ ] Iron ore says "Too hard" until Empower > Power rank 1 (10 copper bars); the tool turns copper colored.
- [ ] Power rank 2 (12 iron bars): area up to 4x4, iron glow. Reach adds 2 tiles a rank. Sharpness speeds chopping.
- [ ] New tiers: Potency (damage spells), Arc (Chain Spark jumps), Distance (Blink), Lasting (buffs, lights, summons).
- [ ] An old character loads with both spells learned.

**Phase 23: the Catalog (branch phase-23-catalog)**
- [ ] J or the Catalog button (inventory, next to the trash) opens it; x, J and Esc close it.
- [ ] Items tab: unfound items are silhouettes; "N / M found" goes up as you pick things up.
- [ ] Item page: Made at, Dropped by, Used in; the Recipes button jumps to the Recipes tab.
- [ ] Enemies tab: kill a slime, its page shows stats, slain count and drops (unseen ones dark).
- [ ] Recipes tab: drop Slime or Darkwood in the slot; unknown recipes are "???" with
      their station; clicking a known row moves to that item.

## Known

- Window positions reset when you quit. Accessories aren't drawn on the character.
