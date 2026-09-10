# Cattle Trail — cattle drives

Design-only, per `design/decisions.json`'s "simulation_pillars" entry: successful cattle drives are one of the four growth levers, alongside shrewd dealing (`ECONOMY.md`), exploration (`EXPLORATION.md`), and romance. Nothing here is implemented in `scripts/`. It exists because `ECONOMY.md`'s market section already promises that "a drive that loses cattle to a bad crossing, a rustler, or a spooked stampede sells fewer head" without ever defining what a drive actually *is* as a player activity — this document is the missing piece those two documents point at but don't fill.

**Design rule, carried over from `ECONOMY.md` and `EXPLORATION.md` so it doesn't need repeating per section: reuse what the county already has.** The travel graph, the trail clock, the county's wandering hauntings, and the companion-perk system are all established elsewhere. This document does not invent a second map, a second clock, new supernatural threats, or new perk ids — it wires a drive on top of what those systems already provide.

## What a drive actually is (PROPOSAL — not accepted design)

**Proposed shape: a drive is a multi-day trip along the existing travel graph, herd-in-tow, not a separate abstracted "drive resolution" screen.** `EXPLORATION.md`'s map already gives the county real legs — Clear Fork to Fort Griffin, Clear Fork to Providence, the shorter hops to the Calloway Spread and Hargrove Range — and its own "Unresolved" section leaves open "whether the player's herd travels with them on every trip, or stays at Clear Fork while the player travels alone." A drive is the case where the answer is yes: the outfit commits the herd to a specific route, the trip runs leg-by-leg on the same trail clock (`scripts/trail_clock.gd`) that already derives day number and clock time for travel and camp-rest cooldowns, and the destination is one of the two market towns named in `ECONOMY.md` — most naturally Fort Griffin, since Birdena Holt's open auction is already the standard route, though a drive to Providence or a direct sale to a rival outfit (Calloway Spread, Hargrove Range) should use the same structure.

This keeps a drive from needing a second time system or a second map, matching this project's stated reason for reusing the trail clock in the first place: it's data the clock already produces, not new logic layered on top of nothing. It also means a drive is not automatically distinct from ordinary travel — it's ordinary travel with a herd along, which is exactly the axis `EXPLORATION.md` left open rather than a new mode bolted beside it.

What a drive is *not*, under this proposal: a separate minigame with its own UI, a dice-roll resolved in one screen the moment you leave Clear Fork, or a fixed number of "drive events" independent of which route was actually taken. The risks below happen on the leg where their location already lives, the same way `EXPLORATION.md`'s road encounters do.

## What can go wrong on a drive, and why

Every risk below is tied to a hazard or actor the county already has — nothing new is introduced here.

