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

## Trade goods, by category and who deals them

Everything here is a real character's actual trade, not an invented commodity list. A future systems pass turning this into numbers should attach values to *these* actors, not new ones.

| Category | Goods | Who deals it | Where |
|---|---|---|---|
| Hides and freight | Cattle hides, general freight | [Consuelo Diaz](wiki/people/consuelo_diaz.md) | Fort Griffin |
| General trade | Dry goods, ammunition, tools | [Nettie Voss](wiki/people/nettie_voss.md) (with [Sallie Voss](wiki/people/sallie_voss.md) learning the trade) | Fort Griffin |
| Rope and cordage | Hemp rope | [Marisol Vasquez](wiki/people/marisol_vasquez.md), via [Cyrus Boone](wiki/people/the_hemp_works_owner.md)'s hemp works; undercut by an unnamed cheaper rival | Unplaced (hemp works) |
| Leather goods | Saddlery, tack | [Petra Kowalski](wiki/people/petra_kowalski.md) | Unplaced |
| Tanned hide | Cured leather | [Philippa Grey](wiki/people/philippa_grey.md) | Unplaced |
| Footwear | Boots | [Adaline Cobb](wiki/people/adaline_cobb.md) | Unplaced |
| Wagons and wheels | Wainwright work | [Marcella Iturbe](wiki/people/marcella_iturbe.md) | Unplaced |
| Furniture | Carpentry | [Wilhelmina Ashby](wiki/people/wilhelmina_ashby.md) | Unplaced |
| Metalwork | General smithing | [Naomi Freeman](wiki/people/naomi_freeman.md), rivaled by [Orin Teague](wiki/people/orin_teague.md) | Unplaced |
| Fine metalwork | Silversmithing/jewelry | [Opaline Marchetti](wiki/people/opaline_marchetti.md) | Unplaced |
| Precision mechanism | Clock/watch repair | [Hepzibah Thorne](wiki/people/hepzibah_thorne.md) | Fort Griffin (Judge Abernathy is a regular customer) |
| Steam machinery | Repair and fabrication | [Ada Mercer](wiki/people/ada_mercer.md) | Clear Fork (the Outfit) |
| Textiles | Weaving, dye | [Ingrid Lindqvist](wiki/people/ingrid_lindqvist.md) | Unplaced |
| Millinery | Hats and trim | [Henrietta Sloane](wiki/people/henrietta_sloane.md) | Unplaced |
| Sewing and mending | Dressmaking | [Winnie Doyle](wiki/people/winnie_doyle.md) | Providence-adjacent |
| Basketry | Load-bearing baskets | [Phoebe Rutledge](wiki/people/phoebe_rutledge.md) | Unplaced |
| Barrels and cooperage | Casks | [Temperance Boucher](wiki/people/temperance_boucher.md) | Unplaced |
| Candles and wax | Chandlery | [Verity Lang](wiki/people/verity_lang.md) | Unplaced |
| Perfume and soap | Toiletries | [Seraphine Duval](wiki/people/seraphine_duval.md) | Unplaced |
| Dairy | Cheese | [Briony Wexford](wiki/people/briony_wexford.md) | Unplaced (contested water with [Hosea Pruett](wiki/people/the_wexford_dairy_neighbor.md)) |
| Confectionery | Sweets | [Sunniva Larsen](wiki/people/sunniva_larsen.md), supplied by [Old Man Prescott](wiki/people/the_larsen_supplier.md) | Unplaced |
| Coffee and tea | Roasting | [Juniper Holloway](wiki/people/juniper_holloway.md), supplied by [Emmanuel Castro](wiki/people/the_holloway_bean_farmer.md) | Unplaced |
| Honey | Apiary | [Faustina Achebe](wiki/people/faustina_achebe.md) | Unplaced |
| Spirits | Distilling | [Adelheid Kraus](wiki/people/adelheid_kraus.md), regulated by [Inspector Wexler](wiki/people/the_kraus_tax_official.md) | Unplaced |
| Brewing | Beer | [Georgiana Hollis](wiki/people/georgiana_hollis.md) | Providence |
| Milling | Flour | [Romy Fenwick](wiki/people/romy_fenwick.md) | Unplaced |
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

- Exact numeric prices, interest rates, and perk-to-currency conversion.
- Whether the player can found a *second* trade relationship that competes with an existing rivalry (e.g., backing Marisol against the hemp rival) or only influence the existing one.
- Whether goods are simulated as inventory items at all, or abstracted into a single "trade goods" resource the player allocates.
- How land purchase (Lowry) interacts with the ranch's own footprint, if at all.

Per this project's standing rule: do not silently implement any of the above as accepted design.
