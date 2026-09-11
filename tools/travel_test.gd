extends SceneTree
## Headless checks for scripts/travel.gd. No rendering, no scene tree, no files:
## the county is built in memory here so this test does not depend on whichever
## data/locations files happen to exist while it runs.
##
## A failed assert() in headless Godot hangs rather than exits, and the runner
## then reports a timeout instead of a failure, so nothing below asserts.
## Failures are collected and reported with push_error + printerr + quit(1).
##
## SABOTAGE SEAM. Set CATTLE_TRAIL_TRAVEL_SABOTAGE=all_reachable and the fixture
## county is rewritten so every location lists every other as a neighbour, which
## is exactly what a broken graph reader would produce. The run must go red. It
## exists so "the unreachable destination was refused" can be proved to be a
## real result rather than a check that cannot fail.

const Travel = preload("res://scripts/travel.gd")
const Clock = preload("res://scripts/trail_clock.gd")

## Floor on the number of checks, set well below the real count so a truncated
## or short-circuited run reports itself instead of passing quietly.
const MINIMUM_CHECKS := 30

var checks := 0
var failures: Array[String] = []


class RecordingResolver:
	## Stands in for the encounter resolver another agent is building. It only
	## proves travel.gd makes the documented call; it authors no content.
	var calls: Array[Dictionary] = []
	var hours_added := 0.0
	var text := "A rider passed going the other way and would not look up."

	func resolve_leg_encounter(context: Dictionary) -> Dictionary:
		calls.append(context)
		return {"id": "test_encounter", "text": text, "hours_added": hours_added}


class BrokenResolver:
	func resolve_leg_encounter(_context: Dictionary) -> Variant:
		return "not a dictionary"


