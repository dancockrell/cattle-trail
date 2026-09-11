# Cattle Trail: gazetteer

Seventeen locations are built as data files under `data/locations/`, plus Clear Fork, which is built and owned separately. A location is real when its file exists and the loader accepts it, not when it is described here. Every entry below that says **(built)** has a file; anything that does not is still a name.

Each entry: what it is, why the outfit would go there, and an art-direction comment for whoever paints it later. Follow the palette and staging already proven in the Clear Fork room (warm dusty daylight, fixed high three-quarter view, hard pixel edges) unless the entry says otherwise.

Read `LOCATION-SCHEMA.md` before editing any file here. Three other agents build against it.

---

## What the files actually contain

Nobody can generate art right now. There is one ground texture and six scenery families. So every location is separated by four things that cost nothing, and the files carry all four:

1. **Ground tint.** `ground.modulate`, with a `ground.modulate_note` saying in one or two sentences why that light and not another. The notes are there so the next person does not flatten them back to neutral for tidiness.
2. **Scenery mix and density.** Every location is `recipe: "authored"` with exact prop placements, so the shape of a place is real data rather than a promise about a scatter function nobody has written yet. Props keep clear of the arrival point and of everyone standing.
3. **The cast.** 155 of the county's 176 written people are now standing somewhere. Of the 21 who are not: 12 belong to Clear Fork, five are wanderers that arrive as encounters rather than stand anywhere, and two are offstage by their own pages.
4. **Stakes.** A `stakes` field, three lines: what the player can **do** there, what they can **lose**, what they **decide**. The schema example does not have this field. It was added because a location with no answer to those three is furniture, and writing the answer down is the cheapest way to catch one that is.

Ground tints, so nobody has to open seventeen files to see the spread:

| Place | modulate | Reads as |
|---|---|---|
| The Salt Flats | 1.38 1.35 1.31 | Blown out, almost white |
| Providence | 1.11 1.08 1.01 | Raw midday on new lumber |
| The Hargrove Range | 1.06 1.00 0.87 | Scraped bright, lately broken |
| Fort Griffin | 1.02 0.97 0.88 | Yellowed, hide smoke |
| The Ochoa Homestead | 1.00 0.99 0.92 | Plain working daylight |
| The Calloway Spread | 1.00 1.00 0.94 | Even, settled |
| The Hemp Works | 1.00 0.95 0.84 | Chaff and forge smoke |
| Hendricks Camp | 0.97 0.93 0.84 | Trail dust toward evening |
| Wexford Dairy | 0.95 1.03 0.91 | The only watered green in the county |
| The Mission Chapel | 0.94 0.92 0.88 | A walled yard, older light |
| Split Oak Camp | 0.93 0.91 0.80 | Deep warm shade under one canopy |
| Timber and Plains | 0.91 0.96 0.87 | A cloud shadow crossing |
| Reyes-Boone Ferry | 0.90 0.96 1.01 | Open water, sun on it |
| The Quiet Rows | 0.86 0.86 0.89 | Colour drained, daylight kept |
| The Narrow Water | 0.81 0.88 0.96 | Cold blue under timber |
| The Thorndike Mine | 0.78 0.76 0.73 | Rock dust, working |
| Bellhollow | 0.71 0.73 0.79 | Shadowed, cold, finished |

---

## Clear Fork (built, owned elsewhere)

The starting ground. Wagon camp, east gathering, the dry crossing, the cart stop, the clue stretch. Documented fully in `LORE.md`. Seven locations list it as a neighbour. Its own file has to list them back or the graph is broken on one side.

---

## Fort Griffin (built)

A hide-and-soldier town on the Clear Fork of the Brazos. Saloons, a trading post, a garrison that mostly minds its own business. The outfit sells here, resupplies here, and hears rumors here. Griffin is loud, crowded, and does not know or care what the outfit has seen out on the grass.

Twenty-five people stand in it, which is the largest cast in the county and the only thing currently saying "town". Law and the garrison, the Voss post, Consuelo Diaz's hide yard, Deacon Marsh's bounty table, the Widow Stroud's ledger, and Birdena Holt's auction with Chester Vane's rigged one beside it.

<!-- art prompt: Fort Griffin trading post exterior, weathered clapboard and hide-stretching racks, a hitching rail with three horses, warm late-afternoon light, background bustle kept low-detail so it reads at a distance. Same palette and pixel density as the Clear Fork room art. No modern signage, no cartoon caricature of period figures. -->

## The Hemp Works (built)

The yards below the Griffin town line: rope walk, barrel yard, chandlery, a forge, and the roasting and hide trades that have no room inside the town. Cyrus Boone owns the ground. Marisol Vasquez's rope is stacked next to the cheaper rival's, and the outfit picks one.

`ECONOMY.md` assigns these trades to Fort Griffin and names the hemp works as the Griffin site. Four of them were grouped here so that Griffin is a town and not a list, which that document's own closing note allows.

<!-- art prompt: An industrial yard below a town: a long rope walk under a shed roof, stacked barrels, a forge with the doors open, hides on racks. Dustier and busier than the town above it. -->

