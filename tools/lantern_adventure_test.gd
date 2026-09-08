extends SceneTree
const Adventure = preload("res://scripts/lantern_adventure.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var a := Adventure.new()
	var fresh := a.to_dict()
	check(a.load_dict(JSON.parse_string(JSON.stringify(fresh))), "Initial version1 JSON roundtrip")
	check(not a.begin(false, false, ["cow_a", "cow_b", "cow_c"]).ok, "Recruitment required")
	check(not a.begin(true, true, ["cow_a", "cow_b", "cow_c"]).ok, "Action-in-flight blocks entry")
	for ids in [["a", "a", "b"], ["a", "b"], ["a", "b", "c", "d"], ["a", "b", " "], ["a", "b", 3]]:
		check(not a.begin(true, false, ids).ok and a.to_dict() == fresh, "Bad roster does not partially start")
	check(a.begin(true, false, ["cow_a", "cow_b", "cow_c"]).ok and a.stage == "carry_lantern" and a.controlled_actor == "eleanor", "Entry locks roster and Eleanor identity")
	check(not a.begin_guiding().ok and not a.finish_at_wagon(true).ok, "Cannot skip spirit or guide checkpoints")
	check(a.pause().ok and a.controlled_actor == "player" and a.stage == "carry_lantern", "Pause returns player preserving checkpoint")
	check(not a.settle_spirit().ok and not a.resume(true, true).ok, "Paused progression and action resume blocked")
	check(a.resume(true).ok and a.settle_spirit().ok and a.stage == "spirit_settled", "Resume then spirit settlement")
	check(not a.guide_cattle("cow_a").ok and a.begin_guiding().ok, "Explicit guide checkpoint required")
	check(not a.guide_cattle("other").ok, "Unknown cattle cannot substitute stable targets")
	check(a.guide_cattle("cow_a").ok and not a.guide_cattle("cow_a").ok, "Each stable cattle ID counts once")
	var failed := a.fail()
	check(failed.ok and failed.return_point_id == "wagon" and a.controlled_actor == "player", "Failure safely returns player")
	var recovered := Adventure.new()
	check(recovered.load_dict(JSON.parse_string(JSON.stringify(a.to_dict()))), "Failed checkpoint roundtrip")
	check(not recovered.retry(false).ok and not recovered.retry(true, true).ok, "Retry checks recruitment and action lock")
	check(recovered.retry(true).ok and recovered.controlled_actor == "eleanor" and recovered.stage == "guide_cattle", "Retry restores Eleanor at same checkpoint")
	check(recovered.guided_cattle == ["cow_a"] and recovered.stranded_cattle == ["cow_a", "cow_b", "cow_c"], "Retry preserves identities and progress")
	check(not recovered.guide_cattle("cow_a").ok and recovered.guide_cattle("cow_b").ok and recovered.guide_cattle("cow_c").ok, "Retry cannot duplicate cattle progression")
	check(recovered.stage == "return_to_wagon" and not recovered.finish_at_wagon(false).ok, "Three cattle require actual wagon return")
	check(recovered.pause().ok and recovered.resume(true).ok and recovered.stage == "return_to_wagon", "Late checkpoint pause retains completed cattle")
	var result := recovered.finish_at_wagon(true)
	check(result.ok and result.completion.milestone_id == Adventure.MILESTONE_ID and not result.completion.reward_applied, "Completion emits stable milestone without applying reward")
	check(recovered.milestone_completed and recovered.stage == "completed" and recovered.controlled_actor == "player", "Completion flag persists and returns player")
	check(not recovered.finish_at_wagon(true).has("completion") and not recovered.retry(true).ok and not recovered.begin(true, false, ["x", "y", "z"]).ok, "Completed instance cannot issue duplicate milestone")
	var loaded := Adventure.new()
	check(loaded.load_dict(JSON.parse_string(JSON.stringify(recovered.to_dict()))) and not loaded.finish_at_wagon(true).has("completion"), "Loaded completion remains one-shot")
	var before := loaded.to_dict()
	var detached := loaded.to_dict()
	detached.guided_cattle.clear()
	check(loaded.to_dict() == before, "Exported arrays are detached")
	for fault in ["version", "fraction", "boolean_version", "extra", "missing", "foreign_actor", "foreign_adventure", "control", "stage", "status", "flag", "duplicate", "unknown", "count", "type", "control_id"]:
		var bad: Dictionary = before.duplicate(true)
		match fault:
			"version": bad.version = 2
			"fraction": bad.version = 1.5
			"boolean_version": bad.version = true
			"extra": bad.extra = 1
			"missing": bad.erase("checkpoint")
			"foreign_actor": bad.character_id = "rustler"
			"foreign_adventure": bad.adventure_id = "other"
			"control": bad.controlled_actor = "eleanor"
			"stage": bad.checkpoint = "carry_lantern"
			"status": bad.status = "paused"
			"flag": bad.milestone_completed = false
			"duplicate": bad.guided_cattle = ["cow_a", "cow_a", "cow_c"]
			"unknown": bad.guided_cattle = ["cow_a", "cow_b", "other"]
			"count": bad.guided_cattle = ["cow_a"]
			"type": bad.stranded_cattle = "cow_a"
			"control_id": bad.stranded_cattle = ["cow_a", "cow_b", "cow\nc"]
		check(not loaded.load_dict(bad) and loaded.to_dict() == before, "Atomic rejection: " + fault)
	var partial := Adventure.new()
	partial.begin(true, false, ["a", "b", "c"])
	var invalid_checkpoint := partial.to_dict()
	invalid_checkpoint.guided_cattle = ["a"]
	check(not partial.load_dict(invalid_checkpoint) and partial.guided_cattle.is_empty(), "Early checkpoint cannot contain guided cattle")
	if failures == 0:
		print("LANTERN ADVENTURE PASS: %d checks; checkpoint identity, retry, strict atomic saves, one-shot milestone; backend only" % checks)
	quit(1 if failures > 0 else 0)
