extends Control

const Actor = preload("res://scripts/actor.gd")
const WORLD := Vector2(640, 360)
const CORRAL := Rect2(475, 110, 125, 155)
const WAGON_FOOTPRINT := Rect2(39,73,100,42)
var manifest: Dictionary
var world: Node2D
var actors: Node2D
var viewport: SubViewport
var view: TextureRect
var player: Node2D
var eleanor: Node2D
var rustler: Node2D
var cows: Array[Node2D] = []
var stats: Label
var journal: Label
var title: Label
var buttons: GridContainer
var objective: Label
var paper: Panel
var message := "Eleanor is waiting by the wagon. Ride over and talk."
var talked := false
var rustler_active := true
var won := false
var ammo := 6
var hits := 0
var cash := 342
var target := Vector2.INF
var facing := Vector2.RIGHT
var rope_target: Node2D
var rope_time := 0.0
var rope: Line2D
var shot: Line2D
var shot_time := 0.0
var shot_cooldown := 0.0
var elapsed := 0.0
var escaped := false
var qa_mode := false
var qa_done := false
var pending_lasso: Node2D
var pending_shot := false
var pending_aim := Vector2.RIGHT
var scenery: Node2D
var solid_scenery: Array = []

func _ready() -> void:
	if "--kits" in OS.get_cmdline_user_args() and not get_tree().has_meta("kits_opened"):
		get_tree().set_meta("kits_opened", true)
		get_tree().change_scene_to_file.call_deferred("res://scenes/kit_browser.tscn")
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art_path := "res://assets/sprites.json" if "--original" in OS.get_cmdline_user_args() else "res://assets/room-art.json"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(art_path))
	viewport = SubViewport.new()
	viewport.size = Vector2i(WORLD)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	world = Node2D.new()
	viewport.add_child(world)
	var background := Sprite2D.new()
	background.texture = load(manifest.get("ground", {}).get("texture", "res://assets/room.png"))
	background.centered = false
	world.add_child(background)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	world.add_child(actors)
	place_scenery()
	spawn("wagon", Vector2(91, 111))
	eleanor = spawn("eleanor", Vector2(148, 127))
	player = spawn("rider", Vector2(199, 231))
	player.action_event.connect(on_player_action_event)
	rustler = spawn("rustler", Vector2(550, 164))
	for i in range(6):
		var positions := [Vector2(294,158),Vector2(350,183),Vector2(408,155),Vector2(278,240),Vector2(360,253),Vector2(421,223)]
		var cow := spawn(["longhorn", "cream", "spotted"][i % 3], positions[i])
		cows.append(cow)
	var gathering := Label.new()
	gathering.text = "EAST GATHERING\nBring all six here"
	gathering.position = Vector2(482, 75)
	gathering.add_theme_font_size_override("font_size", 12)
	gathering.add_theme_color_override("font_color", Color("fff0c4"))
	gathering.add_theme_color_override("font_shadow_color", Color("382513"))
	gathering.add_theme_constant_override("shadow_offset_x", 1)
	gathering.add_theme_constant_override("shadow_offset_y", 1)
	world.add_child(gathering)
	rope = Line2D.new()
	rope.width = 1.0
	rope.default_color = Color("edcf87")
	world.add_child(rope)
	shot = Line2D.new()
	shot.width = 1.0
	shot.default_color = Color("ffe9a7")
	world.add_child(shot)
	view = TextureRect.new()
	view.texture = viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(world_input)
	add_child(view)
	build_ui()
	resized.connect(layout_ui)
	layout_ui()
	qa_mode = "--qa" in OS.get_cmdline_user_args() or "--demo" in OS.get_cmdline_user_args()
	for button in buttons.get_children(): button.disabled = qa_mode
	refresh()
	if "--smoke" in OS.get_cmdline_user_args():
		export_smoke.call_deferred()
	if "--demo" in OS.get_cmdline_user_args():
		qa_done = true
		run_demo.call_deferred()

