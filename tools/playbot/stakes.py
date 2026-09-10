"""Probe 2: was anything at stake.

The bot called the rustler fight satisfied. The owner played it and said it was
boring, and both are true statements about different things: the fight completed
successfully, and completing successfully is not evidence that anything was at
stake. "It worked" is what a formality looks like from inside a state machine.

So this measures the four things that separate an encounter from a formality:

* Risk. Can the player lose anything at all? Everything he owns is watched
  across the whole encounter, and a resource that never moves down in any run is
  reported as one he cannot lose. If nothing at all can go down, the encounter
  cannot be failed, only performed.
* Variance. The same encounter is replayed from one save, several times, with
  the same inputs. If the ending is byte-identical every time, there was nothing
  to find out.
* Decisions. At sampled moments, every verb (and every numbered answer) is
  pressed in turn from the same saved instant, and the distinct outcomes are
  counted. A moment where exactly one input advances anything is a corridor.
* Cost. How many inputs the whole thing takes.

Zero risk plus zero variance is the signature of a formality, and the verdict
says so in the owner's words rather than in a score.

Every number here is measured through the same save and load a player has, and
every measurement is preceded by a round trip control: a save that silently
refused would make every verb look like it changed nothing, which is the answer
this probe is looking for. A moment that fails the control is reported as
unmeasurable, never as a moment with no options.
"""
from __future__ import annotations

import hashlib
import os
from datetime import datetime
from pathlib import Path

from .progress import VERBS, hard_state, parse_clock

ROOT = Path(__file__).resolve().parents[2]

# What the player owns, and which direction counts as losing it.
RESOURCES = [
    ("cash", "down", "money"),
    ("ammo", "down", "ammunition"),
    ("cattle_secured", "down", "cattle already safe"),
    ("strain", "up", "strain"),
    ("player_hits", "up", "wounds taken"),
    ("trust", "down", "Eleanor's trust"),
    ("madness", "up", "Eleanor's madness"),
]
# Time is not risk. It passes whether or not anything is at stake, so it is
# reported beside the risk rather than counted as some of it: an encounter that
# only costs minutes is still an encounter nothing can go wrong in.
TIME = ("minutes", "up", "time on the trail")

# Resources whose absence from the observation is itself a finding: a game with
# no such field has no such thing to lose.
LIFE_LIKE = ["health", "hp", "wounds", "strain", "player_hits"]


def snapshot(obs: dict) -> dict:
    state = obs.get("eleanor_state") or {}
    out = {
        "cash": obs.get("cash"),
        "ammo": obs.get("ammo"),
        "cattle_secured": obs.get("cattle_secured"),
        "strain": obs.get("strain"),
        "player_hits": obs.get("player_hits"),
        "minutes": parse_clock(obs),  # reported as cost, never as risk
        "trust": state.get("trust"),
        "madness": state.get("madness"),
    }
    return out


def _delta(before: dict, after: dict) -> dict:
    out = {}
    for key, _, _ in RESOURCES + [TIME]:
        a, b = before.get(key), after.get(key)
        if isinstance(a, (int, float)) and isinstance(b, (int, float)):
            out[key] = round(b - a, 2)
    return out


class Step:
    """One thing a player does with their hands, replayable from a save."""

    def __init__(self, label: str, run, inputs: int = 1):
        self.label = label
        self.run = run
        self.inputs = inputs


def version_stamp() -> dict:
    """Which build these numbers are about. The rustler is being redesigned by
    another agent, so a number without this is a number that will be quietly
    wrong by tomorrow."""
    out = {"measured_at": datetime.now().isoformat(timespec="seconds"), "files": {}}
    for name in ("scripts/room.gd", "scripts/companion_room.gd", "scripts/bot_api.gd"):
        path = ROOT / name
        if not path.exists():
            out["files"][name] = {"present": False}
            continue
        out["files"][name] = {
            "present": True,
            "md5": hashlib.md5(path.read_bytes()).hexdigest()[:12],
            "modified": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
        }
    return out