- **A bad river crossing, at The Narrow Water.** `LOCATIONS.md` already describes it as "deeper and colder, where the ford is honest but the bank is not," and the scene is about reading the signs before committing the herd to the water. A drive whose route crosses here risks losing head to the water itself, and it's also **The Ford Widow**'s ground (`EXPLORATION.md`'s encounter table) — she "will not let a rider she judges unready cross," which on a drive means the herd, not just the player, is what's waiting on her judgment.
- **A stampede or a spooked herd, tied to the county's late signs.** `LORE.md`: "they spook for ordinary reasons and for dead ones... spirits spooked them; cattle never miss an excuse." `ECONOMY.md`'s escalation rule already says a county with an active water dispute or a recent supernatural incident should visibly depress prices before a drive even reaches market — a drive during a bad stretch of late signs is where that pressure should actually cost cattle, not just quote a lower price at the end.
- **Rustlers, specifically Amos Ketch's crew.** `conflicts-and-rivalries.md` names Ketch as "the clearest actual bad actor in the county" — the non-supernatural threat a drive should actually face, distinct from the two sympathetic rival ranches (Calloway, Hargrove) who compete for the same water and buyers but aren't written as thieves.
- **The Drover Who Isn't, on any open trail.** Per `LORE.md`'s "herd dead that want the count to match," and `EXPLORATION.md`'s table already places him on "any open trail," not one fixed location. A drive is precisely where his effect belongs: convincing at a distance, riding drag on the herd unasked, and the count coming up wrong once he's been near it — a direct, diegetic reason a drive can arrive at Griffin short of the cattle it left with.
- **The Second Shadow, on a night leg.** `EXPLORATION.md` already flags him as "explicitly a night hunter" and ties day/night distinction to the far, longer legs. A drive whose route runs a leg after dark (the longer hauls to Fort Griffin or Providence, or the farther Salt Flats/Quiet Rows detours) is where this should matter, rather than treating night as flavor.
- **Weather and terrain on the harder legs.** The Salt Flats are already written as a place "cattle refuse to cross... without a reason to trust the drover," with heat-shimmer and tracks that end mid-stride — a route through here is a harder, riskier leg by the location's own description, not a new hazard invented for drives.

None of these need a combat resolution to matter, matching `EXPLORATION.md`'s own note that most of the county's wandering figures are "a job to do... rather than a fight to win." A bad crossing is about reading the signs before committing the herd; Ketch's crew is worth avoiding or facing down, not necessarily gunning down; the Drover Who Isn't and the Second Shadow are best handled the way `LORE.md` treats the county's dead generally — noticed and worked around, not fought.

## How companion perks and hands reduce these risks

This reuses the exact perk architecture already cited in `ECONOMY.md` and `EXPLORATION.md`, reading `scripts/companion_perks.gd`'s `DEFINITIONS` — no new perk id is proposed here:

- **`steady_herd`** ("Trail Hand," extends `lasso_follow_seconds`) is already framed in `ECONOMY.md` as "fewer lost cattle" — this is the direct mitigation for a bad crossing or a spooked stampede, since it's mechanically about holding the herd together rather than letting it scatter.
- **`spirit_sense`** ("Between the Footprints," extends `trail_hazard_notice`) is already framed as hazard warning for "the county's 'late signs.'" On a drive this is the perk that gives the player advance notice before a leg carrying the Drover Who Isn't, the Ford Widow, or the Second Shadow turns bad — noticing the wrongness before it costs cattle, per `LORE.md`'s general instruction that late signs should be readable, not a surprise doom-roll.
- **`steady_aim`** ("Steady Aim," extends `shot_range_bonus`) is the existing perk that would matter if a drive runs into Amos Ketch's crew and a fight becomes the actual outcome rather than the avoided one.
- **The outfit's own hands** — Pardo, Alma Okafor, and "Young" Dutch — are already the standing crew, distinct from recruited romance companions. Per their own wiki entries, Alma is the point rider who "reads the trail ahead before the herd commits to it," which is a drive's most literal function even before any companion perk is involved, and Pardo's "feed it, water it, count it" is the drive's baseline discipline stated outright. A drive system should let the outfit's own crew do drive-specific work (routing, counting) independent of which romance companions happen to be along, matching `ECONOMY.md`'s note that expanding this crew is a distinct growth path from recruiting companions.

## What a successful vs. bad drive produces

This is deliberately the input to `ECONOMY.md`'s market section, not a duplicate of it. A drive's outcome should be exactly the two variables that section already prices:

- **Count** — how many head arrive versus how many left Clear Fork. Every risk above is a way to lose head (the river, a stampede, a rustler's take, the Drover Who Isn't skimming the tally); every mitigating perk or hand above is a way to hold the count closer to the number the drive started with.
- **Condition** — per `ECONOMY.md`, "stressed cattle sell for less than calm, well-handled ones." A drive that took the hard route (a night leg, the Salt Flats, a scare at the Narrow Water) without losing head outright should still produce a worse condition than a clean, well-handled trip, feeding the same market-price factor rather than a separate stat.

Beyond the sale itself, a drive should also be where **reputation** gets made or spent — with Birdena Holt if the delivery is honest and reasonably intact (feeding `ECONOMY.md`'s buyer-reputation curve), and potentially against Amos Ketch or the county's general tension level if a drive runs through active trouble. None of this is specified numerically here; it's the same count/condition/reputation vocabulary `ECONOMY.md` already uses, applied to where those numbers should actually come from.

## Unresolved

- Whether a drive is a distinct player-declared mode (commit the herd, choose a route, run the trip) or something that happens automatically whenever the player travels with cattle assigned — no UI or state-machine decision has been made.
- Herd size and scaling: how many head a drive can move at once, and whether that's limited by anything (hands available, `EXPLORATION.md`'s open "world scale" question, wagon/cart capacity).
- Exact numeric loss rates per risk (how much a bad crossing, a stampede, or a Ketch encounter should cost in head or condition), and how `spirit_sense`'s or `steady_herd`'s existing cap values translate into an actual reduction — none of this is specified, matching this project's standing rule against inventing balance.
- Whether a drive can run concurrently with other loops (recruiting, romance scenes, other travel) or is a discrete, blocking activity for the outfit.
- Whether the Drover Who Isn't's "count off by one" effect is a guaranteed encounter on every long drive or a chance-based one, and how it's distinguished mechanically from an ordinary lost-to-the-river head count.
- Whether a drive to Providence or a direct sale to a rival outfit uses the exact same risk/route structure as a Fort Griffin drive, or whether those routes carry different hazards not covered above.
- How a drive interacts with `EXPLORATION.md`'s still-open question of random encounter frequency (seeded vs. authored per trip).

Per this project's standing rule: do not silently implement any of the above as accepted design.
