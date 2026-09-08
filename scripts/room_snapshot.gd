extends RefCounted
const CompanionState = preload("res://scripts/companion_state.gd")
const LanternAdventure = preload("res://scripts/lantern_adventure.gd")
const AdaState = preload("res://scripts/ada_companion.gd")
const GeneratedRoster = preload("res://scripts/generated_companion_roster.gd")
const CartAdventure = preload("res://scripts/ada_cart_adventure.gd")

static func validate(data: Dictionary) -> bool:
	if data.get("version",0)!=1 or not data.get("cattle") is Array or data.cattle.size()!=6: return false
	for key in ["player","eleanor"]:
		if not valid_point(data.get(key)): return false
	var secured := 0
	for cow in data.cattle:
		if not cow is Dictionary or not valid_point(cow.get("position")) or not cow.get("secured") is bool: return false
		if cow.secured: secured += 1
	for key in ["cash","ammo","minutes","hits"]:
		if not number(data.get(key)) or float(data[key])<0: return false
	for key in ["cash","ammo","hits"]:
		if float(data[key])!=floorf(float(data[key])): return false
	if data.ammo>6 or data.hits>2: return false
	for key in ["won","talked","rustler_active"]:
		if not data.get(key) is bool: return false
	if data.won and (secured!=6 or not data.talked or data.rustler_active): return false
	if not data.get("spoken_beats") is Dictionary: return false
	for key in data.spoken_beats:
		if not key is String or not data.spoken_beats[key] is bool: return false
	if not data.get("companion") is Dictionary: return false
	var candidate := CompanionState.new()
	if not candidate.load_dict(data.companion): return false
	if candidate.recruitment=="recruited" and not data.won: return false
	if data.has("lantern_adventure"):
		if not data.lantern_adventure is Dictionary: return false
		var lantern := LanternAdventure.new()
		if not lantern.load_dict(data.lantern_adventure): return false
		if lantern.stage!="not_started" and candidate.recruitment!="recruited": return false
		if lantern.stage!="not_started" and candidate.adventure_status!="completed": return false
	if data.has("ada_companion"):
		if not data.ada_companion is Dictionary: return false
		var ada := AdaState.new()
		if not ada.load_dict(data.ada_companion): return false
	if data.has("generated_companions"):
		var roster := GeneratedRoster.new()
		if not roster.load_dict(data.generated_companions): return false
	if data.has("ada_cart_position") and not valid_point(data.ada_cart_position): return false
	if data.has("ada_cart_heading"):
		if not valid_point(data.ada_cart_heading): return false
		var heading := Vector2(data.ada_cart_heading[0],data.ada_cart_heading[1])
		if absf(heading.length()-1.0)>.001: return false
	if data.has("ada_cart_adventure"):
		if not data.ada_cart_adventure is Dictionary or not valid_point(data.get("ada_cart_position")): return false
		var cart := CartAdventure.new()
		if not cart.load_dict(data.ada_cart_adventure): return false
		if cart.status!="not_started":
			if not data.get("ada_companion") is Dictionary or data.ada_companion.get("recruitment")!="recruited": return false
			if not data.get("lantern_adventure") is Dictionary or data.lantern_adventure.get("status")!="completed": return false
		if cart.status=="active" and candidate.controlled_actor!="player": return false
	return true

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_point(value) -> bool:
	if not value is Array or value.size()!=2: return false
	return number(value[0]) and number(value[1])
