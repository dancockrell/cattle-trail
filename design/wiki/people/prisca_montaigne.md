# Prisca Montaigne

**Status:** romance-eligible companion (`design/characters.json`) &mdash; design only

Age 24. A printer and typesetter running Providence's first newspaper, one page at a time.

## Personality
sharp-tongued, genuinely believes in an honest paper, impatient with Percival Wren's tabloid instincts, hardworking to a fault.

## Appearance and dress
Clearly adult, ordinary but gorgeous woman: slim, small-chested with little or no prominent bust, attractive hip/seat silhouette, healthy and active. Charismatic, comfortable in herself and sexually confident. No approved art exists for this draft.

Ink-stained practical dress, sleeves rolled for the press, a compositor's apron with type-case pockets.

*Art status: unapproved draft.*

## How you meet her
She's trying to print the actual, boring truth about a recent county event while Percival Wren's version (monsters included) is already spreading faster, and needs help getting the facts out before the myth calcifies.

**To recruit her:**
- Help her get a true story printed over a more exciting false one.
- Respect the difference between her paper and Wren's copy.
- Prisca accepts the invitation.

## What she needs
**Raises her strain:** A true story losing to a more exciting false one.

**Recovers it:** Someone caring whether a story is true, not just whether it's good.

## Perk: Good Company
Reuses the existing shared camp-company perk definition rather than authoring a duplicate.

## Her adventure: "The Truth Versus the Tale"
**Objective:** Play as Prisca setting type on a factual story under deadline while a more sensational rumor spreads faster than she can print.

**Her skill:** Directly playable typesetting-under-deadline beats: accuracy competing directly against speed.

**Your support:** The protagonist verifies facts on her behalf so the paper can go to press honest.

**Payoff:** The true story printed, read by fewer people than the rumor, and her genuine satisfaction that it exists anyway.

## Notes
- Name, appearance and encounter are provisional. Deliberately contrasts with percival_wren in npcs.json without being his enemy.
- This is one of three companions actually implemented this pass via the new generic scripts/simple_companion_state.gd + scripts/simple_companion_room.gd system (see scripts/simple_companion_catalog.gd), rather than a bespoke pair of .gd files. Gated behind Birdie's recruitment. Verified with `python tools/verify_godot.py simple-companion simple-companion-room`.
## Known associates

**Affiliated with:** [Conflicts and rivalries](../organizations/conflicts-and-rivalries.md), [Providence](../organizations/providence.md)

**Connected to:** [Silas Cobbett](the_montaigne_rival_editor.md)