func spawn(id: String, at: Vector2) -> Node2D:
	var actor := Actor.new()
	actor.configure(id, manifest.sprites[id])
	actor.position = at
	actors.add_child(actor)
	return actor

func place_scenery() -> void:
	for entry in manifest.get("scenery", []):
		var prop := Sprite2D.new()
		var region := AtlasTexture.new()
		region.atlas = load(entry.texture)
		region.region = Rect2(entry.region[0], entry.region[1], entry.region[2], entry.region[3])
		prop.texture = region
		prop.centered = false
		prop.offset = -Vector2(entry.anchor[0], entry.anchor[1])
		prop.position = Vector2(entry.position[0], entry.position[1])
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Ground-cover stays under hooves; tall props share the actors' ground Y sort.
		if entry.family == "grass":
			world.add_child(prop)
			world.move_child(prop, actors.get_index())
		else:
			actors.add_child(prop)
		if float(entry.collision_radius) > 0:
			solid_scenery.append(entry)

func panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/panel.png")
	for side in range(4):
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, 12)
	return style

func build_ui() -> void:
	title = Label.new()
	title.text = "CATTLE TRAIL  /  CLEAR FORK"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f7d79b"))
	add_child(title)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 17)
	stats.add_theme_color_override("font_color", Color("e9d8b7"))
	add_child(stats)
	paper = Panel.new()
	paper.add_theme_stylebox_override("panel", panel_style())
	add_child(paper)
	objective = Label.new()
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color("402917"))
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper.add_child(objective)
	journal = Label.new()
	journal.add_theme_font_size_override("font_size", 16)
	journal.add_theme_color_override("font_color", Color("402917"))
	journal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper.add_child(journal)
	buttons = GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	add_child(buttons)
	for entry in [["Talk [E]", interact], ["Lasso [L]", lasso], ["Shoot [F]", shoot], ["Reset [R]", reset_room]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(80, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", panel_style())
		button.add_theme_stylebox_override("hover", panel_style())
		button.add_theme_stylebox_override("pressed", panel_style())
		button.add_theme_stylebox_override("disabled", panel_style())
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("382413"))
		button.add_theme_color_override("font_disabled_color", Color("382413"))
		button.add_theme_color_override("font_hover_color", Color("94451d"))
		button.add_theme_color_override("font_pressed_color", Color("94451d"))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		buttons.add_child(button)

func layout_ui() -> void:
	if not is_instance_valid(view): return
	var available := Vector2(size.x, size.y - 270)
	var ratio := minf(available.x / WORLD.x, available.y / WORLD.y)
	# Whole-number enlargement; fractional reduction only when a phone cannot fit 640 pixels.
	var zoom := floorf(ratio) if ratio >= 1.0 else ratio
	view.size = WORLD * zoom
	view.position = Vector2(floorf((size.x - view.size.x) / 2), 83)
	var left := maxf(12, view.position.x)
	var width := size.x - left * 2
	title.position = Vector2(left, 10)
	title.add_theme_font_size_override("font_size", 19 if size.x < 600 else 24)
	stats.position = Vector2(left, 46)
	stats.add_theme_font_size_override("font_size", 14 if size.x < 600 else 17)
	paper.position = Vector2(left, view.position.y + view.size.y + 8)
	paper.size = Vector2(width, 112)
	objective.position = Vector2(14, 10)
	objective.size = Vector2(width - 28, 44)
	journal.position = Vector2(14, 53)
	journal.size = Vector2(width - 28, 57)
	journal.add_theme_font_size_override("font_size", 14 if size.x < 600 else 16)
	objective.add_theme_font_size_override("font_size", 16 if size.x < 600 else 18)
	buttons.position = Vector2(left, paper.position.y + 121)
	buttons.columns = 2 if size.x < 600 else 4
	buttons.size = Vector2(width, 98 if size.x < 600 else 46)
	for button in buttons.get_children():
		button.add_theme_font_size_override("font_size", 13 if size.x < 600 else 17)
		var index: int = button.get_index()
		button.text = ["Talk", "Lasso", "Shoot", "Reset"][index] if size.x < 600 else ["Talk [E]", "Lasso [L]", "Shoot [F]", "Reset [R]"][index]
		button.custom_minimum_size.x = 0 if size.x < 600 else 80

func world_input(event: InputEvent) -> void:
	if qa_mode: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = event.position / view.size * WORLD
	if event is InputEventScreenTouch and event.pressed:
		target = event.position / view.size * WORLD

func _unhandled_key_input(event: InputEvent) -> void:
	if qa_mode: return
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_E or event.keycode == KEY_SPACE: interact()
	if event.keycode == KEY_L: lasso()
	if event.keycode == KEY_F: shoot()
	if event.keycode == KEY_R: reset_room()
	if event.keycode == KEY_K: get_tree().change_scene_to_file("res://scenes/kit_browser.tscn")

func keyboard() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	elapsed += delta
	shot_cooldown = maxf(0, shot_cooldown - delta)
	var direction := Vector2.ZERO if qa_mode else keyboard()
	if direction.length() > 0:
		target = Vector2.INF
	elif target != Vector2.INF:
		direction = target - player.position
		if direction.length() < 4:
			direction = Vector2.ZERO
			target = Vector2.INF
	direction = direction.normalized()
	if won: direction = Vector2.ZERO
	if direction != Vector2.ZERO: facing = direction
	var previous_position: Vector2 = player.position
	player.position = limit_position(player.position + direction * 96 * delta)
	var actual_motion: Vector2 = player.position - previous_position
	player.pose(actual_motion.length() > 0.01, direction, actual_motion.length() / delta)
	for cow in cows:
		var velocity := Vector2.ZERO
		var away: Vector2 = cow.position - player.position
		if cow.secured:
			cow.pose(false)
			continue
		if cow == rope_target and rope_time > 0:
			var follow: Vector2 = player.position - facing * 36
			if cow.position.distance_to(follow) > 8:
				velocity = cow.position.direction_to(follow) * 85
		elif away.length() < 70 and away.length() > 0.1:
			velocity = away.normalized() * (70 - away.length()) * 1.25
		for other in cows:
			if other == cow: continue
			var separation: Vector2 = cow.position - other.position
			if separation.length() < 24 and separation.length() > 0.1:
				velocity += separation.normalized() * (24 - separation.length()) * 2
		var cow_before: Vector2 = cow.position
		cow.position = limit_position(cow.position + velocity * delta)
		var cow_motion: Vector2 = cow.position - cow_before
		cow.pose(cow_motion.length() / delta > 3, cow_motion, cow_motion.length() / delta)
		if CORRAL.has_point(cow.position) and not rustler_active:
			cow.secured = true
			message = "A steer settles in the east gathering. %d of 6 safe." % secured_count()
	if rope_time > 0 and is_instance_valid(rope_target):
		rope_time -= delta
		rope.points = PackedVector2Array([player.position + Vector2(0,-31), (player.position + rope_target.position) / 2 + Vector2(0,-15), rope_target.position + Vector2(0,-16)])
	else:
		rope.clear_points()
		rope_target = null
	shot_time -= delta
	if shot_time <= 0: shot.clear_points()
	if escaped:
		rustler.position.x += 105 * delta
		rustler.pose(true, Vector2.RIGHT, 105.0)
		if rustler.position.x > 670:
			rustler.visible = false
			escaped = false
	if not won and talked and secured_count() == 6 and not rustler_active:
		won = true
		cash += 60
		message = "Eleanor: All six accounted for. Clear Fork is behind us. +$60"
	refresh()
	if qa_mode and not qa_done and elapsed > 0.3:
		qa_done = true
		run_qa()

func limit_position(at: Vector2) -> Vector2:
	var result := at.clamp(Vector2(24, 71), Vector2(616, 303))
	# All moving actors use the same wagon footprint, including lassoed cattle.
	if WAGON_FOOTPRINT.has_point(result):
		var exits := [Vector2(38.9,result.y),Vector2(139.1,result.y),Vector2(result.x,72.9),Vector2(result.x,115.1)]
		var closest: Vector2 = exits[0]
		for point in exits:
			if result.distance_squared_to(point) < result.distance_squared_to(closest): closest = point
		result = closest
	for entry in solid_scenery:
		var center := Vector2(entry.position[0], entry.position[1])
		var delta := result - center
		var radius := float(entry.collision_radius) + 7.0
		if delta.length() < radius:
			var push := delta.normalized() if delta.length() > 0 else center.direction_to(WORLD / 2)
			var candidate := center + push * radius
			if candidate.x < 24 or candidate.x > 616 or candidate.y < 71 or candidate.y > 303:
				candidate = center + center.direction_to(Vector2(320,187)) * radius
			result = candidate
	return result.clamp(Vector2(24, 71), Vector2(616, 303))

func secured_count() -> int:
	var count := 0
	for cow in cows:
		if cow.secured: count += 1
	return count

func interact() -> void:
	if player.position.distance_to(eleanor.position) < 65:
		talked = true
		eleanor.action("talk", Vector2.RIGHT)
		message = "Eleanor: Push from behind. Lasso a stray. Drive off the rustler first."
	else:
		message = "Ride near Eleanor by the wagon, then Talk. Click or tap the ground to ride."
	refresh()

func lasso() -> void:
	if won or player.action_time > 0: return
	if rustler_active and player.position.distance_to(rustler.position) < 110:
		pending_lasso = rustler
		player.action("lasso", rustler.position - player.position)
		if not player.directional: on_player_action_event("rope_release")
		return
	var nearest: Node2D
	var distance := 115.0
	for cow in cows:
		var d := player.position.distance_to(cow.position)
		if d < distance and not cow.secured:
			nearest = cow
			distance = d
	if nearest:
		pending_lasso = nearest
		player.action("lasso", nearest.position - player.position)
		message = "Casting the loop..."
		if not player.directional: on_player_action_event("rope_release")
	else:
		message = "Out of rope range. Ride closer to a stray or the rustler."
	refresh()

func shoot() -> void:
	if won or shot_cooldown > 0 or player.action_time > 0: return
	if ammo == 0:
		message = "Empty. You can still lasso the rustler at close range."
		return
	ammo -= 1
	shot_cooldown = 0.4
	pending_shot = true
	pending_aim = player.position.direction_to(rustler.position) if rustler_active and player.position.distance_to(rustler.position) < 190 else facing
	player.action("shoot", pending_aim)
	if not player.directional: on_player_action_event("fire")
	refresh()

func on_player_action_event(event_name: String) -> void:
	if event_name == "rope_release" and is_instance_valid(pending_lasso):
		var caught := pending_lasso
		pending_lasso = null
		if player.position.distance_to(caught.position) > 130:
			message = "The loop falls short. Ride closer and cast again."
		elif caught == rustler and rustler_active:
			rope_target = caught
			rope_time = 0.7
			clear_rustler("Your loop catches his gun arm. The rustler flees.")
		elif caught in cows and not caught.secured:
			rope_target = caught
			rope_time = 7.0
			message = "Roped! Ride east. The steer follows for seven seconds."
		refresh()
	if event_name != "fire" or not pending_shot: return
	pending_shot = false
	shot_time = 0.10
	var origin: Vector2 = player.position + Vector2(0,-31)
	var endpoint: Vector2 = origin + pending_aim * 150
	if rustler_active and player.position.distance_to(rustler.position) < 190:
		hits += 1
		endpoint = rustler.position + Vector2(0,-20)
		message = "The rustler flinches. One more shot will send him running."
		if hits >= 2: clear_rustler("Two shots send the rustler running. Bring the herd east.")
	else:
		message = "The shot goes wide. Get within range of the rustler."
	shot.points = PackedVector2Array([origin, endpoint])
	refresh()

func clear_rustler(text: String) -> void:
	rustler_active = false
	escaped = true
	cash += 18
	message = text
	refresh()

func refresh() -> void:
	if not is_instance_valid(stats): return
	stats.text = "$%d    CATTLE %d/6    AMMO %d    MAY 12, 1868" % [cash,secured_count(),ammo]
	objective.text = "CLEAR FORK COMPLETE" if won else "Talk to Eleanor  /  Clear the rustler  /  Gather six cattle east"
	if not won and rope_time > 0 and rope_target in cows:
		objective.text = "STEER ROPED  /  %.1fs remaining  /  Ride toward the east gathering" % rope_time
	journal.text = message

func reset_room() -> void:
	get_tree().reload_current_scene()

func demo_ride(destination: Vector2, seconds: float = 8.0) -> bool:
	target = destination
	var deadline := elapsed + seconds
	while player.position.distance_to(destination) > 5 and elapsed < deadline:
		await get_tree().physics_frame
	target = Vector2.INF
	return player.position.distance_to(destination) <= 5

func run_demo() -> void:
	# Continuous scripted play through normal travel/actions: no actor teleports.
	await get_tree().create_timer(1.0).timeout
	assert(await demo_ride(Vector2(183,145)))
	interact()
	await get_tree().create_timer(1.0).timeout
	assert(await demo_ride(Vector2(430,180)))
	shoot()
	await get_tree().create_timer(0.6).timeout
	shoot()
	await get_tree().create_timer(0.6).timeout
	assert(not rustler_active)
	var deadline := elapsed + 120
	while not won and elapsed < deadline:
		var nearest: Node2D
		var distance := INF
		for cow in cows:
			if not cow.secured and player.position.distance_to(cow.position) < distance:
				nearest = cow
				distance = player.position.distance_to(cow.position)
		if nearest == null: break
		# Enter casting range using real movement; the target can move while approached.
		while player.position.distance_to(nearest.position) > 95 and elapsed < deadline:
			target = nearest.position
			await get_tree().physics_frame
		target = Vector2.INF
		lasso()
		await get_tree().create_timer(0.55).timeout
		if rope_target in cows:
			var destination := Vector2(585,clampf(rope_target.position.y,145,225))
			await demo_ride(destination,7.0)
			await get_tree().create_timer(0.4).timeout
		rope_time = 0
	assert(won, "Continuous demo must complete without teleporting actors")
	await get_tree().create_timer(2.0).timeout
	print("CONTINUOUS PLAY PASS: all-six objective completed through travel and actions; no actor teleports")
	get_tree().quit()

func run_qa() -> void:
	# Integration checks invoke the same public actions and movement loop as play.
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://room-desktop.png")
	var initial: Vector2 = player.position
	target = initial + Vector2(30, 0)
	await get_tree().create_timer(0.4).timeout
	assert(player.position.x > initial.x + 20, "Tap movement must move the rider")
	if player.directional:
		for direction in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.RIGHT]:
			player.pose(true, direction)
			assert(str(player.art.animation) == "walk_" + player.direction_name(direction))
		player.art.set_frame_and_progress(2, 0.4)
		player.pose(true, Vector2.UP, 72)
		assert(player.art.frame == 2 and absf(player.art.frame_progress - 0.4) < 0.01, "Turning must retain gait phase")
		player.pose(true, Vector2(1,1.05), 72)
		assert(player.facing == "south")
		player.pose(true, Vector2(1.05,1), 72)
		assert(player.facing == "south", "Small diagonal variations must not chatter between facings")
		player.pose(true, Vector2.RIGHT, 36)
		assert(is_equal_approx(player.art.speed_scale, 0.5))
		player.action("lasso", Vector2.LEFT)
		assert(is_equal_approx(player.art.speed_scale, 1.0), "Action timing must not inherit walk speed")
		assert(player.art.animation == "lasso_west")
		player.pose(true, Vector2.RIGHT)
		assert(player.art.animation == "lasso_west", "Movement must not erase the lasso action")
		await get_tree().create_timer(0.6).timeout
		assert(player.action_time == 0)
		for entry in solid_scenery:
			var center := Vector2(entry.position[0],entry.position[1])
			assert(limit_position(center).distance_to(center) >= float(entry.collision_radius))
		for point in [Vector2(39.5,94),Vector2(138.5,94),Vector2(90,73.5),Vector2(90,114.5)]:
			assert(not WAGON_FOOTPRINT.has_point(limit_position(point)), "Shared wagon collision must resolve all four approaches")
	target = Vector2.INF
	player.position = eleanor.position + Vector2(35, 0)
	interact()
	assert(talked)
	player.position = Vector2(430, 175)
	shoot()
	assert(ammo == 5)
	if player.directional: assert(hits == 0 and pending_shot, "Damage waits for the visible firing pose")
	await get_tree().create_timer(0.15).timeout
	assert(hits == 1 and not pending_shot)
	if player.directional: assert(str(player.art.animation).begins_with("shoot_"))
	await get_tree().create_timer(0.4).timeout
	shoot()
	await get_tree().create_timer(0.5).timeout
	assert(not rustler_active and ammo == 4)
	player.position = cows[0].position - Vector2(45, 0)
	lasso()
	if player.directional: assert(pending_lasso == cows[0], "Lasso must wind up before attachment")
	await get_tree().create_timer(0.3).timeout
	assert(rope_target == cows[0])
	var old: Vector2 = cows[0].position
	target = Vector2(500, 190)
	await get_tree().create_timer(2).timeout
	assert(cows[0].position.distance_to(old) > 10, "Lasso must move a steer")
	target = Vector2.INF
	rope_time = 0
	# Bring every steer in using actual lasso following; never teleport cattle to win.
	var gathering_deadline := elapsed + 60.0
	while secured_count() < 6 and elapsed < gathering_deadline:
		var cow: Node2D
		for candidate in cows:
			if not candidate.secured:
				cow = candidate
				break
		player.position = cow.position - Vector2(30, 0)
		lasso()
		await get_tree().create_timer(0.3).timeout
		assert(is_instance_valid(rope_target))
		var selected: Node2D = rope_target
		target = Vector2(586, clampf(selected.position.y, 145, 225))
		var deadline := elapsed + 7.5
		while not selected.secured and elapsed < deadline:
			await get_tree().physics_frame
		if not selected.secured:
			print("LASSO QA: rider=", player.position, " steer=", selected.position, " target=", target, " rope=", rope_time, " active=", rustler_active)
		assert(selected.secured, "A lassoed steer must reach the gathering area")
		target = Vector2.INF
		rope_time = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(won and cash == 420)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://room-complete.png")
	get_window().size = Vector2i(390,844)
	await get_tree().create_timer(0.3).timeout
	for width in [360,390]:
		get_window().size = Vector2i(width,844)
		await get_tree().create_timer(0.15).timeout
		for button in buttons.get_children():
			assert(button.get_global_rect().end.x <= size.x and button.get_global_rect().end.y <= size.y, "Phone controls must fit in the window")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://room-phone.png")
	print("QA PASS: real atlases, tap movement, dialogue, shooting, lasso following, all-six objective, responsive capture")
	get_tree().quit()

func export_smoke() -> void:
	await get_tree().create_timer(0.5).timeout
	for actor in actors.get_children():
		if not actor is Actor: continue
		if actor.art.sprite_frames.get_frame_texture("idle", 0) == null:
			push_error("Missing exported actor texture")
			get_tree().quit(2)
			return
	await RenderingServer.frame_post_draw
	var path := OS.get_executable_path().get_base_dir().path_join("export-smoke.png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("EXPORT SMOKE: actors=", actors.get_child_count(), " capture_result=", result)
	get_tree().quit(result)
