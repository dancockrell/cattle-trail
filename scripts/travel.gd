extends RefCounted
## The travel layer: where you can ride from here, what the leg costs in trail
## hours, what the clock reads when you get down, and what happened on the way.
##
## design/EXPLORATION.md is the brief. Two of its rules are load-bearing here:
## travel connects the locations already written rather than a new map, and it
## spends the trail clock already running in scripts/trail_clock.gd rather than
## inventing a second time system. This file owns no clock. It converts hours to
## minutes and hands them to Clock.label(); day rollover is the clock's job and
## was already correct.
##
## The graph is the location files, per design/LOCATION-SCHEMA.md: each location
## carries travel.neighbours and travel.hours. Nothing here authors a location.
##
## Pure logic, same shape as scripts/trade_negotiation.gd and
## scripts/cattle_drive_resolver.gd: Dictionaries and numbers in and out, no
## scene tree, no autoload, no singleton. It reads JSON off disk in one function
## (load_county) and every other function takes an already-loaded county, so the
## graph reasoning is testable with no files present at all.
##
## ENCOUNTER SEAM (read this before building the encounter resolver)
## ----------------------------------------------------------------
## This file authors no encounter content and never will. On each leg it makes
## exactly one call, and only when the caller handed ride() a resolver object:
##
##     resolver.resolve_leg_encounter(context: Dictionary) -> Dictionary
##
## context = {
##     "from": String,                  # location id ridden from
##     "to": String,                    # location id ridden to
##     "hours": int,                    # the leg's cost before any encounter
##     "depart_minutes": float,         # trail clock at departure
##     "arrive_minutes": float,         # trail clock on arrival, before any encounter
##     "is_night_leg": bool,            # any part of the leg falls after dark
##     "departs_at_night": bool,
##     "arrives_at_night": bool,
##     "encounter_ids": Array,          # both endpoints' encounters fields, merged,
##                                      # from's first then to's, deduplicated
##     "kinds": Array,                  # [from.kind, to.kind]
##     "with_herd": bool,               # true when the herd is along, per design/DRIVES.md
## }
##
## The resolver returns {} when nothing happened, or:
##
##     {
##       "id": String,                  # the encounter id it chose, for the log
##       "text": String,                # one line the travel screen prints
##       "hours_added": float,          # optional, >= 0: extra hours this cost.
##                                      # travel.gd adds it to the clock and says so.
##     }
##
## is_night_leg is deliberately the same flag scripts/cattle_drive_resolver.gd
## already takes, so a drive leg can feed one into the other with no converter.
##
## Until a resolver exists, ride() returns PLACEHOLDER_ENCOUNTER, which says in
## its own text that it is a placeholder. It does not say the road was quiet.

const Clock = preload("res://scripts/trail_clock.gd")

const LOCATIONS_FOLDER := "res://data/locations"
const MINUTES_PER_HOUR := 60.0

## Night. design/EXPLORATION.md: "Nothing currently branches on day-versus-night;
## that is new logic on top of data the clock already produces." This is that
## logic, and these two numbers are the whole of it. First-pass and untuned:
## dark from 19:00, light again at 05:00. Nothing else in the county holds an
## opinion about when dark is, so this is the one place to change it.
const NIGHT_START_HOUR := 19
const NIGHT_END_HOUR := 5

## Used when a location's travel.hours is missing or nonsense. A leg always
## costs something: a free leg would be the fast travel the brief forbids.
const DEFAULT_LEG_HOURS := 6

const ENCOUNTER_METHOD := "resolve_leg_encounter"

const PLACEHOLDER_ENCOUNTER := {
	"id": "",
	"placeholder": true,
	"text": "PLACEHOLDER: no encounter resolver wired. The road was empty because nothing is built yet, not because nothing was out there.",
	"hours_added": 0.0,
}

## Refusal reasons from plan_leg() and ride(). The player is told which one it
## was, in words, rather than handed a button that does nothing.
const REFUSED_UNKNOWN_ORIGIN := "unknown_origin"
const REFUSED_UNKNOWN_DESTINATION := "unknown_destination"
const REFUSED_SAME_PLACE := "already_there"
const REFUSED_NOT_NEIGHBOUR := "not_a_neighbour"
const REFUSED_NO_TIME := "not_enough_time"

