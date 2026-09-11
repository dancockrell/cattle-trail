extends RefCounted
## Rolls and resolves a road encounter for one leg of travel, per
## design/EXPLORATION.md's "Encounters on the road" and design/DRIVES.md's rule
## that most of the county's wandering figures are a job to do rather than a
## fight to win.
##
## Pure logic, same house style as scripts/cattle_drive_resolver.gd and
## scripts/trade_negotiation.gd: RefCounted, no scene tree, no autoload, no
## singleton state. Time of day and the route come in as parameters from the
## travel layer and the trail clock (scripts/trail_clock.gd); perks come in as
## already-resolved has_* flags the caller got from CompanionPerks.value(...),
## exactly as the drive resolver consumes them.
##
## Every roll is seeded. The same seed, route, time of day and party produce the
## same encounter and the same outcome, so a test is deterministic and a journey
## can be replayed for debugging.
##
## ALL NUMERIC CONSTANTS HERE AND IN data/encounters.json ARE FIRST-PASS AND
## UNTUNED. They exist so the mechanic is callable. They are not balance.

const DATA_PATH := "res://data/encounters.json"

## Chance that a leg carries any encounter at all, before eligibility.
## First-pass guess; EXPLORATION.md's "Next decisions" still lists random
## encounter frequency as open.
const DEFAULT_ENCOUNTER_CHANCE := 0.45

## Party fields the resolver reads and writes back. A caller that supplies none
## of them gets these.
const PARTY_DEFAULTS := {
	"herd_count": 0,
	"condition": 1.0,
	"money": 0,
	"ammunition": 0,
	"trust": 3,
}

## Hard bounds. These are the safety net the data cannot talk its way past:
## an encounter cannot take more cattle than are standing there, cannot push
## money or ammunition below zero, and cannot move a leg's clock outside a day.
const MIN_TRUST := 0
const MAX_TRUST := 5
const MIN_MINUTES_DELTA := -240
const MAX_MINUTES_DELTA := 1440

const VALID_WHEN := ["day", "night", "either"]
const VALID_KIND := ["supernatural", "wanderer", "human", "country"]
const EFFECT_KEYS := ["minutes", "cattle_fraction", "cattle_flat", "condition", "money", "ammunition", "trust"]
## Effects a flavour-only encounter is allowed to carry. Flavour costs time and
## nothing else; anything more and it should not be flagged as flavour.
const FLAVOUR_EFFECT_KEYS := ["minutes", "condition"]
const REQUIRE_KEYS := ["money", "ammunition", "herd_count"]

const LOCATIONS_DIR := "res://data/locations"

## Fallback location vocabulary: the ten places design/LOCATIONS.md names.
## data/locations/*.json is the authority whenever it exists; this list only
## answers before any location file has been written, so there is one source of
## truth rather than a second copy competing with it.
const FALLBACK_LOCATIONS := [
	"clear_fork", "fort_griffin", "the_narrow_water", "bellhollow",
	"the_calloway_spread", "the_hargrove_range", "providence",
	"the_salt_flats", "split_oak_camp", "the_quiet_rows",
]

## Terrain tags a leg may carry. The first six are LOCATION-SCHEMA's own "kind"
## values, so a leg can be described by the kind of place it runs through; the
## rest are trail descriptors for ground between places.
const KNOWN_TERRAIN := [
	"home", "town", "spread", "wild", "crossing", "camp",
	"timber", "plains", "flats", "scrub_hill", "cemetery",
]


## The location ids an encounter's "where" may name. Reads data/locations/*.json
## when it exists and falls back to FALLBACK_LOCATIONS when it does not.
## Returns { ids: Dictionary (id -> true), source: String, count: int }
static func known_locations(dir_path := LOCATIONS_DIR) -> Dictionary:
	var ids := {}
	var dir := DirAccess.open(dir_path)
	if dir != null:
		for file_name in dir.get_files():
			if not file_name.ends_with(".json"):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir_path + "/" + file_name))
			if parsed is Dictionary and parsed.has("id"):
				ids[str(parsed["id"])] = true
	if not ids.is_empty():
		return {"ids": ids, "source": dir_path, "count": ids.size()}
	for id in FALLBACK_LOCATIONS:
		ids[id] = true
	return {"ids": ids, "source": "design/LOCATIONS.md fallback list", "count": ids.size()}


