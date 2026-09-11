extends RefCounted
## One place the game can build, loaded from data/locations/<id>.json.
##
## Every location is a file, Clear Fork included. Nothing about a place lives
## in room.gd any more: the ground, the walkable bounds, the scenery, the cast
## and the arrival point all come from here, so a second location is a new file
## rather than new code.
##
## A location either loads whole or does not load at all. Validation collects
## every fault by name first and only then assigns the typed fields, because a
## half-built place is worse than a missing one: it runs, it looks nearly
## right, and the thing it is missing is discovered by a player.
##
## The bounds check is the one that has already earned its place. Ten
## companions once shipped standing outside the walkable area, answering only
## within 36 units, so nobody could reach them and no check said a word.

const CHARACTER_RECORDS := "res://design/characters.json"
const NPC_RECORDS := "res://design/npcs.json"
const ENCOUNTER_RECORDS := "res://data/encounters.json"
const ART_MANIFEST := "res://assets/room-art.json"
const LOCATION_FOLDER := "res://data/locations"
const KINDS := ["home", "town", "spread", "wild", "crossing", "camp"]
const RECIPES := ["authored", "scattered"]
## A cast member standing exactly on the boundary is still reachable, because
## the player may stand on the boundary too. This margin only rejects the case
## the schema is actually about: somebody placed off the walkable ground.
const REACH_MARGIN := 4.0

var path := ""
var id := ""
var display_name := ""
var kind := ""
var blurb := ""
var ground_texture := ""
var ground_modulate := Color(1, 1, 1, 1)
var bounds := Rect2()
var arrival := Vector2.ZERO
var scenery: Array = []
var cast: Array = []
var markers: Array = []
var goal_area := Rect2()
var blockers: Array = []
var encounters: Array = []
var neighbours: Array = []
var travel_hours := 0.0
var art_gap := ""
var errors: Array = []
var valid := false


## The call a travel system makes. Always returns an instance; ask it whether
## it is valid rather than testing for null, so the reason is never lost.
static func load_location(location_id: String) -> RefCounted:
	var script: GDScript = load("res://scripts/location.gd")
	return script.new(LOCATION_FOLDER.path_join(location_id + ".json"))


static func location_path(location_id: String) -> String:
	return LOCATION_FOLDER.path_join(location_id + ".json")


static func location_ids() -> Array:
	var found: Array = []
	var directory := DirAccess.open(LOCATION_FOLDER)
	if directory == null:
		return found
	for filename in directory.get_files():
		if filename.get_extension().to_lower() == "json":
			found.append(filename.get_basename())
	found.sort()
	return found


func _init(from_path: String) -> void:
	path = from_path
	var raw: Variant = _read_json(from_path)
	if raw == null:
		valid = false
		return
	var document: Dictionary = raw
	var parsed := _validate(document)
	if not errors.is_empty():
		valid = false
		return
	# Nothing above this line has touched the typed fields, so a rejected
	# location leaves an object that cannot be mistaken for a loaded one.
	id = parsed.id
	display_name = parsed.display_name
	kind = parsed.kind
	blurb = parsed.blurb
	ground_texture = parsed.ground_texture
	ground_modulate = parsed.ground_modulate
	bounds = parsed.bounds
	arrival = parsed.arrival
	scenery = parsed.scenery
	cast = parsed.cast
	markers = parsed.markers
	goal_area = parsed.goal_area
	blockers = parsed.blockers
	encounters = parsed.encounters
	neighbours = parsed.neighbours
	travel_hours = parsed.travel_hours
	art_gap = parsed.art_gap
	valid = true


func fault_report() -> String:
	if errors.is_empty():
		return "%s: valid" % path
	return "%s rejected:\n  - %s" % [path, "\n  - ".join(PackedStringArray(errors))]


func _fail(message: String) -> void:
	errors.append(message)


