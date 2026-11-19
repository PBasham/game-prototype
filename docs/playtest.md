# Playtest checklist: Phases 5, 6 and 7

Check out `phase-07-combat`: it contains main plus Phases 5 and 6, so it's the only
branch to test. Nothing in Phases 5 to 7 has been playtested yet. Numbers are first
guesses; the docs listed say where each tunable lives.

## Handy console commands (the ~ key)

| Command | For |
|---|---|
| `devkit` | Tools, blocks, all spells (the book gets its free slots filled) |
| `god`, `mana`, `heal` | Survive while testing |
| `time 21` / `time 12` | Jump to night or noon |
| `summon green_slime 3`, `summon blue_slime` | Enemies at the cursor |
| `peaceful`, `butcher`, `spawns`, `kills` | Control and inspect spawning |
| `book 2 levitate` | Put a spell in a book slot |
| `equip dev grimoire` | A tier 3 book (8 slots) for Hyper Drill |
| `spellopt` | List the spell control options (also Esc, Settings, Spell controls) |
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
- [ ] Equipment window (P): character preview, slots, stats, folding Equipped spells,
  dragging it around.
- [ ] Spell Index (L): learn by clicking a spell then a book or hotbar slot.

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

**Spell controls** (turn each on or off in Esc, Settings, Spell controls)
- [ ] F toggles your movement spell (it has to be in the book).
- [ ] Double jump starts it.
- [ ] Book out (R): number keys pick book spells.
- [ ] Hold R + number: quick cast, then back to what you held.
- [ ] (Off by default) right click casts the off-hand spell.
- [ ] Which of these do you want to keep?

**Scrolls**
- [ ] Paper, Blank Scroll (needs Slime), Spell Weaving Table at the Workbench.
- [ ] Scroll recipes at the table; left click a scroll to learn its spell.

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

- One test failed once in about 13 full runs and never again; possibly a timing
  sensitive test. Not a known game bug.
- Window positions reset when you quit. Accessories aren't drawn on the character.
