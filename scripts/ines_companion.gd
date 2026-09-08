extends RefCounted
## Ines's authored trail: recruitment, affection and field duty remain separate.
const ID := "ines_vale"
const AGE := 23
const CLUES := ["bell_tracks", "cold_ashes", "wrong_shadow"]
var met := false
var clues: Array[String] = []
var trail_completed := false
var recruitment := "available"
var romance_acknowledged := false
var party_assignment := "none"
var trust := 0
var madness := 10.0

func meet() -> bool:
	if met: return false
	met = true
	trust += 5
	return true

func discover_clue(clue_id: String) -> Dictionary:
	if clue_id not in CLUES: return {"ok":false,"reason":"unknown_clue"}
	if not met: return {"ok":false,"reason":"meet_first"}
	if clue_id in clues: return {"ok":false,"reason":"already_found"}
	clues.append(clue_id)
	return {"ok":true,"reason":"clue_found","clue_id":clue_id,"remaining":CLUES.size()-clues.size()}

func complete_trail() -> Dictionary:
	if trail_completed: return {"ok":false,"reason":"already_completed"}
	if not met or clues.size()!=CLUES.size(): return {"ok":false,"reason":"find_clues_first"}
	trail_completed = true
	trust += 15
	return {"ok":true,"reason":"trail_completed","trust_awarded":15}

func invite(mutual_acceptance: bool) -> Dictionary:
	if recruitment=="recruited": return {"ok":false,"reason":"already_recruited"}
	if not trail_completed: return {"ok":false,"reason":"trail_first"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	recruitment = "recruited"
	party_assignment = "camp"
	trust += 10
	return {"ok":true,"reason":"recruited","role":"spirit_scout","romance_started":false}

func acknowledge_romance(mutual_acceptance: bool) -> Dictionary:
	if recruitment!="recruited": return {"ok":false,"reason":"recruit_first"}
	if romance_acknowledged: return {"ok":false,"reason":"already_acknowledged"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	romance_acknowledged = true
	trust += 5
	return {"ok":true,"reason":"romance_acknowledged","trust_awarded":5}

func assign_party(assignment: String) -> bool:
	if recruitment!="recruited" or assignment not in ["camp","field"]: return false
	party_assignment = assignment
	return true

func change_madness(amount: float) -> bool:
	if not is_finite(amount): return false
	madness = clampf(madness+amount,0.0,100.0)
	return true

func perk_record() -> Dictionary:
	return {"id":ID,"recruitment":recruitment,"party_assignment":party_assignment,"perk_id":"spirit_sense"}

func to_dict() -> Dictionary:
	return {"version":1,"character_id":ID,"age":AGE,"met":met,"clues":clues.duplicate(),
		"trail_completed":trail_completed,"recruitment":recruitment,"romance_acknowledged":romance_acknowledged,
		"party_assignment":party_assignment,"trust":trust,"madness":madness}

func load_dict(data: Dictionary) -> bool:
	if data.size()!=11: return false
	for key in to_dict():
		if not data.has(key): return false
	if not _number(data.version,1,1) or not _number(data.age,AGE,AGE) or data.character_id!=ID: return false
	if not data.met is bool or not data.trail_completed is bool or not data.romance_acknowledged is bool: return false
	if not data.clues is Array or data.clues.size()>CLUES.size(): return false
	var restored_clues: Array[String] = []
	for clue in data.clues:
		if not clue is String or clue not in CLUES or clue in restored_clues: return false
		restored_clues.append(clue)
	if data.recruitment not in ["available","recruited"] or data.party_assignment not in ["none","camp","field"]: return false
	if not data.met and not restored_clues.is_empty(): return false
	if data.trail_completed and (not data.met or restored_clues.size()!=CLUES.size()): return false
	if data.recruitment=="recruited" and not data.trail_completed: return false
	if data.romance_acknowledged and data.recruitment!="recruited": return false
	if (data.recruitment=="recruited") != (data.party_assignment in ["camp","field"]): return false
	var expected_trust := (5 if data.met else 0)+(15 if data.trail_completed else 0)+(10 if data.recruitment=="recruited" else 0)+(5 if data.romance_acknowledged else 0)
	if not _number(data.trust,expected_trust,expected_trust) or not _number(data.madness,0,100): return false
	met = data.met
	clues = restored_clues
	trail_completed = data.trail_completed
	recruitment = data.recruitment
	romance_acknowledged = data.romance_acknowledged
	party_assignment = data.party_assignment
	trust = int(data.trust)
	madness = float(data.madness)
	return true

func _number(value,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
