# Cattle Trail: living game design

Cattle Trail is an alternate-1870s Weird West cattle-ranching RPG. This document is the source of truth for what the game is: its world, its cast, its loops and the rules that keep its quality and its player's experience intact.

## Player promise

**Dan, 2026-09-10, reframing the whole project's identity:** Cattle Trail is first a simulation of period economics and cattle ranching specifically, not a companion-collector with a ranch skin. The player grows a cattle operation through four connected levers: **shrewd dealing** (trade, negotiation, debt, market timing), **successful cattle drives** (herding, trail risk, delivery), **exploration** (the wider county and beyond, not one fixed room), and **romance** (the harem-lit pillar, unchanged from before). None of these four is decorative; a companion's usefulness, a rival outfit's pressure, and a trade good's price are all meant to be real numbers in the same simulation, not separate minigames wearing one skin. See [design/ECONOMY.md](design/ECONOMY.md) for the trade/market design, [design/EXPLORATION.md](design/EXPLORATION.md) for the county-travel design, and [design/DRIVES.md](design/DRIVES.md) for what a cattle drive itself actually is. Those three are the intended shape of the whole game, not optional later systems.

Lead a cattle outfit through an alternate 1870s Weird West, gather a harem of adult women with distinct personalities and useful talents, and build a household that helps its members endure an uncanny frontier. Frontier work, affectionate relationships, steampunk machinery and terrifying supernatural uncertainty belong to the same world. Romance is a central progression pillar, alongside trail work, trade and survival. These are ordinary but gorgeous, healthy, active, charismatic women who look after themselves, enjoy their own company and feel comfortable expressing mutual attraction. The game feels like a simple, lively RPG: most relationship development happens through shared adventures and playing as companions, with brief dialogue connecting memorable actions.

The starting room is Clear Fork, Texas, May 12, 1872. The year and date are implementation choices, not a historical claim. The fixed high three-quarter view, warm dusty palette, crisp pixel edges and readable rider/herd are the visual foundation.

## World and cast

- Steam power extends to frontier robotics and mechas. Machines have visible functions, maintenance needs and frontier uses. Machine density, fuel economy and playable mecha control are still open.
- Spirits and magical realism are ordinary accepted facts. A rancher can discuss a dead relative's warning as casually as the weather. People dispute an apparition's meaning or honesty, rather than whether spirits exist at all.
- Vast occult gods physically contend on Earth. Their identities, motives and alliances are difficult to determine. Witness accounts conflict; mad minions offer unreliable explanations. Narrative uncertainty must never make ordinary controls or quest objectives unreadable.
- Women eligible for the romance cast are recruitable companions. The cast mixes authored named women and procedurally generated women, each with individual perks. Recruitment does not imply immediate romance or simultaneous deployment of every companion.
- All romance candidates are explicitly adults, aged 18 or older; the usual range is 18 to 24, with older adults possible. Age is explicit in authored and generated character data. Use clearly adult characterization and visual presentation, and avoid child-coded presentation.
- The feminine art direction is ordinary but gorgeous adult women: slim, small-chested with little or no prominent bust, healthy, active, charming and sexually self-confident, with attractive hip and seat silhouettes. Clothing is self-chosen, rebellious and PG-13, and expresses personality: it is secondary to who she is. This is not a revealing-fantasy cast.
- Wardrobe is period adventure appeal, closer to a Lara Croft reference filtered through 1870s materials: woven fabrics, fitted vests and waistcoats, tied and open-collar blouses, split riding skirts, riding breeches, short riding jackets, corset-inspired outerwear, leather and brass. Not modern shorts and halters. Skirts belong alongside breeches. Daring coverage (bare shoulders, midriff, open back, short hem) is expressed through those period materials.
- Relationships and multi-partner arrangements are voluntary and openly acknowledged. PG-13 presentation supports flirting, kissing, embraces, affectionate rest and fade-to-black intimacy. It does not require explicit sexual imagery or sexual mechanics.
- Every character has madness, including the player, companions, rustlers and other NPCs. Intimacy with loved ones reduces madness. Affection, trusted conversation, shared rest and care all provide that intimacy; recovery is never a mandatory sexual transaction.

## The playable loop

Travel and tend the herd, encounter a person, machine or uncanny event, choose how to help, negotiate or fight, manage strain and resources, return to camp, deepen relationships and recover, then choose companions and perks for the next outing.

Movement, herding, lasso and shoot interactions stay legible as this loop grows. Build compact playable encounters and camp interactions alongside animation work, then extend travel with the same character and state continuity.

