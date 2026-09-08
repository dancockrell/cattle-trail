extends RefCounted
## Shared company restores wellbeing; this model never grants romance or identity.
const SAVE_VERSION := 1
const RECOVERY := 10.0
const MINUTES_SPENT := 30.0
const COOLDOWN_MINUTES := 1440.0
var next_available: Dictionary = {}

func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))

func _id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.strip_edges().is_empty()

func request(actor_ids: Array, currentmadness: Dictionary, now_minutes: float, mutual: bool) -> Dictionary:
	if actor_ids.size() != 2 or not _id(actor_ids[0]) or not _id(actor_ids[1]) or actor_ids[0] == actor_ids[1]:
		return {"ok":false,"event":"invalid_participants"}
	if not is_finite(now_minutes) or now_minutes < 0.0 or not is_finite(now_minutes + COOLDOWN_MINUTES):
		return {"ok":false,"event":"invalid_time"}
	for actor in actor_ids:
		if not currentmadness.has(actor) or not _number(currentmadness[actor]) or float(currentmadness[actor]) < 0.0 or float(currentmadness[actor]) > 100.0:
			return {"ok":false,"event":"invalid_madness"}
	if not mutual: return {"ok":false,"event":"not_mutual"}
	var ready_at := now_minutes
	for actor in actor_ids:
		ready_at = maxf(ready_at,float(next_available.get(actor,0.0)))
	if ready_at > now_minutes: return {"ok":false,"event":"cooldown","next_available_minutes":ready_at}
	var recovered: Dictionary = {}
	var after: Dictionary = {}
	for actor in actor_ids:
		recovered[actor] = minf(RECOVERY,float(currentmadness[actor]))
		after[actor] = maxf(0.0,float(currentmadness[actor])-RECOVERY)
	# No caller-owned arrays or dictionaries are retained or mutated.
	for actor in actor_ids: next_available[actor] = now_minutes + COOLDOWN_MINUTES
	return {"ok":true,"event":"camp_recovery","actors":actor_ids.duplicate(),"recovery":recovered,"after":after,"minutes_spent":MINUTES_SPENT,"next_available_minutes":now_minutes+COOLDOWN_MINUTES}

func to_dict() -> Dictionary:
	return {"version":SAVE_VERSION,"next_available":next_available.duplicate(true)}

func load_dict(data: Dictionary) -> bool:
	if data.size() != 2 or not data.has("version") or not data.has("next_available"): return false
	if not _number(data.version) or float(data.version) != SAVE_VERSION: return false
	if typeof(data.next_available) != TYPE_DICTIONARY: return false
	var candidate: Dictionary = {}
	for actor in data.next_available:
		if not _id(actor) or not _number(data.next_available[actor]) or float(data.next_available[actor]) < 0.0: return false
		candidate[actor] = float(data.next_available[actor])
	next_available = candidate
	return true
