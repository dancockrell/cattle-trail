extends Control
## The county, as a screen you can ride out of.
##
## Built the way scripts/kit_browser.gd builds its screen: one Control scene,
## every node made in _ready, the project's own palette, no new art. There is
## no map art and nobody can make any right now, so the map is the graph drawn
## honestly: a marker per location, a line per trail between them, and the cost
## in hours written on every line. Placement is a relaxation pass that pulls a
## long leg further apart than a short one, so distance on the screen follows
## hours as a tendency. The number printed on the line is the fact.
##
## All logic lives in scripts/travel.gd. This file positions things and prints
## what that file says. It owns no rules about hours, night or reachability.
##
## The trail clock is not restarted here. It is read from and written back to
## the scene tree's "trail_minutes" metadata, so a room that sets that meta
## before changing scene hands its clock over and gets it back advanced by
## however long the ride took. With nothing set it opens at Day 1 12:00, the
## same noon scripts/companion_room.gd starts its own clock at.

const Travel = preload("res://scripts/travel.gd")
const Clock = preload("res://scripts/trail_clock.gd")

const CLOCK_META := "trail_minutes"
const LOCATION_META := "trail_location"
const DEFAULT_MINUTES := 720.0
const HOME_ID := "clear_fork"

const MAP_SIZE := Vector2(820.0, 820.0)
const MARKER_SIZE := Vector2(190.0, 32.0)
## Relaxation. Deterministic: it starts from a sorted radial seed and uses no
## randomness, so the county sits in the same shape every time it is opened.
const RELAX_STEPS := 320
const SEPARATION_STEPS := 200
const MARKER_GAP := Vector2(20.0, 18.0)
const SEED_RADIUS := 220.0

const INK_BRIGHT := Color("f4d69c")
const INK_WARM := Color("c4a368")
const INK_DIM := Color("8a7757")
const INK_NIGHT := Color("ffb27a")
const TRAIL_LINE := Color("54401f")
const TRAIL_LIVE := Color("94451d")
const PANEL_FILL := Color("241b11")
const PANEL_EDGE := Color("55401f")
const BACKGROUND := Color("14100a")

var locations: Dictionary = {}
var problems: Array[String] = []
var preview_only := false

var here_id := HOME_ID
var minutes := DEFAULT_MINUTES
var selected_id := ""

var map_area: Control
var markers: Dictionary = {}
var edge_lines: Array[Line2D] = []
var decorations: Array[Control] = []
var laid_out_for := Vector2.ZERO
var header: Label
var clock_label: Label
var detail_name: Label
var detail_kind: Label
var detail_blurb: Label
var detail_cost: Label
var detail_warning: Label
var ride_button: Button
var log_label: Label
var problem_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_load_county()
	_restore_clock()
	_build_screen()
	map_area.resized.connect(_on_map_resized)
	_lay_out_map()
	_select(_first_destination())

	if "--map-qa" in OS.get_cmdline_user_args():
		_map_qa.call_deferred()


func _load_county() -> void:
	var loaded := Travel.load_county()
	locations = loaded.locations
	problems = loaded.problems
	if locations.is_empty():
		# No location files authored yet. Show the stand-in graph rather than an
		# empty screen, and say plainly on the screen that it is a stand-in.
		locations = Travel.PREVIEW_COUNTY.duplicate(true)
		preview_only = true


func _restore_clock() -> void:
	var tree := get_tree()
	if tree.has_meta(CLOCK_META):
		minutes = float(tree.get_meta(CLOCK_META))
	if tree.has_meta(LOCATION_META):
		here_id = str(tree.get_meta(LOCATION_META))
	if locations.is_empty():
		here_id = ""
	elif not locations.has(here_id):
		# Home has no file yet. Stand at the best-connected place instead of an
		# alphabetical accident, so the player is somewhere with trails out.
		here_id = HOME_ID if locations.has(HOME_ID) else _hub()


func _store_clock() -> void:
	var tree := get_tree()
	tree.set_meta(CLOCK_META, minutes)
	tree.set_meta(LOCATION_META, here_id)


# --- the screen -----------------------------------------------------------

func _build_screen() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	stack.add_child(title_row)

	header = Label.new()
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", INK_BRIGHT)
	title_row.add_child(header)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(spacer)

	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.add_theme_color_override("font_color", INK_WARM)
	title_row.add_child(clock_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)

	map_area = Control.new()
	map_area.custom_minimum_size = Vector2(520.0, 480.0)
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.clip_contents = true
	body.add_child(map_area)

	body.add_child(_detail_panel())


