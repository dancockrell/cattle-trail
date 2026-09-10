# Birdie Calloway

**Status:** romance-eligible companion (`design/characters.json`) &mdash; design only

Age 20. Runaway daughter of the Calloway Spread who traded a bigger house for her own say, and sings for her supper along the way.

## Personality
warm, playful, homesick, stubborn.

## Appearance and dress
Clearly adult, ordinary but gorgeous woman: slim, small-chested with little or no prominent bust, attractive hip/seat silhouette, healthy and active. Charismatic, comfortable in herself and sexually confident. Existing generated sprite in assets/birdie.png and assets/birdie-art.json once produced; currently unapproved.

Simple calico dress with a practical apron for camp work, sleeves rolled, hair loose or in a single braid, no riding gear -- she walks rather than rides. Adult, unpretentious, daring PG-13 coverage suited to camp rather than trail.

*Art status: unapproved draft.*

## How you meet her
She turns up at the edge of camp one evening, having walked off the Calloway Spread rather than marry where she was told to.

**To recruit her:**
- Talk with her once to hear why she left.
- Talk with her again after she has sung at the fire and the camp is easier for it.
- Offer her a place; Birdie accepts the invitation.

## What she needs
**Raises her strain:** Being told what she is going to do with her own life.

**Recovers it:** Being asked to sing rather than being asked what is wrong.

## Perk: Camp Song
Adds to the shared camp madness-recovery bonus alongside Eleanor's Steady Company, under the same stat cap.

## Her adventure: "The Song Her Mother Taught Her"
**Objective:** Play as Birdie teaching the protagonist a half-remembered song around the fire, filling gaps in the words together.

**Her skill:** Directly playable call-and-response singing rather than a dialogue tree.

**Your support:** The protagonist gets the verses wrong on purpose at least once, which is part of the point.

**Payoff:** Finishing the song together and a moment neither one names out loud.

## Notes
- Deliberately estranged daughter of the Calloway Spread (design/LOCATIONS.md), a story hook for later rivalry or reconciliation content; not resolved by this record.
- This is the one new companion actually implemented this pass: scripts/birdie_companion.gd and scripts/birdie_room.gd give her a stationary meet-hear-recruit conversation (no puzzle, no visible actor yet pending art). Verified with `python tools/verify_godot.py birdie birdie-room`.
- romance_adventure below is not yet built; only recruitment, camp rest and flirt are live.
## Known associates

**Affiliated with:** [The Calloway Spread](../organizations/calloway-spread.md), [The Outfit](../organizations/the-outfit.md)

**Connected to:** [Ada Mercer](ada_mercer.md), [Eleanor](eleanor.md), [Ines Vale](ines_vale.md)
