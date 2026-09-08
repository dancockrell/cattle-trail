# Cattle Trail — living game design

Status: accepted creative direction with provisional balance. The user now authorizes building the wider game and making it fun while walk and turn repairs continue in parallel, including generated whole-pose tweens. This supersedes the earlier rule that all companion implementation must wait for final room-art approval. Keep the visual bar intact; that bar is not certified by this scope change.

Implemented first companion proof: after the Clear Fork herd task, Eleanor accepts an invitation into the outfit. The player can control her to steady three distinct cattle and return to the wagon. The adventure grants trust once, a separate optional flirt starts courting, and shared rest reduces madness with her +3 Steady Company perk. Recruitment does not imply romance. Player, Eleanor and rustler have separate madness values. Save/load preserves resolved companion events and the room. The larger procedural cast, supernatural encounters, travel, economy, robots and mechas remain design proposals. This document remains the source of truth for game identity. Asset extraction and animation contracts remain in METHOD.md and the runtime manifests.

## Player promise

Lead a cattle outfit through an alternate 1870s Weird West, gather a harem of adult women with distinct personalities and useful talents, and build a household that helps its members endure an uncanny frontier. Frontier work, affectionate relationships, steampunk machinery and terrifying supernatural uncertainty belong to the same world. Romance is a central progression pillar, alongside trail work and survival. These are ordinary but gorgeous, healthy, active, charismatic women who look after themselves, enjoy their own company and feel comfortable expressing mutual attraction. The game should feel like a simple, lively RPG: most relationship development happens through shared adventures and playing as companions, with brief dialogue connecting memorable actions.

The starting room is provisionally Clear Fork, Texas, May 12, 1872. The year and date are implementation choices, not a historical claim. The fixed high three-quarter view, warm dusty palette, crisp pixel edges and readable original rider/herd remain the visual foundation.

## Accepted world and cast direction

- Steam power extends to frontier robotics and mechas. Machines should have visible functions, maintenance needs and frontier uses; machine density, fuel economy and playable mecha control remain undecided.
- Spirits and magical realism are ordinary accepted facts. A rancher can discuss a dead relative's warning as casually as the weather. People dispute an apparition's meaning or honesty, rather than whether spirits exist at all.
- Vast occult gods physically contend on Earth. Their identities, motives and alliances are difficult to determine. Witness accounts can conflict; mad minions offer unreliable explanations. Narrative uncertainty must not make ordinary controls or quest objectives unreadable.
- Women eligible for the romance cast are recruitable companions. The cast mixes authored named women and procedurally generated women, each with individual perks. Recruitment need not imply immediate romance or simultaneous deployment of every companion.
- All romance candidates are explicitly adults, aged 18 or older; the user's preferred usual age range is 18–24, with older adults possible. Age is explicit in authored and generated character data. Use clearly adult characterization and visual presentation.
- The requested feminine art direction is ordinary but gorgeous adult women: slim, small-chested with little or no prominent bust, healthy, active, charming and sexually self-confident, with attractive hip/seat silhouettes. Self-chosen rebellious PG-13 clothing expresses personality; revealing fantasy costumes are not the cast foundation or their sole identity. Examples for exploration include fitted riding trousers, short riding jackets, open-collar blouses, corset-inspired outerwear and practical short skirts over riding layers. These are art proposals, not approved replacement sprites. Avoid child-coded presentation.
- Relationships and multi-partner arrangements are voluntary and openly acknowledged. PG-13 presentation supports flirting, kissing, embraces, affectionate rest and fade-to-black intimacy; it does not require explicit sexual imagery or sexual mechanics.
- Every character has madness, including the player, companions, rustlers and other NPCs. Intimacy with loved ones reduces madness. Affection, trusted conversation, shared rest and care can provide that intimacy; recovery is not a mandatory sexual transaction.

## Proposed playable loop

Travel and tend the herd → encounter a person, machine or uncanny event → choose how to help, negotiate or fight → manage strain and resources → return to camp → deepen relationships and recover → choose companions and perks for the next outing.

Keep movement, herding, lasso and shoot interactions legible as this loop grows. Build compact playable encounters and camp interactions alongside animation improvements, then extend travel with the same character and state continuity.

## Separate state contracts

These boundaries guide runtime implementation. scripts/companion_state.gd implements the initial Eleanor subset; the broader cast and systems remain proposals.

| State | Owns | Must not imply |
|---|---|---|
| Recruitment | Whether a person is available, invited, recruited or has departed | Romance, physical intimacy or an active party slot |
| Relationship | Trust, affection, relationship stage and mutually chosen relationship agreements | Purchase of consent through gifts, perks or a numeric threshold |
| Party role | Camp role, current field assignment and availability | Ownership of the character or permanent access to a perk |
| Perks | Authored mechanical effects, activation conditions and stacking group | Automatic romance or compulsory intimacy |
| Madness | Current strain value, sources, recovery and narrative consequences | Sexual availability or a forced personality rewrite |

