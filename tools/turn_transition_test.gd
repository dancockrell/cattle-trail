extends SceneTree
const Transition = preload("res://scripts/turn_transition.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var definitions := {
		"northwest": {"north": {
			"idle": {"clip": "turn_nnw_grounded", "seconds": 0.08},
			"walk": {"clip": "turn_nnw_passing", "seconds": 0.10}}},
		"north": {"northeast": {
			"walk": {"clip": "turn_nne_passing", "seconds": 0.09}}}}
	var turn := Transition.new()
	check(turn.request("east", "west", true, 0.3, definitions).is_empty(), "Missing pair must not invent a bridge")
	check(turn.request("north", "north", true, 0.3, definitions).is_empty(), "Same direction needs no bridge")
	check(turn.request("north", "northeast", false, 0.3, definitions).is_empty(), "Missing idle does not borrow walk")
	var start := turn.request("northwest", "north", false, 0.3, definitions)
	check(start.get("clip") == "turn_nnw_grounded", "Idle selects grounded authored clip")
	turn.cancel()
	start = turn.request("northwest", "north", true, 1.37, definitions)
	check(start.get("clip") == "turn_nnw_passing", "Moving selects authored passing clip")
	check(is_equal_approx(float(start.get("phase", -1)), 0.37), "Elapsed gait phase wraps and survives")
	check(turn.step(0.04).is_empty(), "Incomplete bridge emits no completion")
	var repeated := turn.request("northwest", "north", true, 0.9, definitions)
	check(is_equal_approx(float(repeated.get("remaining", -1)), 0.06), "Repeated input does not restart timer")
	check(is_equal_approx(float(repeated.get("phase", -1)), 0.37), "Repeated input does not overwrite preserved gait phase")
	var retarget := turn.request("north", "northeast", true, 0.37, definitions)
	check(retarget.get("to") == "northeast" and retarget.get("clip") == "turn_nne_passing", "Rapid retarget replaces old bridge")
	var done := turn.step(0.20)
	check(done.get("completed", false) and done.get("to") == "northeast", "Completion reports only latest target")
	check(is_equal_approx(float(done.get("phase", -1)), 0.37), "Completion preserves gait phase")
	check(not turn.active and turn.step(1.0).is_empty(), "Completion fires once")
	turn.request("northwest", "north", true, 0.5, definitions)
	check(turn.request("north", "west", true, 0.5, definitions).is_empty() and not turn.active, "Unconfigured retarget cancels stale bridge")
	turn.request("northwest", "north", true, 0.5, definitions)
	turn.cancel()
	check(turn.step(1.0).is_empty() and turn.snapshot().is_empty(), "Action cancel cannot emit delayed completion")
	definitions["northwest"]["north"]["walk"]["seconds"] = 99.0
	start = turn.request("northwest", "north", true, -0.1, definitions)
	check(is_equal_approx(float(start.get("duration", -1)), Transition.MAX_SECONDS), "Authored duration is bounded")
	check(is_equal_approx(float(start.get("phase", -1)), 0.9), "Negative phase normalizes")
	turn.step(-1.0)
	check(is_equal_approx(turn.remaining, Transition.MAX_SECONDS), "Negative delta cannot extend or advance timer")
	if failures == 0:
		print("TURN TRANSITION PASS: authored modes, missing bridge, phase, finite hold, retarget, action cancel, completion")
	quit(1 if failures > 0 else 0)
