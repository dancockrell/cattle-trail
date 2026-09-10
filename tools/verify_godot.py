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
    'turn-actor': (['--headless', '--script', 'tools/turn_actor_test.gd'], r'TURN ACTOR PASS: full bridge poses, authored timing, preserved gait, retarget, action interruption and finite clocks; no rendering'),
    'action-sequence': (['--headless', '--script', 'tools/action_sequence_test.gd'], r'ACTION SEQUENCE PASS: weighted poses, hitch-safe release, exact sockets, cancellation, reentrant replacement and idle; no rendering'),
    'camp-care': (['--headless', '--script', 'tools/camp_care_controller_test.gd'], r'CAMP CARE CONTROLLER PASS: Ada rest, shared partner cooldown, Eleanor bonus, staged failure, migration, pending outing, UI reset'),
    'sprite-density': (['--headless', '--script', 'tools/sprite_density_test.gd'], r'SPRITE DENSITY PASS: detailed and legacy scales, pivots, reflection, sockets, display density and input; no rendering'),
    'camp-recovery': (['--headless', '--script', 'tools/camp_recovery_test.gd'], r'CAMP RECOVERY PASS: \d+ checks; mutual care, per-actor cooldown, input isolation and atomic JSON'),
    'cart-clearance': (['--headless', '--script', 'tools/cart_clearance_test.gd'], r'CART CLEARANCE PASS: default footprints preserved, wagon exit, wider scenery clearance, reachable route; no rendering'),
    'cart-motion': (['--headless', '--script', 'tools/cart_motion_test.gd'], r'CART MOTION PASS: \d+ checks'),
    'ada-cart-controller': (['--headless', '--script', 'tools/ada_cart_controller_test.gd'], r'ADA CART CONTROLLER PASS: boarding, valves, physical checkpoints, pause position, one reward, separate kiss; no rendering'),
    'ada-cart': (['--headless', '--script', 'tools/ada_cart_adventure_test.gd'], r'ADA CART ADVENTURE PASS: \d+ checks'),
    'field-perks': (['--headless', '--script', 'tools/field_perk_controller_test.gd'], r'FIELD PERK CONTROLLER PASS: actual catch duration, recruitment, stacking cap, persisted roster; no rendering'),
    'generated-roster': (['--headless', '--script', 'tools/generated_companion_roster_test.gd'], r'GENERATED ROSTER PASS: \d+ checks; stable identities, atomic persistence, separate consent, reward ledger and preview gate'),
    'perks': (['--headless', '--script', 'tools/companion_perks_test.gd'], r'COMPANION PERKS PASS: assignment, recruitment, unique owners, caps, authored values, preview exclusion, existing rest'),
    'character-roster': (['--headless', '--script', 'tools/export_character_roster.gd'], r'CHARACTER ROSTER PASS: \d+ distinct visual identities bound to deterministic adult character records'),
    'characters': (['--headless', '--script', 'tools/character_factory_test.gd'], r'CHARACTER FACTORY PASS: stable identities, unique art, adult ages, candidate gate, isolated data'),
    'mechanic-controller': (['--headless', '--script', 'tools/mechanic_controller_test.gd'], r'MECHANIC CONTROLLER PASS: unlock, retrieval, valve controls, repair, explicit invite, restore; no rendering'),
    'steam': (['--headless', '--script', 'tools/steam_repair_test.gd'], r'STEAM REPAIR PASS: \d+ checks'),
    'ada': (['--headless', '--script', 'tools/ada_companion_test.gd'], r'ADA COMPANION PASS: repair before invitation, acceptance, one reward, adult identity, atomic save'),
    'banter-delivery': (['--headless', '--script', 'tools/banter_delivery_test.gd'], r'BANTER DELIVERY PASS: deferred history, deduplication, expiry, missing speaker; no rendering'),
    'banter': (['--headless', '--script', 'tools/banter_queue_test.gd'], r'BANTER QUEUE PASS: \d+ checks'),
    'lantern-controller': (['--headless', '--script', 'tools/lantern_controller_test.gd'], r'LANTERN CONTROLLER PASS: entry, physical following, animation ownership, pause resume, one reward; no rendering'),
    'lantern-view': (['--headless', '--script', 'tools/lantern_presentation_test.gd'], r'LANTERN PRESENTATION PASS: checkpoint views, pause and retry, immutable state, restore parity'),
    'lantern': (['--headless', '--script', 'tools/lantern_adventure_test.gd'], r'LANTERN ADVENTURE PASS: \d+ checks; checkpoint identity, retry, strict atomic saves, one-shot milestone; backend only'),
    'clock': (['--headless', '--script', 'tools/trail_clock_test.gd'], r'TRAIL CLOCK PASS: elapsed play, pause, day boundary, invalid delta, daily recovery unlock'),
    'turn': (['--headless', '--script', 'tools/turn_transition_test.gd'], r'TURN TRANSITION PASS: authored modes, missing bridge, phase, finite hold, retarget, action cancel, completion'),
    'compile': (['--headless', '--script', 'tools/compile_sources.gd'], r'SOURCE COMPILATION PASS: \d+ runtime scripts loaded and can_instantiate\(\) verified; no scenes instantiated'),
    'storage': (['--headless', '--script', 'tools/save_storage_test.gd'], r'SAVE STORAGE PASS: roundtrip, replacement, backup fallback, corrupt-primary repair, failed-write preservation, schema fallback, validator isolation, cleanup'),
    'snapshot': (['--headless', '--script', 'tools/room_snapshot_test.gd'], r'ROOM SNAPSHOT PASS: typed data, finite positions, encounter consistency and JSON roundtrip'),
    'ines-room': (['--headless', '--script', 'tools/ines_room_test.gd'], r'INES ROOM PASS: unlock, busy guards, distinct clues, explicit recruitment and romance, field warnings, mobile labels, save counts and restore; no rendering'),
    'ines': (['--headless', '--script', 'tools/ines_companion_test.gd'], r'INES COMPANION PASS: distinct clues, one-time trail/recruitment/romance, deferred acceptance, field-only perk, finite madness and atomic strict saves'),
    'birdie': (['--headless', '--script', 'tools/birdie_test.gd'], r'BIRDIE COMPANION PASS: linear meet/sing/recruit/romance, deferred acceptance, camp-only perk, finite madness and atomic strict saves'),
    'simple-companion': (['--headless', '--script', 'tools/simple_companion_test.gd'], r'SIMPLE COMPANION PASS: generic meet/task/recruit/romance, identity-checked saves, camp-only perk, finite madness'),
    'simple-companion-room': (['--headless', '--script', 'tools/simple_companion_room_test.gd'], r'SIMPLE COMPANION ROOM PASS: unlock gate, busy guards, meet/task/recruit sequence, romance, mobile labels, save/restore across the catalog; no rendering'),
    'trade-negotiation': (['--headless', '--script', 'tools/trade_negotiation_test.gd'], r'TRADE NEGOTIATION PASS: reputation caps at 5, floors at 0, walking away is neutral, accept never moves price, walk produces no sale, honest counter lands above opening price, rigged counter is exposed as a distinct bluff outcome costing reputation, higher reputation yields a strictly better opening price'),
    'cattle-drive': (['--headless', '--script', 'tools/cattle_drive_resolver_test.gd'], r'CATTLE DRIVE RESOLVER PASS: clear route, Narrow Water crossing reduced by steady_herd, stampede improved by spirit_sense, physical hazard unaffected by spirit_sense, Second Shadow night penalty vs unaffected day-only hazard, and count_after bounds under adversarial and malformed input'),
    'birdie-room': (['--headless', '--script', 'tools/birdie_room_test.gd'], r'BIRDIE ROOM PASS: unlock, busy guards, meet/sing/recruit sequence, romance, mobile labels, save counts and restore; no rendering'),
    'phase': (['--headless', '--script', 'tools/animation_phase_test.gd'], r'ANIMATION PHASE PASS: unequal holds, directional remapping, cycle boundaries and roundtrip'),
    'dialogue-scene': (['--headless', '--script', 'tools/dialogue_scene_test.gd'], r'DIALOGUE SCENE PASS: \d+ checks'),
    'companion-liveliness': (['--headless', '--script', 'tools/companion_liveliness_test.gd'], r'COMPANION LIVELINESS PASS: \d+ checks; \d+ companions drawn'),
    'companion-art': (['--headless', '--script', 'tools/companion_art_test.gd'], r'COMPANION ART PASS: \d+ of \d+ companions'),
    'gunfight': (['--headless', '--script', 'tools/gunfight_test.gd'], r'GUNFIGHT PASS: \d+ checks; aim decides the shot, range degrades it, cover stops it, he shoots back on a tell, a hit costs and recovers, and the room still finishes'),
    'rustler-choice': (['--headless', '--script', 'tools/rustler_choice_test.gd'], r'RUSTLER CHOICE PASS: \d+ checks; three answers, three durable outcomes, one decision each, room still finishable'),
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
    parser.add_argument('checks', nargs='*', metavar='CHECK', help='state, phase, turn, clock, lantern, lantern-view, lantern-controller, banter, banter-delivery, steam, ada, storage, snapshot, compile, room, companion, or motion; defaults to state')
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
