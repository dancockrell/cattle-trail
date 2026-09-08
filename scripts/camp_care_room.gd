extends RefCounted
const Recovery = preload("res://scripts/camp_recovery.gd")
var owner
func _init(companion): owner = companion

static func restored_recovery(data: Dictionary):
	var recovery = Recovery.new()
	if data.has("camp_recovery"):
		if not data.camp_recovery is Dictionary or not recovery.load_dict(data.camp_recovery): return null
	var previous: Dictionary = data.get("companion",{})
	if previous.get("rest_count",0)>0:
		var deadline: float = previous.get("next_rest_minute",0.0)
		if data.has("camp_recovery"):
			if recovery.next_available.get("player",0.0)<deadline or recovery.next_available.get("eleanor",0.0)<deadline: return null
		else:
			recovery.next_available["player"] = deadline
			recovery.next_available["eleanor"] = deadline
	return recovery

func _pending() -> bool:
	return owner.cart_adventure.status=="active" or owner.lantern_adventure.status=="active" or owner.state.adventure_status=="active"

func near_ada() -> bool:
	return owner.cart_adventure.status=="completed" and owner.ada_state.recruitment=="recruited" and not owner.is_eleanor() and is_instance_valid(owner.mechanic.ada) and owner.room.player.position.distance_to(owner.mechanic.ada.position)<=45

func rest() -> bool:
	if _pending():
		owner.tell("Pause the companion outing and return to camp before sharing rest.")
		return false
	if owner.room.player.action_time>0 or owner.room.rope_time>0 or owner.room.rope_flight_time>0:
		owner.tell("Finish the current action before resting.")
		return false
	var ada: bool = near_ada()
	if not ada and owner.active_actor().position.distance_to(Vector2(148,127))>55:
		owner.tell("Meet Ada beside the cart or Eleanor at the wagon for shared rest.")
		return false
	var partner := "ada_mercer" if ada else "eleanor"
	var staged = Recovery.new()
	if not staged.load_dict(owner.camp_recovery.to_dict()): return false
	var meters := {"player":owner.state.madness.player}
	meters[partner] = owner.ada_state.madness if ada else owner.state.madness.eleanor
	var result: Dictionary = staged.request(["player",partner],meters,owner.minutes,true)
	if not result.ok:
		owner.tell("Shared rest returns in %d trail minutes." % ceili(maxf(0.0,float(result.get("next_available_minutes",owner.minutes))-owner.minutes)))
		return false
	if ada:
		owner.state.madness.player = result.after.player
		owner.ada_state.madness = result.after.ada_mercer
	else:
		var eleanor_result: Dictionary = owner.state.shared_rest(owner.minutes,true)
		if not eleanor_result.ok:
			owner.tell("Finish Eleanor's three-steer adventure and return her to camp before shared rest.")
			return false
	owner.camp_recovery = staged
	owner.minutes += float(result.minutes_spent)
	if ada:
		owner.room.say_once("ada_camp_rest",owner.mechanic.ada,"ADA","The kettle is behaving. Let's enjoy that while it lasts.",2)
	else: owner.say_event("shared_rest","shared_rest")
	owner.tell("Thirty quiet minutes with Ada. Both recover up to 10 madness; affection is your choice." if ada else "Tea with Eleanor: up to 13 madness recovered for you and 10 for her.")
	owner.save_game()
	return true

func decorate_ui() -> void:
	if _pending(): return
	var button = owner.room.buttons.get_child(4)
	# Caller resets base labels before other encounter decorators; do not overwrite active valve controls.
	button.tooltip_text = "Shared rest: 30 trail minutes. Each participant may rest once per 1440 minutes; changing partners does not reset your cooldown."
	var ada: bool = near_ada()
	var partner := "ada_mercer" if ada else "eleanor"
	var remaining := ceili(maxf(0.0,maxf(float(owner.camp_recovery.next_available.get("player",0)),float(owner.camp_recovery.next_available.get(partner,0)))-owner.minutes))
	if ada:
		owner.room.stats.text = "$%d  HERD 6/6  MADNESS %d  ADA %d" % [owner.room.cash,int(owner.state.madness.player),int(owner.ada_state.madness)]
	button.text = ("Rest with Ada [G]" if ada else "Rest [G]") if remaining==0 else "Rest in %dm" % remaining
	button.tooltip_text += " Ada: up to 10 recovery each; no kiss required." if ada else " Eleanor: up to 13 for you, 10 for her, after Steady Company."

