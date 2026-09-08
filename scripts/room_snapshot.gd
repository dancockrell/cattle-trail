extends RefCounted
const CompanionState = preload("res://scripts/companion_state.gd")
const LanternAdventure = preload("res://scripts/lantern_adventure.gd")

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
	return true

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_point(value) -> bool:
	if not value is Array or value.size()!=2: return false
	return number(value[0]) and number(value[1])