## Stand-in graph, used by scenes/world_map.tscn ONLY when data/locations holds
## no usable files, so the screen can be looked at before the location files
## land. Owner: the travel layer. Replacement: the real files under
## data/locations, authored against design/LOCATION-SCHEMA.md by the locations
## agent. Acceptance: world_map stops showing its PREVIEW banner the moment
## load_county() returns one or more locations, and this constant is then
## deleted outright. The shape is design/EXPLORATION.md's own graph block. It
## invents no location that document does not already have.
const PREVIEW_COUNTY := {
	"clear_fork": {"id": "clear_fork", "name": "Clear Fork", "kind": "home",
		"blurb": "Home ground. The wagon camp and the dry crossing.",
		"travel": {"neighbours": ["fort_griffin", "providence", "split_oak_camp", "the_narrow_water", "the_calloway_spread", "the_salt_flats", "the_quiet_rows"], "hours": 4}},
	"fort_griffin": {"id": "fort_griffin", "name": "Fort Griffin", "kind": "town",
		"blurb": "Hides, soldiers, and the auction. Loud, and it does not care what you saw.",
		"travel": {"neighbours": ["clear_fork"], "hours": 8}},
	"providence": {"id": "providence", "name": "Providence", "kind": "town",
		"blurb": "Raw lumber and a spur line that may never come.",
		"travel": {"neighbours": ["clear_fork"], "hours": 9}},
	"split_oak_camp": {"id": "split_oak_camp", "name": "Split Oak Camp", "kind": "camp",
		"blurb": "One split oak, a line shack, and everyone's notices nailed to the trunk.",
		"travel": {"neighbours": ["clear_fork"], "hours": 5}},
	"the_narrow_water": {"id": "the_narrow_water", "name": "The Narrow Water", "kind": "crossing",
		"blurb": "The ford is honest. The bank is not.",
		"travel": {"neighbours": ["clear_fork", "bellhollow"], "hours": 5}},
	"bellhollow": {"id": "bellhollow", "name": "Bellhollow", "kind": "wild",
		"blurb": "Played-out workings, a few holdouts, and a bell nobody rings.",
		"travel": {"neighbours": ["the_narrow_water"], "hours": 7}},
	"the_calloway_spread": {"id": "the_calloway_spread", "name": "The Calloway Spread", "kind": "spread",
		"blurb": "Better fence than yours, and older claim to the water.",
		"travel": {"neighbours": ["clear_fork", "the_hargrove_range"], "hours": 3}},
	"the_hargrove_range": {"id": "the_hargrove_range", "name": "The Hargrove Range", "kind": "spread",
		"blurb": "Fresh wire, half a barn, more debt than building.",
		"travel": {"neighbours": ["the_calloway_spread"], "hours": 4}},
	"the_salt_flats": {"id": "the_salt_flats", "name": "The Salt Flats", "kind": "wild",
		"blurb": "White ground, wrong sound. Cattle will not cross it on trust alone.",
		"travel": {"neighbours": ["clear_fork"], "hours": 12}},
	"the_quiet_rows": {"id": "the_quiet_rows", "name": "The Quiet Rows", "kind": "wild",
		"blurb": "A tended family plot. The headstone count does not hold still.",
		"travel": {"neighbours": ["clear_fork"], "hours": 11}},
}


# --- the clock, borrowed not rebuilt -------------------------------------

static func hour_of_day(minutes: float) -> int:
	if not is_finite(minutes):
		return 0
	return (maxi(0, int(minutes)) % 1440) / 60


## Dark from NIGHT_START_HOUR, light again at NIGHT_END_HOUR, across midnight.
static func is_night(minutes: float) -> bool:
	var hour := hour_of_day(minutes)
	return hour >= NIGHT_START_HOUR or hour < NIGHT_END_HOUR


static func hours_to_minutes(hours: float) -> float:
	return hours * MINUTES_PER_HOUR


## True when any part of a leg run between these two clock readings falls after
## dark. This is the flag scripts/cattle_drive_resolver.gd calls is_night_leg.
static func is_night_leg(depart_minutes: float, arrive_minutes: float) -> bool:
	if not is_finite(depart_minutes) or not is_finite(arrive_minutes):
		return false
	if arrive_minutes - depart_minutes >= 1440.0:
		return true
	var walk := floorf(depart_minutes)
	while walk < arrive_minutes:
		if is_night(walk):
			return true
		# Step to the next hour boundary rather than every minute: night only
		# changes on the hour, so an hourly walk cannot step over a transition.
		walk = floorf(walk / 60.0) * 60.0 + 60.0
	return is_night(arrive_minutes)


# --- the graph ------------------------------------------------------------