func _read_json(from_path: String) -> Variant:
	if not FileAccess.file_exists(from_path):
		_fail("no location file at " + from_path)
		return null
	var text := FileAccess.get_file_as_string(from_path)
	if text.is_empty():
		_fail("location file is empty: " + from_path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		_fail("location file is not a JSON object: " + from_path)
		return null
	return parsed


func _number(value: Variant) -> float:
	if value is int or value is float:
		var number := float(value)
		if is_finite(number):
			return number
	return NAN


func _validate(document: Dictionary) -> Dictionary:
	var result := {
		"id": "", "display_name": "", "kind": "", "blurb": "",
		"ground_texture": "", "ground_modulate": Color(1, 1, 1, 1),
		"bounds": Rect2(), "arrival": Vector2.ZERO,
		"scenery": [], "cast": [], "markers": [], "goal_area": Rect2(),
		"blockers": [], "encounters": [], "neighbours": [],
		"travel_hours": 0.0, "art_gap": "",
	}
	result.id = str(document.get("id", ""))
	var stem := path.get_file().get_basename()
	if result.id.is_empty():
		_fail("id is missing")
	elif result.id != stem:
		_fail("id '%s' does not match the filename '%s'" % [result.id, stem])
	result.display_name = str(document.get("name", ""))
	if result.display_name.is_empty():
		_fail("name is missing; the travel screen has nothing to show")
	result.kind = str(document.get("kind", ""))
	if not result.kind in KINDS:
		_fail("kind '%s' is not one of %s" % [result.kind, str(KINDS)])
	result.blurb = str(document.get("blurb", ""))
	result.art_gap = str(document.get("art_gap", ""))
	_validate_ground(document, result)
	result.bounds = _validate_bounds(document)
	_validate_arrival(document, result)
	_validate_scenery(document, result)
	_validate_cast(document, result)
	_validate_markers(document, result)
	_validate_areas(document, result)
	_validate_encounters(document, result)
	_validate_travel(document, result)
	return result


func _validate_ground(document: Dictionary, result: Dictionary) -> void:
	var ground: Variant = document.get("ground", null)
	if not ground is Dictionary:
		_fail("ground is missing")
		return
	var texture := str(ground.get("texture", ""))
	if texture.is_empty():
		_fail("ground.texture is missing")
	elif not ResourceLoader.exists(texture):
		_fail("ground.texture does not exist: " + texture)
	result.ground_texture = texture
	var modulate: Variant = ground.get("modulate", [1.0, 1.0, 1.0, 1.0])
	if not modulate is Array or modulate.size() != 4:
		_fail("ground.modulate must be four numbers")
		return
	var channels := PackedFloat32Array()
	for channel in modulate:
		var number := _number(channel)
		# Above 1.0 is legal and used: the salt flats are blown out brighter
		# than the texture. Only a negative or non-finite channel is a fault.
		if is_nan(number) or number < 0.0:
			_fail("ground.modulate values must be finite and zero or more")
			return
		channels.append(number)
	result.ground_modulate = Color(channels[0], channels[1], channels[2], channels[3])


func _validate_bounds(document: Dictionary) -> Rect2:
	var raw: Variant = document.get("bounds", null)
	if not raw is Dictionary:
		_fail("bounds is missing; without it nobody knows where the player may walk")
		return Rect2()
	var span_x: Variant = raw.get("x", null)
	var span_y: Variant = raw.get("y", null)
	if not span_x is Array or span_x.size() != 2 or not span_y is Array or span_y.size() != 2:
		_fail("bounds.x and bounds.y must each be a pair of numbers")
		return Rect2()
	var low := Vector2(_number(span_x[0]), _number(span_y[0]))
	var high := Vector2(_number(span_x[1]), _number(span_y[1]))
	if is_nan(low.x) or is_nan(low.y) or is_nan(high.x) or is_nan(high.y):
		_fail("bounds values must be finite numbers")
		return Rect2()
	if high.x - low.x < 2.0 * REACH_MARGIN or high.y - low.y < 2.0 * REACH_MARGIN:
		_fail("bounds are degenerate: %s to %s" % [str(low), str(high)])
		return Rect2()
	return Rect2(low, high - low)


func _inside(point: Vector2, box: Rect2, margin: float) -> bool:
	if box.size == Vector2.ZERO:
		return false
	return box.grow(-margin).has_point(point)


func _validate_arrival(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("arrivals", null)
	if not raw is Dictionary:
		_fail("arrivals is missing; the player would have nowhere to stand")
		return
	var at := Vector2(_number(raw.get("x", NAN)), _number(raw.get("y", NAN)))
	if is_nan(at.x) or is_nan(at.y):
		_fail("arrivals.x and arrivals.y must be finite numbers")
		return
	if not _inside(at, result.bounds, REACH_MARGIN):
		_fail("arrivals %s is outside bounds %s; the player would arrive off the walkable ground" % [str(at), str(result.bounds)])
	result.arrival = at


## Scenery is either authored placements, which are the same shape the art
## manifest uses, or a seeded scatter drawn from the families the art manifest
## actually contains. Both end as the same array of placements, so room.gd has
## exactly one way to build props.
func _validate_scenery(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("scenery", null)
	if raw == null:
		return
	if not raw is Dictionary:
		_fail("scenery must be an object with a recipe")
		return
	var recipe := str(raw.get("recipe", ""))
	if not recipe in RECIPES:
		_fail("scenery.recipe '%s' is not one of %s" % [recipe, str(RECIPES)])
		return
	if recipe == "authored":
		var props: Variant = raw.get("props", [])
		if not props is Array:
			_fail("scenery.props must be an array")
			return
		var placements: Array = []
		for index in range(props.size()):
			var prop: Variant = props[index]
			if not prop is Dictionary:
				_fail("scenery.props[%d] is not an object" % index)
				continue
			var fault := _prop_fault(prop)
			if not fault.is_empty():
				_fail("scenery.props[%d] %s" % [index, fault])
				continue
			placements.append(prop)
		result.scenery = placements
		return
	result.scenery = _scatter(raw.get("scatter", null), result.bounds)


func _prop_fault(prop: Dictionary) -> String:
	for field in ["texture", "region", "anchor", "position", "family"]:
		if not prop.has(field):
			return "is missing " + field
	if not ResourceLoader.exists(str(prop.texture)):
		return "texture does not exist: " + str(prop.texture)
	for field in ["region", "anchor", "position"]:
		var value: Variant = prop[field]
		var wanted := 4 if field == "region" else 2
		if not value is Array or value.size() != wanted:
			return "%s must be %d numbers" % [field, wanted]
		for number in value:
			if is_nan(_number(number)):
				return field + " must be finite numbers"
	if is_nan(_number(prop.get("collision_radius", 0))):
		return "collision_radius must be a finite number"
	return ""


## A seeded scatter. The frames come from the art manifest's own placements,
## grouped by family, so a scattered location can only ever use art that
## already exists in this project. There is no second art catalogue.
func _scatter(raw: Variant, box: Rect2) -> Array:
	if not raw is Dictionary:
		_fail("scenery.scatter is missing for a scattered recipe")
		return []
	var seed_value := _number(raw.get("seed", NAN))
	if is_nan(seed_value):
		_fail("scenery.scatter.seed must be a finite number")
		return []
	var families: Variant = raw.get("families", null)
	if not families is Dictionary:
		_fail("scenery.scatter.families must be an object of family counts")
		return []
	var catalogue := _family_catalogue()
	var placements: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value)
	for family in families:
		var family_name := str(family)
		var count := _number(families[family])
		if is_nan(count) or count < 0:
			_fail("scenery.scatter.families.%s must be a count of zero or more" % family_name)
			continue
		if int(count) == 0:
			continue
		if not catalogue.has(family_name):
			_fail("scenery.scatter.families.%s: this project has no %s art to scatter" % [family_name, family_name])
			continue
		var frames: Array = catalogue[family_name]
		for i in range(int(count)):
			var frame: Dictionary = (frames[rng.randi_range(0, frames.size() - 1)] as Dictionary).duplicate(true)
			var inner := box.grow(-REACH_MARGIN)
			frame.position = [
				rng.randf_range(inner.position.x, inner.end.x),
				rng.randf_range(inner.position.y, inner.end.y),
			]
			placements.append(frame)
	return placements


func _family_catalogue() -> Dictionary:
	var catalogue := {}
	if not FileAccess.file_exists(ART_MANIFEST):
		_fail("art manifest is missing: " + ART_MANIFEST)
		return catalogue
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	if not manifest is Dictionary:
		_fail("art manifest is not a JSON object: " + ART_MANIFEST)
		return catalogue
	for entry in manifest.get("scenery", []):
		if not entry is Dictionary or not entry.has("family"):
			continue
		var family := str(entry.family)
		if not catalogue.has(family):
			catalogue[family] = []
		catalogue[family].append(entry)
	return catalogue


## Every id must resolve. A person resolves against the written county;
## a wagon or a longhorn resolves against the art manifest, because the
## project has no person record for a wagon and inventing one would be a lie.
func _validate_cast(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("cast", null)
	if not raw is Array:
		_fail("cast is missing")
		return
	var known := _known_ids()
	var players := 0
	var members: Array = []
	for index in range(raw.size()):
		var entry: Variant = raw[index]
		if not entry is Dictionary:
			_fail("cast[%d] is not an object" % index)
			continue
		var member_id := str(entry.get("id", ""))
		var role := str(entry.get("role", ""))
		if member_id.is_empty():
			_fail("cast[%d] has no id" % index)
			continue
		if not known.has(member_id):
			_fail("cast[%d] id '%s' resolves in none of design/characters.json, design/npcs.json or assets/room-art.json" % [index, member_id])
			continue
		if role.is_empty():
			_fail("cast[%d] '%s' has no role" % [index, member_id])
			continue
		var at := result.arrival as Vector2
		if role == "player":
			players += 1
			if players > 1:
				_fail("cast[%d] '%s' is a second player entry; a location has at most one" % [index, member_id])
				continue
			if entry.has("x") or entry.has("y"):
				_fail("cast[%d] '%s' is the player: it stands at arrivals, so it must not carry its own x/y" % [index, member_id])
				continue
		else:
			at = Vector2(_number(entry.get("x", NAN)), _number(entry.get("y", NAN)))
			if is_nan(at.x) or is_nan(at.y):
				_fail("cast[%d] '%s' has no finite x/y" % [index, member_id])
				continue
			if not _inside(at, result.bounds, REACH_MARGIN):
				_fail("cast[%d] '%s' stands at %s, outside bounds %s: nobody could ever reach it" % [index, member_id, str(at), str(result.bounds)])
				continue
		members.append({"id": member_id, "role": role, "position": at,
			"sprite": str(entry.get("sprite", member_id))})
	result.cast = members


func _known_ids() -> Dictionary:
	var known := {}
	var characters: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_RECORDS))
	if characters is Dictionary:
		for record in characters.get("named_characters", []):
			if record is Dictionary and record.has("id"):
				known[str(record.id)] = "characters.json"
	else:
		_fail("could not read " + CHARACTER_RECORDS)
	var npcs: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPC_RECORDS))
	if npcs is Dictionary:
		for record in npcs.get("characters", []):
			if record is Dictionary and record.has("id"):
				known[str(record.id)] = "npcs.json"
	else:
		_fail("could not read " + NPC_RECORDS)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	if manifest is Dictionary:
		for sprite_id in manifest.get("sprites", {}):
			known[str(sprite_id)] = "room-art.json"
	else:
		_fail("could not read " + ART_MANIFEST)
	return known


