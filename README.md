# Cattle Trail

A cattle-ranching and period-economics RPG set in an alternate 1872 Texas, starting on the Clear Fork of the Brazos on Monday, May 12. Spirits are ordinary here, steam machinery is real and breaks in public, and the walking dead are a fact of the country rather than a twist. You run a small outfit and grow it through four connected levers: shrewd dealing (trade, negotiation, debt, market timing), cattle drives (herding, trail risk, delivery), exploration of the wider county, and romance. The romance pillar is harem-lit: adult women with their own work, their own talents and their own reasons for riding with you. All four levers are meant to be the same simulation, not separate minigames wearing one skin.

Built in Godot 4.3.

## What runs today

- **The Clear Fork room is playable.** Ride, talk, lasso, shoot, gather the herd, drive off the rustler. Save and load.
- **Eleanor's lantern crossing** plays: take her brass lantern to the pale crossing spirit, settle it, then guide three stranded cattle east past it.
- **Ada's steam-cart outing** plays: repair the walker, board the two-seat cart, route pressure through valves A/B/C, then drive the lantern course and bring it back.
- **Ines's spirit trail** plays: meet her at the northern trail, read three landmarks, return to her, recruit her and set her camp or field assignment.
- **Birdie's encounter** plays, and her recruitment unlocks the rest of the cast.
- **Nineteen more companions are wired into the game** through the generic simple-companion system. Each is a row in `scripts/simple_companion_catalog.gd` plus a banter file in `data/`, and `scripts/companion_room.gd` builds all nineteen at load: Delphine, Cleo, Prisca, Winnie, Louisa, Faustina, Constance, Beatrix, Roisin, Modesty, Clementine, Sable, Delia, Rilla, Nell, Fina, Willow, Naomi and Ottilie. Meet, do the one thing that matters to her, offer her a place. Recruitment and romance are separate steps in every case.
- **Perks, madness, trust, camp rest and the trail clock** are implemented and persist across saves. Perks have stacking caps.
- `scripts/trade_negotiation.gd` implements the dealing beat from `design/ECONOMY.md`: accept, counter once, or walk away, with per-buyer reputation from 0 to 5 that nudges the opening price. `scripts/cattle_drive_resolver.gd` implements one leg of a drive from `design/DRIVES.md`: route hazards, night effects, and the perks that reduce each one. Both are pure logic with their own test suites. The numbers in them are first-pass placeholders waiting on playtesting, not tuned balance.

The art is a work in progress. Walk cycles and turns are still being repaired, and detailed character sheets in `kits/` have not replaced the room actors yet.

## Play

Import `project.godot` in Godot 4.3 and press F6 on `scenes/room.tscn`. F5 runs the project. **Play Cattle Trail.cmd** launches `build/CattleTrail.exe` once you have exported it (see below).

- **WASD / arrow keys:** ride. **Click or tap ground:** ride to that point.
- **E / Space:** talk. This is the one interaction verb: recruit, read a landmark, board the cart, steady a steer.
- **L:** lasso a nearby steer for eighteen seconds, then lead it east. At close range it also disarms the rustler. During Ada's outing it toggles valve A.
- **F:** fire where you are aiming. Point with the mouse or ride facing him; the round goes where you point, not at him. Accuracy falls off with distance and with how badly your hand is shaking, and scenery stops a bullet. Two rounds in him and he surrenders. Valve B during Ada's outing.
- **R:** reload. Takes 1.6 seconds, during which you cannot fire, and reaching for the rope or catching a round spills it.
- **1 / 2 / 3:** once the rustler has surrendered, decide him: turn him loose, rope him for the law, or hire him on. Each costs or pays differently and Eleanor has something to say about each.
- **F2:** restart the room.
- **Tab:** switch into the active companion adventure, or back out to pause it without losing progress.
- **G:** shared rest at camp. Valve C during Ada's outing.
- **H:** flirt. Always optional, never required for recruitment or recovery.
- **K:** open the sprite kit browser.
- **F5 / F9:** save or restore the outfit. Companion milestones also save on their own, and opening the game restores the last save. Reset clears it.

Clear Fork completes when you have spoken with Eleanor, cleared the rustler, and gathered all six cattle in the east clearing. Push cattle from behind, or lasso a stray and lead it. Then ride back to Eleanor and talk to invite her into the outfit.

## Checks

```
python tools/verify_godot.py <check> [<check> ...]
python tools/verify_godot.py --self-test
```

The verifier requires a positive completion marker in the output, because a failed Godot script assertion can still exit zero. `--self-test` proves that by feeding it a deliberate assertion failure and confirming it rejects the run.

Available checks, from the `CHECKS` dict in `tools/verify_godot.py`:

`compile`, `state`, `storage`, `snapshot`, `clock`, `phase`, `turn`, `turn-actor`, `action-sequence`, `sprite-density`, `banter`, `banter-delivery`, `characters`, `character-roster`, `perks`, `field-perks`, `generated-roster`, `camp-care`, `camp-recovery`, `lantern`, `lantern-view`, `lantern-controller`, `steam`, `ada`, `mechanic-controller`, `ada-cart`, `ada-cart-controller`, `cart-motion`, `cart-clearance`, `ines`, `ines-room`, `birdie`, `birdie-room`, `simple-companion`, `simple-companion-room`, `trade-negotiation`, `cattle-drive`, `room`, `companion`, `motion`.

Most are headless. `room`, `companion` and `motion` open a real rendered game and test actual play.

## Build and art pipeline

```
python tools/extract_assets.py
godot --headless --path . --editor --import --quit
godot --headless --path . --export-release Windows build/CattleTrail.exe
```

`tools/extract_kits.py` builds the expanded atlases and `tools/curate_room.py` picks the default room selection. The pipeline needs Python with Pillow, NumPy and SciPy.

`source/PROVENANCE.md` records where the art came from. `assets/sprites.json`, `kits/manifest.json` and `assets/room-art.json` hold the crops, frame rectangles, ground anchors, sequences and speeds. All artwork is 2D: authored sprites, sprite animation, painted backgrounds, tiles, portraits and flat effects. The Windows export ships runtime assets and scripts, leaving out raw video, source sheets, documents and the extraction tools.

## Design and world

- [`GAME-DESIGN.md`](GAME-DESIGN.md) is the source of truth for how the game plays: the four levers, the state contracts, madness, companion adventures.
- [`design/LORE.md`](design/LORE.md) says what the world is.
- [`design/ECONOMY.md`](design/ECONOMY.md), [`design/DRIVES.md`](design/DRIVES.md) and [`design/EXPLORATION.md`](design/EXPLORATION.md) cover trade, cattle drives and county travel.
- [`design/LOCATIONS.md`](design/LOCATIONS.md) covers the physical places.
- `design/characters.json` holds 80 named romance-eligible companions; `design/npcs.json` holds 96 everyone-else records. Those two files win over any prose that disagrees with them.
- [`design/wiki/`](design/wiki/) is the browsable county: 172 people pages and 9 organization pages, cross-linked by who works for whom, who is related to whom, and who is feuding with whom. Start at [`design/wiki/README.md`](design/wiki/README.md).