## Reads every data/locations/<id>.json into {id: location}. Returns
## {locations: Dictionary, problems: Array[String]}.
##
## It reports problems rather than refusing the whole county, on purpose: a
## half-authored county that names the bad files is more use to the agent
## authoring them than an empty screen. The schema's "the loader rejects it"
## rule is about cast and encounter ids, which this file does not own.
static func load_county(folder := LOCATIONS_FOLDER) -> Dictionary:
	var locations := {}
	var problems: Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		problems.append("No location folder at %s." % folder)
		return {"locations": locations, "problems": problems}
	var files := directory.get_files()
	files.sort()
	for filename in files:
		if filename.get_extension().to_lower() != "json":
			continue
		var text := FileAccess.get_file_as_string(folder.path_join(filename))
		if text.is_empty():
			problems.append("%s is empty." % filename)
			continue
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			problems.append("%s is not a JSON object." % filename)
			continue
		var record: Dictionary = parsed
		var id := str(record.get("id", ""))
		if id.is_empty():
			problems.append("%s has no id." % filename)
			continue
		if id != filename.get_basename():
			problems.append("%s declares id '%s'; the schema says the id matches the filename." % [filename, id])
		if locations.has(id):
			problems.append("Two files claim id '%s'." % id)
			continue
		locations[id] = record
	problems.append_array(audit(locations))
	return {"locations": locations, "problems": problems}