func _detail_panel() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(360.0, 0.0)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_END
	frame.add_theme_stylebox_override("panel", _panel_style(PANEL_FILL, PANEL_EDGE))

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	frame.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	pad.add_child(column)

	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 22)
	detail_name.add_theme_color_override("font_color", INK_BRIGHT)
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_name)

	detail_kind = Label.new()
	detail_kind.add_theme_color_override("font_color", INK_DIM)
	column.add_child(detail_kind)

	detail_blurb = Label.new()
	detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_blurb.add_theme_color_override("font_color", INK_WARM)
	column.add_child(detail_blurb)

	detail_cost = Label.new()
	detail_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_cost.add_theme_color_override("font_color", INK_BRIGHT)
	column.add_child(detail_cost)

	detail_warning = Label.new()
	detail_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_warning.add_theme_color_override("font_color", INK_NIGHT)
	column.add_child(detail_warning)

	ride_button = Button.new()
	ride_button.text = "Ride out"
	ride_button.custom_minimum_size.y = 46
	ride_button.pressed.connect(_ride_selected)
	column.add_child(ride_button)

	var back := Button.new()
	back.text = "Back to camp"
	back.custom_minimum_size.y = 36
	back.pressed.connect(_leave)
	column.add_child(back)

	column.add_child(_heading("ON THE ROAD"))
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_color_override("font_color", INK_WARM)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.text = "Nothing ridden yet."
	column.add_child(log_label)

	column.add_child(_heading("GRAPH"))
	problem_label = Label.new()
	problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	problem_label.add_theme_font_size_override("font_size", 12)
	problem_label.add_theme_color_override("font_color", TRAIL_LIVE)
	column.add_child(problem_label)

	return frame


func _heading(text: String) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var rule := ColorRect.new()
	rule.color = PANEL_EDGE
	rule.custom_minimum_size.y = 1
	row.add_child(rule)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", INK_DIM)
	row.add_child(label)
	return row


func _panel_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	return style


# --- layout ---------------------------------------------------------------

func _on_map_resized() -> void:
	if map_area.size.distance_to(laid_out_for) < 8.0:
		return
	_lay_out_map()
	_refresh()


func _lay_out_map() -> void:
	for line in edge_lines:
		line.queue_free()
	edge_lines.clear()
	for decoration in decorations:
		decoration.queue_free()
	decorations.clear()
	for marker in markers.values():
		marker.queue_free()
	markers.clear()
	if locations.is_empty():
		return

	laid_out_for = map_area.size
	var placement := _layout_positions()

	var drawn := {}
	for id in placement:
		for other in Travel.neighbours(locations, str(id)):
			if not placement.has(other):
				continue
			var key: String = str(id) + "|" + other if str(id) < other else other + "|" + str(id)
			if drawn.has(key):
				continue
			drawn[key] = true
			# A trail is only drawn as rideable when both ends list each other,
			# which is the same thing plan_leg() asks. A line the player can see
			# but cannot ride is the worst thing this screen could draw, so a
			# one-way claim is drawn thin and labelled as the fault it is.
			var mutual: bool = str(id) in Travel.neighbours(locations, other)
			var live: bool = mutual and (id == here_id or other == here_id)
			var from_point: Vector2 = placement[id]
			var to_point: Vector2 = placement[other]
			var line := Line2D.new()
			line.width = 3.0 if live else (2.0 if mutual else 1.0)
			line.default_color = TRAIL_LIVE if live else (TRAIL_LINE if mutual else Color("3a2c18"))
			line.points = PackedVector2Array([from_point, to_point])
			map_area.add_child(line)
			edge_lines.append(line)
			var tag := Label.new()
			tag.text = "%dh" % Travel.leg_hours(locations, str(id), str(other)) if mutual else "one way"
			tag.add_theme_font_size_override("font_size", 13 if mutual else 11)
			tag.add_theme_color_override("font_color", INK_WARM if live else (INK_DIM if mutual else Color("6b4230")))
			# Sit the hours beside the line rather than on it, so the trail
			# still reads underneath the number.
			var nudge := (to_point - from_point).orthogonal().normalized() * 12.0
			tag.position = (from_point + to_point) * 0.5 + nudge - Vector2(10.0, 9.0)
			map_area.add_child(tag)
			decorations.append(tag)

	for id in placement:
		var record: Dictionary = locations[id]
		var marker := Button.new()
		marker.text = str(record.get("name", id))
		marker.size = MARKER_SIZE
		marker.position = placement[id] - MARKER_SIZE * 0.5
		marker.clip_text = true
		marker.pressed.connect(_select.bind(str(id)))
		map_area.add_child(marker)
		markers[id] = marker