Recruitment transitions: unavailable → available after encounter conditions → invited by either party → recruited by mutual agreement. Attraction should usually be mutual and enjoyable; do not make begging, repeated persuasion or a constant refusal loop the core experience. A declined or deferred choice returns to ordinary play without a grind to overturn it. Departed companions retain identity and history. Death, permanent departure and roster limits remain unresolved; do not implement them implicitly.

Relationship transitions are proposed as unfamiliar → acquainted → trusted → courting → partnered. Shared adventures and companion-controlled challenges provide most progression. Mutual choices acknowledge a new stage through short, lively exchanges rather than long dialogue trees or repeated persuasion. A woman can be recruited and valuable before romance. Repeating the same adventure or affectionate action does not endlessly grant the same relationship reward. Exact values and pacing remain provisional.

Each recruited woman's perk can improve the player, outfit or current action. Separate field-only, camp-only and recruited-passive conditions. Use stacking groups and caps to avoid an unlimited generated roster multiplying bonuses without bound. Each perk must explain its effect and when it is active. Numeric examples in characters.json are tuning placeholders, not implemented balance.

## Madness and intimacy proposal

Use a provisional 0–100 meter: 0 is grounded, 100 is overwhelming supernatural strain. Sources include direct occult exposure, hostile influence, traumatic events and exhaustion. Do not reduce it to a moral alignment or equate real-world mental illness with evil. Ordinary NPCs retain the same state shape even when their meter is hidden from the player.

Provisional bands: grounded 0–24; unsettled 25–49; strained 50–74; overwhelmed 75–100. Initial consequences should be authored dialogue, perception cues and recoverable encounter complications. Do not steal movement control or invent random unavoidable attacks. Bands and effects require playtesting before admission.

Recovery can come from a trusted conversation, an embrace, shared sleep, mutual care or a fade-to-black intimate scene. A relationship's meaning matters more than the explicitness of a scene. Show the expected effect before confirming an action, apply the result once, respect the other person's availability, and preserve the option to decline. Solo rest and other support can provide lesser recovery so an isolated player is not locked out of recovery. Proposed recovery amount, time cost and daily cap are fields, not hidden prose rules.

Madness events belong to simulation data. Sound, visual distortion and dialogue are derived presentation. Provide reduced-distortion settings and textual equivalents. An inaccessible or declined intimacy scene must not block returning to the main game.

## Playable companions and short romance adventures

Recruitment, relationship and player control are distinct states. A companion can become playable for an authored short adventure without already being a romantic partner. Proposed control state: controlled actor ID, adventure ID, active role, return actor ID and safe return location. Switching transfers input and camera focus to the companion; it does not copy inventories, erase madness, swap identities or automatically activate every recruited perk. Only the controlled actor receives direct input. The other participants follow the encounter script or a clearly defined support role.

Each adventure has one readable objective, a skill particular to that woman, a playful or exciting interaction with the protagonist, and a short distinctive romantic payoff when mutually chosen. Aim provisionally for a few minutes, not extended dialogue sessions. Return control after success, cancellation or recoverable failure. On failure retain identity and relationship continuity; allow retry without duplicate rewards. Save/load restores the active encounter or its documented safe checkpoint. Switching must never strand the player in an unavailable actor. Do not permit switching during an unresolved lasso/shoot action; finish or safely cancel that action first. Exact switching controls remain a later UI decision.

Representative drafts:

- **Eleanor — Lanterns at the Ford:** play as Eleanor, carry a spirit lantern between stranded cattle and calm a frightened crossing spirit with her healer's skill while the protagonist holds the herd. Afterward, share a relieved laugh and an optional brief embrace at the wagon. The romance grows from competence, care and a small shared scare.
- **Ada — Two Seats, One Regulator:** play as Ada, route pressure through a stalled two-seat steam cart while the protagonist braces its jumpy controls; take a short successful ride together. Her delighted teasing and an optional kiss at the stop are the payoff. Use a compact readable repair challenge, not a long engineering menu.
- **Rosa — The Moon's Wrong Reflection:** play as Rosa, follow moving spirit reflections across a safe stretch of creek while the protagonist follows her signals. Find the real crossing, then enjoy a playful secluded moment and an optional kiss. Her special perception is used directly by the player rather than described in a dialogue tree.

These adventure sketches are design only. They introduce no additional room, playable actor switching, romance rewards, machine controls or occult mechanics to the current build. Keep the relationship experience varied through different skills and situations; procedural companions draw compatible adventure templates instead of recycling the same conversation with a different name.

