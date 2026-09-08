# Cattle Trail — plan for ~1000 composed pages

Authority: `GAME-DESIGN.md` owns systems. `design/LORE.md` owns world voice. This file owns production order, page budgets and the test for whether a page is lore or sludge.

A page here means a manuscript page of finished prose, about 300 words, that could be read aloud without smelling like notes. One thousand pages is about 300,000 words. That is three short novels, or sixty to eighty chapters at house length (3,500–5,500 words). It is not a wiki, not a pantheon, and not a thousand flavor blurbs.

If a stretch could be deleted without anyone in the outfit losing a job, a grudge, a crossing, or a name they use, it does not count toward the thousand.

## What these pages are for

They are the deep well the game drinks from.

After a chapter exists, harvest from it:

- two or three speech-bubble lines that already happened in a mouth
- one journal crumb
- one encounter brief that still has a readable objective
- nothing that needs a new room until a room is actually built

Do not write the harvest first. That is how fifty-one cards become one skeleton. Write the scene. Cut the index card out of it later.

## Laws carried in from work that already failed at scale

These are Cattle Trail rules now. They come from the WW2 corpus and from house prose.

- Magical realism: the marvelous is reported like weather. Nobody stops to be astonished that a ford spoke.
- A story is a person wanting something against another person, a machine, a herd, or the river. If you delete every ledger, brand book, report and sermon and nothing remains, you have not written one yet.
- Decide rank, age, sex, date, kin and whether a surname is shared. Language will fill the unmarked case and be wrong. Rosa Vale and Ines Vale stay two women until a page decides they are not.
- A device used once is a choice. Used across a hundred pages it is the formula. Ban, after three uses, any ending that is only “the count did not match” or “the witness could not say.”
- No chosen-one hiring. No historical lecture. No town that exists to sell hats.
- Systems stay in `GAME-DESIGN.md`. These pages may show a regulator fail. They may not invent a new perk.

## The composition unit

Write in house lengths, not in encyclopedia entries.

| Unit | Words | Job |
|---|---|---|
| Witness page | 500–750 | Open on a job already running. One body discomfort. One fact that does not pay off here. |
| Played scene | 750–1,350 | What the game can later stage. One objective. |
| Print scene | 1,200–2,250 | Same room, more work before the turn. This is the default lore page-block. |
| Chapter | 3,500–5,500 | Two to four scenes. One lead turn. Remainder left on the wagon. |
| Sequence | 2–3 chapters | One job, one night, or one stretch of creek. |

Default output for a writing day: one print scene, or a chapter if the room is already hot.

Each finished scene carries a header the index can parse:

```
# <title>
volume: <I–VII>
place: wagon | gathering | crossing | cart | clue | timber | offstage
hour: <date or trail time>
people: <named, adult ages already decided>
objective: <one readable job>
remainder: <object or unfinished count>
game_use: bubble | journal | adventure | camp | none-yet
canon: locked | provisional | witness-only
```

`witness-only` means the speaker can be wrong. That is how gods stay disputed without a chart.

## Seven volumes (page budgets)

Budgets are targets, not permissions to pad.

### I. The Working Year at Clear Fork — 250 pages

May 12 through first frost, lived from the wagon. This is the spine the current room already implies.

Write it as sequences, not a diary of dates:

- the gather (rustler, six head, east count)
- lanterns at the remembered ford
- the stalled walker and the two-seat cart
- nights the count is right and still nobody sleeps
- a week of ordinary grass, so the uncanny does not happen every page

About 12–16 chapters. Eleanor is present from page one. Ada arrives when the machine does. Rosa is not owed a chapter because a quota is open.

### II. Household Books — 200 pages

One book per named bond, written as work first.

- Eleanor: 70 pages. Competence, a scare, rest that is not rent. Courting only after shared jobs.
- Ada: 60 pages. Brass, teasing after a ride that worked, the first time a machine speaks.
- Rosa: 50 pages. Testimony that can be false. A crossing that agrees with itself once.
- Ines: 20 pages of presence, not recruitment. She points. If kinship with Rosa is real, it is an authored remainder in this book, decided on purpose.

Player interior stays thin. He is seen in what he ropes, skips, and puts off. Do not give him a secret bloodline to fill pages.

### III. The Country That Talks — 150 pages

Places earn pages by being walked. Labels in `LORE.md` stay labels until a scene has leftover mud from them.

Order:

1. wagon and east gathering (already implied — deepen, do not replace)
2. dry crossing in more than one hour
3. cart stop and walker shed
4. clue stretch
5. timber line at weather
6. one other outfit on the same grass
7. Fort Griffin as rumor that finally costs a ride, only when a remainder forces the road

Do not open a street map of Griffin to chase the count.

### IV. Machines and Hands — 100 pages

Steam as agricultural and trail-grade. Stories about a part that has a correct order. Ada can lead; she does not have to own every page.

Allowed: a walker that will not rise, a cart that steers, a regulator that was sold twice, a mecha later only if it has a rancher’s job.

Forbidden: a manual, a parts catalog, a cute ghost in the boiler used for charm.

### V. Local Dead — 150 pages

Particular spirits with jobs. Crossing, herd, well, branded calf, a lantern that is honest when the bank is not.

