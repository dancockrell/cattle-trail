extends RefCounted
## Backend-only authored encounter. Caller owns proximity, presentation and rewards.
## Persist this state and the caller's milestone ledger together: the stable event
## key must also be deduplicated by the caller when restoring an older save.

const SAVE_VERSION := 2
const SPIRIT_STRESS := 6.0
const ADVENTURE_ID := "lanterns_at_the_ford"
const CHARACTER_ID := "eleanor"
const MILESTONE_ID := "lanterns_at_the_ford_completed"
const REQUIRED_CATTLE := 3
const STAGES := ["not_started", "carry_lantern", "spirit_settled", "guide_cattle", "return_to_wagon", "completed"]

var stage := "not_started"
var status := "not_started"
var controlled_actor := "player"
var stranded_cattle: Array[String] = []
var guided_cattle: Array[String] = []
var milestone_completed := false
var spirit_exposure_applied := false

func expose_to_spirit() -> Dictionary:
	if status!="active" or stage!="carry_lantern": return _result(false,"not_approaching_spirit")
	if spirit_exposure_applied: return _result(false,"already_exposed")
	spirit_exposure_applied = true
	var result := _result(true,"spirit_exposure")
	result["madness_delta"] = SPIRIT_STRESS
	return result

func begin(recruited: bool, action_in_flight: bool, cattle_ids: Array) -> Dictionary:
	if status != "not_started": return _result(false, "already_started")
	if not recruited: return _result(false, "not_recruited")
	if action_in_flight: return _result(false, "action_in_flight")
	if not _valid_ids(cattle_ids, REQUIRED_CATTLE) or cattle_ids.size() != REQUIRED_CATTLE:
		return _result(false, "invalid_stranded_cattle")
	stranded_cattle.assign(cattle_ids)
	stage = "carry_lantern"
	status = "active"
	controlled_actor = CHARACTER_ID
	return _result(true, "adventure_started")

func settle_spirit() -> Dictionary:
	return _advance("carry_lantern", "spirit_settled", "spirit_settled")

func begin_guiding() -> Dictionary:
	return _advance("spirit_settled", "guide_cattle", "guiding_started")

func guide_cattle(cattle_id: String) -> Dictionary:
	if status != "active" or stage != "guide_cattle": return _result(false, "not_guiding")
	if not stranded_cattle.has(cattle_id): return _result(false, "unknown_cattle")
	if guided_cattle.has(cattle_id): return _result(false, "already_guided")
	guided_cattle.append(cattle_id)
	if guided_cattle.size() == REQUIRED_CATTLE: stage = "return_to_wagon"
	return _result(true, "cattle_guided")

func finish_at_wagon(at_wagon: bool) -> Dictionary:
	if milestone_completed: return _result(false, "already_completed")
	if status != "active" or stage != "return_to_wagon": return _result(false, "objectives_incomplete")
	if not at_wagon: return _result(false, "not_at_wagon")
	stage = "completed"
	status = "completed"
	controlled_actor = "player"
	milestone_completed = true
	var result := _result(true, "adventure_completed")
	result["completion"] = {"milestone_id": MILESTONE_ID, "adventure_id": ADVENTURE_ID,
		"character_id": CHARACTER_ID, "romance_required": false, "reward_applied": false}
	result["return_point_id"] = "wagon"
	return result

func pause() -> Dictionary:
	return _suspend("paused", "adventure_paused")

func fail() -> Dictionary:
	return _suspend("failed", "safe_retry_available")

func resume(recruited: bool, action_in_flight: bool = false) -> Dictionary:
	return _resume("paused", recruited, action_in_flight)

func retry(recruited: bool, action_in_flight: bool = false) -> Dictionary:
	return _resume("failed", recruited, action_in_flight)

func _advance(expected: String, destination: String, reason: String) -> Dictionary:
	if status != "active" or stage != expected: return _result(false, "wrong_checkpoint")
	stage = destination
	return _result(true, reason)

func _suspend(destination: String, reason: String) -> Dictionary:
	if status != "active": return _result(false, "adventure_inactive")
	status = destination
	controlled_actor = "player"
	var result := _result(true, reason)
	result["return_point_id"] = "wagon"
	return result

