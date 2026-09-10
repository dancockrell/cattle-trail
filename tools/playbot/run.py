"""Play a session and file a report.

    python tools/playbot/run.py            play, judge, write reports/
    python tools/playbot/run.py --no-judge play only, print the trace summary
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-judge", action="store_true", help="skip the critic")
    parser.add_argument("--speed", type=float, default=12.0, help="in-game time scale")
    args = parser.parse_args()

    REPORTS.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    started = time.time()

    game = Game()
    try:
        player = Player(game, speed=args.speed)
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
            print(f"  [{note['outcome']}] {note['desire']}: {note['detail'][:150]}")

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