## State boundaries

These boundaries guide runtime implementation. `scripts/companion_state.gd` implements them.

| State | Owns |
|---|---|
| Recruitment | Whether a person is available, invited, recruited or has departed |
| Relationship | Trust, affection, relationship stage and mutually chosen relationship agreements |
| Party role | Camp role, current field assignment and availability |
| Perks | Authored mechanical effects, activation conditions and stacking group |
| Madness | Current strain value, sources, recovery and narrative consequences |

Recruitment is separate from romance, from physical intimacy and from an active party slot. Relationship state is never purchased through gifts, perks or a numeric threshold. A party role does not mean ownership of the character or permanent access to a perk. A perk never triggers romance or compulsory intimacy. Madness never stands in for sexual availability and never rewrites a personality by force.

Recruitment transitions: unavailable, then available after encounter conditions, then invited by either party, then recruited by mutual agreement. Attraction is usually mutual and enjoyable: begging, repeated persuasion and a constant refusal loop are never the core experience. A declined or deferred choice returns to ordinary play without a grind to overturn it. Departed companions retain identity and history. Death, permanent departure and roster limits are still to be designed.

Relationship transitions: unfamiliar, acquainted, trusted, courting, partnered. Shared adventures and companion-controlled challenges provide most progression. Mutual choices acknowledge a new stage through short, lively exchanges rather than long dialogue trees or repeated persuasion. A woman can be recruited and valuable before romance. Repeating the same adventure or affectionate action does not endlessly grant the same relationship reward.

Each recruited woman's perk improves the player, the outfit or the current action. Field-only, camp-only and recruited-passive conditions are separate. Stacking groups and caps keep an unlimited generated roster from multiplying bonuses without bound. Each perk explains its effect and when it is active. Numeric values in `design/characters.json` are tuning values and get balanced in play.

## Madness and intimacy

Madness is a 0 to 100 meter: 0 is grounded, 100 is overwhelming supernatural strain. Sources include direct occult exposure, hostile influence, traumatic events and exhaustion. Never reduce it to a moral alignment, and never equate real-world mental illness with evil. Ordinary NPCs carry the same state shape even when their meter is hidden from the player.

Bands: grounded 0 to 24; unsettled 25 to 49; strained 50 to 74; overwhelmed 75 to 100. Consequences are authored dialogue, perception cues and recoverable encounter complications. Never steal movement control from the player, and never invent random unavoidable attacks.

Recovery comes from a trusted conversation, an embrace, shared sleep, mutual care or a fade-to-black intimate scene. A relationship's meaning matters more than the explicitness of a scene. Show the expected effect before confirming an action, apply the result once, respect the other person's availability, and preserve the option to decline. Solo rest and other support give lesser recovery, so an isolated player is never locked out of recovery. Recovery amount, time cost and daily cap are fields, not hidden prose rules.

Madness events belong to simulation data. Sound, visual distortion and dialogue are derived presentation. Provide reduced-distortion settings and textual equivalents. An inaccessible or declined intimacy scene must never block returning to the main game.

## Playable companions and short romance adventures

Recruitment, relationship and player control are distinct states. A companion can become playable for an authored short adventure without already being a romantic partner. Control state: controlled actor ID, adventure ID, active role, return actor ID and safe return location. Switching transfers input and camera focus to the companion; it does not copy inventories, erase madness, swap identities or automatically activate every recruited perk. Only the controlled actor receives direct input. The other participants follow the encounter script or a clearly defined support role.

Each adventure has one readable objective, a skill particular to that woman, a playful or exciting interaction with the protagonist, and a short distinctive romantic payoff when mutually chosen. Aim for a few minutes, not extended dialogue sessions. Return control after success, cancellation or recoverable failure. On failure retain identity and relationship continuity, and allow retry without duplicate rewards. Save/load restores the active encounter or its safe checkpoint. Switching must never strand the player in an unavailable actor. Switching is not permitted during an unresolved lasso or shoot action; finish or safely cancel that action first.

The adventures:

- **Eleanor, Lanterns at the Ford (built):** play as Eleanor, carry a spirit lantern between stranded cattle and calm a frightened crossing spirit with her healer's skill while the protagonist holds the herd. Afterward, share a relieved laugh and an optional brief embrace at the wagon. The romance grows from competence, care and a small shared scare.
- **Ada, Two Seats, One Regulator (built):** play as Ada, route pressure through a stalled two-seat steam cart while the protagonist braces its jumpy controls, then take a short successful ride together. Her delighted teasing and an optional kiss at the stop are the payoff. A compact readable repair challenge, not a long engineering menu.
- **Ines, The Moon's Wrong Reflection (not built yet):** play as Ines, follow moving spirit reflections across a safe stretch of creek while the protagonist follows her signals. Find the real crossing, then enjoy a playful secluded moment and an optional kiss. Her special perception is used directly by the player rather than described in a dialogue tree. Separate from Ines's own room encounter (the three-clue spirit trail, recruitment and camp rest), which is built.

