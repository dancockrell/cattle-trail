"""Turns a play trace into judgment, using the Claude CLI as the bot's brain.

No API key lives on this machine, so the bot thinks through the authenticated
`claude` CLI in print mode. tools/playbot/DIRECTIVES.md is the standing brief
and is edited to steer the bot, rather than editing this file.
"""
from __future__ import annotations
import json
import shutil
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
DIRECTIVES = HERE / "DIRECTIVES.md"


def _trim(trace: dict, max_lines: int = 90) -> dict:
    """Keep the trace small enough to think about without losing the evidence."""
    slim = dict(trace)
    slim["heard"] = trace.get("heard", [])[:max_lines]
    final = dict(trace.get("final", {}))
    # The full companion dump is long and mostly repeats; keep the shape and a sample.
    cast = final.get("companions", [])
    final["companions_total"] = len(cast)
    final["companions_sample"] = cast[:4]
    final.pop("companions", None)
    final.pop("transcript", None)
    slim["final"] = final
    # Probe 1 and probe 2: keep every number and every sentence, drop the raw
    # node dumps and the resource snapshots the sentences already summarise.
    presence = dict(trace.get("presence") or {})
    if presence:
        presence["findings"] = [{k: v for k, v in f.items() if k != "detail"}
                                for f in presence.get("findings", [])]
        slim["presence"] = presence
    stakes = []
    for entry in trace.get("stakes") or []:
        lean = {k: v for k, v in entry.items() if k not in ("plays", "decisions")}
        lean["runs"] = [{"inputs": p["inputs"], "net": p["net"], "journal": p["journal"]}
                        for p in entry.get("plays", [])]
        lean["decision_moments"] = [
            {"where": m["where"], "options": m.get("options_that_change_the_outcome"),
             "outcomes": m.get("distinct_outcomes")}
            for m in (entry.get("decisions") or {}).get("measured", [])]
        lean["not_checked"] = [m["why"] for m in
                               (entry.get("decisions") or {}).get("unmeasurable", [])]
        stakes.append(lean)
    if stakes:
        slim["stakes"] = stakes
    return slim


def judge(trace: dict, timeout: int = 600) -> dict:
    prompt = (
        DIRECTIVES.read_text(encoding="utf-8")
        + "\n\n## The play trace\n\n```json\n"
        + json.dumps(_trim(trace), indent=1)[:120000]
        + "\n```\n"
    )
    # On Windows the CLI is a .CMD shim, which bare subprocess will not find,
    # and the prompt is far past the command-line length limit. Resolve the real
    # executable and hand it the prompt on stdin instead of argv.
    exe = shutil.which("claude") or shutil.which("claude.cmd")
    if not exe:
        return {"error": "claude CLI not found on PATH; the bot has no brain to think with"}
    proc = subprocess.run(
        [exe, "-p"], input=prompt,
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout,
    )
    raw = proc.stdout.strip()
    if not raw:
        return {"error": "critic returned nothing", "stderr": proc.stderr[-800:]}
    start, end = raw.find("{"), raw.rfind("}")
    if start < 0 or end < 0:
        return {"error": "critic returned no JSON", "raw": raw[:1500]}
    try:
        return json.loads(raw[start:end + 1])
    except json.JSONDecodeError as exc:
        return {"error": f"critic JSON did not parse: {exc}", "raw": raw[:1500]}