func _validate_markers(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("markers", [])
	if not raw is Array:
		_fail("markers must be an array")
		return
	var placed: Array = []
	for index in range(raw.size()):
		var marker: Variant = raw[index]
		if not marker is Dictionary or not marker.has("text"):
			_fail("markers[%d] needs text" % index)
			continue
		var at := Vector2(_number(marker.get("x", NAN)), _number(marker.get("y", NAN)))
		if is_nan(at.x) or is_nan(at.y):
			_fail("markers[%d] has no finite x/y" % index)
			continue
		placed.append({"text": str(marker.text), "position": at})
	result.markers = placed


func _rect(raw: Variant) -> Rect2:
	if not raw is Array or raw.size() != 4:
		return Rect2()
	var numbers := PackedFloat32Array()
	for value in raw:
		var number := _number(value)
		if is_nan(number):
			return Rect2()
		numbers.append(number)
	return Rect2(numbers[0], numbers[1], numbers[2], numbers[3])


func _validate_areas(document: Dictionary, result: Dictionary) -> void:
	if document.has("goal_area"):
		var goal := _rect(document.goal_area)
		if goal.size == Vector2.ZERO:
			_fail("goal_area must be four finite numbers: x, y, width, height")
		result.goal_area = goal
	var raw: Variant = document.get("blockers", [])
	if not raw is Array:
		_fail("blockers must be an array")
		return
	var boxes: Array = []
	for index in range(raw.size()):
		var blocker: Variant = raw[index]
		if not blocker is Dictionary:
			_fail("blockers[%d] is not an object" % index)
			continue
		var box := _rect(blocker.get("rect", null))
		if box.size == Vector2.ZERO:
			_fail("blockers[%d].rect must be four finite numbers" % index)
			continue
		boxes.append({"id": str(blocker.get("id", "")), "rect": box})
	result.blockers = boxes
	# A blocker named after somebody in the cast is that thing's footprint, so
	# the two cannot drift: move the wagon and forget its footprint and the
	# location is rejected here instead of leaving a hole in the air.
	for blocker in boxes:
		if str(blocker.id).is_empty(): continue
		for member in result.cast:
			if str(member.id) != str(blocker.id): continue
			if not (blocker.rect as Rect2).has_point(member.position as Vector2):
				_fail("blocker '%s' is at %s but '%s' stands at %s: the footprint has been left behind"
					% [str(blocker.id), str(blocker.rect), str(member.id), str(member.position)])


func _validate_encounters(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("encounters", [])
	if not raw is Array:
		_fail("encounters must be an array of ids")
		return
	if raw.is_empty():
		result.encounters = []
		return
	if not FileAccess.file_exists(ENCOUNTER_RECORDS):
		_fail("this location lists encounters but there is no %s to resolve them against" % ENCOUNTER_RECORDS)
		return
	var known := _encounter_ids()
	var listed: Array = []
	for encounter_id in raw:
		if not known.has(str(encounter_id)):
			_fail("encounter '%s' is not in %s" % [str(encounter_id), ENCOUNTER_RECORDS])
			continue
		listed.append(str(encounter_id))
	result.encounters = listed


## The encounter table has not been written yet. Accept either shape it is
## likely to take rather than guessing one: a list of records with ids, or an
## object keyed by id.
func _encounter_ids() -> Dictionary:
	var known := {}
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENCOUNTER_RECORDS))
	var listed: Variant = records
	if records is Dictionary and records.has("encounters"):
		listed = records.encounters
	if listed is Array:
		for record in listed:
			if record is Dictionary and record.has("id"):
				known[str(record.id)] = true
			elif record is String:
				known[record] = true
	elif listed is Dictionary:
		for encounter_id in listed:
			known[str(encounter_id)] = true
	else:
		_fail("encounter table is not readable: " + ENCOUNTER_RECORDS)
	return known