func _initialize() -> void:
	var county := _fixture()
	var sabotaged := OS.get_environment("CATTLE_TRAIL_TRAVEL_SABOTAGE") == "all_reachable"
	if sabotaged:
		county = _sabotage_all_reachable(county)
		print("SABOTAGE ACTIVE: every location rewritten to neighbour every other.")

	_graph_checks(county)
	_clock_checks(county)
	_refusal_checks(county)
	_encounter_checks(county)
	_preview_checks()

	if checks < MINIMUM_CHECKS:
		failures.append("Only %d checks ran; at least %d were expected. The run was cut short." % [checks, MINIMUM_CHECKS])
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		printerr("TRAVEL FAILED: %d of %d checks failed" % [failures.size(), checks])
		quit(1)
		return
	print("TRAVEL PASS: %d checks; symmetric graph, nobody stranded, hours are the endpoints' cost, clock arithmetic across a day boundary, night on arrival, refusals name a reason and spend no time, one documented encounter call per leg" % checks)
	quit(0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


## A county with a hub, a dead end two legs out, and two places that are not
## neighbours, so "refuse an unreachable destination" has something to refuse.
##   clear_fork -- fort_griffin
##   clear_fork -- the_narrow_water -- bellhollow
func _fixture() -> Dictionary:
	return {
		"clear_fork": {"id": "clear_fork", "name": "Clear Fork", "kind": "home", "blurb": "Home ground.",
			"encounters": ["drover_who_isnt"],
			"travel": {"neighbours": ["fort_griffin", "the_narrow_water"], "hours": 4}},
		"fort_griffin": {"id": "fort_griffin", "name": "Fort Griffin", "kind": "town", "blurb": "Hides and soldiers.",
			"encounters": ["bounty_poster"],
			"travel": {"neighbours": ["clear_fork"], "hours": 8}},
		"the_narrow_water": {"id": "the_narrow_water", "name": "The Narrow Water", "kind": "crossing", "blurb": "The bank is not honest.",
			"encounters": ["ford_widow"],
			"travel": {"neighbours": ["clear_fork", "bellhollow"], "hours": 5}},
		"bellhollow": {"id": "bellhollow", "name": "Bellhollow", "kind": "wild", "blurb": "A bell nobody rings.",
			"travel": {"neighbours": ["the_narrow_water"], "hours": 7}},
	}


func _sabotage_all_reachable(county: Dictionary) -> Dictionary:
	var wrecked := county.duplicate(true)
	for id in wrecked:
		var others: Array = wrecked.keys().filter(func(other): return other != id)
		wrecked[id]["travel"]["neighbours"] = others
	return wrecked


func _graph_checks(county: Dictionary) -> void:
	var problems := Travel.audit(county)
	_check(problems.is_empty(), "The fixture county must audit clean, got: " + ", ".join(problems))

	for id in county:
		_check(not Travel.neighbours(county, id).is_empty(), "%s has no neighbours: a player who rode there would be stranded." % id)
		var reach := Travel.reachable_from(county, id)
		_check(reach.size() == county.size(), "Every location must be reachable from %s; reached %d of %d." % [id, reach.size(), county.size()])
		var home := Travel.route(county, id, "clear_fork")
		_check(not home.is_empty(), "There must always be a way home from %s." % id)

	for id in county:
		for other in Travel.neighbours(county, id):
			_check(id in Travel.neighbours(county, other), "Travel must be symmetric: %s lists %s but not the reverse." % [id, other])
			_check(Travel.leg_hours(county, id, other) == Travel.leg_hours(county, other, id), "A leg must cost the same in both directions: %s to %s." % [id, other])

	_check(Travel.leg_hours(county, "clear_fork", "fort_griffin") == 8, "A leg costs the greater of the two endpoints' declared hours (4 and 8 is 8).")
	_check(Travel.leg_hours(county, "clear_fork", "the_narrow_water") == 5, "Clear Fork to the Narrow Water is the crossing's 5 hours, not home's 4.")

	var far := Travel.route(county, "fort_griffin", "bellhollow")
	_check(far.size() == 4, "Fort Griffin to Bellhollow is three legs by way of home and the crossing, got %d stops." % far.size())
	_check(Travel.total_hours(county, far) == 8 + 5 + 7, "The long way round costs the sum of its legs.")

	# A graph reader that cannot see a missing file is worse than one that
	# reports it, so audit has to be able to fail.
	var broken := _fixture()
	broken["bellhollow"]["travel"]["neighbours"] = ["nowhere_at_all"]
	var broken_problems := Travel.audit(broken)
	_check(broken_problems.size() >= 2, "Audit must report both the missing neighbour file and the broken symmetry, got %d problems." % broken_problems.size())
	_check(Travel.neighbours(broken, "bellhollow").is_empty(), "A neighbour with no location file is never offered as a ride.")


func _clock_checks(county: Dictionary) -> void:
	# Day boundary: out of Fort Griffin at Day 1 20:00, eight hours, down at Day 2 04:00.
	var evening := 1200.0
	_check(Clock.label(evening) == "Day 1 20:00", "Fixture departure time must read Day 1 20:00, got " + Clock.label(evening))
	var overnight := Travel.plan_leg(county, "fort_griffin", "clear_fork", evening)
	_check(bool(overnight.ok), "The ride home from Fort Griffin must be allowed.")
	_check(int(overnight.hours) == 8, "That leg is 8 hours, got %d." % int(overnight.get("hours", 0)))
	_check(float(overnight.arrive_minutes) == evening + 480.0, "Eight hours is 480 trail minutes.")
	_check(str(overnight.arrive_label) == "Day 2 04:00", "The clock must roll over the day: expected Day 2 04:00, got " + str(overnight.get("arrive_label", "")))
	_check(bool(overnight.departs_at_night), "20:00 is after dark.")
	_check(bool(overnight.arrives_at_night), "04:00 is still dark.")
	_check(bool(overnight.is_night_leg), "A leg run from 20:00 to 04:00 is a night leg.")

	# Daylight leg, same graph, no night flags anywhere.
	var morning := 1440.0 + 420.0  # Day 2 07:00
	var daylight := Travel.plan_leg(county, "clear_fork", "the_narrow_water", morning)
	_check(str(daylight.arrive_label) == "Day 2 12:00", "Seven in the morning plus five hours is noon, got " + str(daylight.get("arrive_label", "")))
	_check(not bool(daylight.departs_at_night), "07:00 is daylight.")
	_check(not bool(daylight.arrives_at_night), "12:00 is daylight.")
	_check(not bool(daylight.is_night_leg), "A leg run entirely between 07:00 and 12:00 is not a night leg.")

	# A leg that starts in daylight and ends in daylight but runs through dark.
	var long_haul := Travel.is_night_leg(1020.0, 1020.0 + 720.0)  # 17:00 to 05:00 next day
	_check(long_haul, "A twelve-hour haul from 17:00 crosses the dark and must count as a night leg.")
	_check(Travel.is_night(1140.0), "19:00 is night.")
	_check(not Travel.is_night(1139.0), "18:59 is not night.")
	_check(Travel.is_night(240.0), "04:00 is night.")
	_check(not Travel.is_night(300.0), "05:00 is daylight again.")
	_check(Travel.hour_of_day(1440.0 + 90.0) == 1, "Hour of day wraps with the day, not past it.")

	var rows := Travel.destinations(county, "clear_fork", evening)
	_check(rows.size() == 2, "Clear Fork offers two rides in the fixture, got %d." % rows.size())
	_check(int(rows[0].hours) <= int(rows[1].hours), "Destinations are listed cheapest first.")
	_check(not str(rows[0].blurb).is_empty(), "Every destination row carries the schema's blurb for the player to read.")


func _refusal_checks(county: Dictionary) -> void:
	var clock := 720.0

	var unreachable := Travel.ride({"locations": county, "from": "fort_griffin", "to": "bellhollow", "now_minutes": clock})
	_check(not bool(unreachable.ok), "Fort Griffin to Bellhollow is not one leg and must be refused.")
	_check(str(unreachable.get("reason", "")) == Travel.REFUSED_NOT_NEIGHBOUR, "The refusal names its reason, got '%s'." % str(unreachable.get("reason", "")))
	_check(str(unreachable.get("message", "")).contains("Clear Fork"), "The refusal must say which way round to go, got: " + str(unreachable.get("message", "")))
	_check(float(unreachable.now_minutes) == clock, "A refused ride spends no time.")

	var nowhere := Travel.ride({"locations": county, "from": "clear_fork", "to": "abilene", "now_minutes": clock})
	_check(not bool(nowhere.ok), "A destination with no location file is refused rather than ridden to.")
	_check(str(nowhere.get("reason", "")) == Travel.REFUSED_UNKNOWN_DESTINATION, "An unknown destination says so.")
	_check(not str(nowhere.get("message", "")).is_empty(), "Every refusal carries a sentence a player can read.")

	var here := Travel.ride({"locations": county, "from": "clear_fork", "to": "clear_fork", "now_minutes": clock})
	_check(str(here.get("reason", "")) == Travel.REFUSED_SAME_PLACE, "Riding to where you already stand is refused, not charged for.")

	var broke := Travel.ride({"locations": county, "from": "clear_fork", "to": "fort_griffin", "now_minutes": clock, "time_budget_hours": 5})
	_check(not bool(broke.ok), "An eight-hour leg against a five-hour budget must be refused.")
	_check(str(broke.get("reason", "")) == Travel.REFUSED_NO_TIME, "An unaffordable leg says it is unaffordable, got '%s'." % str(broke.get("reason", "")))
	_check(float(broke.now_minutes) == clock, "A refused leg leaves the clock where it was.")

	var afforded := Travel.ride({"locations": county, "from": "clear_fork", "to": "the_narrow_water", "now_minutes": clock, "time_budget_hours": 5})
	_check(bool(afforded.ok), "A five-hour leg against a five-hour budget is affordable.")

	var empty_county := {}
	var nothing := Travel.ride({"locations": empty_county, "from": "clear_fork", "to": "fort_griffin", "now_minutes": clock})
	_check(not bool(nothing.ok) and str(nothing.get("reason", "")) == Travel.REFUSED_UNKNOWN_ORIGIN, "An empty county refuses cleanly rather than crashing.")


func _encounter_checks(county: Dictionary) -> void:
	var clock := 720.0

	var unwired := Travel.ride({"locations": county, "from": "clear_fork", "to": "fort_griffin", "now_minutes": clock})
	_check(bool(unwired.encounter.get("placeholder", false)), "With no resolver wired the leg reports a placeholder, not silence.")
	_check(float(unwired.now_minutes) == clock + 480.0, "The clock advances by the leg's hours and nothing else.")

	var resolver := RecordingResolver.new()
	var wired := Travel.ride({"locations": county, "from": "clear_fork", "to": "the_narrow_water", "now_minutes": clock, "encounter_resolver": resolver, "with_herd": true})
	_check(resolver.calls.size() == 1, "Exactly one encounter call per leg, got %d." % resolver.calls.size())
	var context: Dictionary = resolver.calls[0] if resolver.calls.size() == 1 else {}
	for key in ["from", "to", "hours", "depart_minutes", "arrive_minutes", "is_night_leg", "departs_at_night", "arrives_at_night", "encounter_ids", "kinds", "with_herd"]:
		_check(context.has(key), "The documented encounter context is missing '%s'." % key)
	_check(context.get("encounter_ids", []) == ["drover_who_isnt", "ford_widow"], "Both endpoints' encounter ids reach the resolver, origin first.")
	_check(bool(context.get("with_herd", false)), "with_herd reaches the resolver so a drive leg can be told from an ordinary ride.")
	_check(str(wired.encounter.get("id", "")) == "test_encounter", "The resolver's own answer is what gets reported.")
	_check(wired.log.has(resolver.text), "The encounter's line reaches the player's log.")

	resolver.hours_added = 2.0
	var delayed := Travel.ride({"locations": county, "from": "clear_fork", "to": "the_narrow_water", "now_minutes": clock, "encounter_resolver": resolver})
	_check(float(delayed.now_minutes) == clock + 300.0 + 120.0, "Hours the encounter cost are added to the clock, not discarded.")
	_check(float(delayed.encounter_hours) == 2.0, "The leg reports how much time the encounter took.")

	var broken := Travel.ride({"locations": county, "from": "clear_fork", "to": "fort_griffin", "now_minutes": clock, "encounter_resolver": BrokenResolver.new()})
	_check(bool(broken.ok), "A resolver that returns nonsense must not break the ride.")
	_check(float(broken.now_minutes) == clock + 480.0, "A nonsense encounter costs no time rather than an undefined amount.")

	# Round trip: there and back puts you home, having spent both legs.
	var out_leg := Travel.ride({"locations": county, "from": "clear_fork", "to": "fort_griffin", "now_minutes": clock})
	var back_leg := Travel.ride({"locations": county, "from": "fort_griffin", "to": "clear_fork", "now_minutes": float(out_leg.now_minutes)})
	_check(bool(back_leg.ok), "There is always a way back.")
	_check(float(back_leg.now_minutes) == clock + 960.0, "A round trip costs both legs, never a discount for going home.")


func _preview_checks() -> void:
	var problems := Travel.audit(Travel.PREVIEW_COUNTY)
	_check(problems.is_empty(), "The world map's stand-in graph must obey the same rules it displays, got: " + ", ".join(problems))
	var reach := Travel.reachable_from(Travel.PREVIEW_COUNTY, "the_hargrove_range")
	_check(reach.size() == Travel.PREVIEW_COUNTY.size(), "Every place in the stand-in county is reachable from its far corner.")
