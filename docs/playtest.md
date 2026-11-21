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
- [ ] F7 (or `creative`): Dev items window; tabs, search, click for a stack.
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
- [ ] Dev items (F7): click 1, Shift 10, Ctrl a stack, right click an infinite stack
      (place or eat from it forever; its tooltip says so).
- [ ] Air Push: no hits through walls; stronger push; aim down on the ground: a gust jump.

**Phase 14: Dark Forest (branch phase-14-dark-forest)**
- [ ] New world: the Dark Forest (one big region since Phase 15). `tp` there or walk.
- [ ] Darkwood trees drop Darkwood Saplings; planted, they grow darkwood trees.
      The map preview shows them as purple trees.
- [ ] Tall darkwood trees close together, dark trunks backdrop, half the daylight; the
      edge fades in and out.
- [ ] Chop a darkwood tree: Dark Logs; 1 Dark Log = 4 Darkwood (by hand); Darkwood
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

## Known

- `test_spawns_ahead_when_moving_and_despawn_waits` (test_combat.gd) fails now and
  then: it rolls 40 spawns and wants more than 26 ahead of you, so bad luck can fail it.
  Not a game bug; it passes when rerun.
- Window positions reset when you quit. Accessories aren't drawn on the character.