func _validate_travel(document: Dictionary, result: Dictionary) -> void:
	var raw: Variant = document.get("travel", null)
	if not raw is Dictionary:
		_fail("travel is missing; a location with no travel block cannot be reached or left")
		return
	var listed: Variant = raw.get("neighbours", [])
	if not listed is Array:
		_fail("travel.neighbours must be an array of location ids")
		return
	var reachable: Array = []
	for neighbour in listed:
		var neighbour_id := str(neighbour)
		if not FileAccess.file_exists(location_path(neighbour_id)):
			_fail("neighbour '%s' has no file at %s" % [neighbour_id, location_path(neighbour_id)])
			continue
		reachable.append(neighbour_id)
	result.neighbours = reachable
	var hours := _number(raw.get("hours", 0))
	if is_nan(hours) or hours < 0.0:
		_fail("travel.hours must be a finite number of hours, zero or more")
		return
	result.travel_hours = hours


## Cross-file properties one location cannot see on its own. Travel has to be
## symmetric or a player can ride somewhere and not ride back.
static func audit_all() -> Dictionary:
	var report := {"checked": 0, "faults": []}
	var by_id := {}
	for location_id in location_ids():
		var location: RefCounted = load_location(location_id)
		report.checked += 1
		if not location.valid:
			report.faults.append(location.fault_report())
			continue
		by_id[location_id] = location
	for location_id in by_id:
		var location: RefCounted = by_id[location_id]
		for neighbour in location.neighbours:
			if not by_id.has(neighbour):
				continue
			var other: RefCounted = by_id[neighbour]
			if not location_id in other.neighbours:
				report.faults.append("travel is one-way: %s lists %s, but %s does not list %s"
					% [location_id, neighbour, neighbour, location_id])
	return report
