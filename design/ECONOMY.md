# Cattle Trail — the economy

Design-only, per `design/decisions.json`'s "simulation_pillars" entry: this county's economy is meant to be a real simulation the whole game runs on, not flavor text around a companion-collector. Nothing here is implemented in `scripts/`. It exists so future systems work has a coherent market to plug into instead of inventing prices and actors ad hoc, one feature at a time.

**Design rule, stated once so it doesn't need repeating per section: reuse the county's existing people as the economy's actors.** Every merchant, creditor, and rival below is already a named character in `design/characters.json` or `design/npcs.json` — this document does not invent a parallel merchant roster. Where a system needs a role nobody fills yet, that's flagged explicitly as a gap, not filled with a new throwaway NPC.

## What the player is actually growing

Not a number that goes up. A small cattle outfit that gets *more capable*: a bigger herd it can actually hold together, hands and companions whose skills reduce its costs and risks, standing with the people who buy from and lend to it, and enough reach into the county's trade to not be captive to one buyer. Ranch growth is the spine; romance, drives, and dealing are how you fund and staff it.

## The cattle market

**Base commodity:** longhorns, per `LORE.md` — "the moving bank." Price is not fixed; it moves on:

- **Count and condition.** A drive that loses cattle to a bad crossing, a rustler, or a spooked stampede sells fewer head, and stressed cattle sell for less than calm, well-handled ones.
- **Where you sell.** Fort Griffin's open auction (**Birdena Holt**, honest; contested by **Chester Vane**'s rigged rival auctions per `conflicts-and-rivalries.md`) is the standard route. Selling directly to a rival outfit (the [Calloway Spread](wiki/organizations/calloway-spread.md) or [Hargrove Range](wiki/organizations/hargrove-range.md)) is possible and typically worse-priced, since neither rival needs your cattle as much as Griffin's market does — but it can matter more for standing than for cash.
- **Season and county tension.** A county with an active water dispute (the Calloway/Hargrove conflict) or a recent supernatural incident depresses buyer confidence; per `LORE.md`'s escalation rules, "late signs" should visibly move prices, not just flavor text.
- **Reputation with the buyer.** Repeated fair dealing with Birdena Holt should be worth more over time than one good drive — this is where "shrewd dealing" becomes a real mechanic rather than a one-time roll.

**Open question:** exact base price and the numeric weight of each factor above are unresolved, matching this project's standing rule (`decisions.json`'s "unresolved" entry) against silently inventing balance.

## Shrewd dealing, as a mechanic (PROPOSAL — not accepted design)

`decisions.json`'s `simulation_pillars` names shrewd dealing as one of the four growth levers, alongside drives, exploration, and romance, and it's currently the least defined of the four as an actual player action. This section proposes one concrete shape for it. It is a proposal for future review, same status as the rest of this document — not something to build against yet.

**1. The negotiation itself: a single counter-offer beat, not a tree.** `decisions.json`'s `gameplay_romance` decision already sets the house style for this kind of interaction — "avoid endless conversation trees, begging and constant refusal/persuasion loops" — and a sale should follow the same rule rather than inventing a separate, wordier standard for money. Proposed shape: the buyer states an opening price (already the output of the cattle-market factors above — count/condition, venue, season/tension, reputation). The player has exactly one response: accept, counter once with a number, or walk. A counter either lands (small gain, buyer's patience/reputation tolerates it) or doesn't (buyer holds firm, or — for a rigged actor like Chester Vane — the "counter" is itself the bluff moment, since Vane's whole role in `conflicts-and-rivalries.md` is that his auctions aren't honest in the first place). No second round, no dialogue tree: one offer, one counter, one outcome. This keeps a sale a fifteen-second beat that reads as a real choice rather than a haggling minigame, and it's a small enough surface that it can plug into any buyer (Birdena Holt, Chester Vane, a rival outfit) without per-buyer scripting beyond the numbers.

**2. Reputation with a buyer — first-pass numbers.** The market section above already names buyer reputation as a price factor; this proposes the actual curve, clearly a first pass for future tuning rather than balance:

