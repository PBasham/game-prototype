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
- [ ] Spell Weaving Table: group buttons and search filter all three tabs.
- [ ] Carry an unknown spell's scroll to the table: Spells tab offers Learn for just the
      scroll (it's used up; you know the spell for good).
- [ ] Inventory open, pick up blocks / a wall / a chest / a sapling: over the world they
      show the placement preview and click to place from the mouse stack; non-placeables
      still throw.

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

## Known

- `test_spawns_ahead_when_moving_and_despawn_waits` (test_combat.gd) fails now and
  then: it rolls 40 spawns and wants more than 26 ahead of you, so bad luck can fail it.
  Not a game bug; it passes when rerun.
- Window positions reset when you quit. Accessories aren't drawn on the character.
