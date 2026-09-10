extends SceneTree
const Birdie = preload("res://scripts/birdie_companion.gd")
const Perks = preload("res://scripts/companion_perks.gd")

func _initialize() -> void:
	var birdie := Birdie.new()
	var initial := birdie.to_dict()
	assert(not birdie.sing().ok)
	assert(not birdie.invite(true).ok and not birdie.acknowledge_romance(true).ok)
	assert(birdie.to_dict()==initial)
	assert(birdie.meet() and not birdie.meet() and birdie.trust==5)
	assert(not birdie.invite(true).ok)
	assert(Perks.resolve([birdie.perk_record()],"camp").bonuses.is_empty())
	var before := birdie.to_dict()
	assert(birdie.sing().ok and birdie.trust==10)
	assert(not birdie.sing().ok and birdie.trust==10 and birdie.to_dict()!=before)
	before = birdie.to_dict()
	assert(not birdie.invite(false).ok and birdie.to_dict()==before)
	assert(birdie.invite(true).ok and birdie.trust==20 and not birdie.romance_acknowledged)
	assert(not birdie.invite(true).ok)
	assert(Perks.value([birdie.perk_record()],"camp","rest_madness_recovery")==2.0)
	assert(Perks.resolve([birdie.perk_record()],"field").bonuses.is_empty())
	before = birdie.to_dict()
	assert(not birdie.acknowledge_romance(false).ok and birdie.to_dict()==before)
	assert(birdie.acknowledge_romance(true).ok and birdie.trust==25)
	assert(not birdie.acknowledge_romance(true).ok and birdie.trust==25)
	assert(birdie.change_madness(1000) and birdie.madness==100)
	assert(birdie.change_madness(-1000) and birdie.madness==0)
	assert(not birdie.change_madness(NAN) and not birdie.change_madness(INF) and birdie.madness==0)
	assert(birdie.change_madness(12.5) and birdie.madness==12.5)
	var saved := birdie.to_dict()
	var restored := Birdie.new()
	assert(restored.load_dict(JSON.parse_string(JSON.stringify(saved))) and restored.to_dict()==saved)
	for key in saved:
		var missing := saved.duplicate(true)
		missing.erase(key)
		_reject(restored,missing,saved)
	for change in [{"age":19},{"character_id":"eleanor"},{"version":2},{"met":false},
		{"met":1},{"sang":false},{"romance_acknowledged":1},{"trust":26},
		{"trust":NAN},{"madness":INF},{"madness":-1},{"madness":101},{"extra":true},
		{"recruitment":"available"}]:
		var malformed := saved.duplicate(true)
		malformed.merge(change,true)
		_reject(restored,malformed,saved)
	var impossible := Birdie.new().to_dict()
	impossible.sang = true
	_reject(restored,impossible,saved)
	impossible = Birdie.new().to_dict()
	impossible.romance_acknowledged = true
	impossible.trust = 5
	_reject(restored,impossible,saved)
	assert(not restored.sing().ok and not restored.invite(true).ok and not restored.acknowledge_romance(true).ok)
	assert(restored.trust==25)
	print("BIRDIE COMPANION PASS: linear meet/sing/recruit/romance, deferred acceptance, camp-only perk, finite madness and atomic strict saves")
	quit()

func _reject(subject, malformed: Dictionary, unchanged: Dictionary) -> void:
	assert(not subject.load_dict(malformed))
	assert(subject.to_dict()==unchanged)