Eleanor treats distress as medical. Rosa treats speech as evidence. Ines reads sign. The player decides whether this one is lying today.

Cap any single spirit at two print scenes unless the second scene changes the job.

### VI. Disputed Powers — 80 pages

Keep this the shortest on purpose. A long god book becomes a pantheon.

Write bundles of witnesses who do not agree:

- the thing that walks the river at flood
- the brand that will not stay
- the sermon that arrives in a machine
- the moon’s wrong reflection

No legal names on the HUD. No origin chapter. If two bundles would reconcile neatly, throw one away.

### VII. Other Outfits, Other Women — 70 pages

Seed stories for generated companions. Each is a person with a job, a perk-shaped skill, and a short adventure remainder. Persist identity. Do not reroll a saved woman in prose either.

Ten to fourteen people, five to seven pages each, not seventy templates.

## Order of composition

Do not start seven volumes at once.

**Pass A — lock the index (not pages).** A one-page ledger of decided facts: ages, who is recruited, which places exist, which rumors are not quests. Most of this is already in `characters.json` and `LORE.md`. Copy decisions. Do not invent.

**Pass B — 80 pages on the implemented spine.** The gather, Eleanor’s three cattle, the lantern crossing, Ada’s valves and cart, camp rest as household. This is the only pass that must match the current room beat for beat. Canon: locked where the room already happens; provisional where the room still uses dry trail for a ford.

**Pass C — Eleanor book to the scare and the laugh.** Stop before a vow speech.

**Pass D — Ada book through the talking machine.** One scene only for the voice in the brass.

**Pass E — crossing hour book (Country + Local Dead overlapping).** Same ford in daylight, dusk, and a lie.

**Pass F — Rosa’s first sequence.** Only after the ford has been written without her, so she does not become the explanation for the country.

**Pass G — other outfit and two generated women.** Test that Volume VII does not clone Eleanor.

**Pass H — disputed powers as leftovers.** Build this from contradictions already on the table. Do not outline gods first.

**Pass I — fill the working year.** Ordinary weeks. Hunger, wet, pay too small, a count that is merely correct.

**Pass J — Griffin only if a remainder has already forced the ride.**

Revisit harvest after each pass: bubbles, journal, adventure briefs. Never as a substitute for the pass.

## Cadence that can actually finish

House prose does not survive a thousand-page sprint.

A serious rate for pages that pass a blind test is 4–8 finished pages a day when the room is hot, less when inventing a new place. At 6 pages a day, 1,000 pages is about 170 writing days. Calendar time with animation work in parallel is closer to six to nine months, not a weekend corpus.

Suggested week:

- 4 writing days: one print scene each, or two witness pages
- 1 harvest day: pull bubbles and briefs from what already exists; no new lore
- 1 audit day: read three newest endings next to three older ones. If the shape matches, rewrite the new ending before adding pages

Agents may draft. They do not lock canon. A page is locked only after a read-aloud pass and a check against `LORE.md` plus `GAME-DESIGN.md`.

## Tests before a page joins the count

Read it aloud. Then ask:

1. Could a stranger think this was mid-book and not a model?
2. Is a job still running?
3. Did anyone decide the facts that appear (age, kin, date, whether the spirit is lying)?
4. If every document and brand book vanished, would the scene still happen?
5. Does the last paragraph explain the theme? Cut it.
6. Has this ending already been used?
7. Can the game take one sentence from it without a new system?

Fail any one and the page is draft, not corpus.

## File layout when writing starts

Keep it in `cattle-trail`, not a second universe repo, until the corpus is large enough to fight the game for ownership.

```
design/LORE.md                 world voice (short)
design/LORE-PLAN.md            this plan
lore/INDEX.md                  decided facts only
lore/vol-01-working-year/
lore/vol-02-household/
lore/vol-03-country/
lore/vol-04-machines/
lore/vol-05-local-dead/
lore/vol-06-disputed/
lore/vol-07-others/
lore/harvest/bubbles.md        extracted after prose
lore/harvest/adventures.md
lore/harvest/journal.md
```

One chapter per file. Filenames carry date or sequence, not vibe titles.

## What does not count toward 1000

- design contracts, perk tables, art briefs
- repeated rumor lists
- a map key
- dialogue trees written as trees
- pages that only recap the previous chapter
- any scene whose turn is “they realized they cared”

Those can exist as tools. They are not the book.

## First pages to write (Pass B, in order)

1. Wagon tailgate, morning of May 12, herd not in. Eleanor already working. 1 print scene.
2. Rustler on the same grass. He wants a calf and maybe a whisper. 1 print scene.
3. East gathering when the count finally sits. Remainder: a lantern that has not been lit. 1 print scene.
4. Eleanor walking three cattle as herself. 1 print scene.
5. Dry crossing, frightened spirit, three stranded head. 1–2 print scenes.
6. Ada and the regulator. Valves in the correct order. 1 print scene.
7. Two seats, lanterns in order, optional kiss left as a door, not a trophy. 1 print scene.
8. Shared rest that lowers strain and does not collect a vow. 1 print scene.

That is roughly 25–35 pages. After those exist, the thousand has a grain. Everything else grows from remainders those scenes leave on the wagon.
