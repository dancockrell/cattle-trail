"""Probe 1: is anything actually there.

Nineteen companions shipped as coordinates with dialogue attached. You walked to
an empty patch of dirt, pressed Talk, and read a line in the journal. The bot
played them many times and never once said nobody was home, because everything
it could see was a state transition and a position, and a position is exactly
what a missing character still has.

So this probe does not ask whether a node exists. It asks whether something is
drawn: a texture, visible in the tree, with a size and some alpha left in it. A
Node2D with no texture is the failure that shipped, and it passes an existence
check perfectly.

Two directions, because they are different bugs with different fixes:

* interactive and not drawn: the game accepts a verb somewhere nothing is on
  screen. "The game told me to talk to X, and X is not on screen."
* drawn and not interactive: somebody stands there and pressing anything at her
  does nothing. Deleting the sprite and wiring the interaction look identical
  from the chair and are opposite fixes, so the probe reports it and does not
  say which.

The instrument is checked before the world is. A report that examined nothing
must be loud: a probe that looks at zero actors finds zero missing ones, and
that is indistinguishable from a cast that is all present.
"""
from __future__ import annotations

SATISFIED = "satisfied"
BLOCKED = "blocked"
IGNORED = "ignored_silently"
BROKEN = "probe_broken"


def _where(entry: dict) -> str:
    spot = entry.get("asked_to_stand_at") or entry.get("pos") or {}
    return "({}, {})".format(spot.get("x"), spot.get("y"))


def measure(game) -> dict:
    """Ask the game what is drawn, and check the instrument before the world."""
    report = game.send(cmd="actors")
    examined = int(report.get("examined", 0))
    companions = report.get("companions") or []
    named = report.get("named") or []
    cattle = report.get("cattle") or {}
    unaccounted = report.get("unaccounted") or []

    out: dict = {
        "examined": examined,
        "companions_examined": len(companions),
        "named_examined": len(named),
        "cattle_examined": int(cattle.get("total", 0)),
        "scenery_examined": len(unaccounted),
        "instrument_ok": False,
        "instrument_says": "",
        "findings": [],
        "drawn": {},
    }

    # --- the instrument, first. Three states, never two. ---
    if not report.get("layer_present", False):
        out["instrument_says"] = (
            "the room has no actor layer at all, so nothing could be examined: "
            + str(report.get("error", ""))
        )
        return out
    if examined == 0:
        out["instrument_says"] = ("the probe examined 0 actors. A zero here is a claim about the "
                                  "probe, not about the game. Nothing below is evidence.")
        return out
    if not companions:
        out["instrument_says"] = ("the probe examined 0 companions, so it cannot say whether the "
                                  "cast is on screen. Nothing below is evidence about the cast.")
        return out
    # Positive control: the thing the player is steering is definitely on screen.
    # Without it, a probe that read every texture as missing would report the
    # whole cast absent and look exactly like the finding it was built to make.
    player = next((n for n in named if n.get("name") == "player"), None)
    if player is None or not player.get("drawn"):
        why = (player or {}).get("why_not_drawn", "no player entry in the report")
        out["instrument_says"] = (
            "the positive control failed: the player character itself reads as not drawn ("
            + str(why) + "). Every absence below would be the probe's, so none of it is reported.")
        return out
    out["instrument_ok"] = True
    out["instrument_says"] = (
        "examined {} actors ({} named, {} catalog companions, {} cattle, {} scenery), and the "
        "positive control passed: the player is drawn at {}x{}.".format(
            examined, len(named), len(companions), int(cattle.get("total", 0)), len(unaccounted),
            player["on_screen_size"]["w"], player["on_screen_size"]["h"]))

    # --- the world ---
    interactive = [e for e in named if e.get("interactive")] + companions
    missing = [e for e in interactive if not e.get("drawn")]
    drawn = [e for e in interactive if e.get("drawn")]
    out["drawn"] = {
        "interactive_targets": len(interactive),
        "of_those_on_screen": len(drawn),
        "of_those_invisible": len(missing),
        "companions_on_screen": sum(1 for c in companions if c.get("drawn")),
        "companions_total": len(companions),
        "cattle_on_screen": int(cattle.get("drawn", 0)),
        "scenery_on_screen": sum(1 for e in unaccounted if e.get("drawn")),
    }

    for entry in missing:
        who = entry.get("id") or entry.get("name")
        out["findings"].append({
            "kind": "interactive_but_not_drawn",
            "who": who,
            "says": ("the game told me to talk to {} at {}, and {} is not on screen: {}".format(
                who, _where(entry), who, entry.get("why_not_drawn"))),
            "detail": entry,
        })

    # The reverse. A character standing where no verb reaches her is the same
    # broken promise from the other side, and the two have opposite fixes.
    for entry in companions:
        if entry.get("drawn") and not entry.get("unlocked"):
            out["findings"].append({
                "kind": "drawn_but_nothing_to_do",
                "who": entry.get("id"),
                "says": ("{} is standing at {} and pressing anything at her does nothing: she is "
                         "drawn but locked, so the world shows a person the game will not let me "
                         "meet".format(entry.get("id"), _where(entry))),
                "detail": {"unlocked": False, "pos": entry.get("asked_to_stand_at")},
            })
    return out


def note_for(player, tag: str = "") -> dict:
    """Run the probe and file it as notes, so the critic sees it in the trace."""
    result = measure(player.g)
    where = " ({})".format(tag) if tag else ""
    if not result["instrument_ok"]:
        player.note("I want to know whether anyone is actually on screen",
                    BROKEN,
                    "the presence probe could not measure anything{}: {}".format(
                        where, result["instrument_says"]),
                    **result)
        return result

    invisible = [f for f in result["findings"] if f["kind"] == "interactive_but_not_drawn"]
    furniture = [f for f in result["findings"] if f["kind"] == "drawn_but_nothing_to_do"]
    drawn = result["drawn"]
    player.note(
        "I want the people the game asks me to talk to to be on screen",
        BLOCKED if invisible else SATISFIED,
        ("{} of {} interactive targets are actually drawn{}; {} are a coordinate with dialogue "
         "attached and nothing to look at".format(
             drawn["of_those_on_screen"], drawn["interactive_targets"], where, len(invisible))
         + (": " + "; ".join(f["says"] for f in invisible[:8]) if invisible else "")
         + ". Instrument: " + result["instrument_says"]),
        invisible=[f["who"] for f in invisible], **drawn)
    if furniture:
        player.note(
            "I want a person I can see to be a person I can approach",
            IGNORED,
            ("{} companion(s) are drawn in the world and no verb reaches them{}: ".format(
                len(furniture), where)
             + "; ".join(f["says"] for f in furniture[:6])
             + (" ... and {} more".format(len(furniture) - 6) if len(furniture) > 6 else "")),
            who=[f["who"] for f in furniture])
    return result
