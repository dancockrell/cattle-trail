extends SceneTree
const Ines = preload("res://scripts/ines_companion.gd")
const Perks = preload("res://scripts/companion_perks.gd")

func _initialize() -> void:
	var ines := Ines.new()
	var initial := ines.to_dict()
	assert(not ines.discover_clue("bell_tracks").ok)
	assert(not ines.invite(true).ok and not ines.acknowledge_romance(true).ok)
	assert(not ines.assign_party("field") and ines.to_dict()==initial)
	assert(ines.meet() and not ines.meet() and ines.trust==5)
	assert(not ines.discover_clue("invented").ok and ines.clues.is_empty())
	for clue in ["wrong_shadow","bell_tracks","cold_ashes"]:
		assert(not ines.complete_trail().ok)
		assert(ines.discover_clue(clue).ok)
		assert(not ines.discover_clue(clue).ok and ines.trust==5)
		var checkpoint := Ines.new()
		assert(checkpoint.load_dict(JSON.parse_string(JSON.stringify(ines.to_dict()))))
	assert(ines.complete_trail().ok and ines.trust==20)
	assert(not ines.complete_trail().ok and ines.trust==20)
	var before := ines.to_dict()
	assert(not ines.invite(false).ok and ines.to_dict()==before)
	assert(ines.invite(true).ok and ines.trust==30 and not ines.romance_acknowledged)
	assert(not ines.invite(true).ok)
	assert(Perks.resolve([ines.perk_record()],"field").bonuses.is_empty())
	assert(ines.assign_party("field"))
	assert(Perks.value([ines.perk_record()],"field","trail_hazard_notice")==1.0)
	assert(Perks.resolve([ines.perk_record()],"camp").bonuses.is_empty())
	before = ines.to_dict()
	assert(not ines.acknowledge_romance(false).ok and ines.to_dict()==before)
	assert(ines.acknowledge_romance(true).ok and ines.trust==35)
	assert(not ines.acknowledge_romance(true).ok and ines.trust==35)
	assert(ines.change_madness(1000) and ines.madness==100)
	assert(ines.change_madness(-1000) and ines.madness==0)
	assert(not ines.change_madness(NAN) and not ines.change_madness(INF) and ines.madness==0)
	assert(ines.change_madness(12.5) and ines.madness==12.5)
	var saved := ines.to_dict()
	var restored := Ines.new()
	assert(restored.load_dict(JSON.parse_string(JSON.stringify(saved))) and restored.to_dict()==saved)
	for key in saved:
		var missing := saved.duplicate(true)
		missing.erase(key)
		_reject(restored,missing,saved)
	for change in [{"age":17},{"character_id":"rosa_vale"},{"version":2},{"met":false},
		{"met":1},{"trail_completed":false},{"romance_acknowledged":1},{"trust":36},
		{"trust":NAN},{"madness":INF},{"madness":-1},{"madness":101},{"extra":true},
		{"clues":["bell_tracks","bell_tracks","wrong_shadow"]},{"clues":["bell_tracks",1,"wrong_shadow"]},
		{"clues":["bell_tracks","cold_ashes","unknown"]},{"clues":[]},{"clues":{}},
		{"recruitment":"available"},{"party_assignment":"none"},{"party_assignment":"unknown"}]:
		var malformed := saved.duplicate(true)
		malformed.merge(change,true)
		_reject(restored,malformed,saved)
	var impossible := Ines.new().to_dict()
	impossible.party_assignment = "field"
	_reject(restored,impossible,saved)
	impossible = Ines.new().to_dict()
	impossible.romance_acknowledged = true
	impossible.trust = 5
	_reject(restored,impossible,saved)
	var detached := ines.to_dict()
	detached.clues.clear()
	assert(ines.clues.size()==3)
	assert(not restored.complete_trail().ok and not restored.invite(true).ok and not restored.acknowledge_romance(true).ok)
	assert(restored.trust==35)
	print("INES COMPANION PASS: distinct clues, one-time trail/recruitment/romance, deferred acceptance, field-only perk, finite madness and atomic strict saves")
	quit()

func _reject(subject, malformed: Dictionary, unchanged: Dictionary) -> void:
	assert(not subject.load_dict(malformed))
	assert(subject.to_dict()==unchanged)