Keep the relationship experience varied through different skills and situations. Procedural companions draw compatible adventure templates instead of recycling the same conversation with a different name.

## Named and generated companions

Eleanor is the first continuity anchor: adult, age 24, already present in Clear Fork. She is a frontier healer who takes spirits seriously and brings a steadying camp presence. Her existing sprite identity is the production reference until a deliberate new outfit is chosen.

Ada Mercer (22) has a source-room steam repair encounter, recruitment, cart outing and camp care. Ines Vale (23) has a persisted spirit-trail encounter, recruitment, camp and field assignment, and shared camp rest; see her record below and in `design/characters.json`. Ines supersedes the earlier Rosa Vale draft of the same spirit-listener and scout role, which no longer exists as a separate character.

Procedural companions draw from curated adult names, backgrounds, silhouettes, outfits, temperament traits, encounter hooks and compatible perk packages. Store a stable seed and the resolved character record so loading a save never rerolls identity. Validate age before generating art or dialogue. Generate coherent individuals rather than independently randomizing every attribute. Prioritize ordinary attractive women with health, activity, charm and self-confidence; avoid a generic revealing-fantasy cast. Match each woman to a short playable relationship adventure, not just a perk and a dialogue portrait. A perk package must be usable, and personality, role and visual equipment must agree. Named characters keep stable authored IDs; generated IDs include a persistent identity key.

The default generated age range is 18 to 24. All eligible women can become romance companions through their own recruitment and relationship arcs; they do not need identical personalities or instant acceptance. Recruitment conditions, availability and personal boundaries differ between them. Rules for non-romance incidental population are still open.

## Presentation, interaction and persistence

### Story through action-time speech bubbles

Cattle Trail is substantially a relationship sim. Much of its story emerges through short side comments during actual play, with attractive, expressive speech bubbles and the social liveliness of a Sims-like experience. Keep the amount balanced: enough to establish personality and chemistry, with quiet space between exchanges. The current room implements Eleanor's introduction, first cattle catch, rustler retreat and completion comments; broader relationship-driven banter builds on that.

Trigger comments from meaningful actions and shared circumstances: a difficult catch, a companion's successful assist, a strange spirit encounter, a small mistake, or a callback to an earlier adventure. Characters tease, encourage, react and initiate affection. Give each woman a recognizable voice. A brief exchange should reveal something about the relationship while movement and the task continue. Avoid generic praise after every action or repeated lines on a timer.

Bubble treatment: crisp, warm illustrated panels with legible text, a clear tail identifying the speaker, restrained entrance motion, and personality expressed through wording and occasional small reaction symbols. Keep bubbles clear of faces, action targets and the HUD; reposition at screen edges and preserve readability at narrow widths. Start with one short sentence, usually one or two lines. Allow a short reply, then quiet. Queue or omit low-priority chatter during urgent action rather than stacking bubbles over the herd. Important objectives stay available in the journal after a bubble disappears.

Use relationship history to select relevant comments and remember recently used lines. Player actions supply the context; dialogue adds character and emotional meaning. Never turn normal movement into a sequence of modal conversation stops.

Retain the responsive room and its input model. A compact companion panel shows name, adult age, role, current perk, recruitment and relationship status, and madness when known. Keep controls reachable at narrow widths. Do not cover herd movement with unsolicited relationship popups.

Camp flow: select companion, choose a short shared activity or companion adventure, play its distinct challenge, enjoy a brief affectionate beat, apply one event, return to camp. Conversation-only choices are supporting material, not the dominant progression path. Cancelling before confirmation changes no state. Unavailable choices explain why. A declined invitation preserves the relationship and returns control cleanly. Save resolved character identity, recruitment state, relationship events and agreements, role, perk unlocks, madness, recovery cooldowns, adventure completion and the currently controlled actor with a safe return location. Presentation reconstructs from this state without replaying rewards.

For romantic keyframes, distinguish invitation, mutually accepted affectionate beat and resolved rest. For supernatural beats, distinguish ordinary room, identifiable uncanny intrusion and aftermath. Keep camera, scale, costume, adult identity and environment continuity across each sequence.

