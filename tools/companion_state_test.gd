extends SceneTree

const State = preload("res://scripts/companion_state.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var state = State.new()
	_check(state.ELEANOR_AGE == 24, "Eleanor is the authored adult age")
	_check(state.madness.rustler == 35, "Rustler starts with his own madness meter")
	_check(not state.begin_adventure().ok, "Cannot control an unrecruited companion")
	_check(not state.recruit(false, true).ok, "Herd completion gates recruitment")
	_check(not state.recruit(true, false).ok, "Declining invitation leaves state untouched")
	_check(state.recruitment == "available" and state.relationship_stage == "acquainted", "Recruitment refusal has no relationship penalty")
	_check(state.recruit(true, true).ok, "Recruit after the room objective")
	_check(state.relationship_stage == "acquainted" and state.affection == 0, "Recruitment is not romance")
	_check(not state.recruit(true, true).ok, "Duplicate recruitment has no effect")
	_check(not state.begin_adventure(true).ok and state.controlled_actor == "player", "Active action prevents control handoff")
	_check(state.begin_adventure().ok and state.controlled_actor == "eleanor", "Adventure gives Eleanor control")
	_check(state.steady_cattle("cow_a").ok, "First unique cattle interaction")
	_check(not state.steady_cattle("cow_a").ok and state.steadied_cattle.size() == 1, "Repeated cattle cannot advance objective")
	_check(not state.finish_adventure().ok, "Cannot complete with missing cattle")
	_check(state.cancel_adventure().ok and state.controlled_actor == "player", "Cancel returns player control")
	_check(not state.steady_cattle("cow_b").ok, "Cannot progress while paused")
	_check(state.begin_adventure().ok and state.steadied_cattle.size() == 1, "Resume preserves unique progress")
	# JSON roundtrip during active play must preserve control and the cattle ledger.
	var restored = State.new()
	_check(restored.load_dict(JSON.parse_string(JSON.stringify(state.to_dict()))), "Active save loads through JSON")
	_check(restored.controlled_actor == "eleanor" and not restored.steady_cattle("cow_a").ok, "Loaded adventure cannot duplicate a cattle event")
	_check(restored.steady_cattle("cow_b").ok and restored.steady_cattle("cow_c").ready_to_finish, "Three unique cattle unlock completion")
	_check(not restored.steady_cattle("cow_d").ok, "Objective does not accept an extra reward target")
	_check(restored.finish_adventure().ok, "Adventure completion applies once")
	_check(restored.trust == 30 and restored.relationship_stage == "trusted" and restored.controlled_actor == "player", "Shared adventure grants trust and returns control, not romance")
	_check(not restored.finish_adventure().ok and restored.trust == 30, "Duplicate completion cannot farm trust")
	_check(not restored.begin_adventure().ok, "Completed adventure cannot restart for rewards")
	_check(not restored.choose_romance(false).ok and restored.relationship_stage == "trusted", "Optional romantic beat can be declined")
	# Shared care is available to trusted companions without choosing romance.
	restored.add_madness("player", 40)
	restored.add_madness("eleanor", 30)
	var before: Dictionary = restored.to_dict()
	_check(not restored.shared_rest(100, false).ok and restored.to_dict() == before, "Declined recovery consumes no time or cooldown")
	var rest: Dictionary = restored.shared_rest(100, true)
	_check(rest.ok and rest.player_recovered == 13 and rest.eleanor_recovered == 10 and rest.minutes_spent == 30, "Camp recovery applies Eleanor's +3 perk only to the player")
	_check(restored.relationship_stage == "trusted", "Recovery does not force romance")
	_check(restored.madness.rustler == 35, "Companion shared rest does not recover an absent rustler")
	var loaded = State.new()
	_check(loaded.load_dict(JSON.parse_string(JSON.stringify(restored.to_dict()))), "Post-reward save loads")
	_check(not loaded.finish_adventure().ok and loaded.trust == 30, "Loaded completion cannot pay twice")
	_check(not loaded.shared_rest(100, true).ok and not loaded.shared_rest(1539, true).ok, "Loaded recovery cooldown blocks repeated reward")
	_check(loaded.shared_rest(1540, true).ok and loaded.rest_count == 2, "Recovery unlocks at the exact cooldown boundary")
	_check(loaded.choose_romance(true).ok and loaded.relationship_stage == "courting", "Explicit mutual beat starts romance separately")
	_check(not loaded.choose_romance(true).ok and loaded.affection == 10, "Romance event cannot duplicate affection")
	_check(loaded.add_madness("player", 1000) and loaded.madness.player == 100, "Madness upper bound")
	_check(loaded.add_madness("eleanor", -1000) and loaded.madness.eleanor == 0, "Madness lower bound")
	_check(loaded.add_madness("rustler", 1000) and loaded.madness.rustler == 100, "Rustler madness upper bound")
	_check(loaded.add_madness("rustler", -1000) and loaded.madness.rustler == 0, "Rustler madness lower bound")
	loaded.add_madness("rustler", 61)
	_check(not loaded.add_madness("unknown", 1) and not loaded.add_madness("player", NAN), "Invalid actor and non-finite madness rejected")
	_check(not loaded.shared_rest(NAN, true).ok and not loaded.shared_rest(-1, true).ok, "Invalid game times rejected")
	var snapshot: Dictionary = loaded.to_dict()
	var detached: Dictionary = loaded.to_dict()
	detached.madness.player = 0
	detached.steadied_cattle.clear()
	_check(loaded.to_dict() == snapshot, "Exported save cannot mutate live nested state")
	for corruption in ["age", "events", "duplicate_cattle", "madness", "control", "missing_key"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match corruption:
			"age": bad.age = 17
			"events": bad.events.adventure_completed = false
			"duplicate_cattle": bad.steadied_cattle = ["cow_a", "cow_a", "cow_c"]
			"madness": bad.madness.player = 101
			"control": bad.controlled_actor = "eleanor"
			"missing_key": bad.erase("next_rest_minute")
		_check(not loaded.load_dict(bad) and loaded.to_dict() == snapshot, "Reject malformed save atomically: " + corruption)
	var current = State.new()
	_check(current.load_dict(JSON.parse_string(JSON.stringify(snapshot))) and current.madness.rustler == 61, "V2 JSON roundtrip preserves rustler madness")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 1
	legacy.madness.erase("rustler")
	var legacy_before: Dictionary = legacy.duplicate(true)
	var migrated = State.new()
	_check(migrated.load_dict(JSON.parse_string(JSON.stringify(legacy))), "Original two-actor v1 JSON save migrates")
	_check(migrated.madness.rustler == 35 and migrated.to_dict().version == 2, "Migration supplies rustler default and emits v2")
	_check(migrated.trust == loaded.trust and migrated.rest_count == loaded.rest_count and migrated.next_rest_minute == loaded.next_rest_minute, "Migration retains progression and cooldown")
	_check(not migrated.finish_adventure().ok and not migrated.choose_romance(true).ok and not migrated.shared_rest(1540, true).ok, "Migrated save cannot duplicate completed rewards")
	_check(migrated.load_dict(legacy) and legacy == legacy_before, "Migration does not alter caller-owned save dictionary")
	var migrated_before: Dictionary = migrated.to_dict()
	var broken_legacy: Dictionary = legacy.duplicate(true)
	broken_legacy.madness.player = "bad"
	_check(not migrated.load_dict(broken_legacy) and migrated.to_dict() == migrated_before, "Failed legacy migration is atomic")
	# Fuzz each schema field with incompatible JSON values; rejection must not throw.
	var invalid_fields := {"version": [], "age": {}, "character_id": null, "adventure_id": [], "recruitment": 5, "relationship_stage": {}, "party_assignment": false, "controlled_actor": [], "adventure_status": {}, "trust": "30", "affection": false, "rest_count": 1.5, "next_rest_minute": INF, "madness": [], "events": [], "steadied_cattle": {}}
	for key in invalid_fields:
		var invalid: Dictionary = snapshot.duplicate(true)
		invalid[key] = invalid_fields[key]
		_check(not loaded.load_dict(invalid) and loaded.to_dict() == snapshot, "Wrong field type rejected atomically: " + key)
	for corruption in ["missing_rustler", "bad_rustler", "extra_actor", "nested_cattle", "nonboolean_event"]:
		var invalid: Dictionary = snapshot.duplicate(true)
		match corruption:
			"missing_rustler": invalid.madness.erase("rustler")
			"bad_rustler": invalid.madness.rustler = NAN
			"extra_actor": invalid.madness["stranger"] = 0
			"nested_cattle": invalid.steadied_cattle = [["cow_a"]]
			"nonboolean_event": invalid.events.romance_chosen = 1
		_check(not loaded.load_dict(invalid) and loaded.to_dict() == snapshot, "Nested malformed state rejected atomically: " + corruption)
	print("COMPANION STATE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
