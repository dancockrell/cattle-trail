"""Require positive completion evidence; Godot script assertions can exit with code zero."""
from pathlib import Path
import argparse
import os
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path('C:/Users/Admin/dev/tools/godot/bin/Godot_v4.3-stable_win64_console.exe')
CHECKS = {
    'lantern-view': (['--headless', '--script', 'tools/lantern_presentation_test.gd'], r'LANTERN PRESENTATION PASS: checkpoint views, pause and retry, immutable state, restore parity'),
    'lantern': (['--headless', '--script', 'tools/lantern_adventure_test.gd'], r'LANTERN ADVENTURE PASS: \d+ checks; checkpoint identity, retry, strict atomic saves, one-shot milestone; backend only'),
    'clock': (['--headless', '--script', 'tools/trail_clock_test.gd'], r'TRAIL CLOCK PASS: elapsed play, pause, day boundary, invalid delta, daily recovery unlock'),
    'turn': (['--headless', '--script', 'tools/turn_transition_test.gd'], r'TURN TRANSITION PASS: authored modes, missing bridge, phase, finite hold, retarget, action cancel, completion'),
    'compile': (['--headless', '--script', 'tools/compile_sources.gd'], r'SOURCE COMPILATION PASS: \d+ runtime scripts loaded and can_instantiate\(\) verified; no scenes instantiated'),
    'storage': (['--headless', '--script', 'tools/save_storage_test.gd'], r'SAVE STORAGE PASS: roundtrip, replacement, backup fallback, corrupt-primary repair, failed-write preservation, schema fallback, validator isolation, cleanup'),
    'snapshot': (['--headless', '--script', 'tools/room_snapshot_test.gd'], r'ROOM SNAPSHOT PASS: typed data, finite positions, encounter consistency and JSON roundtrip'),
    'phase': (['--headless', '--script', 'tools/animation_phase_test.gd'], r'ANIMATION PHASE PASS: unequal holds, directional remapping, cycle boundaries and roundtrip'),
    'state': (['--headless', '--script', 'tools/companion_state_test.gd'], r'COMPANION STATE: \d+ checks, 0 failures'),
    'room': (['--', '--qa'], r'QA PASS: real atlases, tap movement, dialogue, shooting, lasso following, all-six objective, responsive capture'),
    'companion': (['--', '--companion-qa'], r'COMPANION ROOM PASS: recruitment, actor switching, three cattle, camp completion, capped recovery, phone controls'),
    'motion': (['--', '--motion-review'], r'MOTION REVIEW PASS: all eight directions for rider and three cattle appearances'),
}


def run_check(godot, arguments, marker, timeout):
    process = subprocess.Popen([str(godot), '--path', str(ROOT), *arguments], cwd=ROOT,
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        # Only terminate the process tree created by this invocation.
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
        else:
            process.kill()
        process.communicate()
        raise RuntimeError(f'Godot check timed out after {timeout}s')
    if process.returncode != 0:
        raise RuntimeError(f'Godot exited {process.returncode}\n{output}')
    if re.search(r'(?m)^\s*(?:SCRIPT ERROR|ERROR):', output):
        raise RuntimeError(f'Godot reported an error despite exit code zero\n{output}')
    if not re.search(marker, output):
        raise RuntimeError(f'Godot did not report the required completion marker\n{output}')
    return output


def self_test(godot):
    scratch = ROOT.parents[1] / 'work'
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='godot-verifier-', dir=scratch) as directory:
        probe = Path(directory) / 'assertion_probe.gd'
        probe.write_text('extends SceneTree\nfunc _initialize():\n\tfail_probe()\n\tprint("PROBE COMPLETE")\n\tquit(0)\nfunc fail_probe():\n\tassert(false,"Intentional verifier rejection probe")\n', encoding='utf-8')
        try:
            run_check(godot, ['--headless', '--script', str(probe)], r'PROBE COMPLETE', 20)
        except RuntimeError as error:
            if 'error despite exit code zero' not in str(error):
                raise
        else:
            raise RuntimeError('Verifier incorrectly accepted an assertion failure')
    print('VERIFIER SELF-TEST PASS: rejected a real assertion despite exit zero and completion marker')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checks', nargs='*', metavar='CHECK', help='state, phase, turn, clock, lantern, lantern-view, storage, snapshot, compile, room, companion, or motion; defaults to state')
    parser.add_argument('--godot', type=Path, default=DEFAULT_GODOT)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    args.checks = args.checks or ['state']
    unknown = set(args.checks) - CHECKS.keys()
    if unknown:
        parser.error('Unknown check: ' + ', '.join(sorted(unknown)))
    if args.self_test:
        self_test(args.godot)
    for check in args.checks:
        arguments, marker = CHECKS[check]
        output = run_check(args.godot, arguments, marker, args.timeout)
        print(f'VERIFIED {check}: {re.search(marker, output).group(0)}')


if __name__ == '__main__':
    main()
