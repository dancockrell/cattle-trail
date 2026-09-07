# Cattle Trail — living game design

Status: accepted creative direction with provisional system proposals. The companion, romance, madness, procedural cast and supernatural systems below are **DESIGN ONLY; not implemented**. The existing playable milestone remains the Clear Fork cattle room. This document is the source of truth for game identity and supersedes any description of Cattle Trail as a purely historical cattle-drive simulation. Asset extraction and animation contracts remain in METHOD.md and the runtime manifests.

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

Keep the current room's movement, herding, lasso and shoot interactions legible before adding this loop. Romance and occult material should enter through a small encounter and a compact camp interaction after animation quality is repaired, not through an expanded map first.

## Separate state contracts

These are proposed runtime boundaries. No file here is loaded by the current game.

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

Retain the responsive current room and its input model. A later compact companion panel should show name, explicit adult age, role, current perk, recruitment/relationship status and madness when known. Keep controls reachable at narrow widths. Do not cover herd movement with unsolicited relationship popups.

Proposed camp flow: select companion → choose a short shared activity or companion adventure → play its distinct challenge → enjoy a brief affectionate beat → apply one event → return to camp. Conversation-only choices are supporting material, not the dominant progression path. Cancelling before confirmation changes no state. Unavailable choices explain why. A declined invitation preserves the relationship and returns control cleanly. Save resolved character identity, recruitment state, relationship events and agreements, role, perk unlocks, madness, recovery cooldowns, adventure completion and the currently controlled actor with a safe return location. Presentation must reconstruct from this state without replaying rewards.

For romantic keyframes, distinguish invitation, mutually accepted affectionate beat and resolved rest. For supernatural beats, distinguish ordinary room, identifiable uncanny intrusion and aftermath. Keep camera, scale, costume, adult identity and environment continuity across each sequence. These are briefs for later frames, not an authorization claim that any existing generated action sequence has passed review.

## Art and animation authority

The approved source/reference_0.png, source/reference_1.png, source/reference_2.png and source/approved-concept.mp4 establish existing actor identity, camera, palette and pixel treatment. They do not establish the new companion wardrobe, mechas or occult designs. Keep those as candidates until compared in the native room.

The user rejected current lasso quality and animation sequencing. Variety cannot substitute for ordered motion. Every admitted cycle must demonstrate contact, lift, travel, landing and a clean loop; every lasso must demonstrate preparation, coherent swing, release and recovery with one release event. Preserve subject proportions, facing, hoof/foot contact and rope continuity. A contact sheet alone is not acceptance evidence. Runtime comparison clips and clear rejection notes are required before calling the room visually complete.

## Milestones and bounded next work

1. **Current: repair the existing room.** Resolve lasso and gait sequence defects in the actual engine; retain movement, herding, Eleanor, rustler, HUD and narrow layout. Compare against the approved concept. Rich kits remain candidates where motion fails.
2. **After that bar is met: one companion proof.** Implement Eleanor recruitment, one short adventure played as Eleanor with a brief mutual romantic beat, one readable perk, and madness/recovery for the player and room NPCs. Demonstrate save/load without duplicated events. Keep one room and a minimal camp interaction.
3. **Later: one generated adult companion and one uncanny/steam encounter.** Prove stable generated identity and perk compatibility. Demonstrate the setting with a bounded encounter before extending travel or adding mecha control.

No milestone here certifies implementation or art completion. The current task may establish date and dialogue continuity while fixing animation; it must not quietly add the future systems.

## Editing and validation

design/companion.schema.json defines the proposed adult companion record. design/characters.json contains three named drafts and one procedural template; it is not a save file. design/decisions.json separates accepted user direction, integration choices, provisional mechanics and unresolved questions. Change this document and those records together when the foundation changes. Validation of their structure does not validate balancing, romance content, generated art or runtime behavior.