## Named and generated companions

Eleanor is the first continuity anchor: adult age 24, already present in Clear Fork. Her proposed identity is a frontier healer who takes spirits seriously and brings a steadying camp presence. Existing sprite identity remains the production reference until a deliberate new outfit is reviewed. Root integration may update her opening dialogue to establish the Weird West; that alone does not implement recruitment or madness.

Ada Mercer, a steam mechanic, and Rosa Vale, a spirit-listener and trail scout, are representative **drafts** in design/characters.json. Their names, backgrounds, looks and numbers remain editable proposals. They are not generated assets or admitted room characters.

Procedural companions draw from curated adult names, backgrounds, silhouettes, outfits, temperament traits, encounter hooks and compatible perk packages. Store a stable seed and the resolved character record so loading a save never rerolls identity. Validate age before generating art or dialogue. Generate coherent individuals rather than independently randomizing every attribute. Prioritize ordinary attractive women with health, activity, charm and self-confidence; avoid a generic revealing-fantasy cast. Match each woman to a short playable relationship adventure, not just a perk and dialogue portrait. A perk package must be usable, and personality, role and visual equipment must agree. Named characters keep stable authored IDs; generated IDs include a persistent identity key.

The default generated age range is 18–24. All eligible women may become romance companions through their own recruitment and relationship arcs; they do not need identical personalities or instant acceptance. Recruitment conditions, availability and personal boundaries can differ. Non-romance incidental population rules remain an open content question.

## Presentation, interaction and persistence

### Story through action-time speech bubbles

Accepted user direction: Cattle Trail is substantially a relationship sim. Much of its story should emerge through short side comments during actual play, with attractive, expressive speech bubbles and the social liveliness of a Sims-like experience. Keep the amount balanced: enough to establish personality and chemistry, with quiet space between exchanges. The current room implements a small proof: Eleanor introduction, first cattle catch, rustler retreat and completion comments. Broader relationship-driven banter remains a design foundation.

Trigger comments from meaningful actions and shared circumstances: a difficult catch, a companion's successful assist, a strange spirit encounter, a small mistake, or a callback to an earlier adventure. Characters can tease, encourage, react and initiate affection. Give each woman a recognizable voice. A brief exchange should reveal something about the relationship while movement and the task continue. Avoid generic praise after every action or repeated lines on a timer.

Proposed bubble treatment: crisp, warm illustrated panels with legible text, a clear tail identifying the speaker, restrained entrance motion, and personality expressed through wording and occasional small reaction symbols. Keep bubbles clear of faces, action targets and the HUD; reposition at screen edges and preserve readability at narrow widths. Start with one short sentence, usually one or two lines. Allow a short reply, then quiet. Queue or omit low-priority chatter during urgent action rather than stacking bubbles over the herd. Important objectives must remain available in the journal after a bubble disappears. Exact styling, duration and frequency require native-room review.

Use relationship history to select relevant comments and remember recently used lines. Player actions should supply the context; dialogue should add character and emotional meaning. Do not turn normal movement into a sequence of modal conversation stops. Broader companion simulation and relationship-driven banter remain planned work, now authorized alongside visual repair.

Retain the responsive current room and its input model. A later compact companion panel should show name, explicit adult age, role, current perk, recruitment/relationship status and madness when known. Keep controls reachable at narrow widths. Do not cover herd movement with unsolicited relationship popups.

Proposed camp flow: select companion → choose a short shared activity or companion adventure → play its distinct challenge → enjoy a brief affectionate beat → apply one event → return to camp. Conversation-only choices are supporting material, not the dominant progression path. Cancelling before confirmation changes no state. Unavailable choices explain why. A declined invitation preserves the relationship and returns control cleanly. Save resolved character identity, recruitment state, relationship events and agreements, role, perk unlocks, madness, recovery cooldowns, adventure completion and the currently controlled actor with a safe return location. Presentation must reconstruct from this state without replaying rewards.

For romantic keyframes, distinguish invitation, mutually accepted affectionate beat and resolved rest. For supernatural beats, distinguish ordinary room, identifiable uncanny intrusion and aftermath. Keep camera, scale, costume, adult identity and environment continuity across each sequence. These are briefs for later frames, not an authorization claim that any existing generated action sequence has passed review.

## Art and animation authority

The approved source/reference_0.png, source/reference_1.png, source/reference_2.png and source/approved-concept.mp4 establish existing actor identity, camera, palette and pixel treatment. They do not establish the new companion wardrobe, mechas or occult designs. Keep those as candidates until compared in the native room.