- Reputation is per-buyer, ranges 0–5, starts at a neutral middle value (2, proposed).
- A fair sale (accepted at the opening price, or a counter that lands) is +1, capped at 5.
- A walked-away sale is neutral — no gain, no loss; refusing a bad offer shouldn't be punished.
- A sale to a buyer known to be rigged (Chester Vane) or a sale where the player's counter is caught as a bluff costs −2.
- Each point of reputation nudges the buyer's opening price in the player's favor by some small, tunable percentage (not specified here — that's exactly the "numeric weight" already flagged unresolved below).

**3. Debt and the Widow Stroud — first-pass numbers.** The existing "Debt and financing" section establishes that the Widow Stroud lends at real interest cost and that Magistrate Holt is where disputes escalate; this proposes the shape of that arc, again a first pass:

- A loan carries a simple flat per-period interest rate (proposed starting point: 10% per drive-cycle, not per day — matching the game's drive-cycle pacing rather than a real-time clock), added to principal each cycle it's outstanding.
- Missing a set number of consecutive repayment windows (proposed: three) moves the debt from "Stroud's own ledger" to "escalated" — Mortimer Vance's collecting failing to resolve it — at which point it becomes Magistrate Holt's matter per the existing text, with consequences (seizure, forced sale, standing loss) left to a future systems pass rather than specified here.
- None of this should read as punitive dice-rolling: the player always sees the current balance and the escalation threshold before it's crossed, matching this project's existing "late signs should visibly move prices, not just flavor text" standard from the market section.

**4. A shrewd-dealing perk, on the existing perk system.** `field_repairs`/`ada_mercer_perk`, `steady_herd`, and `spirit_sense` (per "What the player invests in," reading `scripts/companion_perks.gd`) are the existing precedent: a companion's stat reduces a real cost or risk. A shrewd-dealing perk extends that same system rather than needing a new category — proposed effect is a small, fixed improvement to the counter-offer's odds of landing and/or a reputation-gain bonus, read from the same companion-stat mechanism the three existing perks already use. This is design-only: no new script name, class, or perk id is being claimed as implemented here, only that the existing perk architecture already has room for this without extension.

## Trade goods, by category and who deals them

Everything here is a real character's actual trade, not an invented commodity list. A future systems pass turning this into numbers should attach values to *these* actors, not new ones.

| Category | Goods | Who deals it | Where |
|---|---|---|---|
| Hides and freight | Cattle hides, general freight | [Consuelo Diaz](wiki/people/consuelo_diaz.md) | Fort Griffin |
| General trade | Dry goods, ammunition, tools | [Nettie Voss](wiki/people/nettie_voss.md) (with [Sallie Voss](wiki/people/sallie_voss.md) learning the trade) | Fort Griffin |
| Rope and cordage | Hemp rope | [Marisol Vasquez](wiki/people/marisol_vasquez.md), via [Cyrus Boone](wiki/people/the_hemp_works_owner.md)'s hemp works; undercut by an unnamed cheaper rival | Fort Griffin (hemp works) |
| Leather goods | Saddlery, tack | [Petra Kowalski](wiki/people/petra_kowalski.md) | Fort Griffin |
| Tanned hide | Cured leather | [Philippa Grey](wiki/people/philippa_grey.md) | Fort Griffin |
| Footwear | Boots | [Adaline Cobb](wiki/people/adaline_cobb.md) | Fort Griffin |
| Wagons and wheels | Wainwright work | [Marcella Iturbe](wiki/people/marcella_iturbe.md) | Providence |
| Furniture | Carpentry | [Wilhelmina Ashby](wiki/people/wilhelmina_ashby.md) | Providence |
| Metalwork | General smithing | [Naomi Freeman](wiki/people/naomi_freeman.md), rivaled by [Orin Teague](wiki/people/orin_teague.md) | Fort Griffin |
| Fine metalwork | Silversmithing/jewelry | [Opaline Marchetti](wiki/people/opaline_marchetti.md) | Providence |
| Precision mechanism | Clock/watch repair | [Hepzibah Thorne](wiki/people/hepzibah_thorne.md) | Fort Griffin (Judge Abernathy is a regular customer) |
| Steam machinery | Repair and fabrication | [Ada Mercer](wiki/people/ada_mercer.md) | Clear Fork (the Outfit) |
| Textiles | Weaving, dye | [Ingrid Lindqvist](wiki/people/ingrid_lindqvist.md) | Providence |
| Millinery | Hats and trim | [Henrietta Sloane](wiki/people/henrietta_sloane.md) | Providence |
| Sewing and mending | Dressmaking | [Winnie Doyle](wiki/people/winnie_doyle.md) | Providence-adjacent |
| Basketry | Load-bearing baskets | [Phoebe Rutledge](wiki/people/phoebe_rutledge.md) | Fort Griffin |
| Barrels and cooperage | Casks | [Temperance Boucher](wiki/people/temperance_boucher.md) | Fort Griffin |
| Candles and wax | Chandlery | [Verity Lang](wiki/people/verity_lang.md) | Fort Griffin |
| Perfume and soap | Toiletries | [Seraphine Duval](wiki/people/seraphine_duval.md) | Providence |
| Dairy | Cheese | [Briony Wexford](wiki/people/briony_wexford.md) | Fort Griffin-adjacent (contested water with [Hosea Pruett](wiki/people/the_wexford_dairy_neighbor.md)) |
| Confectionery | Sweets | [Sunniva Larsen](wiki/people/sunniva_larsen.md), supplied by [Old Man Prescott](wiki/people/the_larsen_supplier.md) | Providence |
| Coffee and tea | Roasting | [Juniper Holloway](wiki/people/juniper_holloway.md), supplied by [Emmanuel Castro](wiki/people/the_holloway_bean_farmer.md) | Fort Griffin |
| Honey | Apiary | [Faustina Achebe](wiki/people/faustina_achebe.md) | Split Oak Camp (her hives are along the trail itself) |
| Spirits | Distilling | [Adelheid Kraus](wiki/people/adelheid_kraus.md), regulated by [Inspector Wexler](wiki/people/the_kraus_tax_official.md) | Bellhollow (an out-of-the-way still suits her scrutiny by the tax office) |
| Brewing | Beer | [Georgiana Hollis](wiki/people/georgiana_hollis.md) | Providence |
| Milling | Flour | [Romy Fenwick](wiki/people/romy_fenwick.md) | The Narrow Water (her conflict is an upstream diversion of that same water) |
| Land | Speculative lots | [Ezra Lowry](wiki/people/ezra_lowry.md) | Providence |
| Printed goods | News, notices | [Prisca Montaigne](wiki/people/prisca_montaigne.md) vs. [Silas Cobbett](wiki/people/the_montaigne_rival_editor.md) | Providence |

Several of these have a **rival or a pressure already written into the county** (Naomi/Orin, Marisol/the hemp rival, Prisca/Cobbett, Briony/Pruett, Birdena/Chester) — per `conflicts-and-rivalries.md`. A shrewd-dealing system should let the player's custom shift the balance of these existing feuds rather than invent new ones.

## Debt and financing

**The Widow Stroud** lends to outfits that fall behind, on unfailingly polite, unsentimental terms; her clerk **Mortimer Vance** does the uncomfortable collecting. This is the county's existing debt mechanic and should be the one the player can actually use — a cash-flow release valve after a bad drive, at real interest cost. **Magistrate Holt** is where an unpaid or disputed debt ends up if it escalates.

**Ezra Lowry**'s land speculation is the county's boom-or-bust option: buying in early on the rail spur is a real gamble the game should let the player make and lose, with **Reverend Pike** as the visible cautionary counter-voice already written into Providence.

## What the player invests in

- **Herd size and quality** — the base of everything else.
- **Hands** — [Pardo](wiki/people/pardo.md), [Alma Okafor](wiki/people/point_rider_alma.md), ["Young" Dutch](wiki/people/young_dutch.md) are already the outfit's standing crew; a growth loop could let the player expand this crew, not just recruit romance companions.
- **Companion perks as economic multipliers.** Several already reduce real costs per `scripts/companion_perks.gd`: `field_repairs`/`ada_mercer_perk` (repair efficiency), `steady_herd` (lasso/lead duration, i.e. fewer lost cattle), `spirit_sense` (hazard warning, i.e. fewer losses to the county's "late signs"). A shrewd-dealing or market system should read these same stats rather than invent parallel economic perks.
- **Standing with trade contacts** — the "reputation with the buyer" idea above, generalized to every merchant in the table.

## Rival economic pressure

The [Calloway Spread](wiki/organizations/calloway-spread.md), [Hargrove Range](wiki/organizations/hargrove-range.md), and the two independent crews ([Zilpah Hendricks](wiki/people/zilpah_hendricks.md)'s fair one, [Amos Ketch](wiki/people/the_hendricks_rival_crew_boss.md)'s exploitative one) are all competing for the same water, grass, and buyers the player is. This is already written as real competition, not scenery — an economy system should let their pressure move actual prices and availability, not just supply dialogue.

## Unresolved

- Exact numeric prices, and the exact numeric weight of each cattle-market factor.
- The shrewd-dealing counter-offer's actual shape (one offer/one counter/one outcome) is now proposed above, but the reputation curve (+1/−2/cap 5), the interest rate (10%/cycle), the missed-payment threshold (three cycles), and the perk's exact bonus are all first-pass numbers only — tuning, not accepted balance.
- What "escalated to Magistrate Holt" actually does mechanically (seizure, forced sale, standing loss, or something else) is still open; only the trigger condition is proposed.
- Whether the shrewd-dealing perk needs its own perk id in `companion_perks.gd` or reuses an existing one — proposed as extending the existing system, not specified further.
- Whether the player can found a *second* trade relationship that competes with an existing rivalry (e.g., backing Marisol against the hemp rival) or only influence the existing one.
- Whether goods are simulated as inventory items at all, or abstracted into a single "trade goods" resource the player allocates.
- How land purchase (Lowry) interacts with the ranch's own footprint, if at all.
- The trade-goods table's "Where" placements above were resolved 2026-09-10: checked `characters.json`, `npcs.json`, and the wiki organization pages first for each formerly-"Unplaced" character, found none of the twenty had a stated location anywhere (their wiki entries are trail encounters, not shop listings), and placed them deliberately per this doc's own two-market-town rule, with four exceptions where a character's own conflict names a specific place (Faustina Achebe's hives are on-trail at Split Oak Camp, Adelheid Kraus's still fits Bellhollow's isolation given the tax scrutiny on it, Romy Fenwick's mill sits on the water actually being diverted at The Narrow Water, Briony Wexford's dairy is a farm adjacent to Fort Griffin rather than in it). That leaves most craft/trade goods split between Fort Griffin and Providence, which is a real concentration rather than invented spread — a future pass could deliberately relocate a few of these (the leather-goods cluster in particular) to a third location if that reads as too crowded once the county has more built rooms to compare against.

Per this project's standing rule: do not silently implement any of the above as accepted design.
