# Cattle Trail — the wiki

This is the browsable version of the county: who lives here, who works for whom, who's related to whom, who's feuding with whom, and why. The machine-readable source of truth stays [`design/characters.json`](../characters.json) (romance-eligible companions) and [`design/npcs.json`](../npcs.json) (everyone else) — this wiki is generated from and cross-linked to that data, not a replacement for it. If the two ever disagree, the JSON wins; fix the wiki page to match.

World rules and tone live in [`LORE.md`](../LORE.md). Physical places live in [`LOCATIONS.md`](../LOCATIONS.md). Game mechanics live in [`GAME-DESIGN.md`](../../GAME-DESIGN.md).

## Organizations — start here

The fastest way into the world is by institution, not by scrolling a name list:

- [The Outfit](organizations/the-outfit.md) — the player's own household
- [The Calloway Spread](organizations/calloway-spread.md) — the established rival ranch
- [The Hargrove Range](organizations/hargrove-range.md) — the newer, scrappier rival ranch
- [Fort Griffin](organizations/fort-griffin.md) — law, trade, medicine, communications
- [Providence](organizations/providence.md) — the boomtown: speculation, press, faith, law
- [Bellhollow](organizations/bellhollow.md) — the played-out mining camp and its holdouts
- [Independent trail crews](organizations/independent-outfits.md) — Zilpah Hendricks's crew and its contrasting bad-actor counterpart
- [Family and personal networks](organizations/family-and-personal-networks.md) — blood, mentorship, and old history that crosses the above groupings
- [Conflicts and rivalries](organizations/conflicts-and-rivalries.md) — a map of who's actually opposed to whom, and on what terms

## People

Every named character has a page under [`people/`](people/), generated from their full record: background, personality, what raises and lowers their strain, their reason for being in this world, and — for romance-eligible companions — their playable adventure. Each page lists **known associates**: the other characters and organizations that page's own record, or another page, links to. That list is how you find out who knows whom, and who knows people who know whom, without memorizing 151 names.

Romance-eligible companions are marked **(companion)**; everyone else is marked by their [`npcs.json`](../npcs.json) category (family, rival_outfit, outfit_hand, town, antagonist, supernatural, wanderer).

## Keeping this honest

A person or organization only gets a room, a quest, or new mechanics when a story beat actually needs it — this wiki existing is not itself an implementation claim. Check each page's own status line, and `scripts/` for whether anything's actually wired into the game.
