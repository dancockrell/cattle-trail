extends SceneTree
## The location loader. Two things are being proved here and they are separate
## claims: that Clear Fork loads out of its file with the numbers the room
## actually uses, and that a broken location is refused by name rather than
## half built.
##
## Every rejection case below is paired with a control: the same fixture with
## the fault taken back out, which must load. Without that pair a validator
## that rejected everything would pass this file, and a validator that rejected
## everything carries exactly as much information as one that rejects nothing.
##
## A failed assert in headless Godot hangs instead of exiting, so nothing here
## asserts. Faults are pushed, printed and counted, and the run ends on quit(1).
const Location = preload("res://scripts/location.gd")
const Room = preload("res://scripts/room.gd")
const FIXTURE_FOLDER := "user://location_test"

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error("LOCATION FAIL: " + label)
	print("LOCATION FAIL: ", label)


## A location that is deliberately fine. Every rejection case starts from this
## and breaks exactly one thing, so a red result names the thing that was
## broken rather than anything else about the fixture.
func sound_fixture() -> Dictionary:
	return {
		"id": "fixture",
		"name": "Fixture Flat",
		"kind": "wild",
		"blurb": "A place that exists only to be broken.",
		"ground": {"texture": "res://assets/ground-v3.png", "modulate": [1.0, 1.0, 1.0, 1.0]},
		"bounds": {"x": [24, 616], "y": [71, 303]},
		"arrivals": {"x": 200, "y": 200},
		"scenery": {"recipe": "authored", "props": []},
		"cast": [
			{"id": "rider", "role": "player"},
			{"id": "eleanor", "role": "companion", "x": 300, "y": 200},
		],
		"encounters": [],
		"travel": {"neighbours": [], "hours": 4},
	}