class Stakes:
    def __init__(self, player):
        self.p = player
        self.g = player.g

    # ---------- plumbing ----------

    def _anchor(self) -> dict:
        """Save, then prove the save round-trips. Without the proof, a refused
        save reads as an encounter where nothing ever changes."""
        here = dict(self.p.controlled())
        self.g.move(here.get("x", 0.0), here.get("y", 0.0))
        # Stop walking and let any rope or shot finish first: room.gd refuses to
        # save mid-action, and a refused save is invisible from the return value.
        self._settle()
        here = dict(self.p.controlled())
        state = hard_state(self.p.obs)
        saved = True
        if os.environ.get("PLAYBOT_BREAK_SAVE") != "1":
            saved = bool(self.g.act("save").get("ok", True))
        self.p.refresh(4)
        self.p.goto(min(max(here.get("x", 0.0) + 90.0, 30.0), 600.0),
                    min(max(here.get("y", 0.0) + 60.0, 80.0), 295.0), tries=18)
        away = self.p.dist(self.p.controlled(), here)
        self.g.act("load")
        self.p.refresh(4)
        back = self.p.dist(self.p.controlled(), here)
        ok = saved and away >= 20.0 and back <= 8.0 and hard_state(self.p.obs) == state
        return {"ok": ok, "saved": saved, "walked_away": round(away, 1),
                "came_back": round(back, 1),
                "state_restored": hard_state(self.p.obs) == state, "at": here}

    def _settle(self, tries: int = 12) -> None:
        """Let an animation finish before reading the world. A lasso still in
        flight lands after the load and moves the state back off the anchor,
        which reads as a save that did not round trip."""
        for _ in range(tries):
            obs = self.p.refresh(6)
            busy = (obs.get("player_busy")
                    or float(obs.get("rope_time", 0.0)) > 0.0
                    or float(obs.get("rope_flight", 0.0)) > 0.0)
            if not busy:
                return

    def _reload(self) -> None:
        self.g.act("load")
        self._settle()

    def _restore(self, anchor_state: str) -> bool:
        """Put the world back on the anchor. Tab is a toggle the save does not
        carry, so a press of it is undone by pressing it again rather than by
        throwing the whole moment away."""
        self._reload()
        if hard_state(self.p.obs) == anchor_state:
            return True
        self.g.act("switch")
        self._reload()
        return hard_state(self.p.obs) == anchor_state

    def _options_here(self) -> list:
        try:
            return list(self.g.options().get("options") or [])
        except Exception:
            return []

    # ---------- the four measurements ----------

    def _one_run(self, steps: list) -> dict:
        before = snapshot(self.p.obs)
        worst = dict(before)
        journal: list = []
        # Counted by the driver rather than declared by the step, so a fight
        # that takes more shots on a bad run reads as costing more.
        opening_actions = self.g.action_count
        for step in steps:
            step.run(self.p)
            self.p.refresh(6)
            line = str(self.p.obs.get("message", ""))
            if line and (not journal or journal[-1] != line):
                journal.append(line)
            now = snapshot(self.p.obs)
            # The low-water mark matters as much as the ending: a fight you can
            # be hurt in and then heal from still had something at stake.
            for key, direction, _ in RESOURCES + [TIME]:
                a, b = worst.get(key), now.get(key)
                if isinstance(a, (int, float)) and isinstance(b, (int, float)):
                    worst[key] = min(a, b) if direction == "down" else max(a, b)
        after = snapshot(self.p.obs)
        return {
            "inputs": self.g.action_count - opening_actions,
            "before": before,
            "after": after,
            "net": _delta(before, after),
            "worst": _delta(before, worst),
            "journal": journal,
            "ending": hard_state(self.p.obs),
        }

    def _decisions(self, steps: list, moments: int = 4) -> dict:
        """At sampled instants inside the encounter, press everything available
        from the same saved moment and count the distinct outcomes."""
        if not steps:
            return {"measured": [], "unmeasurable": []}
        picks = sorted({round(i * (len(steps) - 1) / max(1, moments - 1))
                        for i in range(min(moments, len(steps)))})
        measured, unmeasurable = [], []
        self._reload()
        for index, step in enumerate(steps):
            if index in picks:
                moment = self._sweep(f"before step {index + 1}: {step.label}")
                (measured if moment.get("measurable") else unmeasurable).append(moment)
            step.run(self.p)
            self.p.refresh(6)
        return {"measured": measured, "unmeasurable": unmeasurable, "sampled_at": picks}

    def _sweep(self, label: str) -> dict:
        control = self._anchor()
        if not control["ok"]:
            return {"where": label, "measurable": False,
                    "why": ("the game refused to save at this instant"
                            if not control.get("saved") else
                            "save and load did not round trip here (walked {} away, came back {}, "
                            "state restored {})".format(control["walked_away"],
                                                        control["came_back"],
                                                        control["state_restored"]))
                           + ", so counting options here would measure the probe"}
        anchor_state = hard_state(self.p.obs)
        anchor_journal = str(self.p.obs.get("message", ""))
        outcomes: dict = {}
        moved, spoke, silent, unrestored = [], [], [], []
        presses = [("act", verb) for verb in VERBS]
        presses += [("choose", option) for option in self._options_here()]
        for kind, name in presses:
            result = self.g.act(name) if kind == "act" else self.g.choose(name)
            self.p.refresh(2)
            after = hard_state(self.p.obs)
            said = str(result.get("message", ""))
            if after != anchor_state:
                moved.append(name)
                outcomes.setdefault(after, []).append(name)
            elif said != anchor_journal:
                spoke.append(name)
            else:
                silent.append(name)
            if not self._restore(anchor_state):
                unrestored.append(name)
        if unrestored:
            return {"where": label, "measurable": False,
                    "why": "the world did not come back after pressing {}".format(unrestored)}
        return {
            "where": label,
            "measurable": True,
            "moved_the_world": moved,
            "only_answered_with_a_line": spoke,
            "did_nothing_at_all": silent,
            # Two buttons wired to one outcome are one option, not two.
            "distinct_outcomes": list(outcomes.values()),
            "options_that_change_the_outcome": len(outcomes),
        }

    # ---------- the whole encounter ----------

    def measure(self, name: str, steps: list, runs: int = 3, moments: int = 4) -> dict:
        result: dict = {"encounter": name, "version": version_stamp(),
                        "runs_requested": runs, "steps": [s.label for s in steps]}
        control = self._anchor()
        result["anchor_control"] = control
        if not control["ok"]:
            result["measurable"] = False
            result["why"] = (
                "the encounter could not be anchored: save and load did not round trip (walked {} "
                "units away, came back {} from the save point, hard state restored {}). Nothing "
                "below would be a measurement of the game."
                .format(control["walked_away"], control["came_back"], control["state_restored"]))
            return result
        plays = []
        for _ in range(runs):
            self._reload()
            plays.append(self._one_run(steps))
        result["measurable"] = True
        result["plays"] = plays
        result["runs_completed"] = len(plays)
        # The script's own denominator. If nothing moved in any direction and
        # nothing was said, the steps probably never reached the encounter, and
        # "nothing is at stake" would be a fact about the bot's hands.
        touched = any(v for play in plays for k, v in play["net"].items() if k != TIME[0])
        spoke = any(play["journal"] for play in plays)
        result["encounter_actually_happened"] = bool(touched or spoke)

        # Risk.
        losable, unmovable, unreadable = [], [], []
        for key, direction, label in RESOURCES:
            values = [play["worst"].get(key) for play in plays if key in play["worst"]]
            if not values:
                # Three states, never two: a resource the probe could not read a
                # number for is not a resource the game does not have.
                unreadable.append(label)
                continue
            moved = [v for v in values if (v < 0 if direction == "down" else v > 0)]
            if moved:
                losable.append({"resource": label, "field": key,
                                "worst": min(moved) if direction == "down" else max(moved)})
            else:
                unmovable.append(label)
        times = [play["net"].get(TIME[0]) for play in plays if TIME[0] in play["net"]]
        current = snapshot(self.p.obs)
        no_life = [k for k in LIFE_LIKE if current.get(k) is None]
        result["risk"] = {
            "losable": losable,
            "never_went_down": unmovable,
            "could_not_be_read_as_a_number": unreadable,
            "no_such_resource_as": no_life,
            "time_spent_minutes": max(times) if times else None,
            "anything_at_stake": bool(losable),
        }

        # Variance.
        endings = {play["ending"] for play in plays}
        journals = {tuple(play["journal"]) for play in plays}
        # Minutes are excluded: the clock advances slightly differently every
        # run and would report every encounter as varying, which is the answer
        # this is trying to detect.
        nets = {tuple(sorted((k, v) for k, v in play["net"].items() if k != TIME[0]))
                for play in plays}
        result["variance"] = {
            "distinct_endings": len(endings),
            "distinct_journals": len(journals),
            "distinct_resource_outcomes": len(nets),
            "varies": len(endings) > 1 or len(journals) > 1 or len(nets) > 1,
        }

        # Decisions and cost.
        self._reload()
        result["decisions"] = self._decisions(steps, moments=moments)
        measured = result["decisions"]["measured"]
        branching = [m for m in measured if m["options_that_change_the_outcome"] >= 2]
        corridor = [m for m in measured if m["options_that_change_the_outcome"] == 1]
        dead = [m for m in measured if m["options_that_change_the_outcome"] == 0]
        # Two sampled instants either side of one surrender are one decision,
        # not two. Counting moments alone would flatter any encounter whose
        # single choice happens to sit still for a while.
        signatures = {tuple(sorted(tuple(sorted(group)) for group in m["distinct_outcomes"]))
                      for m in branching}
        result["decision_count"] = {
            "distinct_decisions": len(signatures),
            "moments_measured": len(measured),
            "moments_unmeasurable": len(result["decisions"]["unmeasurable"]),
            "moments_with_a_real_choice": len(branching),
            "moments_with_exactly_one_input_that_advances": len(corridor),
            "moments_with_none": len(dead),
            "where_the_choices_are": [
                "{} ({})".format(m["where"],
                                 " or ".join("/".join(g) for g in m["distinct_outcomes"]))
                for m in branching],
        }
        costs = [play["inputs"] for play in plays]
        result["cost_in_inputs"] = min(costs) if costs else 0
        result["cost_range"] = [min(costs), max(costs)] if costs else [0, 0]
        result["verdict"] = self.verdict(name, result)
        return result

    @staticmethod
    def verdict(name: str, r: dict) -> str:
        if not r.get("measurable"):
            return "{}: not measured. {}".format(name, r.get("why", ""))
        risk = r["risk"]
        if risk["losable"]:
            lost = ", ".join("{} ({:+g} at worst)".format(item["resource"], item["worst"])
                             for item in risk["losable"])
            risk_words = "the player can lose " + lost
        else:
            risk_words = "nothing the player owns can go down"
        if risk.get("time_spent_minutes"):
            risk_words += " (it costs {:g} minutes of trail time, which passes either way)".format(
                risk["time_spent_minutes"])
        var = r["variance"]
        var_words = ("the outcome varies between runs ({} distinct endings, {} distinct set(s) of "
                     "journal lines and {} distinct sets of resource outcomes over {} runs of the "
                     "same inputs)".format(
                         var["distinct_endings"], var["distinct_journals"],
                         var["distinct_resource_outcomes"], r["runs_completed"])
                     if var["varies"] else
                     "the outcome never varies over {} identical runs".format(r["runs_completed"]))
        d = r["decision_count"]
        if d["moments_measured"] == 0:
            dec_words = "no moment could be measured, so the decision count says nothing"
        elif d["moments_with_a_real_choice"] == 0:
            dec_words = ("there are 0 decisions: at every one of the {} moments measured, at most "
                         "one input advanced anything".format(d["moments_measured"]))
        else:
            count = d.get("distinct_decisions", d["moments_with_a_real_choice"])
            dec_words = "there {} {} decision{}, at {}".format(
                "is" if count == 1 else "are", count, "" if count == 1 else "s",
                "; ".join(d["where_the_choices_are"]))
        if not r.get("encounter_actually_happened", True):
            return ("{}: NOT CHECKED. Nothing in the world moved and nothing was said across {} "
                    "runs, so the bot's hands probably never reached this encounter. Calling it a "
                    "formality would be a claim about the probe.".format(name, r["runs_completed"]))
        formality = (not risk["anything_at_stake"]) and (not var["varies"]) and \
                    d["moments_with_a_real_choice"] == 0
        tail = (" That is a formality, not an encounter."
                if formality else
                (" It is thin, but it is not empty."
                 if not risk["anything_at_stake"] or not var["varies"] else ""))
        span = r.get("cost_range") or [r["cost_in_inputs"], r["cost_in_inputs"]]
        cost_words = ("{} inputs".format(span[0]) if span[0] == span[1]
                      else "{} to {} inputs".format(span[0], span[1]))
        return "{} costs {}, {}, {}, and {}.{}".format(
            name, cost_words, risk_words, var_words, dec_words, tail)


