extends RefCounted
## Caller validates physical arrivals and commits milestone rewards with this state.
const SAVE_VERSION := 1
const ADVENTURE_ID := "two_seats_one_regulator"
const MILESTONE_ID := "two_seats_one_regulator_completed"
const PATTERN := [true, false, true]
const STAGES := ["inspect", "route_pressure", "drive", "return_to_camp", "completed"]
var status := "not_started"
var stage := "inspect"
var controlled_actor := "player"
var valves: Array[bool] = [false, false, false]
var checkpoints: Array[int] = []
var strain := 0
var milestone_completed := false
var romance_chosen := false

func _result(ok: bool, event: String) -> Dictionary:
	return {"ok": ok, "event": event}

func begin(recruited: bool, action_in_flight: bool = false) -> Dictionary:
	if status != "not_started": return _result(false,"already_started")
	if not recruited: return _result(false,"not_recruited")
	if action_in_flight: return _result(false,"action_in_flight")
	status = "active"
	controlled_actor = "ada_cart"
	return _result(true,"adventure_started")

func inspect() -> Dictionary:
	if status != "active" or stage != "inspect": return _result(false,"not_inspecting")
	stage = "route_pressure"
	return _result(true,"inspection_complete")

func set_valve(index: int, opened: bool) -> Dictionary:
	if status != "active" or stage != "route_pressure": return _result(false,"not_routing")
	if index < 0 or index >= 3: return _result(false,"unknown_valve")
	valves[index] = opened
	return _result(true,"valve_changed")

func toggle_valve(index: int) -> Dictionary:
	if index < 0 or index >= 3: return _result(false,"unknown_valve")
	return set_valve(index,not valves[index])

func confirm_routing() -> Dictionary:
	if status != "active" or stage != "route_pressure": return _result(false,"not_routing")
	if valves != PATTERN:
		# Bounded to the exact JSON integer range; ordinary play never reaches this.
		if strain >= 2147483647: return _result(false,"strain_limit")
		strain += 1
		var result := _result(false,"routing_incorrect")
		result["strain_delta"] = 1
		return result
	stage = "drive"
	return _result(true,"routing_complete")

func checkpoint_arrived(id: int) -> Dictionary:
	if status != "active" or stage != "drive": return _result(false,"not_driving")
	if id != checkpoints.size(): return _result(false,"out_of_order_checkpoint")
	checkpoints.append(id)
	if checkpoints.size() == 3: stage = "return_to_camp"
	return _result(true,"checkpoint_reached")

func finish_at_camp(at_camp: bool) -> Dictionary:
	if milestone_completed: return _result(false,"already_completed")
	if status != "active" or stage != "return_to_camp": return _result(false,"objectives_incomplete")
	if not at_camp: return _result(false,"not_at_camp")
	status = "completed"
	stage = "completed"
	controlled_actor = "player"
	milestone_completed = true
	var result := _result(true,"adventure_completed")
	result["completion"] = {"milestone_id":MILESTONE_ID,"adventure_id":ADVENTURE_ID,"character_id":"ada_mercer","romance_required":false,"reward_applied":false}
	return result

func pause() -> Dictionary:
	if status != "active": return _result(false,"not_active")
	status = "paused"
	controlled_actor = "player"
	return _result(true,"adventure_paused")

func choose_romance(mutual: bool) -> Dictionary:
	if status != "completed": return _result(false,"outing_incomplete")
	if romance_chosen: return _result(false,"already_chosen")
	if not mutual: return _result(false,"not_mutual")
	romance_chosen = true
	return _result(true,"mutual_kiss")

func resume(recruited: bool, action_in_flight: bool = false) -> Dictionary:
	if status != "paused": return _result(false,"not_paused")
	if not recruited: return _result(false,"not_recruited")
	if action_in_flight: return _result(false,"action_in_flight")
	status = "active"
	controlled_actor = "ada_cart"
	return _result(true,"adventure_resumed")

func to_dict() -> Dictionary:
	return {"version":SAVE_VERSION,"status":status,"stage":stage,"controlled_actor":controlled_actor,"valves":valves.duplicate(),"checkpoints":checkpoints.duplicate(),"strain":strain,"milestone_completed":milestone_completed,"romance_chosen":romance_chosen}

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

func load_dict(data: Dictionary) -> bool:
	var keys := ["version","status","stage","controlled_actor","valves","checkpoints","strain","milestone_completed","romance_chosen"]
	if data.size() != keys.size(): return false
	for key in keys:
		if not data.has(key): return false
	if not _integer(data.version,1,1) or not _integer(data.strain,0,2147483647): return false
	if typeof(data.status) != TYPE_STRING or not ["not_started","active","paused","completed"].has(data.status): return false
	if typeof(data.stage) != TYPE_STRING or not STAGES.has(data.stage): return false
	if typeof(data.controlled_actor) != TYPE_STRING or data.controlled_actor != ("ada_cart" if data.status == "active" else "player"): return false
	if typeof(data.milestone_completed) != TYPE_BOOL: return false
	if typeof(data.romance_chosen) != TYPE_BOOL or (data.romance_chosen and data.status != "completed"): return false
	if typeof(data.valves) != TYPE_ARRAY or data.valves.size() != 3: return false
	for valve in data.valves:
		if typeof(valve) != TYPE_BOOL: return false
	if typeof(data.checkpoints) != TYPE_ARRAY or data.checkpoints.size() > 3: return false
	for index in range(data.checkpoints.size()):
		if not _integer(data.checkpoints[index],index,index): return false
	if data.milestone_completed != (data.status == "completed"): return false
	if (data.stage == "completed") != (data.status == "completed"): return false
	if data.status == "not_started" and (data.stage != "inspect" or data.strain != 0 or data.valves != [false,false,false]): return false
	if data.stage == "inspect" and (data.strain != 0 or data.valves != [false,false,false]): return false
	if data.stage in ["inspect","route_pressure"] and not data.checkpoints.is_empty(): return false
	if data.stage in ["drive","return_to_camp","completed"] and data.valves != PATTERN: return false
	if data.stage == "drive" and data.checkpoints.size() >= 3: return false
	if data.stage in ["return_to_camp","completed"] and data.checkpoints.size() != 3: return false
	# Commit only after the complete candidate has passed all checks.
	status = data.status
	stage = data.stage
	controlled_actor = data.controlled_actor
	valves.assign(data.valves)
	checkpoints.clear()
	for id in data.checkpoints: checkpoints.append(int(id))
	strain = int(data.strain)
	milestone_completed = data.milestone_completed
	romance_chosen = data.romance_chosen
	return true
