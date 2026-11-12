# Decision log

Newest first. Each entry: what was decided, why, and what it affects.

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
