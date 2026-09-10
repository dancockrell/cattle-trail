"""Play a session and file a report.

    python tools/playbot/run.py            play, judge, write reports/
    python tools/playbot/run.py --no-judge play only, print the trace summary
    python tools/playbot/run.py --deep     also climb the whole unlock chain and
                                           measure the cast behind it (slower)
"""
from __future__ import annotations
import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from playbot.driver import Game, GameError
from playbot.player import Player
from playbot import critic

REPORTS = Path(__file__).resolve().parents[2] / "reports"


def print_climb(climb: dict) -> None:
    """The deep session's numbers, in the order they answer the question:
    how far up, what it cost, how alike the cast is, how often there is a choice."""
    if not climb:
        return
    print(f"\nTHE CLIMB (reached: {climb.get('reached')})")
    print(f"  {'stage':<22} {'status':<13} {'acts':>5} {'mins':>6} {'lines':>6}  signposted")
    for stage in climb.get("stages", []):
        signpost = "yes" if stage["named_on_entry"] else ("late" if stage["named_during"] else "no")
        status = stage["status"]
        if stage.get("already_done_on_entry") and status == "cleared":
            status = "already done"
        print(f"  {stage['name']:<22} {status:<13} {stage['actions']:>5} "
              f"{stage['minutes']:>6} {len(stage['new_lines']):>6}  {signpost}")
        if stage["stall"]:
            print(f"      stalled: {stage['stall']}")

    fit = climb.get("distinctness") or {}
    if fit:
        print("\nIS THE CAST ACTUALLY DIFFERENT")
        print(f"  visited {fit.get('visited')} companions, "
              f"{len(fit.get('unreachable', []))} unlocked but unreachable")
        if fit.get("visited", 0) >= 2:
            print(f"  distinct interaction shapes across them all: "
                  f"{fit.get('distinct_interaction_shapes')}")
            for shape in fit.get("interaction_shapes", []):
                verbs = " -> ".join(f"{v}{'*' if adv else ''}" for v, adv in shape["shape"])
                print(f"    {shape['count']:>3} of them: {verbs}   (* advanced her state)")
            print(f"  distinct button-label sequences the game showed: "
                  f"{fit.get('distinct_button_label_sequences')}")
            for seq in fit.get("button_label_sequences", []):
                print(f"    {seq['count']:>3} of them: {' -> '.join(seq['labels'])}")
            silent = fit.get("steps_that_said_nothing_at_all", {})
            print(f"  steps that produced no words at all: {silent.get('count')} of "
                  f"{silent.get('of_total_steps')}")
            print(f"  speech-bubble lines from the whole cast: "
                  f"{fit.get('spoken_lines_from_the_whole_cast')}")
            overlap = fit.get("pairwise_word_overlap", {})
            print(f"  word overlap between any two: mean {overlap.get('mean')} "
                  f"(min {overlap.get('min')}, max {overlap.get('max')}) over "
                  f"{overlap.get('pairs')} pairs")
            vocab = fit.get("vocabulary", {})
            print(f"  {vocab.get('words_every_single_one_says')} of "
                  f"{vocab.get('distinct_words_across_the_cast')} distinct words are said by "
                  f"every single one ({vocab.get('shared_fraction')} of the vocabulary)")
            for slot in fit.get("per_step_journal", []):
                print(f"    step {slot['step']} ({slot['verb']}): "
                      f"{slot['mean_words_in_the_line']} words per line, "
                      f"{slot['words_shared_by_all']} shared by all, "
                      f"{slot['distinct_words_in_this_slot']} distinct in total")
        for entry in fit.get("unreachable", [])[:20]:
            print(f"    unreachable: {entry['id']} (closest approach {entry['distance']})")

    choice = climb.get("choice") or {}
    if choice.get("moments_measured") is not None:
        print("\nDOES IT EVER OFFER ME A CHOICE")
        print(f"  {choice['moments_measured']} moment(s) measured, "
              f"{choice['moments_unmeasurable']} unmeasurable and excluded")
        print(f"  two or more verbs that move the world: "
              f"{choice['moments_with_two_or_more_options_that_advance']}")
        print(f"  exactly one: {choice['moments_with_exactly_one']}    "
              f"none at all: {choice['moments_with_none']}")
        print(f"  branching ratio: {choice['branching_ratio']}")
        for moment in choice.get("branching_moments", []):
            shown = " | ".join("/".join(group) for group in moment["outcomes"])
            print(f"    {moment['where']}: {shown}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-judge", action="store_true", help="skip the critic")
    parser.add_argument("--speed", type=float, default=12.0, help="in-game time scale")
    parser.add_argument("--deep", action="store_true",
                        help="climb the whole unlock chain, visit the cast behind it, and count "
                             "the moments that offer more than one option")
    parser.add_argument("--timeout", type=float, default=60.0,
                        help="seconds to wait on a silent game before giving up")
    args = parser.parse_args()

    REPORTS.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    started = time.time()

    game = Game(timeout=args.timeout)
    try:
        player = Player(game, speed=args.speed, deep=args.deep)
        trace = player.play()
    except GameError as exc:
        print(f"the game stopped talking to the bot: {exc}")
        return 1
    finally:
        game.close()

    trace["seconds"] = round(time.time() - started, 1)
    trace_path = REPORTS / f"trace-{stamp}.json"
    trace_path.write_text(json.dumps(trace, indent=1), encoding="utf-8")

    counts: dict[str, int] = {}
    for note in trace["notes"]:
        counts[note["outcome"]] = counts.get(note["outcome"], 0) + 1
    print(f"played in {trace['seconds']}s: {counts}")
    print(f"heard {len(trace['heard'])} distinct lines of dialogue")
    if trace["engine_errors"]:
        print(f"engine errors: {len(trace['engine_errors'])}")
        for line in trace["engine_errors"][:5]:
            print("  " + line)
    for note in trace["notes"]:
        if note["outcome"] in ("ignored_silently", "blocked"):
            print(f"  [{note['outcome']}] {note['desire']}: {note['detail'][:220]}")
    print_climb(trace.get("climb") or {})

    if args.no_judge:
        print(f"trace: {trace_path}")
        return 0

    print("thinking about it...")
    verdict = critic.judge(trace)
    verdict_path = REPORTS / f"verdict-{stamp}.json"
    verdict_path.write_text(json.dumps(verdict, indent=1), encoding="utf-8")
    if "error" in verdict:
        print("critic problem:", verdict["error"])
    else:
        print("\nVERDICT:", verdict.get("verdict", ""))
        print("\nBIGGEST LEVER:", verdict.get("biggest_single_lever", ""))
        for complaint in verdict.get("complaints", [])[:6]:
            print(f"\n[{complaint.get('severity')}] {complaint.get('desire')}")
            print(f"  happened: {complaint.get('what_happened')}")
            print(f"  build:    {complaint.get('content_order')}")
    print(f"\ntrace: {trace_path}\nverdict: {verdict_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