## Positions in map_area coordinates. Three passes, none of them random: a
## sorted radial seed, a spring relaxation weighted by each leg's hours, and a
## separation pass that pushes overlapping markers apart so every name stays
## readable. Then the whole thing is fitted into the panel.
func _layout_positions() -> Dictionary:
	var frame := map_area.size
	if frame.x < 200.0 or frame.y < 200.0:
		frame = MAP_SIZE
	var placement := _radial_seed(_hub())
	placement = _relax(placement)
	# Fit BEFORE separating. Separating first and scaling afterwards shrinks the
	# gaps back out of existence, which is exactly how the first build of this
	# screen shipped eight overlapping names.
	placement = _fit(placement, frame)
	# Separate, clamp, and separate again: clamping a marker back inside the
	# panel can push it into its neighbour, so the second pass cleans that up.
	placement = _separate(placement)
	placement = _clamp_into(placement, frame)
	placement = _separate(placement)
	return _clamp_into(placement, frame)


func _relax(seed_placement: Dictionary) -> Dictionary:
	var ids := seed_placement.keys()
	ids.sort()
	var pos := seed_placement.duplicate()
	if ids.size() < 2:
		return pos
	# Fruchterman-Reingold, with each spring's rest length scaled by the leg's
	# hours, so a fourteen-hour haul settles further out than a two-hour one.
	var k := 250.0
	var temperature := 170.0
	for step in range(RELAX_STEPS):
		var force := {}
		for id in ids:
			force[id] = Vector2.ZERO
		for first in range(ids.size()):
			for second in range(first + 1, ids.size()):
				var a = ids[first]
				var b = ids[second]
				var delta: Vector2 = pos[a] - pos[b]
				if delta.length() < 0.01:
					# Two markers exactly on top of each other need a push in
					# some direction, and it has to be the same one every run.
					delta = Vector2(float(first + 1), float(second + 1)).normalized()
				var distance := maxf(1.0, delta.length())
				var push: Vector2 = delta.normalized() * (k * k / distance)
				force[a] += push
				force[b] -= push
		for a in ids:
			for b in Travel.neighbours(locations, str(a)):
				if not pos.has(b):
					continue
				var delta: Vector2 = pos[b] - pos[a]
				var distance := maxf(1.0, delta.length())
				var rest := k * clampf(float(Travel.leg_hours(locations, str(a), str(b))) / 6.0, 0.5, 2.2)
				force[a] += delta.normalized() * (distance * distance / rest) * 0.5
		for id in ids:
			# A weak pull to the middle keeps a disconnected piece of the county
			# on screen instead of drifting off the edge.
			force[id] -= pos[id] * 0.02
		for id in ids:
			pos[id] = pos[id] + force[id].limit_length(temperature)
		temperature = maxf(2.0, temperature * 0.985)
	return pos


func _separate(placement: Dictionary) -> Dictionary:
	var ids := placement.keys()
	ids.sort()
	var pos := placement.duplicate()
	var span := MARKER_SIZE + MARKER_GAP
	for step in range(SEPARATION_STEPS):
		var moved := false
		for first in range(ids.size()):
			for second in range(first + 1, ids.size()):
				var a = ids[first]
				var b = ids[second]
				var delta: Vector2 = pos[b] - pos[a]
				var overlap := Vector2(span.x - absf(delta.x), span.y - absf(delta.y))
				if overlap.x <= 0.0 or overlap.y <= 0.0:
					continue
				moved = true
				# Push along whichever axis needs the least movement.
				if overlap.x / span.x < overlap.y / span.y:
					var shift_x := overlap.x * 0.5 * (1.0 if delta.x >= 0.0 else -1.0)
					pos[a] = pos[a] - Vector2(shift_x, 0.0)
					pos[b] = pos[b] + Vector2(shift_x, 0.0)
				else:
					var shift_y := overlap.y * 0.5 * (1.0 if delta.y >= 0.0 else -1.0)
					pos[a] = pos[a] - Vector2(0.0, shift_y)
					pos[b] = pos[b] + Vector2(0.0, shift_y)
		if not moved:
			break
	return pos