static func _seed_for(base_seed: int, salt: String) -> int:
	## Deterministic per-purpose stream. Two different questions asked of the
	## same leg seed must not reuse the same sequence.
	return base_seed ^ (int(hash(salt)) * 1103515245)


static func _rng(base_seed: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(base_seed, salt)
	return rng


## Reads and validates data/encounters.json.
## Returns { ok: bool, count: int, order: Array[String], by_id: Dictionary,
##           errors: Array[String] }
static func load_table(path := DATA_PATH) -> Dictionary:
	var result := {"ok": false, "count": 0, "order": [], "by_id": {}, "errors": []}
	if not FileAccess.file_exists(path):
		result.errors.append("Encounter table not found at %s" % path)
		return result
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		result.errors.append("Encounter table at %s is empty" % path)
		return result
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has("encounters"):
		result.errors.append("Encounter table at %s is not an object with an 'encounters' array" % path)
		return result
	var rows = parsed["encounters"]
	if not rows is Array or rows.is_empty():
		result.errors.append("Encounter table at %s has no encounters" % path)
		return result
	var places := known_locations()
	var allowed_locations: Dictionary = places["ids"]
	result["location_source"] = places["source"]
	for row in rows:
		if not row is Dictionary:
			result.errors.append("Encounter entry is not an object")
			continue
		var id = row.get("id", "")
		if not id is String or id.is_empty():
			result.errors.append("Encounter entry has no id")
			continue
		if result.by_id.has(id):
			result.errors.append("Duplicate encounter id '%s'" % id)
			continue
		for problem in validate(row, allowed_locations):
			result.errors.append(problem)
		result.by_id[id] = row
		result.order.append(id)
	result.count = result.order.size()
	result.ok = result.errors.is_empty() and result.count > 0
	return result


## Structural check on one encounter row. Returns a list of problems; empty
## means the row is sound. Called by load_table and directly by the test.
static func validate(row: Dictionary, allowed_locations := {}) -> Array:
	if allowed_locations.is_empty():
		allowed_locations = known_locations()["ids"]
	var problems: Array = []
	var id: String = str(row.get("id", "?"))
	if not VALID_WHEN.has(str(row.get("when", ""))):
		problems.append("%s: 'when' must be one of %s" % [id, str(VALID_WHEN)])
	if not VALID_KIND.has(str(row.get("kind", ""))):
		problems.append("%s: 'kind' must be one of %s" % [id, str(VALID_KIND)])
	var weight := int(row.get("weight", 0))
	if weight < 1 or weight > 100:
		problems.append("%s: weight %d outside 1-100" % [id, weight])
	var ceiling := float(row.get("max_cattle_loss_fraction", -1.0))
	if ceiling < 0.0 or ceiling > 1.0:
		problems.append("%s: max_cattle_loss_fraction %f outside 0-1" % [id, ceiling])
	var flavour := bool(row.get("flavour_only", false))
	if flavour and ceiling > 0.0:
		problems.append("%s: flavour_only encounters must not be able to cost cattle" % id)
	var where = row.get("where", {})
	if not where is Dictionary:
		problems.append("%s: 'where' must be an object" % id)
		where = {}
	var places := 0
	for location in where.get("locations", []):
		places += 1
		if not allowed_locations.has(str(location)):
			problems.append("%s: unknown location '%s'" % [id, str(location)])
	for terrain in where.get("terrain", []):
		places += 1
		if not KNOWN_TERRAIN.has(str(terrain)):
			problems.append("%s: unknown terrain tag '%s'" % [id, str(terrain)])
	if bool(where.get("open_trail", false)):
		places += 1
	if places == 0:
		problems.append("%s: can never occur anywhere (no locations, terrain or open_trail)" % id)
	if str(row.get("intro", "")).is_empty():
		problems.append("%s: no intro text" % id)
	var options = row.get("options", [])
	if not options is Array or options.is_empty():
		problems.append("%s: no options" % id)
		return problems
	var option_ids := {}
	for option in options:
		if not option is Dictionary:
			problems.append("%s: option is not an object" % id)
			continue
		var option_id := str(option.get("id", ""))
		if option_id.is_empty():
			problems.append("%s: option has no id" % id)
			continue
		if option_ids.has(option_id):
			problems.append("%s: duplicate option id '%s'" % [id, option_id])
		option_ids[option_id] = true
		if str(option.get("label", "")).is_empty():
			problems.append("%s/%s: option has no label" % [id, option_id])
		var requires = option.get("requires", {})
		if not requires is Dictionary:
			problems.append("%s/%s: 'requires' must be an object" % [id, option_id])
			requires = {}
		for key in requires.keys():
			if not REQUIRE_KEYS.has(str(key)):
				problems.append("%s/%s: unknown requirement '%s'" % [id, option_id, str(key)])
		var outcomes = option.get("outcomes", [])
		if not outcomes is Array or outcomes.is_empty():
			problems.append("%s/%s: option has no outcomes" % [id, option_id])
			continue
		var outcome_ids := {}
		for outcome in outcomes:
			if not outcome is Dictionary:
				problems.append("%s/%s: outcome is not an object" % [id, option_id])
				continue
			var outcome_id := str(outcome.get("id", ""))
			if outcome_id.is_empty():
				problems.append("%s/%s: outcome has no id" % [id, option_id])
				continue
			if outcome_ids.has(outcome_id):
				problems.append("%s/%s: duplicate outcome id '%s'" % [id, option_id, outcome_id])
			outcome_ids[outcome_id] = true
			var outcome_weight := int(outcome.get("weight", 0))
			if outcome_weight < 1 or outcome_weight > 100:
				problems.append("%s/%s/%s: outcome weight %d outside 1-100" % [id, option_id, outcome_id, outcome_weight])
			if str(outcome.get("text", "")).is_empty():
				problems.append("%s/%s/%s: outcome has no text" % [id, option_id, outcome_id])
			var effects = outcome.get("effects", {})
			if not effects is Dictionary:
				problems.append("%s/%s/%s: 'effects' must be an object" % [id, option_id, outcome_id])
				effects = {}
			for key in effects.keys():
				if not EFFECT_KEYS.has(str(key)):
					problems.append("%s/%s/%s: unknown effect key '%s'" % [id, option_id, outcome_id, str(key)])
				elif flavour and not FLAVOUR_EFFECT_KEYS.has(str(key)):
					problems.append("%s/%s/%s: flavour_only encounter carries effect '%s'" % [id, option_id, outcome_id, str(key)])
			var fraction := float(effects.get("cattle_fraction", 0.0))
			if fraction < 0.0 or fraction > 1.0:
				problems.append("%s/%s/%s: cattle_fraction %f outside 0-1" % [id, option_id, outcome_id, fraction])
			var perk_weight = outcome.get("perk_weight", {})
			if not perk_weight is Dictionary:
				problems.append("%s/%s/%s: 'perk_weight' must be an object" % [id, option_id, outcome_id])
	return problems


static func _party_from(source: Dictionary) -> Dictionary:
	var party := {}
	for key in PARTY_DEFAULTS.keys():
		party[key] = source.get(key, PARTY_DEFAULTS[key])
	party["herd_count"] = maxi(0, int(party["herd_count"]))
	party["money"] = maxi(0, int(party["money"]))
	party["ammunition"] = maxi(0, int(party["ammunition"]))
	party["trust"] = clampi(int(party["trust"]), MIN_TRUST, MAX_TRUST)
	party["condition"] = clampf(float(party["condition"]), 0.0, 1.0)
	return party


## True when this encounter may occur on this leg. Time of day is checked
## first and applies to every encounter, including ones a location declares
## explicitly in its own "encounters" array: a night-only encounter is never
## eligible by day, however it was reached.
static func is_eligible(row: Dictionary, leg: Dictionary) -> bool:
	var is_night := bool(leg.get("is_night", false))
	var when := str(row.get("when", "either"))
	if when == "day" and is_night:
		return false
	if when == "night" and not is_night:
		return false
	var declared: Array = leg.get("location_encounters", [])
	if declared.has(str(row.get("id", ""))):
		return true
	var where: Dictionary = row.get("where", {})
	var endpoints := [str(leg.get("from", "")), str(leg.get("to", ""))]
	for location in where.get("locations", []):
		if endpoints.has(str(location)):
			return true
	var terrain: Array = leg.get("terrain", [])
	for tag in where.get("terrain", []):
		if terrain.has(str(tag)):
			return true
	if bool(where.get("open_trail", false)) and bool(leg.get("open_trail", true)):
		return true
	return false


## What the travel layer calls once per leg.
##
## params:
##   seed: int                     -- the leg's seed; same seed, same result
##   from: String, to: String      -- location ids at either end
##   terrain: Array[String]        -- terrain tags this leg crosses
##   location_encounters: Array    -- ids either endpoint declares (LOCATION-SCHEMA)
##   open_trail: bool              -- default true; false for a leg wholly inside a place
##   is_night: bool                -- from the trail clock
##   party: Dictionary             -- herd_count, condition, money, ammunition, trust,
##                                    has_steady_herd / has_spirit_sense / has_steady_aim
##   encounter_chance: float       -- optional override of DEFAULT_ENCOUNTER_CHANCE
##   table: Dictionary             -- optional preloaded load_table() result
##
## Returns:
##   { encounter_id: String ("" when the leg is quiet), encounter: Dictionary,
##     options: Array of { id, label, available, unavailable_reason },
##     considered: int, eligible: int, flavour_only: bool, notes: Array[String] }
static func roll_for_leg(params: Dictionary) -> Dictionary:
	var table: Dictionary = params.get("table", {})
	if table.is_empty():
		table = load_table()
	var out := {
		"encounter_id": "",
		"encounter": {},
		"options": [],
		"considered": 0,
		"eligible": 0,
		"flavour_only": false,
		"notes": [],
	}
	if not table.get("ok", false):
		out.notes.append("Encounter table did not load; leg resolved as quiet.")
		for problem in table.get("errors", []):
			out.notes.append(str(problem))
		return out

	var leg := {
		"from": str(params.get("from", "")),
		"to": str(params.get("to", "")),
		"terrain": params.get("terrain", []),
		"location_encounters": params.get("location_encounters", []),
		"open_trail": bool(params.get("open_trail", true)),
		"is_night": bool(params.get("is_night", false)),
	}
	var base_seed := int(params.get("seed", 0))
	var party := _party_from(params.get("party", {}))

	var eligible: Array = []
	var total_weight := 0
	for id in table.get("order", []):
		out.considered += 1
		var row: Dictionary = table["by_id"][id]
		if not is_eligible(row, leg):
			continue
		eligible.append(row)
		total_weight += int(row.get("weight", 0))
	out.eligible = eligible.size()

	if eligible.is_empty():
		out.notes.append("No encounter is eligible on this leg (%d considered)." % out.considered)
		return out

	var chance := clampf(float(params.get("encounter_chance", DEFAULT_ENCOUNTER_CHANCE)), 0.0, 1.0)
	var gate := _rng(base_seed, "encounter-gate")
	if gate.randf() >= chance:
		out.notes.append("Quiet leg: %d of %d encounters were eligible, none rolled." % [out.eligible, out.considered])
		return out

	var pick := _rng(base_seed, "encounter-pick")
	var roll := pick.randi_range(1, maxi(1, total_weight))
	var chosen: Dictionary = eligible[eligible.size() - 1]
	var running := 0
	for row in eligible:
		running += int(row.get("weight", 0))
		if roll <= running:
			chosen = row
			break

	out.encounter_id = str(chosen.get("id", ""))
	out.encounter = chosen
	out.flavour_only = bool(chosen.get("flavour_only", false))
	out.options = options_for(chosen, party)
	out.notes.append("%s on this leg (%d of %d eligible, weight roll %d of %d)." % [out.encounter_id, out.eligible, out.considered, roll, total_weight])
	return out


## Which options the player can actually take, given what the outfit has on it.
static func options_for(row: Dictionary, party_source: Dictionary) -> Array:
	var party := _party_from(party_source)
	var listed: Array = []
	for option in row.get("options", []):
		if not option is Dictionary:
			continue
		var entry := {
			"id": str(option.get("id", "")),
			"label": str(option.get("label", "")),
			"available": true,
			"unavailable_reason": "",
		}
		var requires: Dictionary = option.get("requires", {})
		for key in requires.keys():
			var needed := int(requires[key])
			if int(party.get(str(key), 0)) < needed:
				entry["available"] = false
				entry["unavailable_reason"] = "needs %d %s" % [needed, str(key)]
				break
		listed.append(entry)
	return listed


static func _outcome_weight(outcome: Dictionary, party_source: Dictionary) -> int:
	var weight := int(outcome.get("weight", 0))
	var perk_weight: Dictionary = outcome.get("perk_weight", {})
	for flag in perk_weight.keys():
		if bool(party_source.get(str(flag), false)):
			weight += int(perk_weight[flag])
	return clampi(weight, 1, 1000)


## Applies one outcome's effects to the party, bounded. This is the only place
## that touches party numbers, so every ceiling lives in one function:
## you cannot lose more cattle than are standing there or more than the
## encounter's own max_cattle_loss_fraction allows, money and ammunition stop
## at zero rather than going negative, condition stays inside 0-1, trust stays
## inside 0-5, and a leg's time delta stays inside a day.
static func _apply_effects(row: Dictionary, effects: Dictionary, party_source: Dictionary) -> Dictionary:
	var party := _party_from(party_source)
	var before := party.duplicate()
	var bounds: Array = []

	var minutes := clampi(int(effects.get("minutes", 0)), MIN_MINUTES_DELTA, MAX_MINUTES_DELTA)
	if minutes != int(effects.get("minutes", 0)):
		bounds.append("minutes clamped to %d" % minutes)

	var herd := int(party["herd_count"])
	var fraction := clampf(float(effects.get("cattle_fraction", 0.0)), 0.0, 1.0)
	var flat := int(effects.get("cattle_flat", 0))
	var loss := int(round(float(herd) * fraction)) + maxi(0, -flat)
	var gain := maxi(0, flat)
	var ceiling_fraction := clampf(float(row.get("max_cattle_loss_fraction", 0.0)), 0.0, 1.0)
	var ceiling := int(ceil(float(herd) * ceiling_fraction))
	if loss > ceiling:
		bounds.append("cattle loss %d capped at this encounter's ceiling of %d" % [loss, ceiling])
		loss = ceiling
	if loss > herd:
		bounds.append("cattle loss %d capped at the %d head actually present" % [loss, herd])
		loss = herd
	party["herd_count"] = maxi(0, herd - loss + gain)

	var money_delta := int(effects.get("money", 0))
	var money_after := int(party["money"]) + money_delta
	if money_after < 0:
		bounds.append("paid only the %d on hand, %d short" % [int(party["money"]), -money_after])
		money_after = 0
	party["money"] = money_after

	var ammunition_after := int(party["ammunition"]) + int(effects.get("ammunition", 0))
	if ammunition_after < 0:
		bounds.append("spent only the %d rounds on hand" % int(party["ammunition"]))
		ammunition_after = 0
	party["ammunition"] = ammunition_after

	party["condition"] = clampf(float(party["condition"]) + float(effects.get("condition", 0.0)), 0.0, 1.0)
	party["trust"] = clampi(int(party["trust"]) + int(effects.get("trust", 0)), MIN_TRUST, MAX_TRUST)

	var applied := {
		"minutes": minutes,
		"cattle": party["herd_count"] - before["herd_count"],
		"condition": party["condition"] - before["condition"],
		"money": party["money"] - before["money"],
		"ammunition": party["ammunition"] - before["ammunition"],
		"trust": party["trust"] - before["trust"],
	}
	## Perk flags and anything else the caller carries survive untouched.
	var party_after := party_source.duplicate()
	for key in party.keys():
		party_after[key] = party[key]
	return {"party_after": party_after, "applied": applied, "bounds": bounds}


## Resolves one chosen option.
##
## params:
##   encounter_id: String          -- or pass 'encounter' directly
##   encounter: Dictionary         -- optional, skips the table lookup
##   option_id: String
##   party: Dictionary
##   seed: int                     -- the same leg seed roll_for_leg was given
##   table: Dictionary             -- optional preloaded load_table() result
##
## Returns { ok, outcome_id, text, applied, party_after, bounds, notes }
static func resolve_choice(params: Dictionary) -> Dictionary:
	var out := {
		"ok": false,
		"outcome_id": "",
		"text": "",
		"applied": {},
		"party_after": _party_from(params.get("party", {})),
		"bounds": [],
		"notes": [],
	}
	var row: Dictionary = params.get("encounter", {})
	if row.is_empty():
		var table: Dictionary = params.get("table", {})
		if table.is_empty():
			table = load_table()
		var wanted := str(params.get("encounter_id", ""))
		if not table.get("by_id", {}).has(wanted):
			out.notes.append("No encounter '%s' in the table." % wanted)
			return out
		row = table["by_id"][wanted]

	var option_id := str(params.get("option_id", ""))
	var option: Dictionary = {}
	for candidate in row.get("options", []):
		if candidate is Dictionary and str(candidate.get("id", "")) == option_id:
			option = candidate
			break
	if option.is_empty():
		out.notes.append("No option '%s' on encounter '%s'." % [option_id, str(row.get("id", ""))])
		return out

	var party_source: Dictionary = params.get("party", {})
	var party := _party_from(party_source)
	var requires: Dictionary = option.get("requires", {})
	for key in requires.keys():
		if int(party.get(str(key), 0)) < int(requires[key]):
			out.notes.append("Option '%s' needs %d %s; the outfit has %d." % [option_id, int(requires[key]), str(key), int(party.get(str(key), 0))])
			return out

	var outcomes: Array = option.get("outcomes", [])
	var total := 0
	for outcome in outcomes:
		total += _outcome_weight(outcome, party_source)
	var rng := _rng(int(params.get("seed", 0)), "outcome:%s:%s" % [str(row.get("id", "")), option_id])
	var roll := rng.randi_range(1, maxi(1, total))
	var chosen: Dictionary = outcomes[outcomes.size() - 1]
	var running := 0
	for outcome in outcomes:
		running += _outcome_weight(outcome, party_source)
		if roll <= running:
			chosen = outcome
			break

	var effects: Dictionary = chosen.get("effects", {})
	var applied := _apply_effects(row, effects, party_source)
	out.ok = true
	out.outcome_id = str(chosen.get("id", ""))
	out.text = str(chosen.get("text", ""))
	out.applied = applied["applied"]
	out.party_after = applied["party_after"]
	out.bounds = applied["bounds"]
	out.notes.append("%s / %s / %s (roll %d of %d)." % [str(row.get("id", "")), option_id, out.outcome_id, roll, total])
	return out


## Roll and resolve in one call, choosing among the available options by the
## same seed. This is the path a bot or an automated replay takes; a player
## facing the choice goes through roll_for_leg then resolve_choice instead.
static func run_leg(params: Dictionary) -> Dictionary:
	var rolled := roll_for_leg(params)
	var out := {
		"encounter_id": rolled["encounter_id"],
		"option_id": "",
		"outcome_id": "",
		"text": "",
		"applied": {},
		"party_after": _party_from(params.get("party", {})),
		"bounds": [],
		"considered": rolled["considered"],
		"eligible": rolled["eligible"],
		"notes": rolled["notes"],
	}
	if str(rolled["encounter_id"]).is_empty():
		return out
	var available: Array = []
	for option in rolled["options"]:
		if bool(option["available"]):
			available.append(str(option["id"]))
	if available.is_empty():
		out.notes.append("Encounter %s rolled but the outfit can afford none of its options." % rolled["encounter_id"])
		return out
	var rng := _rng(int(params.get("seed", 0)), "auto-option:%s" % str(rolled["encounter_id"]))
	var option_id: String = available[rng.randi_range(0, available.size() - 1)]
	var resolved := resolve_choice({
		"encounter": rolled["encounter"],
		"option_id": option_id,
		"party": params.get("party", {}),
		"seed": int(params.get("seed", 0)),
	})
	out.option_id = option_id
	out.outcome_id = resolved["outcome_id"]
	out.text = resolved["text"]
	out.applied = resolved["applied"]
	out.party_after = resolved["party_after"]
	out.bounds = resolved["bounds"]
	for note in resolved["notes"]:
		out.notes.append(note)
	return out