## Graph-only integrity. Says nothing about cast, bounds, art or encounter
## content: those belong to the location loader, not to travel.
static func audit(locations: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var ids := locations.keys()
	ids.sort()
	for id in ids:
		var listed := _raw_neighbours(locations, id)
		if listed.is_empty():
			problems.append("%s lists no neighbours: anyone who rides there is stranded." % id)
		for other in listed:
			var other_id := str(other)
			if not locations.has(other_id):
				problems.append("%s lists neighbour '%s', which has no location file." % [id, other_id])
				continue
			if not (str(id) in _raw_neighbours(locations, other_id)):
				problems.append("Travel is not symmetric: %s lists %s, %s does not list %s." % [id, other_id, other_id, id])
		var declared: Dictionary = locations.get(id, {}).get("travel", {})
		if declared.has("hours") and int(declared.get("hours", 0)) <= 0:
			problems.append("%s declares travel.hours %d; a leg has to cost something." % [id, int(declared.get("hours", 0))])
	return problems


static func _raw_neighbours(locations: Dictionary, id: String) -> Array:
	var record: Dictionary = locations.get(id, {})
	var travel: Dictionary = record.get("travel", {})
	var listed: Variant = travel.get("neighbours", [])
	return listed if typeof(listed) == TYPE_ARRAY else []


static func _declared_hours(locations: Dictionary, id: String) -> int:
	var record: Dictionary = locations.get(id, {})
	var travel: Dictionary = record.get("travel", {})
	var hours := int(travel.get("hours", DEFAULT_LEG_HOURS))
	return hours if hours > 0 else DEFAULT_LEG_HOURS


## Neighbours that actually exist, sorted, deduplicated. A neighbour named in a
## file with no location file of its own is dropped here and reported by audit()
## rather than offered to the player as a ride to nowhere.
static func neighbours(locations: Dictionary, id: String) -> Array[String]:
	var result: Array[String] = []
	for other in _raw_neighbours(locations, id):
		var other_id := str(other)
		if other_id == id or result.has(other_id):
			continue
		if locations.has(other_id):
			result.append(other_id)
	result.sort()
	return result


## The schema puts travel.hours on the location, not on the edge, so a leg's
## cost is the greater of the two endpoints' declared hours. That is symmetric
## by construction, which the schema's "travel is symmetric" rule demands, and
## it reads right: the far, hard place sets the price of reaching it.
static func leg_hours(locations: Dictionary, from_id: String, to_id: String) -> int:
	return maxi(_declared_hours(locations, from_id), _declared_hours(locations, to_id))


## Every location reachable from here, mapped to the number of legs it takes.
## The origin itself is included at 0.
static func reachable_from(locations: Dictionary, from_id: String) -> Dictionary:
	var seen := {}
	if not locations.has(from_id):
		return seen
	seen[from_id] = 0
	var queue: Array[String] = [from_id]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for other in neighbours(locations, here):
			if seen.has(other):
				continue
			seen[other] = int(seen[here]) + 1
			queue.append(other)
	return seen


## Fewest-legs route from one location to another, both ends included. Empty
## when nothing connects them. This is what keeps the player from being
## stranded: the map can always name the first leg of the way home even when
## home is three legs off.
static func route(locations: Dictionary, from_id: String, to_id: String) -> Array[String]:
	var empty: Array[String] = []
	if not locations.has(from_id) or not locations.has(to_id):
		return empty
	if from_id == to_id:
		var here_only: Array[String] = [from_id]
		return here_only
	var came_from := {from_id: ""}
	var queue: Array[String] = [from_id]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		for other in neighbours(locations, here):
			if came_from.has(other):
				continue
			came_from[other] = here
			if other == to_id:
				var path: Array[String] = []
				var walk := to_id
				while walk != "":
					path.push_front(walk)
					walk = str(came_from[walk])
				return path
			queue.append(other)
	return empty


static func total_hours(locations: Dictionary, path: Array) -> int:
	var hours := 0
	for index in range(1, path.size()):
		hours += leg_hours(locations, str(path[index - 1]), str(path[index]))
	return hours


# --- what the screen asks ------------------------------------------------

## One row per place you can ride to from here, ready to print. Sorted by hours
## then name, so the cheap rides sit at the top.
## Each row: {id, name, kind, blurb, hours, arrive_minutes, arrive_label,
##            arrives_at_night, is_night_leg, affordable, refusal}
## time_budget_hours of 0 or less means no budget, and every row is affordable.
static func destinations(locations: Dictionary, from_id: String, now_minutes: float, time_budget_hours := 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for other in neighbours(locations, from_id):
		var plan := plan_leg(locations, from_id, other, now_minutes, time_budget_hours)
		var record: Dictionary = locations.get(other, {})
		rows.append({
			"id": other,
			"name": str(record.get("name", other)),
			"kind": str(record.get("kind", "")),
			"blurb": str(record.get("blurb", "")),
			"hours": int(plan.get("hours", 0)),
			"arrive_minutes": float(plan.get("arrive_minutes", now_minutes)),
			"arrive_label": str(plan.get("arrive_label", "")),
			"arrives_at_night": bool(plan.get("arrives_at_night", false)),
			"is_night_leg": bool(plan.get("is_night_leg", false)),
			"affordable": bool(plan.get("ok", false)),
			"refusal": str(plan.get("message", "")),
		})
	rows.sort_custom(_cheaper_first)
	return rows


static func _cheaper_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a.hours) != int(b.hours):
		return int(a.hours) < int(b.hours)
	return str(a.name) < str(b.name)


## What one leg would cost and when it would put you down, without riding it.
## Returns {ok, reason, message, ...} and on ok also from, to, hours,
## depart_minutes, arrive_minutes, depart_label, arrive_label,
## departs_at_night, arrives_at_night, is_night_leg.
static func plan_leg(locations: Dictionary, from_id: String, to_id: String, now_minutes: float, time_budget_hours := 0) -> Dictionary:
	if not locations.has(from_id):
		return _refused(REFUSED_UNKNOWN_ORIGIN, "There is no location '%s' to ride out of." % from_id)
	if not locations.has(to_id):
		return _refused(REFUSED_UNKNOWN_DESTINATION, "There is no location '%s' to ride to." % to_id)
	if from_id == to_id:
		return _refused(REFUSED_SAME_PLACE, "You are already at %s." % _name_of(locations, to_id))
	if not (to_id in neighbours(locations, from_id)):
		var message := "No trail runs straight from %s to %s." % [_name_of(locations, from_id), _name_of(locations, to_id)]
		var path := route(locations, from_id, to_id)
		if path.size() > 1:
			message += " Go by way of %s: %d legs, %d hours." % [_name_of(locations, path[1]), path.size() - 1, total_hours(locations, path)]
		else:
			message += " Nothing connects them."
		return _refused(REFUSED_NOT_NEIGHBOUR, message)
	var hours := leg_hours(locations, from_id, to_id)
	var depart := now_minutes if is_finite(now_minutes) else 0.0
	if depart < 0.0:
		depart = 0.0
	if time_budget_hours > 0 and hours > time_budget_hours:
		return _refused(REFUSED_NO_TIME, "%s is %d hours out and you have %d. You cannot buy that leg." % [_name_of(locations, to_id), hours, time_budget_hours])
	var arrive := depart + hours_to_minutes(float(hours))
	return {
		"ok": true,
		"reason": "",
		"message": "",
		"from": from_id,
		"to": to_id,
		"hours": hours,
		"depart_minutes": depart,
		"arrive_minutes": arrive,
		"depart_label": Clock.label(depart),
		"arrive_label": Clock.label(arrive),
		"departs_at_night": is_night(depart),
		"arrives_at_night": is_night(arrive),
		"is_night_leg": is_night_leg(depart, arrive),
	}


## Rides one leg. params keys:
##   locations: Dictionary        -- the county, from load_county().locations
##   from: String, to: String     -- location ids
##   now_minutes: float           -- the trail clock, not owned here
##   time_budget_hours: int       -- optional, 0 means no budget
##   with_herd: bool              -- optional, design/DRIVES.md's herd-along case
##   encounter_resolver: Object   -- optional, see ENCOUNTER SEAM at the top
## Returns the plan_leg() dictionary, plus on success:
##   encounter: Dictionary        -- whatever the resolver said, or PLACEHOLDER_ENCOUNTER
##   encounter_hours: float       -- hours the encounter added, already in the clock
##   now_minutes: float           -- the clock AFTER the leg. Hand this back to the clock.
##   log: Array[String]           -- lines the screen prints, in order
## A refusal comes back with ok false, a reason, a sentence for the player, and
## the clock untouched. Nothing fails silently and nothing ever teleports.
static func ride(params: Dictionary) -> Dictionary:
	var locations: Dictionary = params.get("locations", {})
	var from_id := str(params.get("from", ""))
	var to_id := str(params.get("to", ""))
	var now_minutes := float(params.get("now_minutes", 0.0))
	var time_budget_hours := int(params.get("time_budget_hours", 0))
	var with_herd := bool(params.get("with_herd", false))
	var resolver: Object = params.get("encounter_resolver", null)

	var plan := plan_leg(locations, from_id, to_id, now_minutes, time_budget_hours)
	if not bool(plan.get("ok", false)):
		plan["now_minutes"] = now_minutes
		return plan

	var log_lines: Array[String] = []
	log_lines.append("Rode out of %s at %s." % [_name_of(locations, from_id), str(plan.depart_label)])
	log_lines.append("%d hours to %s." % [int(plan.hours), _name_of(locations, to_id)])

	var encounter := _resolve_encounter(resolver, {
		"from": from_id,
		"to": to_id,
		"hours": int(plan.hours),
		"depart_minutes": float(plan.depart_minutes),
		"arrive_minutes": float(plan.arrive_minutes),
		"is_night_leg": bool(plan.is_night_leg),
		"departs_at_night": bool(plan.departs_at_night),
		"arrives_at_night": bool(plan.arrives_at_night),
		"encounter_ids": _encounter_ids(locations, from_id, to_id),
		"kinds": [str(locations.get(from_id, {}).get("kind", "")), str(locations.get(to_id, {}).get("kind", ""))],
		"with_herd": with_herd,
	})

	var added := float(encounter.get("hours_added", 0.0))
	if not is_finite(added) or added < 0.0:
		added = 0.0
	var arrive := float(plan.arrive_minutes) + hours_to_minutes(added)
	if not str(encounter.get("text", "")).is_empty():
		log_lines.append(str(encounter.text))
	if added > 0.0:
		log_lines.append("That cost another %s." % _hours_phrase(added))

	plan["encounter"] = encounter
	plan["encounter_hours"] = added
	plan["arrive_minutes"] = arrive
	plan["arrive_label"] = Clock.label(arrive)
	plan["arrives_at_night"] = is_night(arrive)
	plan["is_night_leg"] = is_night_leg(float(plan.depart_minutes), arrive)
	plan["now_minutes"] = arrive
	log_lines.append("Down at %s, %s." % [_name_of(locations, to_id), str(plan.arrive_label)])
	if bool(plan.arrives_at_night):
		log_lines.append("Arrived after dark.")
	plan["log"] = log_lines
	return plan


static func _resolve_encounter(resolver: Object, context: Dictionary) -> Dictionary:
	if resolver == null or not resolver.has_method(ENCOUNTER_METHOD):
		return PLACEHOLDER_ENCOUNTER.duplicate(true)
	var answer: Variant = resolver.call(ENCOUNTER_METHOD, context)
	if typeof(answer) != TYPE_DICTIONARY:
		return {}
	return answer


static func _encounter_ids(locations: Dictionary, from_id: String, to_id: String) -> Array:
	var ids: Array = []
	for id in [from_id, to_id]:
		var record: Dictionary = locations.get(id, {})
		var listed: Variant = record.get("encounters", [])
		if typeof(listed) != TYPE_ARRAY:
			continue
		for entry in listed:
			var encounter_id := str(entry)
			if not ids.has(encounter_id):
				ids.append(encounter_id)
	return ids


static func _refused(reason: String, message: String) -> Dictionary:
	var lines: Array[String] = [message]
	return {"ok": false, "reason": reason, "message": message, "hours": 0, "log": lines}


static func _name_of(locations: Dictionary, id: String) -> String:
	var record: Dictionary = locations.get(id, {})
	return str(record.get("name", id))


static func _hours_phrase(hours: float) -> String:
	if hours >= 1.0:
		return "%d hours" % int(round(hours))
	return "%d minutes" % int(round(hours * MINUTES_PER_HOUR))
