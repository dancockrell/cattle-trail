extends SceneTree
## Headless check for scripts/encounter_table.gd and data/encounters.json.
##
## Uses push_error + print + quit(1) rather than assert: a failed assert in
## headless Godot hangs, and the runner then reports a timeout instead of a
## failure.
##
## Every count printed at the end is a denominator. A run that examined nothing
## must not read as a pass, so each population has a floor set well below its
## real size, and anything that could not be checked is printed as NOT CHECKED
## with its reason and carried into the summary line.

const Encounters = preload("res://scripts/encounter_table.gd")

const NPCS_PATH := "res://design/npcs.json"
const CHARACTERS_PATH := "res://design/characters.json"
const LOCATIONS_DIR := "res://data/locations"

## Floors. Each is well under the real population, so it fires on an empty or
## truncated input and never needs touching otherwise.
const MIN_ENCOUNTERS := 10
const MIN_OUTCOMES := 25
const MIN_NPC_REFS := 8
const MIN_CHECKS := 60

var checks := 0
var failures := 0
var skipped: Array = []


func ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ENCOUNTER TABLE FAIL: " + message)
		print("FAIL: " + message)


func _load_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _initialize() -> void:
	var table: Dictionary = Encounters.load_table()
	for problem in table.get("errors", []):
		failures += 1
		push_error("ENCOUNTER TABLE FAIL: " + str(problem))
		print("FAIL: " + str(problem))
	ok(table.get("ok", false), "data/encounters.json must load and validate")
	if not table.get("ok", false):
		_finish(0, 0, 0, 0, 0)
		return

	var ids: Array = table["order"]
	var encounter_count := ids.size()
	ok(encounter_count >= MIN_ENCOUNTERS, "expected at least %d encounters, found %d" % [MIN_ENCOUNTERS, encounter_count])

	# ---- ids referenced by the data must resolve -------------------------------
	var known_people := {}
	var npcs = _load_json(NPCS_PATH)
	if npcs is Dictionary:
		for person in npcs.get("characters", []):
			known_people[str(person.get("id", ""))] = true
	else:
		skipped.append("design/npcs.json could not be read")
	var characters = _load_json(CHARACTERS_PATH)
	if characters is Dictionary:
		for person in characters.get("named_characters", []):
			known_people[str(person.get("id", ""))] = true
	else:
		skipped.append("design/characters.json could not be read")
	ok(known_people.size() > 100, "the two cast files must yield a real roster to check against, got %d ids" % known_people.size())

	var places: Dictionary = Encounters.known_locations()
	var allowed_locations: Dictionary = places["ids"]
	ok(allowed_locations.size() >= 10, "the location vocabulary must have real entries, got %d from %s" % [allowed_locations.size(), str(places["source"])])

	var npc_refs := 0
	var reusing := 0
	var flavour := 0
	var outcome_count := 0
	var option_count := 0
	var location_refs := 0
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		var named := false
		for npc_id in row.get("npcs", []):
			npc_refs += 1
			named = true
			ok(known_people.has(str(npc_id)), "%s references npc '%s' which is in neither npcs.json nor characters.json" % [id, str(npc_id)])
		if named:
			reusing += 1
		if bool(row.get("flavour_only", false)):
			flavour += 1
		else:
			ok(named, "%s is not marked flavour_only but names nobody" % id)
		for location in row.get("where", {}).get("locations", []):
			location_refs += 1
			ok(allowed_locations.has(str(location)), "%s references unknown location '%s'" % [id, str(location)])
		for option in row.get("options", []):
			option_count += 1
			for outcome in option.get("outcomes", []):
				outcome_count += 1
	ok(npc_refs >= MIN_NPC_REFS, "expected at least %d npc references, found %d" % [MIN_NPC_REFS, npc_refs])
	ok(outcome_count >= MIN_OUTCOMES, "expected at least %d outcomes, found %d" % [MIN_OUTCOMES, outcome_count])

	# Most encounters must offer a real decision, not a single button.
	var with_choice := 0
	for id in ids:
		if table["by_id"][id].get("options", []).size() >= 2:
			with_choice += 1
	ok(with_choice >= encounter_count - flavour, "every non-flavour encounter must offer at least two options; %d of %d have one" % [encounter_count - with_choice, encounter_count])

	# Non-flavour encounters must be able to cost something real.
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		if bool(row.get("flavour_only", false)):
			continue
		var can_cost := false
		for option in row.get("options", []):
			for outcome in option.get("outcomes", []):
				var effects: Dictionary = outcome.get("effects", {})
				if float(effects.get("cattle_fraction", 0.0)) > 0.0:
					can_cost = true
				if int(effects.get("cattle_flat", 0)) < 0:
					can_cost = true
				if float(effects.get("condition", 0.0)) < 0.0:
					can_cost = true
				if int(effects.get("money", 0)) < 0 or int(effects.get("ammunition", 0)) < 0 or int(effects.get("trust", 0)) < 0:
					can_cost = true
		ok(can_cost, "%s is not marked flavour_only but nothing can be lost in it" % id)

	# ---- encounter ids referenced by location files ----------------------------
	var location_files := 0
	var declared_refs := 0
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(LOCATIONS_DIR)) or DirAccess.open(LOCATIONS_DIR) != null:
		var dir := DirAccess.open(LOCATIONS_DIR)
		if dir != null:
			for file_name in dir.get_files():
				if not file_name.ends_with(".json"):
					continue
				location_files += 1
				var location = _load_json(LOCATIONS_DIR + "/" + file_name)
				if not location is Dictionary:
					ok(false, "location file %s did not parse" % file_name)
					continue
				for declared in location.get("encounters", []):
					declared_refs += 1
					ok(table["by_id"].has(str(declared)), "location %s declares encounter '%s' which is not in data/encounters.json" % [file_name, str(declared)])
	if location_files == 0:
		skipped.append("NOT CHECKED: no data/locations/*.json exist yet, so no location-declared encounter id was verified")

	# ---- seeded rolls are reproducible ----------------------------------------
	var rich := {"herd_count": 400, "condition": 1.0, "money": 200, "ammunition": 40, "trust": 3}
	var leg := {
		"seed": 1872,
		"from": "clear_fork",
		"to": "fort_griffin",
		"terrain": ["plains", "timber"],
		"open_trail": true,
		"is_night": false,
		"party": rich,
		"encounter_chance": 1.0,
		"table": table,
	}
	var first := Encounters.run_leg(leg)
	var second := Encounters.run_leg(leg)
	ok(first["encounter_id"] == second["encounter_id"] and first["option_id"] == second["option_id"] and first["outcome_id"] == second["outcome_id"], "the same seed must replay the same encounter, option and outcome")
	ok(first["party_after"]["herd_count"] == second["party_after"]["herd_count"], "the same seed must produce the same herd count")

	# ...and different seeds must actually reach different encounters, or the
	# roll is a constant dressed as a random one.
	var seen := {}
	var day_encounters := {}
	var night_encounters := {}
	for seed_value in range(0, 400):
		var day_leg := leg.duplicate()
		day_leg["seed"] = seed_value
		var day_roll := Encounters.roll_for_leg(day_leg)
		if not str(day_roll["encounter_id"]).is_empty():
			seen[day_roll["encounter_id"]] = true
			day_encounters[day_roll["encounter_id"]] = true
		var night_leg := leg.duplicate()
		night_leg["seed"] = seed_value
		night_leg["is_night"] = true
		var night_roll := Encounters.roll_for_leg(night_leg)
		if not str(night_roll["encounter_id"]).is_empty():
			night_encounters[night_roll["encounter_id"]] = true
	ok(seen.size() >= 3, "400 day legs must reach more than a couple of distinct encounters, reached %d" % seen.size())
	ok(day_encounters.size() > 0 and night_encounters.size() > 0, "both day and night legs must produce encounters (day %d, night %d)" % [day_encounters.size(), night_encounters.size()])

	# ---- day-only never at night, night-only never by day ----------------------
	var night_only := 0
	var day_only := 0
	for id in ids:
		if str(table["by_id"][id].get("when", "")) == "night":
			night_only += 1
		elif str(table["by_id"][id].get("when", "")) == "day":
			day_only += 1
	ok(night_only >= 2 and day_only >= 1, "the table must contain both night-only and day-only encounters to make this check meaningful (night %d, day %d)" % [night_only, day_only])
	for id in day_encounters.keys():
		ok(str(table["by_id"][id].get("when", "")) != "night", "night-only encounter '%s' fired on a day leg" % id)
	for id in night_encounters.keys():
		ok(str(table["by_id"][id].get("when", "")) != "day", "day-only encounter '%s' fired on a night leg" % id)

	# The same filter must hold when a location declares the encounter outright,
	# which is the path that bypasses terrain entirely.
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		var when := str(row.get("when", ""))
		if when == "either":
			continue
		var declared_leg := {"from": "clear_fork", "to": "clear_fork", "terrain": [], "open_trail": false, "location_encounters": [id], "is_night": when == "day"}
		ok(not Encounters.is_eligible(row, declared_leg), "%s is %s-only but was eligible on the opposite leg even when a location declared it" % [id, when])
		var right_leg := declared_leg.duplicate()
		right_leg["is_night"] = when == "night"
		ok(Encounters.is_eligible(row, right_leg), "%s is %s-only and must be eligible on a %s leg a location declared it for" % [id, when, when])

	# ---- the chooser is tested where the wrong answer is available -------------
	var poor := {"herd_count": 4, "condition": 0.2, "money": 0, "ammunition": 0, "trust": 0}
	var gated := 0
	var open_options := 0
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		for entry in Encounters.options_for(row, poor):
			if bool(entry["available"]):
				open_options += 1
			else:
				gated += 1
	ok(gated >= 3, "a broke outfit must have some options closed to it, %d were" % gated)
	ok(open_options >= ids.size(), "every encounter must leave a broke outfit at least one option it can take")
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		var any_open := false
		for entry in Encounters.options_for(row, poor):
			if bool(entry["available"]):
				any_open = true
		ok(any_open, "%s leaves an outfit with nothing at all no way to act" % id)

	# A gated option must refuse rather than resolve on credit.
	var refused := 0
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		for entry in Encounters.options_for(row, poor):
			if bool(entry["available"]):
				continue
			var attempt := Encounters.resolve_choice({"encounter": row, "option_id": entry["id"], "party": poor, "seed": 7})
			if not bool(attempt["ok"]):
				refused += 1
			ok(not bool(attempt["ok"]), "%s/%s resolved despite the outfit not being able to pay for it" % [id, str(entry["id"])])
	ok(refused >= 3, "at least a few options must actually be refused to a broke outfit, %d were" % refused)

	# ---- every outcome is bounded, against an adversarial party ----------------
	# Exhaustive: every outcome of every option, applied directly, with a party
	# that has less of everything than the data asks for.
	var adversarial := {"herd_count": 3, "condition": 0.02, "money": 1, "ammunition": 1, "trust": 0, "has_steady_herd": true}
	var bounded := 0
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		var ceiling := float(row.get("max_cattle_loss_fraction", 0.0))
		for option in row.get("options", []):
			for outcome in option.get("outcomes", []):
				bounded += 1
				var applied: Dictionary = Encounters._apply_effects(row, outcome.get("effects", {}), adversarial)
				var after: Dictionary = applied["party_after"]
				var label := "%s/%s/%s" % [id, str(option.get("id", "")), str(outcome.get("id", ""))]
				ok(int(after["herd_count"]) >= 0, "%s drove the herd below zero" % label)
				ok(int(after["herd_count"]) <= 3 + maxi(0, int(outcome.get("effects", {}).get("cattle_flat", 0))), "%s created cattle out of nothing" % label)
				ok(int(after["money"]) >= 0, "%s drove money negative" % label)
				ok(int(after["ammunition"]) >= 0, "%s drove ammunition negative" % label)
				ok(float(after["condition"]) >= 0.0 and float(after["condition"]) <= 1.0, "%s put condition outside 0-1" % label)
				ok(int(after["trust"]) >= Encounters.MIN_TRUST and int(after["trust"]) <= Encounters.MAX_TRUST, "%s put trust outside its range" % label)
				var lost := maxi(0, 3 - int(after["herd_count"]) + maxi(0, int(outcome.get("effects", {}).get("cattle_flat", 0))))
				ok(float(lost) <= ceil(3.0 * ceiling), "%s lost %d head past its own ceiling of %f" % [label, lost, ceiling])
				ok(bool(after.get("has_steady_herd", false)), "%s dropped a perk flag the caller was carrying" % label)
	ok(bounded >= MIN_OUTCOMES, "expected at least %d outcomes exercised for bounds, exercised %d" % [MIN_OUTCOMES, bounded])

	# An empty outfit cannot be taken below empty by the worst encounter there is.
	var empty := {"herd_count": 0, "condition": 0.0, "money": 0, "ammunition": 0, "trust": 0}
	for id in ids:
		var row: Dictionary = table["by_id"][id]
		for option in row.get("options", []):
			for outcome in option.get("outcomes", []):
				var after: Dictionary = Encounters._apply_effects(row, outcome.get("effects", {}), empty)["party_after"]
				ok(int(after["herd_count"]) >= 0 and int(after["money"]) >= 0 and int(after["ammunition"]) >= 0, "%s took an already-empty outfit below zero" % id)

	# ---- perks shift outcomes rather than being ignored ------------------------
	var with_perk := 0
	var without_perk := 0
	for seed_value in range(0, 200):
		var base := leg.duplicate()
		base["seed"] = seed_value
		var plain := base.duplicate()
		plain["party"] = rich
		var perked := base.duplicate()
		var perk_party := rich.duplicate()
		perk_party["has_steady_herd"] = true
		perk_party["has_spirit_sense"] = true
		perk_party["has_steady_aim"] = true
		perked["party"] = perk_party
		var a := Encounters.run_leg(plain)
		var b := Encounters.run_leg(perked)
		without_perk += int(a["party_after"]["herd_count"])
		with_perk += int(b["party_after"]["herd_count"])
	ok(with_perk > without_perk, "a party carrying the drive perks must arrive with more cattle over 200 legs (%d vs %d)" % [with_perk, without_perk])

	# ---- a quiet leg is possible and reported honestly -------------------------
	var quiet_leg := leg.duplicate()
	quiet_leg["encounter_chance"] = 0.0
	var quiet := Encounters.roll_for_leg(quiet_leg)
	ok(str(quiet["encounter_id"]).is_empty(), "an encounter chance of zero must produce no encounter")
	ok(int(quiet["considered"]) == encounter_count, "a quiet leg must still report how many encounters it considered")

	_finish(encounter_count, flavour, outcome_count, npc_refs, reusing)


func _finish(encounter_count: int, flavour: int, outcome_count: int, npc_refs: int, reusing: int) -> void:
	for note in skipped:
		print("SKIPPED: " + str(note))
	if checks < MIN_CHECKS:
		failures += 1
		push_error("ENCOUNTER TABLE FAIL: only %d checks ran, expected at least %d" % [checks, MIN_CHECKS])
		print("FAIL: only %d checks ran, expected at least %d" % [checks, MIN_CHECKS])
	if failures > 0:
		print("ENCOUNTER TABLE FAILED: %d of %d checks failed" % [failures, checks])
		quit(1)
		return
	print("ENCOUNTER TABLE PASS: %d checks, 0 failures; %d encounters (%d flavour, %d reuse a written character), %d outcomes bounded, %d npc ids resolved, %d not checked" % [checks, encounter_count, flavour, reusing, outcome_count, npc_refs, skipped.size()])
	quit(0)
