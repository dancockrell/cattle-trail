"""Climbing the unlock chain with a player's hands only.

The bulk of Cattle Trail's cast sits behind one long chain: finish the opening
room, recruit Eleanor, play her adventure, carry the lantern to the ford, repair
Ada's walker, drive her cart, walk Ines's clue trail, then meet Birdie. Only
Birdie's recruitment opens the other nineteen.

Everything here drives that chain through the same seven verbs a player has
(move, interact, lasso, shoot, switch, rest, flirt) and the same text a player
reads on screen. Nothing reaches into game state to force a gate, because "can a
player actually get here" is the whole question. When a stage will not advance,
the climb stops and records where and why, and the stages after it are marked
never attempted rather than failed.

Three measurements come out of it:

* the cost of each stage, in player actions, in-game minutes and lines of
  dialogue, plus whether the game ever named the next step on screen;
* how different the nineteen actually are from each other once they open;
* how often a moment offers more than one option that does anything.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field, asdict

# The room's own bounds, from scripts/room.gd limit_position().
LOW = (24.0, 71.0)
HIGH = (616.0, 303.0)

WAGON = (148.0, 127.0)
CROSSING = (400.0, 220.0)
FORD_EXIT = (500.0, 220.0)
ADA = (230.0, 145.0)
WALKER = (280.0, 165.0)
CART_PARK = (220.0, 280.0)
CART_STOPS = [(330.0, 300.0), (445.0, 300.0), (405.0, 235.0)]
INES = (405.0, 105.0)
INES_CLUES = [(445.0, 285.0), (340.0, 90.0), (580.0, 285.0)]
BIRDIE = (110.0, 180.0)

# Every verb the UI offers. Used by the choice probe.
VERBS = ["interact", "lasso", "shoot", "switch", "rest", "flirt"]

# Fields of an observation that describe the player's standing in the world,
# as opposed to the journal line, the clock, or a position that drifts a pixel
# while frames run. A verb that moves one of these did something.
HARD_STATE = ["won", "cash", "ammo", "cattle_secured", "rustler_active",
              "talked", "controlling", "eleanor_state", "companions"]


def parse_clock(obs: dict) -> float | None:
    """In-game minutes since the trail began, from the clock a player can read."""
    match = re.match(r"Day (\d+) (\d+):(\d+)", str(obs.get("clock", "")))
    if not match:
        return None
    return (int(match.group(1)) - 1) * 1440.0 + int(match.group(2)) * 60.0 + int(match.group(3))


def hard_state(obs: dict) -> str:
    return repr([obs.get(key) for key in HARD_STATE])


@dataclass
class StageRecord:
    """What one rung of the chain cost, and whether the game pointed at it."""
    name: str
    goal: str
    status: str = "not_attempted"   # cleared | stalled | not_attempted
    stall: str = ""
    actions: int = 0
    minutes: float = 0.0
    new_lines: list = field(default_factory=list)
    objectives: list = field(default_factory=list)
    named_on_entry: bool = False    # the game pointed here before the bot went
    named_during: bool = False      # the game named it at any point in the stage
    already_done_on_entry: bool = False  # the quick session had already cleared it

    def dict(self) -> dict:
        return asdict(self)


class Progression:
    """Drives the unlock chain and measures the climb."""

    def __init__(self, player):
        self.p = player
        self.g = player.g
        self.stages: list[StageRecord] = []
        self.choice_moments: list[dict] = []
        self.cast: list[dict] = []
        self.entry_text = ""

    # ---------- plumbing ----------

    def act(self, verb: str) -> dict:
        return self.g.act(verb)

    def obs(self) -> dict:
        return self.p.obs

    def approach(self, x: float, y: float, tries: int = 45) -> bool:
        """Walk somewhere, then try two sidesteps if scenery is in the way.
        A player who cannot get somewhere tries again from another angle."""
        x = min(max(x, LOW[0]), HIGH[0])
        y = min(max(y, LOW[1]), HIGH[1])
        if self.p.goto(x, y, tries=tries):
            return True
        for dx, dy in ((0.0, 26.0), (26.0, 0.0), (-26.0, -26.0)):
            via_x = min(max(x + dx, LOW[0]), HIGH[0])
            via_y = min(max(y + dy, LOW[1]), HIGH[1])
            self.p.goto(via_x, via_y, tries=20)
            if self.p.goto(x, y, tries=25):
                return True
        return False

    def near_enough(self, x: float, y: float, radius: float) -> bool:
        here = self.p.controlled()
        return self.p.dist(here, {"x": x, "y": y}) <= radius

    def journal(self) -> str:
        return str(self.obs().get("message", ""))

    def objective(self) -> str:
        return str(self.obs().get("objective", ""))

    def wait_for(self, test, chunks: int = 40, frames: int = 8) -> bool:
        """Let the world run until something a player can see becomes true."""
        for _ in range(chunks):
            if test(self.obs()):
                return True
            self.p.refresh(frames)
        return test(self.obs())

    def eleanor_state(self) -> dict:
        return self.obs().get("eleanor_state") or {}

    def companion(self, cid: str) -> dict:
        for entry in self.obs().get("companions", []):
            if entry.get("id") == cid:
                return entry
        return {}

    def button_label(self) -> str:
        """What the first action button currently says. It is the only place the
        game advertises what the next press will do."""
        buttons = self.obs().get("buttons") or []
        return str(buttons[0]["text"]) if buttons else ""

    def simple_cast(self) -> list:
        return [c for c in self.obs().get("companions", []) if c.get("kind") == "simple"]

    # ---------- the climb ----------

    def run(self) -> list[StageRecord]:
        specs = [
            ("open_the_room", "clear the rustler and gather six cattle",
             ["rustler", "cattle", "gather", "herd"], self._open_the_room),
            ("recruit_eleanor", "invite Eleanor into the outfit",
             ["eleanor", "invite", "outfit"], self._recruit_eleanor),
            ("eleanor_adventure", "play Eleanor and steady three cattle",
             ["eleanor", "stead", "companion"], self._eleanor_adventure),
            ("lantern_crossing", "carry the lantern and guide three cattle across",
             ["lantern", "ford", "crossing", "spirit"], self._lantern_crossing),
            ("ada_repair", "meet Ada and repair the steam walker",
             ["ada", "walker", "regulator", "mechanic"], self._ada_repair),
            ("ada_cart", "drive Ada's cart to three lanterns and home",
             ["cart", "board", "seats", "regulator"], self._ada_cart),
            ("ines_trail", "meet Ines and read three spirit clues",
             ["ines", "clue", "trail", "spirit"], self._ines_trail),
            ("birdie", "meet Birdie, hear her sing, invite her",
             ["birdie", "sing", "cook"], self._birdie),
            ("the_nineteen_unlock", "the other nineteen become reachable",
             ["delphine", "cleo", "prisca", "winnie", "louisa"], self._the_nineteen),
        ]
        self.entry_text = self.objective() + " " + self.journal()
        stopped = False
        for name, goal, words, runner in specs:
            record = StageRecord(name=name, goal=goal)
            self.stages.append(record)
            if stopped:
                continue
            entry = self.entry_text.lower()
            record.named_on_entry = any(word in entry for word in words)
            start_actions = self.g.action_count
            start_minutes = parse_clock(self.obs())
            start_lines = len(self.p.said)
            start_objectives = len(self.p.objectives)
            record.already_done_on_entry = self._already_done(name)
            try:
                record.stall = runner()
            except Exception as exc:   # a stalled climb is a report, never a crash
                record.stall = f"the bot fell over trying this stage: {exc!r}"
            end_minutes = parse_clock(self.obs())
            record.actions = self.g.action_count - start_actions
            if start_minutes is not None and end_minutes is not None:
                record.minutes = round(end_minutes - start_minutes, 1)
            record.new_lines = self.p.said[start_lines:]
            record.objectives = self.p.objectives[start_objectives:]
            seen = " ".join(record.objectives + record.new_lines).lower()
            record.named_during = any(word in seen for word in words)
            record.status = "cleared" if not record.stall else "stalled"
            self.entry_text = self.objective() + " " + self.journal()
            self.sample_choice(f"after {name}")
            if record.stall:
                stopped = True
        return self.stages

    def _already_done(self, name: str) -> bool:
        """True when the earlier part of the session already finished this rung,
        so a cost of zero here means "not paid again", not "free"."""
        state = self.eleanor_state()
        checks = {
            "open_the_room": lambda: bool(self.obs().get("won")),
            "recruit_eleanor": lambda: state.get("recruitment") == "recruited",
            "eleanor_adventure": lambda: state.get("adventure") == "completed",
            "lantern_crossing": self._lantern_done,
            "ada_repair": lambda: self.companion("ada_mercer").get("recruitment") == "recruited",
            "ada_cart": self._cart_done,
            "ines_trail": lambda: self.companion("ines_vale").get("recruitment") == "recruited",
            "birdie": lambda: self.companion("birdie_calloway").get("recruitment") == "recruited",
        }
        test = checks.get(name)
        return bool(test and test())

    def reached(self) -> str:
        cleared = [s.name for s in self.stages if s.status == "cleared"]
        return cleared[-1] if cleared else "nothing"

    # ---------- stages ----------

    def _open_the_room(self) -> str:
        if self.obs().get("won"):
            return ""
        for _ in range(14):
            if not self.obs().get("rustler_active"):
                break
            self.approach(520, 170, tries=25)
            self.act("shoot")
            self.p.refresh(6)
        if self.obs().get("rustler_active"):
            return "the rustler never cleared, so cattle can never be secured"
        for _ in range(45):
            o = self.p.refresh(10)
            if o.get("won") or o.get("cattle_secured", 0) >= 6:
                break
            loose = [c for c in o.get("cattle", []) if not c["secured"]]
            if not loose:
                break
            cow = min(loose, key=lambda c: self.p.dist(c["pos"], self.p.controlled(o)))
            self.approach(cow["pos"]["x"] - 6, cow["pos"]["y"] + 10, tries=22)
            self.act("lasso")
            self.p.refresh(10)
            self.approach(520, 150, tries=30)
        o = self.p.refresh(8)
        if not o.get("won"):
            return f"secured only {o.get('cattle_secured')} of 6 cattle; the room never completed"
        return ""

    def _recruit_eleanor(self) -> str:
        if self.eleanor_state().get("recruitment") == "recruited":
            return ""
        el = self.obs()["eleanor"]
        if not self.approach(el["x"] + 14, el["y"] + 8):
            return "could not walk back to Eleanor after the herd was safe"
        for _ in range(4):
            self.act("interact")
            self.p.refresh(8)
            if self.eleanor_state().get("recruitment") == "recruited":
                return ""
        return f"Talk beside Eleanor never recruited her; the game said {self.journal()!r}"

    def _eleanor_adventure(self) -> str:
        if self.eleanor_state().get("adventure") == "completed":
            return ""
        # Park the trail boss at the wagon: the lantern crossing after this one
        # can only be started from there, and switching leaves him where he stands.
        self.approach(WAGON[0] + 20, WAGON[1] + 30)
        if self.obs().get("controlling") != "eleanor":
            self.act("switch")
            self.p.refresh(8)
        if self.obs().get("controlling") != "eleanor":
            return f"Companion [Tab] would not hand over control; the game said {self.journal()!r}"
        for _ in range(6):
            o = self.obs()
            steadied = self._steadied()
            if steadied >= 3:
                break
            here = self.p.controlled(o)
            cows = sorted(o.get("cattle", []), key=lambda c: self.p.dist(c["pos"], here))
            moved = False
            for cow in cows:
                if not self.approach(cow["pos"]["x"] - 10, cow["pos"]["y"] + 12, tries=30):
                    continue
                before = self._steadied()
                self.act("interact")
                self.p.refresh(10)
                if self._steadied() > before:
                    moved = True
                    break
            if not moved:
                return (f"Eleanor steadied {self._steadied()} of 3 cattle and then could not "
                        f"reach another; the game said {self.journal()!r}")
        if not self.approach(WAGON[0], WAGON[1] + 24):
            return "Eleanor could not get back to the wagon to finish her adventure"
        for _ in range(4):
            self.act("interact")
            self.p.refresh(10)
            if self.eleanor_state().get("adventure") == "completed":
                return ""
        return f"Eleanor's adventure never closed out; the game said {self.journal()!r}"

    def _steadied(self) -> int:
        match = re.search(r"(\d+) of 3 steadied", self.objective())
        return int(match.group(1)) if match else 0

    def _lantern_crossing(self) -> str:
        if self._lantern_done():
            return ""
        # Tab at the wagon starts the crossing; the trail boss has to be standing there.
        if not self.approach(WAGON[0] + 20, WAGON[1] + 30):
            return "could not reach the wagon to start the lantern crossing"
        for _ in range(3):
            if self.obs().get("controlling") == "eleanor":
                break
            self.act("switch")
            self.p.refresh(8)
        if self.obs().get("controlling") != "eleanor":
            return f"Companion [Tab] at the wagon did not start the crossing: {self.journal()!r}"
        if not self.approach(*CROSSING):
            return "Eleanor could not reach the pale crossing spirit"
        self.act("interact")     # settle the spirit
        self.p.refresh(10)
        self.act("interact")     # begin guiding
        self.p.refresh(10)
        for delivery in range(3):
            o = self.obs()
            here = self.p.controlled(o)
            stranded = [c for c in o.get("cattle", []) if c["pos"]["x"] < 400]
            if not stranded:
                return f"only {delivery} of 3 cattle were across and no stranded steer was left to guide"
            cow = min(stranded, key=lambda c: self.p.dist(c["pos"], here))
            if not self.approach(cow["pos"]["x"] - 12, cow["pos"]["y"] + 10, tries=30):
                return f"could not walk beside stranded steer {delivery + 1}"
            self.act("interact")
            self.p.refresh(8)
            self.approach(*FORD_EXIT, tries=45)
            crossed = self.wait_for(
                lambda ob, want=delivery + 1: f"{want} of 3 cattle across" in str(ob.get("message", "")),
                chunks=18)
            if not crossed and self._across() < delivery + 1:
                return (f"steer {delivery + 1} would not follow Eleanor across; "
                        f"the game said {self.journal()!r}")
        if not self.approach(WAGON[0], WAGON[1] + 24):
            return "Eleanor could not get back to the wagon with the lantern"
        for _ in range(4):
            self.act("interact")
            self.p.refresh(10)
            if self._lantern_done():
                return ""
        return f"the lantern crossing never closed out; the game said {self.journal()!r}"

    def heard(self, needle: str) -> bool:
        """Has this line been on screen at any point? The crossing and the cart
        outing have no field in the observation, so their completion is read the
        way a player reads it, off the journal line under the room."""
        needle = needle.lower()
        return any(needle in line.lower() for line in self.p.said)

    def _across(self) -> int:
        best = 0
        for line in self.p.said:
            match = re.search(r"(\d+) of 3 cattle across", line)
            if match:
                best = max(best, int(match.group(1)))
        return best

    def _lantern_done(self) -> bool:
        return self.heard("lanterns at the ford complete")

    def _ada_repair(self) -> str:
        ada = self.companion("ada_mercer")
        if ada.get("recruitment") == "recruited":
            return ""
        if not self.approach(ADA[0], ADA[1] + 32):
            return "could not reach Ada beside her stalled walker"
        self.act("interact")
        self.p.refresh(8)
        if "ada" not in self.journal().lower() and "regulator" not in self.journal().lower():
            return (f"Talk beside Ada's walker said nothing about her; the crossing that gates "
                    f"her may not have completed. The game said {self.journal()!r}")
        if not self.approach(WAGON[0], WAGON[1] + 28):
            return "could not reach the wagon to retrieve the spare regulator"
        self.act("interact")
        self.p.refresh(8)
        if not self.approach(WALKER[0], WALKER[1] + 40):
            return "could not stand at the walker"
        pressure, feed, vent = self._walker()
        if pressure is None:
            return f"the walker panel never appeared; the objective read {self.objective()!r}"
        # Vent down to 5 or below with the feed shut, then fit the regulator.
        if feed:
            self.act("lasso")
        if not vent:
            self.act("shoot")
        self.p.refresh(4)
        def vented(ob: dict) -> bool:
            reading = self._walker(ob)[0]
            return reading is not None and reading <= 5.0

        if not self.wait_for(vented, chunks=60, frames=4):
            return f"pressure would not fall to 5; the walker read {self.objective()!r}"
        self.act("interact")
        self.p.refresh(6)
        if "regulator fitted" not in self.journal().lower():
            return f"the regulator would not fit; the game said {self.journal()!r}"
        # Close the vent, feed back up into the 30 to 50 band, close the feed, test.
        self.act("shoot")
        self.act("lasso")
        self.p.refresh(4)
        def in_band(ob: dict) -> bool:
            reading = self._walker(ob)[0]
            return reading is not None and 32.0 <= reading <= 48.0

        if not self.wait_for(in_band, chunks=80, frames=3):
            return f"pressure never settled in the 30 to 50 band; walker read {self.objective()!r}"
        self.act("lasso")
        self.p.refresh(4)
        self.act("interact")
        self.p.refresh(8)
        if "repaired" not in self.journal().lower():
            return f"the walker test failed; the game said {self.journal()!r}"
        if not self.approach(ADA[0], ADA[1] + 32):
            return "walker repaired but could not walk back to Ada to invite her"
        for _ in range(3):
            self.act("interact")
            self.p.refresh(8)
            if self.companion("ada_mercer").get("recruitment") == "recruited":
                return ""
        return f"Ada would not join; the game said {self.journal()!r}"

    def _walker(self, obs: dict | None = None) -> tuple:
        text = str((obs or self.obs()).get("objective", ""))
        match = re.search(r"WALKER / (\d+) pressure / Feed (\w+) / Vent (\w+)", text)
        if not match:
            return (None, None, None)
        return (float(match.group(1)), match.group(2) == "open", match.group(3) == "open")

    def _ada_cart(self) -> str:
        if self._cart_done():
            return ""
        if not self.approach(*CART_PARK):
            return "could not reach the cart stop on the lower trail"
        self.act("interact")     # board
        self.p.refresh(8)
        if "playing ada" not in self.journal().lower():
            return f"boarding the cart did nothing; the game said {self.journal()!r}"
        self.act("interact")     # inspect
        self.p.refresh(6)
        if "route pressure" not in self.journal().lower():
            return f"the inspection did not open the valve routing; the game said {self.journal()!r}"
        # Valves start all closed and want outer feeds open, middle bypass shut.
        self.act("lasso")        # valve A
        self.p.refresh(4)
        self.act("rest")         # valve C
        self.p.refresh(4)
        self.act("interact")     # test the routing
        self.p.refresh(8)
        if "drive" not in self.journal().lower():
            return f"the valve routing was rejected; the game said {self.journal()!r}"
        for index, stop in enumerate(CART_STOPS):
            if not self._drive_to(stop, f"Lantern {index + 1} of 3 reached"):
                return (f"the cart never reached lantern {index + 1} of 3; "
                        f"the game said {self.journal()!r}")
        if not self._drive_to(CART_PARK, "", chunks=60):
            pass   # the arrival is confirmed by the Talk below, not by the drive
        for _ in range(6):
            self.act("interact")
            self.p.refresh(10)
            if self._cart_done():
                return ""
            self._drive_to(CART_PARK, "", chunks=12)
        return f"the cart outing never closed out at camp; the game said {self.journal()!r}"

    def _drive_to(self, point: tuple, needle: str, chunks: int = 45) -> bool:
        """Steer the cart at a point. The observation carries no cart position,
        so this drives on the journal line alone, exactly as a player reading
        the screen would, and gives up after a bounded number of frames."""
        self.g.move(point[0], point[1])
        for _ in range(chunks):
            self.p.refresh(8)
            if needle and self.heard(needle):
                return True
            if not needle and self.heard("outing complete"):
                return True
            self.g.move(point[0], point[1])
        return False

    def _cart_done(self) -> bool:
        if self.heard("outing complete"):
            return True
        ines = self.companion("ines_vale")
        return bool(ines) and ines.get("recruitment") == "recruited"

    def _ines_trail(self) -> str:
        if self.companion("ines_vale").get("recruitment") == "recruited":
            return ""
        if not self.approach(*INES):
            return "could not reach Ines on the northern trail"
        self.act("interact")
        self.p.refresh(8)
        if "ines" not in self.journal().lower():
            return (f"Talk on the northern trail said nothing about Ines; the cart outing that "
                    f"gates her may not have completed. The game said {self.journal()!r}")
        for index, clue in enumerate(INES_CLUES):
            if not self.approach(*clue):
                return f"could not reach spirit clue {index + 1} of 3"
            self.act("interact")
            self.p.refresh(8)
        if not self.approach(*INES):
            return "could not walk back to Ines with the clues"
        for _ in range(4):
            self.act("interact")
            self.p.refresh(8)
            if self.companion("ines_vale").get("recruitment") == "recruited":
                return ""
        return f"Ines never joined; the game said {self.journal()!r}"

    def _birdie(self) -> str:
        if self.companion("birdie_calloway").get("recruitment") == "recruited":
            return ""
        if not self.approach(*BIRDIE):
            return "could not reach Birdie at the camp edge"
        for _ in range(5):
            self.act("interact")
            self.p.refresh(8)
            if self.companion("birdie_calloway").get("recruitment") == "recruited":
                return ""
        return (f"Birdie would not join after five Talks; the game said {self.journal()!r}. "
                f"Her state: {self.companion('birdie_calloway')}")

    def _the_nineteen(self) -> str:
        self.p.refresh(8)
        cast = self.simple_cast()
        open_now = [c for c in cast if c.get("unlocked")]
        if len(open_now) >= len(cast) and cast:
            return ""
        return f"only {len(open_now)} of {len(cast)} stayed locked open"

    # ---------- the distinctness probe ----------

    def visit_the_cast(self, limit: int = 19) -> dict:
        """Walk to every unlocked companion and play her whole sequence, then
        measure how much any of it differs from anybody else's."""
        cast = [c for c in self.simple_cast() if c.get("unlocked")][:limit]
        for entry in cast:
            self.cast.append(self._visit(entry))
        return self.distinctness()

    def _visit(self, entry: dict) -> dict:
        cid = entry["id"]
        goal = entry.get("pos", {})
        record = {"id": cid, "reached": False, "distance": None, "steps": [], "lines": []}
        self.approach(goal.get("x", 0.0), goal.get("y", 0.0), tries=40)
        self.p.refresh(6)
        live = self.companion(cid)
        here = self.p.controlled()
        record["distance"] = round(self.p.dist(here, goal), 1)
        record["reached"] = bool(live.get("near"))
        if not record["reached"]:
            record["stall"] = (f"stood {record['distance']} units away, the closest the room lets "
                               f"the player get; she only answers within "
                               f"{entry.get('near_radius', 36)} units")
            return record
        for verb in ["interact", "interact", "interact", "flirt"]:
            before_lines = len(self.p.said)
            before_state = hard_state(self.obs())
            advertised = self.button_label()
            result = self.act(verb)
            self.p.refresh(6)
            gained = self.p.said[before_lines:]
            spoken = [line for line in gained if not line.startswith("(journal) ")]
            record["lines"].extend(gained)
            record["steps"].append({
                "verb": verb,
                "advertised": advertised,
                "advanced": hard_state(self.obs()) != before_state,
                "journal": self.journal(),
                "new_lines": gained,
                "spoken_lines": spoken,
                "said_nothing": not self.journal().strip() and not spoken,
            })
        final = self.companion(cid)
        record["final"] = {k: final.get(k) for k in ("met", "task_done", "recruitment", "romance")}
        return record

    def distinctness(self) -> dict:
        """Compute how alike the cast is. Structure first, then vocabulary."""
        visited = [c for c in self.cast if c.get("reached")]
        out = {
            "visited": len(visited),
            "unreachable": [{"id": c["id"], "distance": c["distance"], "why": c.get("stall", "")}
                            for c in self.cast if not c.get("reached")],
        }
        if len(visited) < 2:
            out["verdict"] = ("fewer than two companions could be reached, so no comparison "
                              "between them is possible")
            return out
        # Structure: the ordered sequence of verbs and whether each advanced anything.
        signatures = {}
        for entry in visited:
            key = tuple((s["verb"], s["advanced"]) for s in entry["steps"])
            signatures.setdefault(key, []).append(entry["id"])
        out["distinct_interaction_shapes"] = len(signatures)
        out["what_this_number_means"] = (
            "the bot pressed the same fixed sequence at every companion: Talk, Talk, Talk, "
            "Flirt. One shape therefore means one sequence completed every one of them and "
            "not one of them wanted anything different. It cannot show a difference that "
            "would only appear under some other sequence."
        )
        labels = {}
        for entry in visited:
            key = tuple(s.get("advertised", "") for s in entry["steps"])
            labels.setdefault(key, []).append(entry["id"])
        out["distinct_button_label_sequences"] = len(labels)
        out["button_label_sequences"] = [{"labels": list(k), "count": len(v), "who": v[:6]}
                                         for k, v in labels.items()]
        silent = [(c["id"], i + 1) for c in visited
                  for i, s in enumerate(c["steps"]) if s.get("said_nothing")]
        spoken = sum(len(s.get("spoken_lines", [])) for c in visited for s in c["steps"])
        out["steps_that_said_nothing_at_all"] = {
            "count": len(silent),
            "of_total_steps": sum(len(c["steps"]) for c in visited),
            "which": silent[:24],
        }
        out["spoken_lines_from_the_whole_cast"] = spoken
        out["interaction_shapes"] = [
            {"shape": [list(step) for step in key], "count": len(ids), "who": ids[:6]}
            for key, ids in signatures.items()
        ]
        recruited = [c["id"] for c in visited if (c.get("final") or {}).get("recruitment") == "recruited"]
        out["recruited_in_three_talks"] = len(recruited)
        # Vocabulary: pairwise Jaccard over every word each one produced.
        bags = {c["id"]: self._words(c) for c in visited}
        pairs = []
        ids = sorted(bags)
        for i, left in enumerate(ids):
            for right in ids[i + 1:]:
                a, b = bags[left], bags[right]
                if not a or not b:
                    continue
                pairs.append(len(a & b) / len(a | b))
        if pairs:
            out["pairwise_word_overlap"] = {
                "pairs": len(pairs),
                "mean": round(sum(pairs) / len(pairs), 3),
                "min": round(min(pairs), 3),
                "max": round(max(pairs), 3),
            }
        every = set.intersection(*bags.values()) if bags else set()
        union = set.union(*bags.values()) if bags else set()
        out["vocabulary"] = {
            "distinct_words_across_the_cast": len(union),
            "words_every_single_one_says": len(every),
            "shared_fraction": round(len(every) / len(union), 3) if union else 0.0,
        }
        # Slot by slot: how much of each journal line is common to everybody.
        slots = []
        depth = min(len(c["steps"]) for c in visited)
        for index in range(depth):
            texts = [self._tokens(c["steps"][index]["journal"]) for c in visited]
            common = set.intersection(*[set(t) for t in texts]) if texts else set()
            total = set.union(*[set(t) for t in texts]) if texts else set()
            lengths = [len(t) for t in texts]
            slots.append({
                "step": index + 1,
                "verb": visited[0]["steps"][index]["verb"],
                "mean_words_in_the_line": round(sum(lengths) / len(lengths), 1),
                "words_shared_by_all": len(common),
                "distinct_words_in_this_slot": len(total),
            })
        out["per_step_journal"] = slots
        out["identical_journal_lines"] = self._identical_lines(visited)
        return out

    @staticmethod
    def _tokens(text: str) -> list:
        return [w for w in re.findall(r"[a-z']+", str(text).lower()) if len(w) > 1]

    def _words(self, entry: dict) -> set:
        text = " ".join([s["journal"] for s in entry["steps"]] + entry["lines"])
        # Drop her own name and speaker tag so the comparison is about the writing.
        own = set(entry["id"].split("_"))
        return {w for w in self._tokens(text) if w not in own}

    def _identical_lines(self, visited: list) -> int:
        """How many journal lines are word-for-word identical across companions
        once each one's own name is taken out."""
        counts = {}
        for entry in visited:
            own = set(entry["id"].split("_"))
            for step in entry["steps"]:
                key = " ".join(w for w in self._tokens(step["journal"]) if w not in own)
                counts[key] = counts.get(key, 0) + 1
        return sum(1 for key, n in counts.items() if n > 1 and key)

    # ---------- the choice probe ----------

    def sample_choice(self, label: str) -> dict | None:
        """Save, press every verb in turn and load back after each, so the count
        is of options genuinely available at one moment rather than a sequence of
        things done one after another.

        Three outcomes per verb, never two: it moved the world, it only answered
        with a line, or it did nothing at all. And three outcomes for the moment
        itself: a moment whose save and load cannot be proved to round-trip is
        recorded as unmeasurable rather than counted as offering nothing, because
        a broken save would make every verb look like it changed nothing.
        """
        here = self.p.controlled()
        self.g.move(here.get("x", 0.0), here.get("y", 0.0))   # stop walking first
        self.p.refresh(6)
        anchor_state = hard_state(self.obs())
        anchor_journal = self.journal()
        anchor_pos = dict(self.p.controlled())
        # Seam so the unmeasurable branch below can be executed on purpose. A
        # branch nobody can reach deliberately is a branch nobody can prove they
        # fixed, and this one decides whether a zero means "no options" or
        # "the probe is broken".
        if os.environ.get("PLAYBOT_BREAK_SAVE") != "1":
            self.act("save")
        self.p.refresh(4)
        # Positive control. Walk a long way off, load, and require the world to
        # come back. Without this a save that silently refused would read as a
        # moment where no verb did anything, which is the answer being measured.
        drifted = self.approach(anchor_pos.get("x", 0.0) + 90.0,
                                anchor_pos.get("y", 0.0) + 60.0, tries=18)
        moved_away = self.p.dist(self.p.controlled(), anchor_pos)
        self.act("load")
        self.p.refresh(4)
        came_back = self.p.dist(self.p.controlled(), anchor_pos)
        if moved_away < 20.0 or came_back > 8.0 or hard_state(self.obs()) != anchor_state:
            moment = {"where": label, "measurable": False,
                      "why": (f"save and load did not round-trip here: walked {moved_away:.1f} "
                              f"units away (drift check reached target: {drifted}) and came back "
                              f"{came_back:.1f} units from where the save was taken. Counting "
                              f"verbs here would measure the probe, not the game.")}
            self.choice_moments.append(moment)
            return moment
        moved_world, spoke_only, silent, unrestored = [], [], [], []
        outcomes: dict = {}
        for verb in VERBS:
            result = self.act(verb)
            # act() answers without advancing the world, so the observation in
            # hand is still the one from before the press. Take a fresh one, or
            # every verb reads as having changed nothing and the probe reports
            # the answer it was built to look for.
            self.p.refresh(2)
            after_state = hard_state(self.obs())
            after_journal = str(result.get("message", ""))
            if after_state != anchor_state:
                moved_world.append(verb)
                outcomes.setdefault(after_state, []).append(verb)
            elif after_journal != anchor_journal:
                spoke_only.append(verb)
            else:
                silent.append(verb)
            self.act("load")
            self.p.refresh(3)
            if hard_state(self.obs()) != anchor_state:
                unrestored.append(verb)
        if unrestored:
            moment = {"where": label, "measurable": False,
                      "why": f"the world did not come back after pressing {unrestored}, so the "
                             f"later presses at this moment were made from a different state"}
            self.choice_moments.append(moment)
            return moment
        moment = {
            "where": label,
            "measurable": True,
            "objective": self.objective(),
            "moved_the_world": moved_world,
            "only_answered_with_a_line": spoke_only,
            "did_nothing_at_all": silent,
            # Two buttons wired to one action are one option, not two. After the
            # herd is safe, Lasso falls through to Flirt, so counting buttons
            # would have doubled this number for free.
            "distinct_outcomes": [verbs for verbs in outcomes.values()],
            "options_that_advance": len(outcomes),
            "buttons_that_advance": len(moved_world),
        }
        self.choice_moments.append(moment)
        return moment

    def choice_summary(self) -> dict:
        measurable = [m for m in self.choice_moments if m.get("measurable")]
        unmeasurable = [m for m in self.choice_moments if not m.get("measurable")]
        branching = [m for m in measurable if m["options_that_advance"] >= 2]
        corridor = [m for m in measurable if m["options_that_advance"] == 1]
        dead = [m for m in measurable if m["options_that_advance"] == 0]
        ratio = round(len(branching) / len(measurable), 3) if measurable else None
        return {
            "moments_measured": len(measurable),
            "moments_unmeasurable": len(unmeasurable),
            "moments_with_two_or_more_options_that_advance": len(branching),
            "moments_with_exactly_one": len(corridor),
            "moments_with_none": len(dead),
            "branching_ratio": ratio,
            "branching_moments": [{"where": m["where"], "outcomes": m["distinct_outcomes"]}
                                  for m in branching],
            "moments": self.choice_moments,
        }

    # ---------- report ----------

    def report(self) -> dict:
        return {
            "stages": [s.dict() for s in self.stages],
            "reached": self.reached(),
            "cast": self.cast,
            "distinctness": self.distinctness() if self.cast else {},
            "choice": self.choice_summary(),
        }