# ---------- the encounters ----------

def _go(x: float, y: float, label: str) -> Step:
    return Step(label, lambda p: p.goto(x, y, tries=30))


def _press(verb: str, label: str = "") -> Step:
    return Step(label or "press {}".format(verb), lambda p: p.g.act(verb))


def _settle(seconds_of_frames: int, label: str) -> Step:
    return Step(label, lambda p: p.refresh(seconds_of_frames), inputs=0)


def rustler_steps() -> list:
    """Ride at the man the game points you at, shoot him down, and say what
    happens to him."""
    def down(obs: dict) -> bool:
        return bool(obs.get("rustler_surrendered")) or not obs.get("rustler_active", True)

    def open_fire(p):
        """Shoot until he quits or the pistol is empty, then rope him. He shoots
        back and misses are real, so a fixed number of presses would measure the
        script rather than the fight."""
        for _ in range(8):
            if down(p.obs):
                return
            p.g.act("shoot" if int(p.obs.get("ammo", 0)) > 0 else "lasso")
            for _ in range(6):
                p.refresh(10)
                if down(p.obs):
                    return

    def decide(p):
        options = p.g.options().get("options") or []
        if options:
            p.g.choose(options[0])

    return [
        _go(500.0, 175.0, "ride within range of the rustler"),
        Step("fight him until he quits", open_fire, inputs=2),
        _settle(30, "let him put his hands up"),
        Step("say what happens to him", decide),
    ]


