extends RefCounted
## Birdie's authored recruitment: meet, sing, invite. No puzzle, no field assignment --
## her perk is camp-only and always active once recruited.
const ID := "birdie_calloway"
const AGE := 20
var met := false
var sang := false
var recruitment := "available"
var romance_acknowledged := false
var trust := 0
var madness := 10.0

func meet() -> bool:
	if met: return false
	met = true
	trust += 5
	return true

func sing() -> Dictionary:
	if not met: return {"ok":false,"reason":"meet_first"}
	if sang: return {"ok":false,"reason":"already_sang"}
	sang = true
	trust += 5
	return {"ok":true,"reason":"song_shared"}

func invite(mutual_acceptance: bool) -> Dictionary:
	if recruitment=="recruited": return {"ok":false,"reason":"already_recruited"}
	if not met or not sang: return {"ok":false,"reason":"hear_the_song_first"}
	if not mutual_acceptance: return {"ok":false,"reason":"not_accepted"}
	recruitment = "recruited"
	trust += 10
	return {"ok":true,"reason":"recruited","role":"camp_cook_and_singer","romance_started":false}

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

## Camp-only and always assigned once recruited: she has no field role to toggle to.
func perk_record() -> Dictionary:
	return {"id":ID,"recruitment":recruitment,"party_assignment":("camp" if recruitment=="recruited" else "none"),"perk_id":"camp_song"}

func to_dict() -> Dictionary:
	return {"version":1,"character_id":ID,"age":AGE,"met":met,"sang":sang,
		"recruitment":recruitment,"romance_acknowledged":romance_acknowledged,
		"trust":trust,"madness":madness}

func load_dict(data: Dictionary) -> bool:
	if data.size()!=9: return false
	for key in to_dict():
		if not data.has(key): return false
	if not _number(data.version,1,1) or not _number(data.age,AGE,AGE) or data.character_id!=ID: return false
	if not data.met is bool or not data.sang is bool or not data.romance_acknowledged is bool: return false
	if data.recruitment not in ["available","recruited"]: return false
	if not data.met and data.sang: return false
	if data.recruitment=="recruited" and not (data.met and data.sang): return false
	if data.romance_acknowledged and data.recruitment!="recruited": return false
	var expected_trust := (5 if data.met else 0)+(5 if data.sang else 0)+(10 if data.recruitment=="recruited" else 0)+(5 if data.romance_acknowledged else 0)
	if not _number(data.trust,expected_trust,expected_trust) or not _number(data.madness,0,100): return false
	met = data.met
	sang = data.sang
	recruitment = data.recruitment
	romance_acknowledged = data.romance_acknowledged
	trust = int(data.trust)
	madness = float(data.madness)
	return true

func _number(value,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