## Art and animation

`source/reference_0.png`, `source/reference_1.png`, `source/reference_2.png` and `source/approved-concept.mp4` establish existing actor identity, camera, palette and pixel treatment. They do not cover new companion wardrobe, mechas or occult designs; compare those in the native room.

Animation quality bar: variety cannot substitute for ordered motion. Every cycle demonstrates contact, lift, travel, landing and a clean loop. Every lasso demonstrates preparation, coherent swing, release and recovery with one release event. Preserve subject proportions, facing, hoof and foot contact, and rope continuity. Judge motion from runtime comparison clips, not from a contact sheet.

Detailed character masters: preserve native source detail and work at roughly 160-pixel figures, choosing a matching runtime presentation resolution rather than flattening to a coarse master. The room renders at its displayed integer density up to 4x while preserving the same logical trail size and physics; source-pixel density and optional per-frame pivots let 160-pixel figures keep the existing 40-world-unit body scale. Candidate packages hold individual whole poses and observed facing views. Keep incomplete pose banks out of runtime animation selection.

## What is next

1. **Detailed whole-character animation.** Preserve the requested detail, correct contact and passing opposition, and get turn views right on the sheets.
2. **The broader game.** Admit a coherent detailed character kit and a generated companion encounter using persistent identity and compatible perks, then expand travel, uncanny encounters and mecha play on those foundations.
3. **The four pillars.** Economy, exploration and drives per their design documents, built into the same simulation as the companions.

## Records

`design/companion.schema.json` defines the adult companion record. `design/characters.json` contains the named characters and a procedural template; it is not a save file. Change this document and those records together when the foundation changes.

## Current systems

### Trail time

Saved trail time advances at one game minute per real second of active simulation. Day 1 starts at noon on May 12, 1872. Shared rest spends its declared 30 minutes and becomes available after its daily cooldown; ordinary play expires that cooldown. The HUD shows trail day and time, and completed-adventure rest availability. No offline elapsed time is applied. World travel, a day/night art set and scheduled NPC behavior are not built yet.

### Lanterns at the Ford

Eleanor has whole-character source art carrying a brass lantern, and the crossing spirit has four states. The authored progression is a persisted backend: take the lantern, settle the spirit, guide three distinct cattle and return to the wagon. Pause and recoverable failure return control safely while preserving the checkpoint. Completion uses a stable milestone and cannot issue a duplicate reward.

The room starts the lantern encounter through Companion at the wagon after Steady Company completes. A spectral longhorn appears on the dry trail crossing. Three cattle move across under Eleanor's guidance, with arrival credited from physical positions. Pause returns player control at the wagon; resume and save/load preserve checkpoint and cattle progress. Completion adds 10 trust once, separate from romance. Existing walk clips remain, with a generated brass lantern prop belt-mounted during the activity. The four spirit states and one equipment sprite are encounter art outside the base room's 330 selected actor frames. The full water-ford scenery and polished whole-character carry cycles are still to do.

Spirit exposure has a mechanical consequence: Eleanor gains 6 madness once when approaching the agitated crossing spirit within 80 world pixels, or interacting within reach. The encounter stores this event separately from speech history, so interrupted dialogue, retries and reloads cannot stack the charge. The lantern save format is version 2; older started checkpoints migrate as already exposed without retroactively altering their madness. Shared rest is the recovery route, independent of choosing romance.

### Side-comment delivery

Delivery keeps at most two pending meaningful lines when the bubble is occupied. Equal priorities retain order; higher priority replaces the oldest lower-priority pending line. Pending room comments expire after six seconds, so stale banter does not accumulate. Low-priority ambient remarks are not queued. A beat enters spoken history only when its bubble actually opens; save restoration clears unspoken pending presentation. None of this pauses player movement or advances relationship state.

### Ada's first encounter

The stalled agricultural walker has a fictional pressure puzzle. Shut feed, vent to 5 or below, install the recovered regulator, close vent, build pressure into 30 to 50, close feed and test. Overpressure above 85 faults the machine and shuts feed; venting allows retry without losing the part. Successful testing locks the repaired state. Ada's identity (adult, 22), madness, first meeting, trust and invitation are separate persisted state. Repair precedes an accepted invitation, which grants trust once without romance. Outer saves retain this optional state and accept older saves without it. The room places Ada and the walker after the lantern crossing and activates contextual Feed, Vent, Install/Test and Invite controls. This walker encounter is distinct from the later Two Seats, One Regulator romance adventure.