func _fit(placement: Dictionary, frame: Vector2) -> Dictionary:
	if placement.is_empty():
		return placement
	var low := Vector2.INF
	var high := -Vector2.INF
	for id in placement:
		var point: Vector2 = placement[id]
		low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	var extent := high - low
	var usable := frame - MARKER_SIZE - MARKER_GAP
	var scale := 1.0
	if extent.x > 0.5 and extent.y > 0.5:
		scale = minf(usable.x / extent.x, usable.y / extent.y)
	# Only ever shrink. Blowing a three-location county up to fill the panel
	# would claim a scale the graph does not have.
	scale = clampf(scale, 0.05, 1.0)
	var drawn_extent := extent * scale
	var origin := (frame - drawn_extent) * 0.5
	var fitted := {}
	for id in placement:
		var point: Vector2 = placement[id]
		fitted[id] = origin + (point - low) * scale
	return fitted


## Keeps every marker whole inside the panel. The map area clips, so a marker
## nudged past the edge by the separation pass would lose half its name.
func _clamp_into(placement: Dictionary, frame: Vector2) -> Dictionary:
	var half := MARKER_SIZE * 0.5
	var clamped := {}
	for id in placement:
		var point: Vector2 = placement[id]
		clamped[id] = Vector2(
			clampf(point.x, half.x + 2.0, maxf(half.x + 2.0, frame.x - half.x - 2.0)),
			clampf(point.y, half.y + 2.0, maxf(half.y + 2.0, frame.y - half.y - 2.0)))
	return clamped


## A deterministic starting shape for the relaxation: the hub in the middle,
## each further ring out by SEED_RADIUS, sorted so the same county always seeds
## the same way. Anything the hub cannot reach still gets a ring of its own, so
## a broken graph is visible on screen instead of silently missing from it.
func _radial_seed(hub: String) -> Dictionary:
	var placement := {}
	if locations.is_empty():
		return placement
	var centre := hub
	if centre.is_empty():
		centre = str(locations.keys()[0])
	placement[centre] = Vector2.ZERO
	var layers: Array[Array] = []
	var seen := {centre: true}
	var frontier: Array[String] = [centre]
	while not frontier.is_empty():
		var next: Array[String] = []
		for id in frontier:
			for other in Travel.neighbours(locations, id):
				if seen.has(other):
					continue
				seen[other] = true
				next.append(other)
		if not next.is_empty():
			next.sort()
			layers.append(next)
		frontier = next

	var orphans: Array[String] = []
	for id in locations:
		if not seen.has(id):
			orphans.append(str(id))
	if not orphans.is_empty():
		orphans.sort()
		layers.append(orphans)

	for layer_index in range(layers.size()):
		var layer: Array = layers[layer_index]
		var radius := SEED_RADIUS * float(layer_index + 1)
		for index in range(layer.size()):
			var angle := TAU * float(index) / float(layer.size()) - PI * 0.5
			placement[layer[index]] = Vector2(cos(angle), sin(angle)) * radius
	return placement


## The hub is whichever location has the most trails running out of it, which
## on the authored county is home. Ties go to the home id, then alphabetically,
## so the map does not rearrange itself between runs.
func _hub() -> String:
	var best := ""
	var best_count := -1
	var ids := locations.keys()
	ids.sort()
	for id in ids:
		var count := Travel.neighbours(locations, str(id)).size()
		if count > best_count or (count == best_count and str(id) == HOME_ID):
			best = str(id)
			best_count = count
	return best


# --- state ----------------------------------------------------------------

func _first_destination() -> String:
	var rows := Travel.destinations(locations, here_id, minutes)
	return str(rows[0].id) if not rows.is_empty() else here_id


func _select(id: String) -> void:
	selected_id = id
	_refresh()


func _refresh() -> void:
	clock_label.text = Clock.label(minutes)
	if Travel.is_night(minutes):
		clock_label.add_theme_color_override("font_color", INK_NIGHT)
		clock_label.text += "  (dark)"
	else:
		clock_label.add_theme_color_override("font_color", INK_WARM)

	var record: Dictionary = locations.get(here_id, {})
	header.text = "THE COUNTY / YOU ARE AT %s" % str(record.get("name", here_id)).to_upper()
	if preview_only:
		header.text += "   [PREVIEW GRAPH]"

	var reachable := Travel.neighbours(locations, here_id)
	for id in locations:
		var marker: Button = markers.get(id)
		if marker == null:
			continue
		var fill := PANEL_FILL
		var edge := PANEL_EDGE
		var ink := INK_DIM
		if id == here_id:
			fill = Color("3b2a16")
			edge = INK_BRIGHT
			ink = INK_BRIGHT
		elif id in reachable:
			fill = Color("2b2015")
			edge = TRAIL_LIVE
			ink = INK_WARM
		if id == selected_id:
			edge = INK_BRIGHT
			ink = INK_BRIGHT
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			marker.add_theme_stylebox_override(state, _panel_style(fill, edge))
		marker.add_theme_color_override("font_color", ink)
		marker.add_theme_color_override("font_hover_color", INK_BRIGHT)
		marker.add_theme_color_override("font_pressed_color", INK_BRIGHT)

	_refresh_detail()
	_refresh_problems()


