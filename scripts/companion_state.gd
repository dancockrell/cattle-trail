extends RefCounted
## One-companion simulation state. The room owns proximity, input and game time.
## Balance values are provisional; recruitment never implies a romantic stage.

const SAVE_VERSION := 2
const ELEANOR_AGE := 24
const ADVENTURE_ID := "clear_fork_steady_company"
const REQUIRED_CATTLE := 3
const REST_MINUTES := 30.0
const REST_COOLDOWN_MINUTES := 1440.0
const REST_RECOVERY := 10.0
const Perks = preload("res://scripts/companion_perks.gd")

var recruitment := "available"
var relationship_stage := "acquainted"
var trust := 10
var affection := 0
var party_assignment := "none"
var madness := {"player": 10.0, "eleanor": 10.0, "rustler": 35.0}
var adventure_status := "not_started"
var steadied_cattle: Array[String] = []
var controlled_actor := "player"
var events := {"adventure_completed": false, "romance_chosen": false}
var next_rest_minute := 0.0
var rest_count := 0

func recruit(herd_complete: bool, mutual_acceptance: bool) -> Dictionary:
	if recruitment == "recruited":
		return _result(false, "already_recruited")
	if not herd_complete:
		return _result(false, "herd_incomplete")
	if not mutual_acceptance:
		return _result(false, "not_accepted")
	recruitment = "recruited"
	party_assignment = "camp"
	return _result(true, "recruited")

func begin_adventure(action_in_flight: bool = false) -> Dictionary:
	if recruitment != "recruited":
		return _result(false, "not_recruited")
	if action_in_flight:
		return _result(false, "action_in_flight")
	if adventure_status == "completed":
		return _result(false, "already_completed")
	if adventure_status == "active":
		return _result(false, "already_active")
	adventure_status = "active"
	controlled_actor = "eleanor"
	party_assignment = "field"
	return _result(true, "adventure_started")

func steady_cattle(cattle_id: String) -> Dictionary:
	if adventure_status != "active" or controlled_actor != "eleanor":
		return _result(false, "adventure_inactive")
	if cattle_id.is_empty() or cattle_id.length() > 128:
		return _result(false, "invalid_cattle_id")
	if steadied_cattle.has(cattle_id):
		return _result(false, "already_steadied")
	if steadied_cattle.size() >= REQUIRED_CATTLE:
		return _result(false, "all_cattle_steadied")
	steadied_cattle.append(cattle_id)
	return {"ok": true, "reason": "cattle_steadied", "count": steadied_cattle.size(), "ready_to_finish": steadied_cattle.size() == REQUIRED_CATTLE}

func finish_adventure() -> Dictionary:
	if events.adventure_completed:
		return _result(false, "already_completed")
	if adventure_status != "active":
		return _result(false, "adventure_inactive")
	if steadied_cattle.size() != REQUIRED_CATTLE:
		return _result(false, "cattle_remaining")
	adventure_status = "completed"
	controlled_actor = "player"
	party_assignment = "camp"
	events.adventure_completed = true
	trust = mini(100, trust + 20)
	relationship_stage = "trusted"
	return {"ok": true, "reason": "adventure_completed", "trust_gained": 20, "romance_started": false}

func cancel_adventure() -> Dictionary:
	if adventure_status != "active":
		return _result(false, "adventure_inactive")
	adventure_status = "paused"
	controlled_actor = "player"
	party_assignment = "camp"
	# Preserve progress so retrying cannot award a second event for a cattle ID.
	return _result(true, "adventure_paused")

func choose_romance(mutual_acceptance: bool) -> Dictionary:
	if not events.adventure_completed:
		return _result(false, "adventure_incomplete")
	if events.romance_chosen:
		return _result(false, "already_chosen")
	if not mutual_acceptance:
		return _result(false, "not_accepted")
	events.romance_chosen = true
	relationship_stage = "courting"
	affection = mini(100, affection + 10)
	return _result(true, "mutual_romance")

func shared_rest(now_minutes: float, mutual_acceptance: bool) -> Dictionary:
	if not is_finite(now_minutes) or now_minutes < 0.0:
		return _result(false, "invalid_time")
	if recruitment != "recruited" or not events.adventure_completed:
		return _result(false, "trusted_company_required")
	if adventure_status == "active" or party_assignment != "camp":
		return _result(false, "return_to_camp")
	if not mutual_acceptance:
		return _result(false, "not_accepted")
	if now_minutes < next_rest_minute:
		return {"ok": false, "reason": "rest_cooldown", "available_at_minute": next_rest_minute}
	var player_before: float = madness.player
	var eleanor_before: float = madness.eleanor
	var perk_bonus := Perks.value([{"id":"eleanor", "perk_id":"eleanor_perk", "recruitment":recruitment, "party_assignment":party_assignment}], "camp", "rest_madness_recovery")
	add_madness("player", -(REST_RECOVERY + perk_bonus))
	add_madness("eleanor", -REST_RECOVERY)
	next_rest_minute = now_minutes + REST_COOLDOWN_MINUTES
	rest_count += 1
	return {"ok": true, "reason": "shared_rest", "minutes_spent": REST_MINUTES, "player_recovered": player_before - madness.player, "eleanor_recovered": eleanor_before - madness.eleanor, "perk_bonus": perk_bonus, "available_at_minute": next_rest_minute}

