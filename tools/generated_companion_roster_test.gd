extends SceneTree
const Roster = preload("res://scripts/generated_companion_roster.gd")
const Factory = preload("res://scripts/character_factory.gd")
var checks := 0
var failed := false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("ROSTER FAIL: " + label)
		quit(1)

func _initialize() -> void:
	var catalog := {"variants": [{"id":"rancher_01", "age":24, "family":"rancher", "atlas":"res://kits/example.png", "rect":[0,0,64,64], "status":"candidate"}]}
	var resolved: Array = Factory.new().create_roster(catalog, "fixture-world", 1, true)
	resolved[0].sprite.source_note = {"provenance":"fixture", "revision":2}
	resolved[0].madness = 10.5
	var roster = Roster.new()
	check(not roster.import_records(resolved), "candidate art blocked by default")
	check(roster.import_records(resolved, true), "explicit offline import")
	var id: String = resolved[0].id
	resolved[0].name = "External mutation"
	check(roster.get_record(id).name != "External mutation", "import owns deep copy")
	check(not roster.assign(id, "field"), "assignment requires recruitment")
	check(not roster.recruit(id, false), "decline is not recruitment")
	check(roster.recruit(id, true), "accepted invitation")
	check(roster.get_record(id).relationship == "unmet", "recruitment does not start romance")
	check(not roster.recruit(id, true), "repeat invitation unchanged")
	check(roster.assign(id, "camp"), "camp assignment")
	check(not roster.choose_relationship(id, "courting", false), "romance requires mutual choice")
	check(roster.reward_activity(id, "ford:first", 20, 5, -6), "first activity reward")
	check(not roster.reward_activity(id, "ford:first", 20, 5, -6), "reward once")
	check(roster.get_record(id).relationship == "unmet", "numbers do not imply romance")
	check(roster.choose_relationship(id, "courting", true), "explicit romance choice")
	var perks: Array = roster.perk_state()
	perks[0].sprite.rect[0] = 999
	check(roster.get_record(id).sprite.rect[0] == 0, "perk query deep copy")
	var saved: String = roster.to_json()
	var restored = Roster.new(true)
	check(restored.load_json(saved), "JSON roundtrip")
	check(restored.to_json() == saved, "resolved identity and art preserved")
	check(restored.get_record(id).madness == 4.5, "fractional madness preserved")
	check(restored.get_record(id).sprite.source_note.provenance == "fixture", "unknown art metadata preserved")
	check(not Roster.new().load_json(saved), "save cannot smuggle preview to production")
	check(not restored.reward_activity(id, "ford:first", 20, 5, -6), "reload preserves reward ledger")
	var before: Dictionary = restored.to_dict()
	var bad: Dictionary = before.duplicate(true)
	bad.records[0].age = 17
	check(not restored.load_dict(bad) and restored.to_dict() == before, "minor age atomic rejection")
	bad = before.duplicate(true)
	bad.records.append(bad.records[0].duplicate(true))
	check(not restored.load_dict(bad) and restored.to_dict() == before, "duplicate identity rejected")
	bad.records[1].id = "distinct_identity"
	check(not restored.load_dict(bad), "duplicate art identity rejected")
	bad = before.duplicate(true)
	bad.records[0].sprite.rect[2] = NAN
	check(not restored.load_dict(bad), "nonfinite art rectangle rejected")
	bad = before.duplicate(true)
	bad.records[0].sprite.anchor[0] = 64
	check(not restored.load_dict(bad), "anchor must be inside cell")
	bad = before.duplicate(true)
	bad.records[0].trust = true
	check(not restored.load_dict(bad), "bool is not numeric trust")
	check(not restored.load_json("{bad") and restored.to_dict() == before, "malformed JSON atomic")
	bad = before.duplicate(true)
	bad.records[0].production_preview = false
	check(Roster.new().load_dict(bad), "approved resolved identities accepted")
	if failed:
		quit(1)
		return
	print("GENERATED ROSTER PASS: %d checks; stable identities, atomic persistence, separate consent, reward ledger and preview gate" % checks)
	quit()