func _refresh_detail() -> void:
	var record: Dictionary = locations.get(selected_id, {})
	detail_name.text = str(record.get("name", selected_id))
	var kind := str(record.get("kind", ""))
	var legs := Travel.neighbours(locations, selected_id).size()
	detail_kind.text = "%s / %d trail%s out" % [kind.to_upper() if not kind.is_empty() else "PLACE", legs, "" if legs == 1 else "s"]
	detail_blurb.text = str(record.get("blurb", "No blurb written for this place yet."))

	if selected_id == here_id:
		detail_cost.text = "You are standing here."
		detail_warning.text = ""
		ride_button.disabled = true
		ride_button.text = "Ride out"
		return

	var plan := Travel.plan_leg(locations, here_id, selected_id, minutes)
	if not bool(plan.get("ok", false)):
		detail_cost.text = str(plan.get("message", "That ride is refused."))
		detail_warning.text = ""
		ride_button.disabled = true
		ride_button.text = "No trail from here"
		return

	detail_cost.text = "%d hours. Out at %s, down at %s." % [int(plan.hours), str(plan.depart_label), str(plan.arrive_label)]
	if bool(plan.arrives_at_night):
		detail_warning.text = "You get there after dark."
	elif bool(plan.is_night_leg):
		detail_warning.text = "Part of that ride is after dark."
	else:
		detail_warning.text = ""
	ride_button.disabled = false
	ride_button.text = "Ride out: %d hours" % int(plan.hours)


func _refresh_problems() -> void:
	var lines: Array[String] = []
	if preview_only:
		lines.append("Stand-in graph from travel.gd PREVIEW_COUNTY. Author data/locations/*.json and this goes away.")
	lines.append("%d locations, %d trails." % [locations.size(), edge_lines.size()])
	for problem in problems:
		lines.append(problem)
	problem_label.text = "\n".join(lines)


func _ride_selected() -> void:
	if selected_id.is_empty() or selected_id == here_id:
		return
	var result := Travel.ride({
		"locations": locations,
		"from": here_id,
		"to": selected_id,
		"now_minutes": minutes,
		# No encounter resolver is wired yet. When one exists it goes here and
		# nothing else on this screen changes. See travel.gd's ENCOUNTER SEAM.
		"encounter_resolver": null,
	})
	var told: Array = result.get("log", [])
	log_label.text = "\n".join(told)
	if not bool(result.get("ok", false)):
		return
	minutes = float(result.now_minutes)
	here_id = selected_id
	_store_clock()
	_lay_out_map()
	_select(_first_destination())


func _leave() -> void:
	_store_clock()
	get_tree().change_scene_to_file("res://scenes/room.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_leave()


# --- review ---------------------------------------------------------------

## Windowed review pass: draw, save a frame, print what is on the screen, quit.
## Run with: Godot --path . res://scenes/world_map.tscn -- --map-qa
func _map_qa() -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var overlaps := _count_overlaps()
	var output := "res://reports/world-map-review.png"
	var saved := get_viewport().get_texture().get_image().save_png(output)
	if saved != OK:
		push_error("World map capture failed: " + output)
		get_tree().quit(1)
		return
	print("WORLD MAP QA: %d locations, %d markers placed, %d trails drawn, %d marker overlaps, standing at %s, clock %s, preview_graph=%s" % [locations.size(), markers.size(), edge_lines.size(), overlaps, here_id, Clock.label(minutes), str(preview_only)])
	get_tree().quit(0)


## Counts markers whose rectangles intersect. A name sitting on another name is
## the defect this screen is most likely to ship, and it is invisible in source.
func _count_overlaps() -> int:
	var rects: Array[Rect2] = []
	for marker in markers.values():
		rects.append(Rect2(marker.position, marker.size))
	var count := 0
	for first in range(rects.size()):
		for second in range(first + 1, rects.size()):
			if rects[first].intersects(rects[second]):
				count += 1
	return count