func write_fixture(document: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(FIXTURE_FOLDER)
	var path: String = FIXTURE_FOLDER.path_join(str(document.get("id", "fixture")) + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "could not write the fixture at " + path)
		return path
	file.store_string(JSON.stringify(document, "  "))
	file.close()
	return path


func load_fixture(document: Dictionary):
	return Location.new(write_fixture(document))


## One rejection case: break the fixture, demand a refusal that says why, and
## demand that the loaded object stays empty rather than half filled.
func reject(label: String, needle: String, damage: Callable) -> void:
	var document := sound_fixture()
	damage.call(document)
	var broken = load_fixture(document)
	check(not broken.valid, "%s must be rejected" % label)
	var said := false
	for fault in broken.errors:
		if str(fault).findn(needle) >= 0: said = true
	check(said, "%s must be refused in words naming '%s'; got %s" % [label, needle, str(broken.errors)])
	check(broken.cast.is_empty() and broken.scenery.is_empty() and broken.bounds == Rect2()
		and broken.display_name.is_empty(),
		"%s must not half load: a rejected location keeps every field empty" % label)


func _initialize() -> void:
	# --- Clear Fork, out of its file, with the numbers the room builds from ---
	var clear_fork = Location.load_location("clear_fork")
	check(clear_fork.valid, "Clear Fork must load: " + clear_fork.fault_report())
	if clear_fork.valid:
		check(clear_fork.id == "clear_fork", "id")
		check(clear_fork.display_name == "Clear Fork", "name")
		check(clear_fork.kind == "home", "kind")
		check(clear_fork.ground_texture == "res://assets/ground-v3.png", "ground texture")
		check(clear_fork.ground_modulate == Color(1, 1, 1, 1), "ground modulate")
		check(clear_fork.bounds == Rect2(24, 71, 592, 232), "bounds, got " + str(clear_fork.bounds))
		check(clear_fork.arrival == Vector2(199, 231), "arrival, got " + str(clear_fork.arrival))
		check(clear_fork.scenery.size() == 69, "69 authored props, got %d" % clear_fork.scenery.size())
		check(clear_fork.cast.size() == 10, "10 cast members, got %d" % clear_fork.cast.size())
		check(clear_fork.goal_area == Rect2(475, 110, 125, 155), "east gathering, got " + str(clear_fork.goal_area))
		check(clear_fork.markers.size() == 1, "one map label, got %d" % clear_fork.markers.size())
		var cattle := 0
		var players := 0
		for member in clear_fork.cast:
			if str(member.role) == "cattle": cattle += 1
			if str(member.role) == "player": players += 1
		check(cattle == 6, "six head of cattle, got %d" % cattle)
		check(players == 1, "exactly one player, got %d" % players)
		# The bounds rule, on the real file: nobody in the cast is off the
		# walkable ground, which is the bug that already shipped once.
		var reachable := true
		for member in clear_fork.cast:
			if not clear_fork.bounds.has_point(member.position as Vector2): reachable = false
		check(reachable, "every Clear Fork cast member stands inside the walkable bounds")

	# --- the control: the fixture with nothing wrong with it must load ---
	var sound = load_fixture(sound_fixture())
	check(sound.valid, "the undamaged fixture must load, or every rejection below proves nothing: "
		+ sound.fault_report())
	check(sound.cast.size() == 2, "the undamaged fixture keeps its cast")
	var no_player := sound_fixture()
	no_player.cast.remove_at(0)
	no_player.id = "no_player"
	check(load_fixture(no_player).valid,
		"a location need not list the player: everyone else's files place nobody, and the player stands at arrivals")

	# --- rejections, one fault each ---
	reject("a cast member outside bounds", "outside bounds", func(d):
		d.cast[1].x = 900.0)
	reject("a cast member on the wrong side of the boundary", "outside bounds", func(d):
		d.cast[1].y = 12.0)
	reject("an unresolvable cast id", "resolves in none", func(d):
		d.cast[1].id = "nobody_by_that_name")
	reject("an arrival outside bounds", "arrivals", func(d):
		d.arrivals.x = -40.0)
	reject("a neighbour with no file", "has no file", func(d):
		d.travel.neighbours = ["a_place_nobody_wrote"])
	reject("a missing name", "name is missing", func(d):
		d.erase("name"))
	reject("a kind nobody supports", "kind", func(d):
		d.kind = "space_station")
	reject("missing bounds", "bounds is missing", func(d):
		d.erase("bounds"))
	reject("a ground texture that is not there", "does not exist", func(d):
		d.ground.texture = "res://assets/no-such-ground.png")
	reject("two players in the cast", "second player entry", func(d):
		d.cast.append({"id": "rider", "role": "player"}))
	reject("an encounter id nobody wrote", "is not in", func(d):
		d.encounters = ["an_encounter_that_was_never_written"])
	reject("a footprint left behind when its owner moved", "left behind", func(d):
		d.cast.append({"id": "wagon", "role": "prop", "x": 400.0, "y": 250.0})
		d.blockers = [{"id": "wagon", "rect": [39, 73, 100, 42]}])
	# Two cases that cannot be produced by damaging the document, because the
	# fixture writer names the file after the id it is given.
	var mismatched := sound_fixture()
	mismatched.id = "somewhere_else"
	var mismatched_path: String = write_fixture(mismatched)
	check(Location.new(mismatched_path).valid,
		"the mismatch control: the same document under its own name must load")
	var moved := FIXTURE_FOLDER.path_join("not_the_same_name.json")
	DirAccess.copy_absolute(mismatched_path, moved)
	var wrong_name = Location.new(moved)
	check(not wrong_name.valid, "a location whose id disagrees with its filename must be refused")
	check(wrong_name.display_name.is_empty(),
		"a location refused for a filename mismatch must not half load")

	# A missing file is its own case and is refused before anything is parsed.
	var absent = Location.load_location("a_location_that_was_never_written")
	check(not absent.valid, "a location with no file must be refused")
	check(not absent.errors.is_empty(), "a missing location must say what was missing")

	# --- the room refuses what the loader refuses ---
	var room: Control = Room.new()
	check(room.location != null and room.location.valid,
		"a fresh Room adopts Clear Fork from its file")
	check(room.CORRAL == Rect2(475, 110, 125, 155),
		"the room takes its gathering area from the file, got " + str(room.CORRAL))
	check(room.WAGON_FOOTPRINT == Rect2(39, 73, 100, 42),
		"the room takes the wagon footprint from the file, got " + str(room.WAGON_FOOTPRINT))
	check(room.limit_position(Vector2(0, 250)).x == 24,
		"the walkable bounds in the file are the ones the room clamps to")
	var damaged := sound_fixture()
	damaged.cast[1].x = 900.0
	check(not room.adopt_location(load_fixture(damaged), false),
		"the room must refuse an invalid location")
	check(room.location.id == "clear_fork",
		"a refused location must leave the room standing where it was")
	room.free()

	# --- the county as a whole: every file valid, travel symmetric ---
	var audit := Location.audit_all()
	check(audit.checked >= 1, "the audit must look at at least one location file, saw %d" % audit.checked)
	check(audit.faults.is_empty(), "every location file must load and travel must be symmetric:\n"
		+ "\n".join(PackedStringArray(audit.faults)))

	if failures > 0:
		printerr("LOCATION FAILED: %d of %d checks" % [failures, checks])
		quit(1)
		return
	if checks < 60:
		printerr("LOCATION FAILED: only %d checks ran; this file is meant to run far more" % checks)
		quit(1)
		return
	print("LOCATION PASS: %d checks; Clear Fork loads from data/locations/clear_fork.json, %d location file(s) audited, and a location with a cast member outside bounds, an unresolvable id, a missing neighbour or a stranded footprint is refused by name without half loading" % [checks, audit.checked])
	quit(0)