The user rejected current lasso quality and animation sequencing. Variety cannot substitute for ordered motion. Every admitted cycle must demonstrate contact, lift, travel, landing and a clean loop; every lasso must demonstrate preparation, coherent swing, release and recovery with one release event. Preserve subject proportions, facing, hoof/foot contact and rope continuity. A contact sheet alone is not acceptance evidence. Runtime comparison clips and clear rejection notes are required before calling the room visually complete.

## Milestones and bounded next work

1. **Ongoing: repair and enrich animation.** Resolve lasso, walk and turn sequence defects in the actual engine, including generated whole-pose intermediates. Compare against the approved concept. Rich kits remain candidates where motion fails.
2. **Current playable companion proof.** Eleanor recruitment, cattle-calming adventure, optional mutual flirt, camp perk and madness/recovery now have a first implementation. Improve activity variety and presentation through playtesting; prove save/load and avoid duplicated events. The full Lanterns at the Ford spirit-lantern encounter remains later work, not a claim about this cattle-calming proof.
3. **Later: one generated adult companion and one uncanny/steam encounter.** Prove stable generated identity and perk compatibility. Demonstrate the setting with a bounded encounter before extending travel or adding mecha control.

No milestone here certifies art completion. The latest user instruction authorizes further systems following this design; label each concrete implementation accurately and retain editable proposals for unfinished features.

## Editing and validation

design/companion.schema.json defines the proposed adult companion record. design/characters.json contains three named drafts and one procedural template; it is not a save file. design/decisions.json separates accepted user direction, integration choices, provisional mechanics and unresolved questions. Change this document and those records together when the foundation changes. Validation of their structure does not validate balancing, romance content, generated art or runtime behavior.

### Trail time in the current room

The source now advances saved trail time at a provisional one game minute per real second of active simulation. Day 1 starts at noon on May 12, 1872. Shared rest spends its declared 30 minutes and becomes available after its existing daily cooldown; ordinary play can now expire that cooldown. The HUD shows trail day/time and completed-adventure rest availability. No offline elapsed time is applied. This implements the clock and recovery availability, not world travel, a day/night art set or scheduled NPC behavior.

### Lantern adventure production boundary

Lanterns at the Ford now has initial whole-character source art: Eleanor carrying a brass lantern and four states of the crossing spirit. Its authored progression is being implemented as a separate persisted backend: take the lantern, settle the spirit, guide three distinct cattle and return to the wagon. Pause and recoverable failure return control safely while preserving the checkpoint. Completion uses a stable milestone and cannot issue a duplicate completion reward. The Clear Fork cattle-calming activity remains the current playable adventure; lantern-carry walking, the ford layout and room interactions still need integration. New lantern dialogue is authored event content and is not yet triggered in the room.

Current lantern integration supersedes the earlier backend-only boundary: the source room now starts the lantern encounter through Companion at the wagon after Steady Company completes. A real spectral longhorn appears on the existing dry trail crossing. Three stable existing cattle move across under Eleanor's guidance, with arrival credited from physical positions. Pause returns player control at the wagon; resume and save/load preserve checkpoint and cattle progress. Completion adds 10 trust once, separate from romance. Existing walk clips remain, with a whole generated brass lantern prop belt-mounted during the activity. The four spirit states and one equipment sprite are additional encounter art outside the base room's 330 selected actor-frame count. The full water-ford scenery and polished whole-character carry cycles remain unfinished.

Spirit exposure now has a provisional mechanical consequence: Eleanor gains 6 madness once when approaching the agitated crossing spirit within 80 world pixels (or interacting within reach). The encounter stores this event separately from speech history, so interrupted dialogue, retries and reloads cannot stack the charge. Current lantern save format is version2; older started checkpoints migrate as already exposed without retroactively altering their madness. Existing shared rest remains the recovery route, independent of choosing romance.

Side-comment delivery now keeps at most two pending meaningful lines when the bubble is occupied. Equal priorities retain order; higher priority can replace the oldest lower-priority pending line. Pending room comments expire after six seconds, so stale banter does not accumulate. Low-priority ambient remarks are not queued. A beat enters spoken history only when its bubble actually opens; save restoration clears unspoken pending presentation. This does not pause player movement or advance relationship state.

Ada first-encounter backend: the stalled agricultural walker now has a fictional pressure puzzle. Shut feed, vent to5orbelow, install the recovered regulator, close vent, build pressure into30–50, close feed and test. Overpressure above85faults the machine and shuts feed; venting allows retry without losing the part. Successful testing locks the repaired state. Ada's adult22identity, madness, first meeting, trust and invitation are separate persisted state. Repair must precede an accepted invitation, which grants trust once without romance. Outer saves retain this optional state and accept older saves without it. This backend does not yet place Ada/the walker or activate repair controls in the room, and is distinct from the later Two Seats, One Regulator romance adventure.
