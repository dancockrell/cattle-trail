extends RefCounted
## Generic state for the "meet, one flavor task, invite" recruitment shape --
## the same shape scripts/birdie_companion.gd hand-wrote for one character.
## Bringing a new companion of this shape into the game is now a data row in
## scripts/simple_companion_catalog.gd, not a new pair of .gd files.
##
## Deliberately does not cover companions with a puzzle (Ada's pressure/valve
## repair), a multi-step collection (Ines's three clues), or a field/camp
## assignment toggle -- those stay hand-written because their state machines
## actually differ, not just their flavor text. This covers the "single-beat
## task, no assignment options" shape shared by e.g. Delphine (win a hand of
## cards), Cleo (a nervous shave), Prisca (verify a fact) and others.
var id: String
var age: int
var perk_id: String
var met := false
var task_done := false
var recruitment := "available"
var romance_acknowledged := false
var trust := 0
var madness := 10.0

func configure(p_id: String, p_age: int, p_perk_id: String) -> void:
	id = p_id
	age = p_age
	perk_id = p_perk_id

func meet() -> bool:
	if met: return false
	met = true
	trust += 5
	return true

func complete_task() -> Dictionary:
	if not met: return {"ok":false,"reason":"meet_first"}
	if task_done: return {"ok":false,"reason":"already_done"}
	task_done = true
	trust += 5
	return {"ok":true,"reason":"task_done"}

func invite(mutual_acceptance: bool) -> Dictionary:
	if recruitment=="recruited": return {"ok":false,"reason":"already_recruited"}
	if not met or not task_done: return {"ok":false,"reason":"task_first"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	recruitment = "recruited"
	trust += 10
	return {"ok":true,"reason":"recruited"}

func acknowledge_romance(mutual_acceptance: bool) -> Dictionary:
	if recruitment!="recruited": return {"ok":false,"reason":"recruit_first"}
	if romance_acknowledged: return {"ok":false,"reason":"already_acknowledged"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	romance_acknowledged = true
	trust += 5
	return {"ok":true,"reason":"romance_acknowledged","trust_awarded":5}

func change_madness(amount: float) -> bool:
	if not is_finite(amount): return false
	madness = clampf(madness+amount,0.0,100.0)
	return true

## Camp-only and always assigned once recruited, matching Birdie's precedent:
## none of the companions this system covers have an authored field role yet.
func perk_record() -> Dictionary:
	return {"id":id,"recruitment":recruitment,"party_assignment":("camp" if recruitment=="recruited" else "none"),"perk_id":perk_id}

func to_dict() -> Dictionary:
	return {"version":1,"character_id":id,"age":age,"perk_id":perk_id,"met":met,"task_done":task_done,
		"recruitment":recruitment,"romance_acknowledged":romance_acknowledged,
		"trust":trust,"madness":madness}

func load_dict(data: Dictionary) -> bool:
	if data.size()!=10: return false
	for key in to_dict():
		if not data.has(key): return false
	if not _number(data.version,1,1) or not _number(data.age,age,age) or data.character_id!=id: return false
	if data.perk_id!=perk_id: return false
	if not data.met is bool or not data.task_done is bool or not data.romance_acknowledged is bool: return false
	if data.recruitment not in ["available","recruited"]: return false
	if not data.met and data.task_done: return false
	if data.recruitment=="recruited" and not (data.met and data.task_done): return false
	if data.romance_acknowledged and data.recruitment!="recruited": return false
	var expected_trust := (5 if data.met else 0)+(5 if data.task_done else 0)+(10 if data.recruitment=="recruited" else 0)+(5 if data.romance_acknowledged else 0)
	if not _number(data.trust,expected_trust,expected_trust) or not _number(data.madness,0,100): return false
	met = data.met
	task_done = data.task_done
	recruitment = data.recruitment
	romance_acknowledged = data.romance_acknowledged
	trust = int(data.trust)
	madness = float(data.madness)
	return true

func _number(value,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
