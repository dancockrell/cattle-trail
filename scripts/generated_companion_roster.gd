extends RefCounted
## Resolved identities persist without consulting or rerolling the factory.
const VERSION := 1
const RELATIONSHIPS := ["unmet", "unfamiliar", "acquainted", "trusted", "courting", "partnered"]
var _records: Array[Dictionary] = []
var _allow_preview := false

func _init(allow_production_preview := false) -> void:
	_allow_preview = allow_production_preview

func _integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and floorf(float(value)) == float(value)

func _json_value(value, depth := 0) -> bool:
	if depth > 32: return false
	if value == null or value is bool or value is String or value is int: return true
	if value is float: return is_finite(value)
	if value is Array:
		for item in value:
			if not _json_value(item, depth + 1): return false
		return true
	if value is Dictionary:
		for key in value:
			if not key is String or not _json_value(value[key], depth + 1): return false
		return true
	return false

func _valid(record: Dictionary, preview: bool) -> bool:
	if not _json_value(record): return false
	for key in ["id", "art_id", "name", "family", "temperament", "perk_id", "perk_status", "animation_status"]:
		if not record.get(key) is String or record[key].is_empty(): return false
	if record.get("origin") != "generated" or not _integer(record.get("age"), 18, 100): return false
	if not record.get("production_preview") is bool: return false
	if record.production_preview and not preview: return false
	if record.get("romance_requires_mutual_acceptance") != true: return false
	if not record.get("romance_requires_mutual_acceptance") is bool: return false
	if not record.get("recruitment") in ["available", "recruited"]: return false
	if not record.get("relationship") in RELATIONSHIPS: return false
	if not record.get("party_assignment") in ["none", "camp", "field"]: return false
	if record.recruitment != "recruited" and record.party_assignment != "none": return false
	for key in ["trust", "affection"]:
		if not _integer(record.get(key), 0, 100): return false
	if not (record.get("madness") is int or record.get("madness") is float) or not is_finite(float(record.madness)) or record.madness < 0 or record.madness > 100: return false
	if not record.get("activity_rewards") is Dictionary: return false
	for key in record.activity_rewards:
		if key.is_empty() or not record.activity_rewards[key] is bool or record.activity_rewards[key] != true: return false
	var sprite = record.get("sprite")
	if not sprite is Dictionary or not sprite.get("atlas") is String or sprite.atlas.is_empty(): return false
	if not sprite.get("rect") is Array or sprite.rect.size() != 4: return false
	if not sprite.get("anchor") is Array or sprite.anchor.size() != 2: return false
	for i in range(4):
		if not _integer(sprite.rect[i], 0 if i < 2 else 1, 1000000): return false
	for i in range(2):
		if not _integer(sprite.anchor[i], 0, int(sprite.rect[i + 2]) - 1): return false
	return true

func import_records(resolved: Array, allow_production_preview := false) -> bool:
	var combined: Array = _records.duplicate(true)
	for value in resolved:
		if not value is Dictionary or not _json_value(value): return false
		var record: Dictionary = value.duplicate(true)
		if not record.has("party_assignment"): record.party_assignment = "none"
		if not record.has("activity_rewards"): record.activity_rewards = {}
		combined.append(record)
	return _replace(combined, _allow_preview or allow_production_preview)

func _replace(values: Array, preview: bool) -> bool:
	var ids := {}
	var art_ids := {}
	var candidate: Array[Dictionary] = []
	for value in values:
		if not value is Dictionary or not _valid(value, preview): return false
		if ids.has(value.id) or art_ids.has(value.art_id): return false
		ids[value.id] = true
		art_ids[value.art_id] = true
		candidate.append(value.duplicate(true))
	_records = candidate
	return true

func to_dict() -> Dictionary:
	return {"version": VERSION, "records": _records.duplicate(true)}

func load_dict(data, allow_production_preview := false) -> bool:
	if not data is Dictionary or not _json_value(data): return false
	if data.size() != 2 or not _integer(data.get("version"), VERSION, VERSION): return false
	if not data.get("records") is Array: return false
	return _replace(data.records, _allow_preview or allow_production_preview)

func to_json() -> String:
	return JSON.stringify(to_dict())

func load_json(text: String, allow_production_preview := false) -> bool:
	var parsed := JSON.new()
	if parsed.parse(text) != OK: return false
	return load_dict(parsed.data, allow_production_preview)

func _find(id: String) -> Dictionary:
	for record in _records:
		if record.id == id: return record
	return {}

func get_record(id: String) -> Dictionary:
	return _find(id).duplicate(true)

func recruit(id: String, accepted_choice: bool) -> bool:
	var record := _find(id)
	if record.is_empty() or not accepted_choice or record.recruitment != "available": return false
	record.recruitment = "recruited"
	return true

func assign(id: String, assignment: String) -> bool:
	var record := _find(id)
	if record.is_empty() or record.recruitment != "recruited" or assignment not in ["none", "camp", "field"]: return false
	record.party_assignment = assignment
	return true

func choose_relationship(id: String, stage: String, mutual_acceptance: bool) -> bool:
	var record := _find(id)
	if record.is_empty() or not mutual_acceptance or stage not in RELATIONSHIPS: return false
	if stage == record.relationship: return false
	record.relationship = stage
	return true

func reward_activity(id: String, activity_id: String, trust_delta: int, affection_delta: int, madness_delta: int) -> bool:
	var record := _find(id)
	if record.is_empty() or activity_id.is_empty() or record.activity_rewards.has(activity_id): return false
	if trust_delta < -100 or trust_delta > 100 or affection_delta < -100 or affection_delta > 100 or madness_delta < -100 or madness_delta > 100: return false
	record.trust = clampi(int(record.trust) + trust_delta, 0, 100)
	record.affection = clampi(int(record.affection) + affection_delta, 0, 100)
	record.madness = clampf(float(record.madness) + madness_delta, 0, 100)
	record.activity_rewards[activity_id] = true
	return true

func perk_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in _records:
		if record.recruitment == "recruited": result.append(record.duplicate(true))
	return result

func perk_state_records() -> Array[Dictionary]:
	return perk_state()
