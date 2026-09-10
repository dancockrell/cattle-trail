# Cattle Trail — exploration and travel

This is the design for travel between the county's locations. Travel is not built yet: the game is still one room (Clear Fork) per `GAME-DESIGN.md`'s scope decision, and building it is the next step for this system. When it is built it connects the ten locations already written in [LOCATIONS.md](LOCATIONS.md) rather than a new map, and spends the trail clock already running in `scripts/trail_clock.gd` rather than a second time system.

## The map, as a travel graph

Distances and adjacency below are provisional, since the county's scale is still open (see "Next decisions"). What's fixed is the *shape*: Clear Fork is the hub, everything else is reached from it or from a neighbor, and nothing here invents a location `LOCATIONS.md` doesn't already have.

```
                    Providence
                        |
      Split Oak Camp -- Clear Fork (home) -- Fort Griffin
                        |        \
              The Narrow Water    The Calloway Spread -- The Hargrove Range
                        |
                   Bellhollow

  Reached from Clear Fork by a longer, riskier ride: The Salt Flats, The Quiet Rows
  Named but explicitly offstage per LORE.md: Abilene, the other railheads
```

- **Clear Fork** is home -- the wagon camp, the only ground the player starts owning any claim to.
- **Fort Griffin** and **Providence** are the two market towns (see [ECONOMY.md](ECONOMY.md)); a full loop between them and home is the game's basic "supply run."
- **The Calloway Spread** and **Hargrove Range** are close enough to Clear Fork to visit without a full expedition, matching their role as immediate neighbors and rivals.
- **The Narrow Water**, **Split Oak Camp**, and **Bellhollow** are travel-encounter locations more than destinations -- per their own `LOCATIONS.md` entries, something is usually *happening* there rather than waiting there.
- **The Salt Flats** and **The Quiet Rows** are the farthest, strangest, and least visited by design; `LOCATIONS.md` already calls the Quiet Rows "a slow-burn location: return visits, not one-time set dressing."

## What travel actually costs

Per `scripts/trail_clock.gd`, the game already tracks trail minutes precisely enough to derive a day number and clock time (`"Day %d %02d:%02d"`), and camp-rest cooldowns already run on it. Nothing currently branches on day-versus-night; that is new logic on top of data the clock already produces, not a new clock. Travel spends this same one:

- A short hop (Clear Fork to the Calloway Spread or Hargrove Range) costs part of a day.
- A trip to a market town (Fort Griffin, Providence) costs most of a day each way.
- The far locations (Salt Flats, Quiet Rows) cost a full day or more, and are where a day/night distinction should actually matter -- `the_second_shadow` is explicitly a night hunter, and `LORE.md`'s own escalation rules describe things generally getting worse after dark even where a specific entity's record doesn't say so.

## Encounters on the road

The county already has wandering, location-tied hauntings and figures written for exactly this -- travel is what should surface them, rather than a fixed room:

| Location | Who you might meet |
|---|---|
| The Narrow Water | [The Ford Widow](wiki/people/the_ford_widow.md) |
| Timber and plains (en route) | [The Second Shadow](wiki/people/the_second_shadow.md) |
| The Salt Flats | [The Eight-Legged Doe](wiki/people/the_eight_legged_doe.md) |
| Split Oak Camp | [The man from farther west](wiki/people/the_split_oak_traveler.md) |
| Any open trail | [The Drover Who Isn't](wiki/people/the_drover_who_isnt.md), per `LORE.md`'s "herd dead that want the count to match" |
| Bellhollow | [Gideon](wiki/people/gideon_stark.md) and [Eulalie Stark](wiki/people/the_stark_widow_sister.md), and the bell itself |

None of these need a combat system to matter -- per `LORE.md`'s own instruction, most are a job to do (hold the herd, read the sign, decide whether to cross) rather than a fight to win.

## What travel is *for*

Not movement for its own sake. Every location already has a reason to visit that exploration would simply make reachable instead of assumed:

- **Recruit companions** who aren't at Clear Fork already -- most of the 65 written-but-unwired companions have an encounter hook tied to a place (a Providence boarding house, a Fort Griffin trading post, a homestead near the trail) that travel would make literal.
- **Trade and sell** at Fort Griffin and Providence, per [ECONOMY.md](ECONOMY.md).
- **Follow rumors** -- `LORE.md`'s own rumor list is written as things heard, not yet resolved into quests; travel is what would let the player go check one.
- **Visit standing relationships** -- a companion recruited from Providence presumably still has people there ([Mrs. Pruitt](wiki/people/mrs_pruitt.md), [Reverend Pike](wiki/people/reverend_pike.md)) worth a return trip, per the associate links already in the wiki.

## Next decisions

- Whether travel is a menu/map screen, a mini drive sequence per leg, or something else. This is the one that has to be settled before any of it can be built.
- World scale, and from it the real distances and travel-time numbers.
- Whether the player's herd travels with them on every trip, or stays at Clear Fork while the player travels alone or with one companion. [DRIVES.md](DRIVES.md) takes the "herd along" case as its own subject, so this is really the question of what an ordinary trip does.
- Random encounter frequency, and whether it's seeded or authored per trip.