## The Wexford Dairy (built)

Milk cows on the only good water for a mile, and Hosea Pruett next door who wants it. The county's big water fight at the size of two families. The greenest ground anywhere, because the argument is about water and the ground has to show it.

<!-- art prompt: A small dairy on watered grass, milk shed and stock tank, cows that are plainly not longhorns. Greener than anything else in the county. -->

## The Narrow Water (built)

A second crossing upriver from Clear Fork, deeper and colder, where the ford is honest but the bank is not. Cottonwood roots and a washed-out cart track. Something is usually wrong here before the outfit arrives, and the scene is about reading the signs before committing the herd to the water. Romy Fenwick's mill sits on this water and somebody upstream is diverting it.

<!-- art prompt: A river crossing at dusk, cottonwoods leaning over dark water, a half-collapsed bank on the far side, mist low over the surface. Moody but not horror-saturated: this is a place with a problem, not a haunted house. Match the dry-crossing art style already in Clear Fork rather than inventing a new water-rendering technique. -->

## The Reyes-Boone Ferry (built)

The same river with the timber cut back. Clementina Reyes-Boone runs a safe crossing at a fair price. Gustaf Renner runs an unsafe one cheaper, every single day, which is the whole trap.

Derived location. The ferry is written in Clementina Reyes-Boone's and Gustaf Renner's pages. Nothing put it on the map, so its place between Griffin and the Narrow Water is an inference and is recorded as one here and in the file's `art_gap`.

<!-- art prompt: A ferry landing on a wide slow river, a flat-decked cable ferry at the bank, a second scruffier boat tied further down. Open sun on the water. -->

## Bellhollow (built)

A near-abandoned mining camp in scrub hill country, played out a decade ago and mostly returned to the country. Three holdouts. The name is literal: a bell somewhere in the collapsed workings rings when nobody is there to ring it. Adelheid Kraus keeps a still out here because the tax office has to ride a long way to find it.

<!-- art prompt: Collapsed mine headframe and a scatter of leaning shacks on a scrub hillside, one window lit at dusk, a bell tower visible but the bell itself obscured. Desaturate slightly relative to Clear Fork to read as a harder, poorer place, without going full horror-palette. -->

## The Thorndike Mine (built)

A mine that still pays, on shoring that will not hold. Birgitta Holm works it and Elias Thorndike owns it. Dusty and working, deliberately not the same grey as Bellhollow's cold finished one.

Derived location. The mine is written in Birgitta Holm's and Elias Thorndike's pages. Its position past Bellhollow is an inference.

<!-- art prompt: A working mine adit in a scrub hillside, timbering at the mouth, ore cart and spoil heap. Rock dust on everything. Daylight, ordinary, a going concern. -->

## The Calloway Spread (built)

A neighboring cattle operation, larger and better-fenced than the outfit's own, run by a family that has been in this county longer. Not enemies by default: rivals for water, grass, and market timing, which is plenty of friction on its own without inventing villainy. Cole, Hattie and Whit are all here, and so is the lawyer who drew up the marriage Birdie walked away from.

<!-- art prompt: A proper ranch house and outbuildings behind good fencing, windmill pumping water into a stock tank, tidier and more established than the outfit's own wagon camp. Same period and palette; this should read as "further along the same road," not a different setting. -->

## The Hargrove Range (built)

A second, newer rival spread. Where the Calloway Spread reads as established and tidy, Hargrove ground reads as recently claimed and still being proven: fresh fence wire, a half-finished barn, more debt than the buildings show. Deal with Cass, not Reed. Delia Marsh is on the fence line watching for a fairer offer.

<!-- art prompt: A newer ranch spread with visibly fresh-cut fence posts and a half-raised barn frame, a surveyor's stakes still in the ground nearby. Same palette as Clear Fork and the Calloway Spread; the "newness" should read through construction state, not a different color grade. -->

## Providence (built)

A rail-line town growing fast on the promise of a spur line that may or may not get built. Boomtown energy: fresh lumber, tents next to real buildings, speculators, a church with no steeple yet. Twenty-four people, the county's whole craft trade, its honest paper and its better-selling one, and Magistrate Holt for anything that reaches a courtroom.

<!-- art prompt: A single dusty main street half-built, raw new lumber next to canvas tents, a locomotive whistle implied rather than shown (no train needs to be on-screen). Bright midday light, busier and more chaotic than Griffin. -->

## The Mission Chapel (built)

Adobe, a walled yard, and a longer memory of the county than anything in Providence. Padre Ruiz answers questions about things that happened before the town got here. Dr Thistlewood is selling a tonic in the yard and Dinah Okonkwo is trying to prove what is in it.

Derived location. The mission chapel is written on Padre Ruiz's page and in the Providence wiki. Its position between Providence and Griffin is an inference.

<!-- art prompt: A small adobe mission chapel and a walled yard, bell in an open cote, deep shade against a pale wall. Older and quieter than anything in Providence. -->