func _resume(expected: String, recruited: bool, action_in_flight: bool) -> Dictionary:
	if status != expected: return _result(false, "not_" + expected)
	if not recruited: return _result(false, "not_recruited")
	if action_in_flight: return _result(false, "action_in_flight")
	status = "active"
	controlled_actor = CHARACTER_ID
	return _result(true, "checkpoint_resumed")

func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "checkpoint": stage, "status": status,
		"controlled_actor": controlled_actor, "guided_count": guided_cattle.size()}

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "adventure_id": ADVENTURE_ID, "character_id": CHARACTER_ID,
		"checkpoint": stage, "status": status, "controlled_actor": controlled_actor,
		"stranded_cattle": stranded_cattle.duplicate(), "guided_cattle": guided_cattle.duplicate(),
		"milestone_completed": milestone_completed,"spirit_exposure_applied":spirit_exposure_applied}

func load_dict(data: Dictionary) -> bool:
	# Detached candidate, complete validation, then assignment: invalid input is atomic.
	var candidate := data.duplicate(true)
	if not (candidate.get("version") is int or candidate.get("version") is float): return false
	if candidate.get("version")==1:
		if candidate.has("spirit_exposure_applied"): return false
		# Old active checkpoints never gain a surprise retroactive stress charge.
		candidate["spirit_exposure_applied"] = candidate.get("checkpoint","not_started")!="not_started"
		candidate["version"] = SAVE_VERSION
	if not _valid_save(candidate): return false
	stage = candidate.checkpoint
	status = candidate.status
	controlled_actor = candidate.controlled_actor
	stranded_cattle.assign(candidate.stranded_cattle)
	guided_cattle.assign(candidate.guided_cattle)
	milestone_completed = candidate.milestone_completed
	spirit_exposure_applied = candidate.spirit_exposure_applied
	return true

func _valid_save(d: Dictionary) -> bool:
	var expected := to_dict()
	if d.size() != expected.size(): return false
	for key in expected:
		if not d.has(key): return false
	if not (d.version is int or d.version is float): return false
	if not is_finite(float(d.version)) or float(d.version) != float(SAVE_VERSION): return false
	for key in ["adventure_id", "character_id", "checkpoint", "status", "controlled_actor"]:
		if not d[key] is String: return false
	if d.adventure_id != ADVENTURE_ID or d.character_id != CHARACTER_ID: return false
	if d.checkpoint not in STAGES or d.status not in ["not_started", "active", "paused", "failed", "completed"]: return false
	if not d.milestone_completed is bool: return false
	if not d.spirit_exposure_applied is bool: return false
	if not _valid_ids(d.stranded_cattle, REQUIRED_CATTLE) or not _valid_ids(d.guided_cattle, REQUIRED_CATTLE): return false
	for cattle_id in d.guided_cattle:
		if not d.stranded_cattle.has(cattle_id): return false
	if d.checkpoint == "not_started":
		return d.status == "not_started" and d.controlled_actor == "player" and d.stranded_cattle.is_empty() and d.guided_cattle.is_empty() and not d.milestone_completed and not d.spirit_exposure_applied
	if d.stranded_cattle.size() != REQUIRED_CATTLE: return false
	if d.checkpoint == "completed":
		return d.status == "completed" and d.controlled_actor == "player" and d.guided_cattle.size() == REQUIRED_CATTLE and d.milestone_completed
	if d.status not in ["active", "paused", "failed"] or d.milestone_completed: return false
	if d.controlled_actor != (CHARACTER_ID if d.status == "active" else "player"): return false
	if d.checkpoint in ["carry_lantern", "spirit_settled"] and not d.guided_cattle.is_empty(): return false
	if d.checkpoint == "guide_cattle" and d.guided_cattle.size() >= REQUIRED_CATTLE: return false
	if d.checkpoint == "return_to_wagon" and d.guided_cattle.size() != REQUIRED_CATTLE: return false
	return true

func _valid_ids(value: Variant, maximum: int) -> bool:
	if not value is Array or value.size() > maximum: return false
	var unique := {}
	for item in value:
		if not item is String or item.is_empty() or item.length() > 128 or item.strip_edges() != item: return false
		for index in range(item.length()):
			if item.unicode_at(index) < 32 or item.unicode_at(index) == 127: return false
		if unique.has(item): return false
		unique[item] = true
	return true