The stationary mechanic encounter uses Ada's detailed elevated 160-pixel master at four source pixels per world unit, preserving the same approximate world height as her older sprite. The steam handler's state art is unchanged.

### Two Seats, One Regulator

After Ada accepts the outfit invitation, a wooden and brass two-seat cart appears on the lower trail. Board to control Ada in the occupied cart, inspect its regulator, open outer valves A and C and leave middle bypass B closed. A wrong test produces one point of Ada strain and permits a retry. Follow three physical brass-lantern checkpoints in order, return to the cart stop and finish for 15 trust once. An optional kiss is a separate mutual choice, remembered once and worth 5 additional trust. Romance is not required to drive or finish.

The room transfers movement to the whole occupied-cart actor; the trail-boss and standing Ada sprites hide during the outing. Pausing parks an empty cart, returns player control and preserves the driving position and checkpoints for resumption. After the outing Ada stands beside the cart for the closing exchange. The save includes all activity flags and cart position. Old saves without this activity remain supported.

Cart artwork provides occupied SE, S, SW and N plus empty parked SE views. E and W inputs use their closest quarter view, and northern diagonals use N. These mappings are explicit in the sprite metadata; wheel cycles and interpolated cart turns are not authored yet. Steering accelerates toward 32 world pixels per second at 48 pixels per second squared, brakes at 64, and turns at a maximum 2.5 radians per second. Reverse input steers through a turn; releasing directional input brakes. Brake [E] clears a click destination and stops the cart immediately during the lantern route. The cart uses 15 pixels of extra scenery, wagon and world-edge clearance; human and cattle footprints keep their existing size. Heading is saved; velocity is stopped on pause, boarding, completion and load.

### Camp care

After Ada's cart outing, Rest near her spends 30 trail minutes and restores up to 10 madness for each participant. Eleanor gives up to 13 player and 10 companion recovery. Each participant has a 1,440-minute cooldown, so changing partners cannot repeat player recovery. Saved recovery deadlines migrate from older Eleanor rests. Active outings must be paused and unfinished actions resolved first; romance remains a separate choice.

Recruited Ines offers the same 30-minute, up-to-10-each shared rest while assigned to camp and within 45 units of her actor. Her participant deadline shares the player cooldown with Eleanor and Ada. Field assignment, active outings and unfinished actions prevent Ines rest. Romance is not required; a short spirit-themed remark accompanies the quiet time. Her nearby madness display and Rest control are connected without duplicate HUD entries.

### Ines Vale's spirit trail

Meet Ines, investigate bell tracks, cold ashes and a wrong shadow, then complete the trail for a one-time trust reward. Accepted recruitment assigns her to camp; explicit field assignment activates her Spirit Sense perk. A mutual romance acknowledgement never follows automatically from recruitment. Deferred choices preserve ordinary progression. Earned rewards, clue identities, adult identity and finite madness are validated before restoring a save. Older saves initialize her untouched state. Short action-time remarks are authored in `data/ines_banter.json`.

Her encounter unlocks after Ada's completed cart outing. The elevated Ines sprite stands by the northern trail; Talk reads three nearby scenery landmarks, then returns to Ines for completion and a separate invitation. Flirt is optional. Field assignment extends landmark warnings from 24 to 36 world units, while reading still requires approach within 24; revisits grant no rewards. Contextual desktop and mobile controls and prerequisite-aware saves are connected. Ines is stationary during this encounter; player-controlled scouting and finished movement animation come later.

The trail has three sprite landmarks: a spectral brass bell, cold embers and a crow shadow with no bird overhead. They appear after meeting her, at the clue positions, below actors and without collision changes. Their four effects loops are not finished yet.

### Persistent generated companions and capped perks

Resolved generated companion identities are stored inside the room save, without rerolling names or appearances on load. Recruitment, relationship choice, camp and field assignment, and one-time activity rewards are separate. Madness retains fractional values. The roster has no population limit; adult identity, unique visual IDs and finite values are validated atomically. Production-preview artwork does not enter the default live roster. The 96 character appearances are an offline candidate library until their encounters and art are authored.

The perk resolver uses authored values and activation rules instead of trusting numbers in a save. Eleanor's Steady Company recovery uses it and gives 3 additional player recovery. Recruited rancher-family helpers add 2 seconds to a successful cattle lasso's following duration, capped at 4 seconds across the outfit (18 seconds becomes 20 or 22). The hook is implemented; a generated rancher encounter to use it comes next. Mechanic repair efficiency and spirit-scout warning tiers have capped resolver definitions and need a consuming gameplay action. Recruitment never starts romance, and no effect ever scales with clothing.