## The Ochoa Homestead (built)

One widow, one boy, a good medicinal garden, and whoever is sick this week. Deliberately the most ordinary ground in the county. Marguerite Solis and Seraphina Oduya both turn up at the same crisis and disagree about how to run it.

Derived location. The homestead is written on Elena Ochoa's page and named in Marguerite Solis's recruitment hook. Its position near Providence is an inference.

<!-- art prompt: A soddy or small cabin, a fenced kitchen garden, a well, washing on a line. Nothing strange about it, which is the point. -->

## The Salt Flats (built)

Dead-white ground south of the usual trail, where nothing grows and sound carries wrong. Cattle refuse to cross it without a reason to trust the drover. Magnolia Pruitt knows the route and will sell it. Two people and six props on the whole map, which is correct.

<!-- art prompt: A flat white salt pan under a bleached sky, heat-shimmer distortion kept subtle, a single line of wagon tracks vanishing toward the horizon. High-key lighting, almost overexposed, to contrast against Clear Fork's warm palette. -->

## Split Oak Camp (built)

An old line-shack and a single enormous, storm-split live oak that other outfits use as a waypoint and a message board: notices, brands, and warnings nailed to its trunk over the years. Neutral ground by informal custom. Hallie Brandt keeps the trunk. Faustina Achebe's hives are along the trail here.

<!-- art prompt: One massive live oak, visibly split by old lightning damage but still alive and full-canopied, a small line-shack in its shade, scraps of paper and carved marks visible on the lower trunk. Warm daylight, generous shade pooling under the canopy. -->

## Timber and Plains (built)

Trees arguing with open grass, straight out of `LORE.md`'s own list. Weather comes off the plains faster than a man wants. Crossing it saves hours and puts you in the timber at dusk, which is when the Second Shadow works.

<!-- art prompt: Mixed timber breaking into open grass, a storm front visible low on the plains side. The one location the existing scenery set already suits; the missing piece is sky. -->

## Hendricks Camp (built)

Another outfit's bedground. Zilpah Hendricks runs a fair crew. Amos Ketch is camped too close with a worse one, and Cutter Boyle is here for hire by whoever pays first.

Derived location. Both crews are written in `independent-outfits.md`. A bedground for them is an inference.

<!-- art prompt: A trail crew's night camp: chuckwagon, remuda line, bedrolls, a fire going down. Should read as the outfit's own camp seen from outside. -->

## The Quiet Rows (built)

A small family cemetery from a homestead that failed years back, fenced and still tended by someone nobody in the outfit has met. The graves are ordinary. What is not ordinary is that the count of headstones does not match the count from the last visit. A slow-burn location: return visits, not one-time set dressing. Verona Ashcombe is at the fence the second time.

<!-- art prompt: A small wrought-iron-fenced plot on open grassland, a handful of leaning headstones, wildflowers growing through the fence line, no fog or horror lighting: daylight, ordinary, which is what makes the wrongness land. -->

## Abilene (offstage)

A name men use in the past tense already, per `LORE.md`. For now it exists in dialogue as a horizon rather than a destination.

## The other railheads (offstage)

Same rule as Abilene. They are talked about, not visited, until a decision says otherwise.

---

## The graph

```
bellhollow              7h  ->  the_narrow_water, thorndike_mine
clear_fork              0h  ->  
fort_griffin            9h  ->  clear_fork, reyes_boone_ferry, the_hemp_works, the_mission, wexford_dairy
hendricks_camp          5h  ->  split_oak_camp, timber_and_plains
ochoa_homestead         4h  ->  providence, the_quiet_rows
providence             10h  ->  clear_fork, ochoa_homestead, the_mission
reyes_boone_ferry       4h  ->  fort_griffin, the_narrow_water
split_oak_camp          5h  ->  clear_fork, hendricks_camp, timber_and_plains
the_calloway_spread     4h  ->  clear_fork, the_hargrove_range
the_hargrove_range      3h  ->  the_calloway_spread
the_hemp_works          2h  ->  fort_griffin
the_mission             6h  ->  fort_griffin, providence, the_salt_flats
the_narrow_water        5h  ->  bellhollow, clear_fork, reyes_boone_ferry, timber_and_plains
the_quiet_rows         11h  ->  clear_fork, ochoa_homestead
the_salt_flats         14h  ->  clear_fork, the_mission
thorndike_mine          3h  ->  bellhollow
timber_and_plains       4h  ->  hendricks_camp, split_oak_camp, the_narrow_water
wexford_dairy           3h  ->  fort_griffin
```

Travel is symmetric in the files. The seven links into Clear Fork can only be checked from this side until Clear Fork's own file exists.

---

## Adding one

Pick a place already written in `LORE.md` or the wiki. If it is not written, do not add it. If it is written but nothing puts it on the map, say so in the entry and in the file's `art_gap`, the way the five derived locations above do.

Then write the file per `LOCATION-SCHEMA.md`, and answer the three `stakes` lines before anything else. If they cannot be answered, the place is furniture and should not be built.
