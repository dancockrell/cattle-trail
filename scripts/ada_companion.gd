extends RefCounted
## Ada's first repair and invitation, separate from her later romance adventure.
const Repair = preload("res://scripts/steam_repair.gd")
const AGE := 22
var repair = Repair.new()
var met := false
var recruitment := "available"
var trust := 0
var madness := 10.0

func meet() -> bool:
	if met: return false
	met = true
	trust = mini(100,trust+5)
	# Ada has shut the feed before inviting the player to inspect the gauge.
	repair.set_feed(false)
	return true

func invite(mutual_acceptance: bool) -> Dictionary:
	if recruitment=="recruited": return {"ok":false,"reason":"already_recruited"}
	if not met or not repair.completed: return {"ok":false,"reason":"repair_first"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	recruitment = "recruited"
	trust = mini(100,trust+10)
	return {"ok":true,"reason":"recruited","role":"steam_mechanic","romance_started":false}

func to_dict() -> Dictionary:
	return {"version":1,"character_id":"ada_mercer","age":AGE,"met":met,
		"recruitment":recruitment,"trust":trust,"madness":madness,"repair":repair.to_dict()}

func load_dict(data: Dictionary) -> bool:
	if data.size()!=8: return false
	for key in to_dict():
		if not data.has(key): return false
	if not _number(data.version,1,1) or not _number(data.age,AGE,AGE): return false
	if data.character_id!="ada_mercer" or not data.met is bool: return false
	if data.recruitment not in ["available","recruited"]: return false
	if not _number(data.trust,0,100) or float(data.trust)!=floorf(float(data.trust)): return false
	if not _number(data.madness,0,100) or not data.repair is Dictionary: return false
	var restored = Repair.new()
	if not restored.load_dict(data.repair): return false
	if data.recruitment=="recruited" and (not data.met or not restored.completed): return false
	met = data.met
	recruitment = data.recruitment
	trust = int(data.trust)
	madness = float(data.madness)
	repair = restored
	return true

func _number(value,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
