# Location schema

One file per location under `data/locations/<id>.json`. The game grows by adding
files here, not by adding scenes or scripts. Clear Fork is one of these files
like everywhere else: there is no special case for the first room.

## The honest art constraint

Today the project has exactly one ground texture (`assets/ground-v3.png`) and six
scenery families (trees, rocks, grass, scrub, camp, fence) plus cattle, rider,
Eleanor, rustler, wagon and the 96 character variants. There is no building art,
no town art, and no second ground. Nobody on this project can generate new art
right now.

So a location is differentiated by four things that cost nothing:

1. **Ground tint** (`ground.modulate`). The salt flats are bleached, Bellhollow
   sits in shadow, Providence is raw and bright. Same texture, different light.
2. **Scenery recipe**. Density, family mix and scatter. A timber crossing is
   thick with trees and has no groundcover; the flats have almost nothing on
   them; a spread is fences and camp props.
3. **Who is standing there.** The county already has around 180 written people,
   most assigned to a place in the wiki and in ECONOMY.md. A location is mostly
   its cast.
4. **What can happen there.** The verbs the place offers and the encounters it
   rolls.

Do not pretend a location looks like something it does not. If Fort Griffin
reads as a field with a fence today, say so in its `art_gap` field, which exists
to record exactly that.

## Fields

```jsonc
{
  "id": "clear_fork",                  // matches the filename
  "name": "Clear Fork",                // shown to the player
  "kind": "home | town | spread | wild | crossing | camp",
  "blurb": "One line the travel screen shows.",

  "ground": {
    "texture": "res://assets/ground-v3.png",
    "modulate": [1.0, 1.0, 1.0, 1.0]   // per-location light; this is the cheapest
  },                                    // differentiator available, use it

  "bounds": {"x": [24, 616], "y": [71, 303]},  // where the player may walk.
                                               // Anyone placed outside this who
                                               // must be spoken to is unreachable:
                                               // that bug has already shipped once.

  "scenery": {
    "recipe": "authored | scattered",
    "props": [ /* authored: exact placements, same shape as assets/room-art.json */ ],
    "scatter": {                        // scattered: a seed and a density per family
      "seed": 1872,
      "families": {"trees": 14, "rocks": 3, "grass": 2, "scrub": 0, "camp": 0, "fence": 0}
    }
  },

  "arrivals": {"x": 199, "y": 231},     // where the player stands on arrival

  "cast": [                             // who is here. ids from design/characters.json
    {"id": "eleanor", "x": 148, "y": 127, "role": "companion"},
    {"id": "nettie_voss", "x": 300, "y": 200, "role": "trade"}
  ],                                    // or design/npcs.json. Must be inside bounds.

  "encounters": ["ford_widow", "drover_who_isnt"],  // ids from data/encounters.json
  "travel": {"neighbours": ["fort_griffin", "the_narrow_water"], "hours": 6},

  "art_gap": "Reads as open prairie. Needs a fort palisade and buildings to read as Fort Griffin."
}
```

## Rules

- **Every id must resolve.** A cast id that is in neither `characters.json` nor
  `npcs.json`, an encounter id not in `data/encounters.json`, or a neighbour with
  no location file, is a broken location. The loader rejects it rather than
  loading a half-built place.
- **Everyone in `cast` must be inside `bounds`**, far enough in to be reached.
  Ten companions once shipped standing outside the walkable area, answering only
  within 36 units, so nobody could ever speak to them.
- **No location may be a formality.** The bot measures risk, variance, decisions
  and cost per encounter. A place where nothing can be lost, nothing varies and
  nothing is chosen is furniture. Either give it stakes or do not build it.
- **Travel is symmetric.** If A lists B as a neighbour, B lists A.
- Prefer placing people who already exist over inventing new ones. The county is
  full of written characters with nowhere to stand.
