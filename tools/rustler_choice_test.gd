extends SceneTree
## The Clear Fork rustler surrenders and the player says what happens to him.
## This check exists to prove the three answers are actually different, so it
## measures the outcome the room applies, not the buttons it draws.
const Room = preload("res://scripts/room.gd")

class StubActor extends Node2D:
	var action_time := 0.0
	var last_action := ""
	var posed := false
	func action(name: String, _direction := Vector2.RIGHT) -> void:
		last_action = name
		action_time = 0.5
	func pose(_moving: bool, _direction := Vector2.RIGHT, _speed := 0.0, _mode := "walk") -> void:
		posed = true

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

## A room object with only the pieces a decision touches. No scene, no
## rendering, no companion.
func beaten_room() -> Control:
	var room: Control = Room.new()
	room.rustler = StubActor.new()
	room.add_child(room.rustler)
	room.rustler_surrenders("beaten")
	return room

## What a player can still see about this rustler after the dust settles.
func outcome_of(choice: String) -> Dictionary:
	var room := beaten_room()
	var opening: int = room.cash
	var accepted: bool = room.choose_rustler(choice)
	var record := {
		"accepted": accepted,
		"cash_delta": room.cash - opening,
		"present": room.rustler_present,
		"escaping": room.escaped,
		"hired": room.rustler_hired,
		"journal": room.message,
		"closing": room.eleanor_closing_line(),
		"outcome": room.rustler_outcome(),
	}
	room.free()
	return record

func _initialize() -> void:
	check(Room.RUSTLER_CHOICES.size() >= 3, "At least three answers must be offered")
	check(Room.rustler_fate_for("nonsense").is_empty(), "An unauthored choice has no fate")

	# The authored table: every row differs from every other row on money, and
	# no two rows share a line of writing.
	var seen_cash := {}
	var seen_text := {}
	for choice in Room.RUSTLER_CHOICES:
		var fate: Dictionary = Room.rustler_fate_for(choice)
		check(not fate.is_empty(), "Authored fate for " + choice)
		check(not seen_cash.has(int(fate.cash)), "Distinct money for " + choice)
		seen_cash[int(fate.cash)] = choice
		for key in ["journal", "eleanor_line", "rustler_line", "label", "short"]:
			var line := str(fate[key])
			check(line.length() > 0, "Written line for %s.%s" % [choice, key])
			check(not line.contains(String.chr(0x2014)), "No em dash in %s.%s" % [choice, key])
			check(not seen_text.has(line), "Line reused across fates: " + line)
			seen_text[line] = choice
	check(seen_cash.size() == Room.RUSTLER_CHOICES.size(), "Every fate pays a different amount")

	# The applied outcome, measured on a real room object one choice at a time.
	# A build where all three answers secretly did the same thing fails here:
	# the tuples below would collide even if the authored table above was fine.
	var applied := {}
	for choice in Room.RUSTLER_CHOICES:
		var record := outcome_of(choice)
		check(record.accepted, "The room accepts " + choice)
		check(record.outcome.fate == choice, "The room records which answer was given")
		check(not record.outcome.pending, "A decided encounter stops asking")
		check(record.journal != "beaten", "A decision writes its own journal line")
		check(record.closing.length() > 0 and record.closing != "Eleanor: Clear Fork is behind us.",
			"Eleanor closes differently once a fate is chosen")
		var signature := "%d|%s|%s" % [record.cash_delta, record.present, record.hired]
		check(not applied.has(signature), "Applied outcome for %s differs from %s" % [choice, applied.get(signature, "")])
		applied[signature] = choice
		check(record.escaping == not record.present, "He leaves the ground exactly when his fate says he is gone")
	check(applied.size() == Room.RUSTLER_CHOICES.size(), "Three answers produce three durable outcomes")

	# The two the design requires by name.
	var loose := outcome_of("loose")
	var hire := outcome_of("hire")
	var law := outcome_of("law")
	check(not loose.present and not loose.hired, "Letting him go removes him for good")
	check(hire.present and hire.hired, "Hiring him keeps a hand on the outfit")
	check(law.cash_delta > 0 and law.present and not law.hired, "The law pays a bounty and holds him")
	check(loose.cash_delta != hire.cash_delta and hire.cash_delta != law.cash_delta and loose.cash_delta != law.cash_delta,
		"Money moves differently for every answer")

	# Nothing can be decided twice, and nothing can be decided early.
	var fresh: Control = Room.new()
	fresh.rustler = StubActor.new()
	fresh.add_child(fresh.rustler)
	check(not fresh.rustler_choice_pending(), "No decision is offered before he is beaten")
	check(not fresh.choose_rustler("law") and fresh.cash == 342, "An unbeaten rustler cannot be sold to the county")
	fresh.rustler_surrenders("beaten")
	check(not fresh.rustler_active and fresh.rustler_choice_pending(), "Two hits leave him waiting, not gone")
	check(not fresh.escaped, "A surrendered man waits instead of running")
	check(fresh.rustler.last_action == "yield_southwest", "He plays his giving-up pose")
	var paid: int = fresh.cash
	check(fresh.choose_rustler("law") and fresh.cash == paid + 25, "The bounty is paid once")
	check(not fresh.choose_rustler("hire") and fresh.cash == paid + 25 and fresh.rustler_fate == "law",
		"A settled fate cannot be overwritten")
	fresh.free()

	# The room must still be finishable whatever the player decides, including
	# refusing to decide at all.
	var ignored := beaten_room()
	check(not ignored.rustler_active, "Gathering is never blocked by an open decision")
	check(ignored.eleanor_closing_line().contains("waiting"), "An undecided rustler is named at completion")
	ignored.free()

	check(checks >= 60, "Instrument check: this suite must actually run its cases")
	if failures == 0: print("RUSTLER CHOICE PASS: %d checks; three answers, three durable outcomes, one decision each, room still finishable" % checks)
	quit(1 if failures else 0)