func add_madness(actor_id: String, delta: float) -> bool:
	if not madness.has(actor_id) or not is_finite(delta):
		return false
	madness[actor_id] = clampf(float(madness[actor_id]) + delta, 0.0, 100.0)
	return true

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "character_id": "eleanor", "age": ELEANOR_AGE, "recruitment": recruitment, "relationship_stage": relationship_stage, "trust": trust, "affection": affection, "party_assignment": party_assignment, "madness": madness.duplicate(true), "adventure_id": ADVENTURE_ID, "adventure_status": adventure_status, "steadied_cattle": steadied_cattle.duplicate(), "controlled_actor": controlled_actor, "events": events.duplicate(true), "next_rest_minute": next_rest_minute, "rest_count": rest_count}

func load_dict(data: Dictionary) -> bool:
	# Validate fully before mutation. JSON restores numbers as floats.
	if not data.has("version") or not _whole_number(data.version, 1, SAVE_VERSION):
		return false
	var candidate: Dictionary = data.duplicate(true)
	if candidate.version == 1:
		if not candidate.has("madness") or not candidate.madness is Dictionary:
			return false
		# Original v1 saves tracked only player and Eleanor. Never mutate input.
		if candidate.madness.size() == 2 and candidate.madness.has("player") and candidate.madness.has("eleanor"):
			candidate.madness["rustler"] = 35.0
		candidate.version = SAVE_VERSION
	if not _valid_save(candidate):
		return false
	recruitment = candidate.recruitment
	relationship_stage = candidate.relationship_stage
	trust = int(candidate.trust)
	affection = int(candidate.affection)
	party_assignment = candidate.party_assignment
	madness = candidate.madness.duplicate(true)
	adventure_status = candidate.adventure_status
	steadied_cattle.assign(candidate.steadied_cattle)
	controlled_actor = candidate.controlled_actor
	events = candidate.events.duplicate(true)
	next_rest_minute = float(candidate.next_rest_minute)
	rest_count = int(candidate.rest_count)
	return true

func _valid_save(d: Dictionary) -> bool:
	for key in to_dict():
		if not d.has(key):
			return false
	for key in ["character_id", "adventure_id", "recruitment", "relationship_stage", "party_assignment", "controlled_actor", "adventure_status"]:
		if not d[key] is String:
			return false
	if not _whole_number(d.version, SAVE_VERSION, SAVE_VERSION) or not _whole_number(d.age, ELEANOR_AGE, ELEANOR_AGE):
		return false
	if d.version != SAVE_VERSION or d.character_id != "eleanor" or d.age != ELEANOR_AGE or d.adventure_id != ADVENTURE_ID:
		return false
	if d.recruitment not in ["available", "recruited"] or d.relationship_stage not in ["acquainted", "trusted", "courting"]:
		return false
	if d.party_assignment not in ["none", "camp", "field"] or d.controlled_actor not in ["player", "eleanor"]:
		return false
	if d.adventure_status not in ["not_started", "active", "paused", "completed"]:
		return false
	if not _whole_number(d.trust, 0, 100) or not _whole_number(d.affection, 0, 100) or not _whole_number(d.rest_count, 0, 1000000):
		return false
	if not _number_in_range(d.next_rest_minute, 0.0, 1000000000000.0):
		return false
	if not d.madness is Dictionary or d.madness.size() != 3:
		return false
	for actor_id in ["player", "eleanor", "rustler"]:
		if not d.madness.has(actor_id) or not _number_in_range(d.madness[actor_id], 0.0, 100.0):
			return false
	if not d.events is Dictionary or d.events.size() != 2:
		return false
	for event_id in ["adventure_completed", "romance_chosen"]:
		if not d.events.has(event_id) or not d.events[event_id] is bool:
			return false
	if not d.steadied_cattle is Array or d.steadied_cattle.size() > REQUIRED_CATTLE:
		return false
	var unique := {}
	for cattle_id in d.steadied_cattle:
		if not cattle_id is String or cattle_id.is_empty() or cattle_id.length() > 128 or unique.has(cattle_id):
			return false
		unique[cattle_id] = true
	if (d.adventure_status == "active") != (d.controlled_actor == "eleanor"):
		return false
	if (d.party_assignment == "field") != (d.adventure_status == "active"):
		return false
	if d.recruitment == "available" and (d.party_assignment != "none" or d.adventure_status != "not_started"):
		return false
	if d.recruitment == "recruited" and d.party_assignment == "none":
		return false
	if d.adventure_status == "not_started" and not d.steadied_cattle.is_empty():
		return false
	if d.events.adventure_completed != (d.adventure_status == "completed"):
		return false
	if d.events.adventure_completed and d.steadied_cattle.size() != REQUIRED_CATTLE:
		return false
	if d.events.romance_chosen and not d.events.adventure_completed:
		return false
	var expected_stage := "courting" if d.events.romance_chosen else ("trusted" if d.events.adventure_completed else "acquainted")
	if d.relationship_stage != expected_stage:
		return false
	if d.rest_count > 0 and (not d.events.adventure_completed or d.next_rest_minute <= 0):
		return false
	if d.rest_count == 0 and d.next_rest_minute != 0:
		return false
	return true

func _number_in_range(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_in_range(value, minimum, maximum) and float(value) == floorf(float(value))

func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason}
