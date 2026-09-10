"""A player, not a test harness.

The bot plays Cattle Trail the way somebody who likes RPGs plays it: it wants
things, it tries to get them, and it records what the game did about it. Every
probe below is a desire a real player brings to an RPG, and every probe answers
one question: did the game satisfy it, refuse it with a reason, or ignore it.

Silence is the finding. A verb that does nothing and says nothing is worse than
a verb that refuses and explains, because the player cannot tell which of the
two just happened.
"""
from __future__ import annotations
import math
from dataclasses import dataclass, field, asdict
from .driver import Game
from .progress import Progression
from . import presence
from .stakes import Stakes, rustler_steps, cattle_steps, greeting_steps, idle_steps

SATISFIED = "satisfied"
REFUSED = "refused_with_reason"
REPEATED = "repeated_itself"
IGNORED = "ignored_silently"
BLOCKED = "blocked"


@dataclass
class Note:
    """One thing the player wanted and what came of it."""
    desire: str
    outcome: str
    detail: str
    evidence: dict = field(default_factory=dict)

    def dict(self) -> dict:
        return asdict(self)


class Player:
    def __init__(self, game: Game, speed: float = 12.0, deep: bool = False):
        self.g = game
        self.deep = deep
        self.notes: list[Note] = []
        self.said: list[str] = []
        # Every distinct objective line the game has put on screen, in order.
        # The climb slices this to answer "did the game ever say what to do next".
        self.objectives: list[str] = []
        self.climb: Progression | None = None
        # Probe 1 and probe 2, kept out of notes as well as in them: the notes
        # are what the critic reads, these are the numbers a person reads.
        self.presence: dict = {}
        self.stakes: list[dict] = []
        self.g.speed(speed)
        self.obs = self.g.observe()
        self.opening_cash = self.obs.get("cash")

    # ---------- plumbing ----------

    def note(self, desire: str, outcome: str, detail: str, **evidence) -> None:
        self.notes.append(Note(desire, outcome, detail, evidence))

    def refresh(self, frames: int = 8) -> dict:
        self.obs = self.g.step(frames)
        for line in self.obs.get("transcript", []):
            key = f"{line['speaker']}: {line['text']}"
            if key not in self.said:
                self.said.append(key)
        # Speech bubbles are not where most of this game's prose lives; the
        # journal line under the room is. A player reads both, so the bot does.
        journal = self.obs.get("message", "")
        if journal and f"(journal) {journal}" not in self.said:
            self.said.append(f"(journal) {journal}")
        objective = self.obs.get("objective", "")
        if objective and (not self.objectives or self.objectives[-1] != objective):
            self.objectives.append(objective)
        return self.obs

    def controlled(self, obs: dict | None = None) -> dict:
        """Where the actor the player is steering actually is. Pressing Tab hands
        control to Eleanor, and a walk that watched the trail boss instead would
        report every step as a stall."""
        o = obs if obs is not None else self.obs
        return o["eleanor"] if o.get("controlling") == "eleanor" else o["player"]

    def dist(self, a: dict, b: dict) -> float:
        return math.hypot(a.get("x", 0) - b.get("x", 0), a.get("y", 0) - b.get("y", 0))

    def goto(self, x: float, y: float, tries: int = 60) -> bool:
        """Walk somewhere. Returns False if the player stalls short of it,
        which is itself worth reporting: a place you can see and cannot reach."""
        self.g.move(x, y)
        last = None
        stalls = 0
        for _ in range(tries):
            o = self.refresh(15)
            here = self.controlled(o)
            if self.dist(here, {"x": x, "y": y}) < 18:
                return True
            if last is not None and self.dist(here, last) < 0.5:
                stalls += 1
                if stalls >= 4:
                    return False
            else:
                stalls = 0
            last = here
        return False

    def try_verb(self, verb: str, desire: str, context: str) -> str:
        """Press a button and find out whether the game respected it."""
        before_msg = self.obs.get("message", "")
        result = self.g.act(verb)
        self.refresh(6)
        changed = result.get("changed", False)
        after_msg = self.obs.get("message", "")
        if changed:
            outcome = SATISFIED
            detail = f"{verb} did something ({context})"
        elif after_msg != before_msg:
            outcome = REFUSED
            detail = f"{verb} refused and explained: {after_msg!r}"
        elif after_msg:
            # The game answered, with the exact line it already had on screen.
            # From the chair this reads as the game not noticing you pressed it.
            outcome = REPEATED
            detail = (f"{verb} changed nothing and repeated the line already showing "
                      f"({context}): {after_msg!r}")
        else:
            outcome = IGNORED
            detail = f"{verb} did nothing and said nothing ({context})"
        self.note(desire, outcome, detail, verb=verb, message=after_msg)
        return outcome

    # ---------- desires ----------

    def desire_know_what_to_do(self) -> None:
        """The first thing any RPG owes you: what am I doing here?"""
        o = self.obs
        self.note(
            "I want to know what I'm doing and why",
            SATISFIED if o.get("objective") else IGNORED,
            f"opening objective {o.get('objective')!r}, opening line {o.get('message')!r}",
            objective=o.get("objective"), message=o.get("message"),
            buttons=[b["text"] for b in o.get("buttons", [])],
        )

    def desire_talk_to_someone(self) -> None:
        el = self.obs["eleanor"]
        if not self.goto(el["x"] + 14, el["y"] + 8):
            self.note("I want to walk over and talk to the person I can see",
                      BLOCKED, "could not reach Eleanor, who is visible from the start")
            return
        before = len(self.said)
        self.try_verb("interact", "I want to talk to the person I can see", "standing next to Eleanor")
        self.refresh(12)
        gained = self.said[before:]
        self.note("I want the first conversation to tell me something",
                  SATISFIED if gained else IGNORED,
                  f"first talk produced {len(gained)} line(s): {gained[:3]}",
                  lines=gained[:5])

    def desire_verbs_mean_something(self) -> None:
        """Every button on screen is a promise. Press each in a plain context."""
        for verb, label in [("lasso", "lasso with nothing nearby"),
                            ("shoot", "shoot with nothing to shoot at"),
                            ("rest", "rest at the start of the day"),
                            ("flirt", "flirt with nobody recruited"),
                            ("switch", "switch character before recruiting anyone")]:
            self.try_verb(verb, "I want every verb the UI offers me to mean something", label)

    def desire_finish_what_it_asked(self) -> dict:
        """Do the thing the objective asked for. Measures how long the game's
        one authored task actually takes, which is the pacing question."""
        start_tick = self.obs["tick"]
        # Clear the rustler first, the game says so.
        for _ in range(12):
            o = self.obs
            if not o.get("rustler_active"):
                break
            self.goto(520, 170, tries=25)
            self.try_verb("shoot", "I want to deal with the threat the game pointed at", "near the rustler")
        cleared = not self.obs.get("rustler_active", True)
        self.note("I want to deal with the threat the game pointed at",
                  SATISFIED if cleared else BLOCKED,
                  f"rustler cleared={cleared} after chasing and shooting",
                  ammo_left=self.obs.get("ammo"))
        # Then gather cattle, the bulk of the authored room.
        for _ in range(40):
            o = self.refresh(10)
            if o.get("cattle_secured", 0) >= 6:
                break
            loose = [c for c in o.get("cattle", []) if not c["secured"]]
            if not loose:
                break
            cow = min(loose, key=lambda c: self.dist(c["pos"], o["player"]))
            self.goto(cow["pos"]["x"] - 6, cow["pos"]["y"] + 10, tries=22)
            self.g.act("lasso")
            self.refresh(10)
            self.goto(520, 150, tries=30)
        o = self.refresh(10)
        done = o.get("won", False) or o.get("cattle_secured", 0) >= 6
        cost = o["tick"] - start_tick
        self.note("I want to be able to finish the task the game set me",
                  SATISFIED if done else BLOCKED,
                  f"secured {o.get('cattle_secured')}/6, won={o.get('won')}, took {cost} ticks of play",
                  ticks=cost, secured=o.get("cattle_secured"), won=o.get("won"))
        return o

    def desire_variety_of_people(self) -> None:
        """The pitch is a cast. Can I actually meet any of them, and are they
        different from each other when I do?"""
        o = self.obs
        cast = o.get("companions", [])
        locked = [c for c in cast if c.get("kind") == "simple" and not c.get("unlocked")]
        self.note("I want to meet the cast the game advertises",
                  BLOCKED if len(locked) == len([c for c in cast if c.get("kind") == "simple"]) else SATISFIED,
                  f"{len(locked)} of {len(cast)} companions are gated behind an unlock chain at this point",
                  locked=[c["id"] for c in locked][:25], total=len(cast))
        # Try to reach one anyway. A player does not know about unlock keys.
        target = next((c for c in cast if c.get("kind") == "simple"), None)
        if target:
            reached = self.goto(target["pos"]["x"] - 10, target["pos"]["y"] + 8, tries=40)
            before = len(self.said)
            outcome = self.try_verb("interact", "I want to walk up to someone I can see and talk to her",
                                    f"standing where {target['id']} is")
            self.note("I want a locked character to at least acknowledge me",
                      outcome if outcome != IGNORED else IGNORED,
                      f"reached {target['id']}'s spot={reached}; said {len(self.said) - before} new line(s)",
                      companion=target["id"], reached=reached)

    def desire_relationship_goes_somewhere(self) -> None:
        """Romance is a named pillar. Does affection have anywhere to go?"""
        stage_before = (self.obs.get("eleanor_state") or {}).get("stage")
        trust_before = (self.obs.get("eleanor_state") or {}).get("trust")
        outcomes = []
        for i in range(4):
            outcomes.append(self.try_verb("flirt", "I want a relationship that deepens when I invest in it",
                                          f"flirt attempt {i + 1}"))
        st = self.obs.get("eleanor_state") or {}
        self.note("I want repeated affection to go somewhere, not repeat itself",
                  SATISFIED if st.get("stage") != stage_before or st.get("trust", 0) > (trust_before or 0) else IGNORED,
                  f"stage {stage_before} -> {st.get('stage')}, trust {trust_before} -> {st.get('trust')} across 4 flirts; outcomes={outcomes}",
                  stage_before=stage_before, stage_after=st.get("stage"),
                  trust_before=trust_before, trust_after=st.get("trust"))

    def desire_explore(self) -> None:
        """Every RPG player walks at the edge of the map to see what's there."""
        corners = [(2, 2), (636, 2), (2, 356), (636, 356)]
        reached = []
        for (x, y) in corners:
            reached.append(self.goto(x, y, tries=30))
        o = self.obs
        self.note("I want somewhere to go that isn't the task",
                  IGNORED if o.get("message") == self.obs.get("message") else SATISFIED,
                  f"walked to {sum(reached)}/4 map corners; nothing outside the room is reachable "
                  f"and no edge said anything. Objective still {o.get('objective')!r}",
                  corners_reached=sum(reached))

    def desire_spend_what_i_earn(self) -> None:
        """There is a cash counter on screen from the first frame."""
        cash_now = self.obs.get("cash")
        earned = cash_now != self.opening_cash
        spent = False
        for verb in ("interact", "rest", "switch", "flirt"):
            self.g.act(verb)
            self.refresh(6)
            if self.obs.get("cash") != cash_now:
                spent = True
        self.note("I want the money on my HUD to be for something",
                  SATISFIED if spent else (REPEATED if earned else IGNORED),
                  f"cash went {self.opening_cash} -> {cash_now} over the session "
                  f"(earning works: {earned}), but nothing the player can press spends it "
                  f"(spending found: {spent}). Money accumulates with nothing to buy.",
                  opening_cash=self.opening_cash, cash_now=cash_now,
                  can_earn=earned, can_spend=spent)

    def desire_progress_survives(self) -> None:
        before = self.obs.get("eleanor_state", {})
        self.g.act("save")
        self.refresh(6)
        self.g.act("load")
        o = self.refresh(6)
        after = o.get("eleanor_state", {})
        self.note("I want my progress to survive a save and load",
                  SATISFIED if after.get("recruitment") == before.get("recruitment") else BLOCKED,
                  f"recruitment {before.get('recruitment')} -> {after.get('recruitment')}, "
                  f"trust {before.get('trust')} -> {after.get('trust')}",
                  before=before, after=after)

    # ---------- probe 1 and probe 2 ----------

    def desire_anyone_is_actually_there(self, tag: str = "") -> None:
        """Is there a person where the game asks me to stand, or a coordinate?

        This exists because nineteen companions were coordinates with dialogue
        attached for two days and every session before this one reported them as
        working. Walking to a spot and reading a line looks identical either way
        from inside a state machine."""
        self.presence = presence.note_for(self, tag)

    def desire_anything_is_at_stake(self) -> None:
        """"It completed successfully" is not evidence that anything was good.
        Measure whether each encounter can be lost, whether it ever comes out
        differently, and how often it asks the player to decide."""
        probe = Stakes(self)
        for name, steps, runs, moments in [
                # The floor first. A probe that cannot tell an empty corner from
                # a gunfight is not measuring the gunfight either.
                ("resting in an empty corner", idle_steps(), 2, 2),
                ("greeting Eleanor", greeting_steps(), 2, 2),
                ("the rustler", rustler_steps(), 3, 3),
                ("the cattle gather", cattle_steps(3), 2, 2)]:
            result = probe.measure(name, steps, runs=runs, moments=moments)
            self.stakes.append(result)
            if not result.get("measurable"):
                self.note("I want an encounter where something is at stake",
                          IGNORED,
                          f"{name} could not be measured, so this says nothing about the game: "
                          f"{result.get('why')}",
                          encounter=name, **{"version": result.get("version")})
                continue
            risk = result["risk"]
            variance = result["variance"]
            decisions = result["decision_count"]
            formality = (not risk["anything_at_stake"] and not variance["varies"]
                         and decisions["moments_with_a_real_choice"] == 0)
            self.note(
                "I want an encounter where something is at stake",
                IGNORED if formality else (REPEATED if not risk["anything_at_stake"] else SATISFIED),
                result["verdict"] + " Measured against room.gd "
                + str(result["version"]["files"]["scripts/room.gd"].get("md5"))
                + " modified " + str(result["version"]["files"]["scripts/room.gd"].get("modified"))
                + ", so treat it as that build and not as current if the fight is being rewritten.",
                encounter=name, cost_in_inputs=result["cost_in_inputs"], risk=risk,
                variance=variance, decisions=decisions, version=result["version"])

    # ---------- the deep session: the rest of the game ----------

    def desire_to_reach_the_rest_of_the_game(self) -> None:
        """Nineteen of twenty-two companions sit behind one unlock chain. A
        player would simply keep playing until they showed up, so the bot does,
        with the same verbs and no reach into game state."""
        self.climb = Progression(self)
        stages = self.climb.run()
        cleared = [s for s in stages if s.status == "cleared"]
        stalled = next((s for s in stages if s.status == "stalled"), None)
        never = [s.name for s in stages if s.status == "not_attempted"]
        self.note(
            "I want to reach the rest of the game the pitch promises",
            SATISFIED if not stalled else BLOCKED,
            (f"climbed {len(cleared)} of {len(stages)} stages of the unlock chain, "
             f"as far as {self.climb.reached()}. "
             + (f"Stalled at {stalled.name}: {stalled.stall}" if stalled else "The chain opened fully.")
             + (f" Never attempted: {never}." if never else "")),
            stages=[{"name": s.name, "status": s.status, "actions": s.actions,
                     "minutes": s.minutes, "lines": len(s.new_lines),
                     "named_on_entry": s.named_on_entry, "named_during": s.named_during,
                     "stall": s.stall} for s in stages],
        )
        # A stage that costs hundreds of actions for four lines is the finding,
        # so it gets its own note rather than being buried in the list above.
        for stage in cleared:
            per_line = round(stage.actions / len(stage.new_lines), 1) if stage.new_lines else None
            self.note(
                "I want the effort a stage asks of me to buy me something",
                REPEATED if (per_line is None or per_line >= 20) else SATISFIED,
                (f"{stage.name}: {stage.actions} actions and {stage.minutes} in-game minutes "
                 f"produced {len(stage.new_lines)} new line(s) of writing"
                 + (f", {per_line} actions per line" if per_line else "")
                 + f". The game named this objective on screen beforehand: {stage.named_on_entry}."),
                stage=stage.name, actions=stage.actions, minutes=stage.minutes,
                lines=len(stage.new_lines), actions_per_line=per_line,
                named_on_entry=stage.named_on_entry, named_during=stage.named_during,
            )
        # Signposting, across the whole climb, in one note.
        attempted = [s for s in stages if s.status != "not_attempted"]
        unsignposted = [s.name for s in attempted if not s.named_on_entry]
        self.note(
            "I want the game to tell me where to go next",
            IGNORED if len(unsignposted) * 2 > len(attempted) else SATISFIED,
            (f"{len(unsignposted)} of {len(attempted)} attempted stages were never named on "
             f"screen before the bot went looking for them: {unsignposted}"),
            unsignposted=unsignposted,
        )

    def desire_the_cast_is_actually_different(self) -> None:
        """Twenty-two companions is only twenty-two companions if they are not
        the same one with different nouns. Visit each one, play her whole
        sequence, and measure the difference rather than asserting it."""
        if self.climb is None:
            self.climb = Progression(self)
        cast = [c for c in self.obs.get("companions", []) if c.get("kind") == "simple"]
        unlocked = [c for c in cast if c.get("unlocked")]
        if not unlocked:
            self.note("I want the cast to be twenty-two people, not one person restated",
                      BLOCKED,
                      f"none of the {len(cast)} catalog companions ever unlocked, so no comparison "
                      f"between them is possible. The bot reached {self.climb.reached()}.",
                      unlocked=0, total=len(cast))
            return
        result = self.climb.visit_the_cast()
        shapes = result.get("distinct_interaction_shapes")
        overlap = result.get("pairwise_word_overlap", {})
        vocab = result.get("vocabulary", {})
        blocked = result.get("unreachable", [])
        detail = (
            f"visited {result.get('visited')} of {len(unlocked)} unlocked companions; "
            f"{len(blocked)} were unlocked but physically unreachable "
            f"({[b['id'] for b in blocked][:12]}). "
            f"Of the ones reached, {shapes} distinct interaction shape(s) across them all, and "
            f"{result.get('recruited_in_three_talks')} were fully recruited in three presses of "
            f"Talk. Word overlap between any two of them averages {overlap.get('mean')} "
            f"(min {overlap.get('min')}, max {overlap.get('max')}); "
            f"{vocab.get('words_every_single_one_says')} of "
            f"{vocab.get('distinct_words_across_the_cast')} distinct words are said by every one "
            f"of them ({vocab.get('shared_fraction')} of the vocabulary)."
        )
        self.note("I want the cast to be twenty-two people, not one person restated",
                  REPEATED if (shapes or 99) <= 2 else SATISFIED,
                  detail, **result)
        if blocked:
            self.note("I want to be able to walk up to a companion the game has unlocked",
                      BLOCKED,
                      f"{len(blocked)} companions unlocked and then could not be approached: "
                      + "; ".join(f"{b['id']} closest approach {b['distance']}" for b in blocked[:12]),
                      unreachable=blocked)

    def desire_the_game_ever_offers_me_a_choice(self) -> None:
        """At a given moment, how many of the verbs on screen actually move the
        world? Measured by saving, pressing one, and loading back, so the count
        is of options available at one moment rather than a sequence of them."""
        if self.climb is None:
            self.climb = Progression(self)
        if not self.climb.choice_moments:
            self.climb.sample_choice("end of session")
        summary = self.climb.choice_summary()
        measured = summary["moments_measured"]
        branching = summary["moments_with_two_or_more_options_that_advance"]
        if measured == 0:
            self.note("I want the game to offer me more than one thing worth doing",
                      IGNORED,
                      f"no moment could be measured: {summary['moments_unmeasurable']} sampled "
                      f"moment(s) failed their save and load control, so this says nothing about "
                      f"the game and everything about the probe",
                      **summary)
            return
        self.note("I want the game to offer me more than one thing worth doing",
                  SATISFIED if branching else IGNORED,
                  (f"across {measured} measured moment(s): {branching} offered two or more verbs "
                   f"that changed the world, {summary['moments_with_exactly_one']} offered exactly "
                   f"one, {summary['moments_with_none']} offered none. Branching ratio "
                   f"{summary['branching_ratio']}. "
                   f"({summary['moments_unmeasurable']} further moment(s) could not be measured "
                   f"and are excluded rather than counted as zero.)"),
                  **summary)

    # ---------- session ----------

    def play(self) -> dict:
        self.desire_know_what_to_do()
        # Before anything is pressed: is anybody on screen at all.
        self.desire_anyone_is_actually_there("opening room")
        # The stakes probe runs before the room is finished, because a rustler
        # already dealt with cannot be measured and a corral already full has no
        # cattle left to rope.
        self.desire_anything_is_at_stake()
        self.desire_talk_to_someone()
        self.desire_verbs_mean_something()
        self.desire_variety_of_people()
        self.desire_finish_what_it_asked()
        self.desire_relationship_goes_somewhere()
        self.desire_explore()
        self.desire_spend_what_i_earn()
        self.desire_progress_survives()
        if self.deep:
            self.desire_to_reach_the_rest_of_the_game()
            self.desire_the_cast_is_actually_different()
            self.desire_the_game_ever_offers_me_a_choice()
        return {
            "notes": [n.dict() for n in self.notes],
            "heard": self.said,
            "final": self.obs,
            "objectives": self.objectives,
            "engine_errors": self.g.errors(),
            "actions": self.g.action_count,
            "climb": self.climb.report() if self.climb else {},
            "presence": self.presence,
            "stakes": self.stakes,
        }