def cattle_steps(head: int = 3) -> list:
    """Rope strays and push them into the east gathering. The bulk of the
    authored room, measured on the first few head so a session stays quick."""
    steps: list = []

    def rope_nearest(p):
        obs = p.obs
        loose = [c for c in obs.get("cattle", []) if not c["secured"]]
        if not loose:
            return
        cow = min(loose, key=lambda c: p.dist(c["pos"], p.controlled()))
        p.goto(cow["pos"]["x"] - 6, cow["pos"]["y"] + 10, tries=22)
        p.g.act("lasso")

    for index in range(head):
        steps.append(Step("rope stray {}".format(index + 1), rope_nearest, inputs=2))
        steps.append(_go(537.0, 187.0, "push it into the east gathering"))
    return steps


def idle_steps() -> list:
    """The floor. Ride into an empty corner and press Rest twice. Nothing can be
    lost, nothing varies and nothing is decided, so if the probe cannot call this
    a formality it cannot call anything one, and its verdict on the encounters
    that matter is worth nothing either.
    """
    return [
        _go(60.0, 290.0, "ride into an empty corner"),
        _press("rest", "press Rest with nothing to rest from"),
        _press("rest", "press Rest again"),
    ]


def greeting_steps() -> list:
    """The control. Walking to Eleanor and pressing Talk is a formality by
    design, and a probe that cannot tell it apart from a gunfight is telling
    you nothing."""
    return [
        Step("ride to Eleanor", lambda p: p.goto(p.obs["eleanor"]["x"] + 14,
                                                 p.obs["eleanor"]["y"] + 8, tries=30)),
        _press("interact", "press Talk"),
    ]
