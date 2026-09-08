extends SceneTree
const Recovery = preload("res://scripts/camp_recovery.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var c := Recovery.new()
	var ids := ["player","ada"]
	var madness := {"player":8.0,"ada":30.0,"ines":50.0}
	check(not c.request([],madness,0,true).ok,"Exactly two participants")
	check(not c.request(["ada","ada"],madness,0,true).ok,"Distinct participants")
	check(not c.request([" ","ada"],madness,0,true).ok,"Nonempty identifiers")
	for t in [-1.0,NAN,INF]: check(not c.request(ids,madness,t,true).ok,"Invalid time")
	check(not c.request(ids,madness,0,false).ok and c.next_available.is_empty(),"Mutual choice required without cooldown mutation")
	check(not c.request(ids,{"player":true,"ada":5},0,true).ok,"Boolean madness rejected")
	check(not c.request(ids,{"player":101,"ada":5},0,true).ok,"Range enforced")
	check(not c.request(ids,{"player":NAN,"ada":5},0,true).ok,"Finite madness required")
	var result := c.request(ids,madness,100,true)
	check(result.ok and result.minutes_spent == 30.0,"Successful recovery spends scene time")
	check(result.recovery == {"player":8.0,"ada":10.0} and result.after == {"player":0.0,"ada":20.0},"Actual recovery floored at zero")
	check(madness == {"player":8.0,"ada":30.0,"ines":50.0} and ids == ["player","ada"],"Caller inputs unchanged")
	result.actors.clear()
	result.after.player = 100.0
	check(ids.size() == 2 and madness.player == 8.0,"Result cannot mutate caller inputs")
	check(not c.request(["ada","player"],madness,110,true).ok,"Swapped pair remains blocked")
	check(not c.request(["player","ines"],madness,110,true).ok,"First participant rotation blocked")
	check(not c.request(["ines","ada"],madness,110,true).ok,"Second participant rotation blocked")
	check(not c.next_available.has("ines"),"Rejected pair does not consume new participant cooldown")
	var r := Recovery.new()
	check(r.load_dict(JSON.parse_string(JSON.stringify(c.to_dict()))),"JSON roundtrip")
	check(not r.request(ids,madness,1539.9,true).ok and r.request(ids,madness,1540,true).ok,"Boundary expires at1440 minutes")
	var saved := r.to_dict()
	var bad := saved.duplicate(true)
	bad.version = true
	check(not r.load_dict(bad) and r.to_dict() == saved,"Boolean version rejection atomic")
	bad = saved.duplicate(true)
	bad.next_available.ada = INF
	check(not r.load_dict(bad) and r.to_dict() == saved,"Nonfinite deadline rejection atomic")
	bad = saved.duplicate(true)
	bad.next_available[""] = 5
	check(not r.load_dict(bad) and r.to_dict() == saved,"Invalid stored ID rejection atomic")
	var many: Dictionary = {}
	for i in range(1000): many["person_%d" % i] = float(i)
	check(r.load_dict({"version":1,"next_available":many}) and r.next_available.size() == 1000,"No artificial participant count limit")
	many.clear()
	check(r.next_available.size() == 1000,"Loaded dictionary detached from caller")
	var zero := Recovery.new().request(["p","a"],{"p":0,"a":0},0,true)
	check(zero.ok and zero.recovery == {"p":0.0,"a":0.0},"Zero madness remains zero")
	if failures == 0: print("CAMP RECOVERY PASS: %d checks; mutual care, per-actor cooldown, input isolation and atomic JSON" % checks)
	quit(1 if failures else 0)
