extends Control

const Actor = preload("res://scripts/actor.gd")
const SpeechBubble = preload("res://scripts/speech_bubble.gd")
const CompanionRoom = preload("res://scripts/companion_room.gd")
const BanterQueue = preload("res://scripts/banter_queue.gd")
const WORLD := Vector2(640, 360)
const CORRAL := Rect2(475, 110, 125, 155)
const WAGON_FOOTPRINT := Rect2(39,73,100,42)
const LEAD_SECONDS := 18.0
var ride_speed := 32.0
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
var rope_flight_target: Node2D
var rope_flight_time := 0.0
const ROPE_FLIGHT_SECONDS := 0.20
var rope: Line2D
var rope_far_wrap: Line2D
var rope_catch_age := 0.0
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
var sequence_walking := false
var stride_subjects: Array[Node2D] = []
var speech: Control
var spoken_beats := {}
var pending_banter = BanterQueue.new()
var motion_review_heading := Vector2.RIGHT
var companion: RefCounted

func _ready() -> void:
	if "--kits" in OS.get_cmdline_user_args() and not get_tree().has_meta("kits_opened"):
		get_tree().set_meta("kits_opened", true)
		get_tree().change_scene_to_file.call_deferred("res://scenes/kit_browser.tscn")
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art_path := "res://assets/sprites.json" if "--original" in OS.get_cmdline_user_args() else "res://assets/room-art.json"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(art_path))
	ride_speed = float(manifest.sprites.rider.get("locomotion",{}).get("travel_speed",96.0))
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
	rope_far_wrap = Line2D.new()
	rope_far_wrap.width = 1.0
	rope_far_wrap.default_color = Color("c4a368")
	world.add_child(rope_far_wrap)
	world.move_child(rope_far_wrap,world.get_children().find(actors))
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
	speech = SpeechBubble.new()
	add_child(speech)
	resized.connect(layout_ui)
	layout_ui()
	qa_mode = "--qa" in OS.get_cmdline_user_args() or "--demo" in OS.get_cmdline_user_args() or "--pose-review" in OS.get_cmdline_user_args() or "--herd-review" in OS.get_cmdline_user_args() or "--sequence-review" in OS.get_cmdline_user_args() or "--stride-compare" in OS.get_cmdline_user_args()
	for button in buttons.get_children(): button.disabled = qa_mode
	refresh()
	if "--smoke" in OS.get_cmdline_user_args():
		export_smoke.call_deferred()
	if "--demo" in OS.get_cmdline_user_args():
		qa_done = true
		run_demo.call_deferred()
	if "--pose-review" in OS.get_cmdline_user_args():
		qa_done = true
		run_pose_review.call_deferred()
	if "--herd-review" in OS.get_cmdline_user_args():
		qa_done = true
		run_herd_review.call_deferred()
	if "--sequence-review" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_sequence_review.call_deferred()
	if "--stride-compare" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_stride_compare.call_deferred()
	if "--movement-batch" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_movement_batch.call_deferred()
	if "--speech-review" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_speech_review.call_deferred()
	if "--motion-review" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_motion_review.call_deferred()
	if "--neck-review" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_neck_review.call_deferred()
	companion = CompanionRoom.new(self)
	if "--companion-qa" in OS.get_cmdline_user_args():
		qa_mode = true
		qa_done = true
		run_companion_qa.call_deferred()
	elif not qa_mode and not "--smoke" in OS.get_cmdline_user_args():
		companion.load_game()

func spawn(id: String, at: Vector2) -> Node2D:
	var actor := Actor.new()
	actor.configure(id, manifest.sprites[id])
	actor.position = at
	actors.add_child(actor)
	return actor

func _process(delta: float) -> void:
	if is_instance_valid(speech): speech.tick(delta,view)
	pending_banter.tick(delta)
	if not is_instance_valid(speech) or speech.remaining>0: return
	# Only display a queued event while its original speaker still exists.
	for attempt in range(2):
		var next: Dictionary = pending_banter.take()
		if next.is_empty(): break
		if spoken_beats.has(next.beat): continue
		var actor = instance_from_id(int(next.payload.actor_id))
		if not is_instance_valid(actor) or not actor is Node2D or not actor.visible: continue
		if speech.say(actor,next.payload.speaker,next.payload.text,next.payload.height,next.priority):
			spoken_beats[next.beat] = true
			break

func say_once(beat: String, actor: Node2D, name_text: String, line: String, importance := 0) -> void:
	if spoken_beats.has(beat): return
	var height := 62 if actor==player else 42
	if speech.say(actor,name_text,line,height,importance):
		spoken_beats[beat] = true
	elif importance>=1:
		pending_banter.offer(beat,{"actor_id":actor.get_instance_id(),"speaker":name_text,"text":line,"height":height},importance,6.0)

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
	for entry in [["Talk [E]", interact], ["Lasso [L]", lasso], ["Shoot [F]", shoot], ["Companion [Tab]", switch_companion], ["Rest [G]", rest_companion], ["Reset [R]", reset_room]]:
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
	var available := Vector2(size.x, maxf(80,size.y - (326 if size.x<600 else 270)))
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
	paper.size = Vector2(width, 154 if size.x<600 else 112)
	objective.position = Vector2(14, 10)
	objective.size = Vector2(width - 28, 64 if size.x<600 else 44)
	journal.position = Vector2(14, 78 if size.x<600 else 53)
	journal.size = Vector2(width - 28, 68 if size.x<600 else 57)
	journal.add_theme_font_size_override("font_size", 14 if size.x < 600 else 16)
	objective.add_theme_font_size_override("font_size", 16 if size.x < 600 else 18)
	buttons.position = Vector2(left, paper.position.y + paper.size.y + 9)
	buttons.columns = 2 if size.x < 600 else 6
	buttons.size = Vector2(width, 150 if size.x < 600 else 46)
	for button in buttons.get_children():
		button.add_theme_font_size_override("font_size", 13 if size.x < 600 else 17)
		var index: int = button.get_index()
		button.text = ["Talk", "Lasso", "Shoot", "Companion", "Rest", "Reset"][index] if size.x < 600 else ["Talk [E]", "Lasso [L]", "Shoot [F]", "Companion [Tab]", "Rest [G]", "Reset [R]"][index]
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
	if event.keycode == KEY_TAB: switch_companion()
	if event.keycode == KEY_G: rest_companion()
	if event.keycode == KEY_H and companion != null: companion.flirt()
	if event.keycode == KEY_F5 and companion != null: companion.save_game()
	if event.keycode == KEY_F9 and companion != null: companion.load_game()
	if event.keycode == KEY_K: get_tree().change_scene_to_file("res://scenes/kit_browser.tscn")

func keyboard() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	if "--neck-review" in OS.get_cmdline_user_args():
		update_rope(delta)
		return
	if "--motion-review" in OS.get_cmdline_user_args():
		for subject in stride_subjects:
			var speed := ride_speed if subject==player else 24.0
			subject.position += motion_review_heading*speed*delta
			subject.pose(true,motion_review_heading,speed)
		return
	if "--movement-batch" in OS.get_cmdline_user_args():
		for subject in stride_subjects:
			var heading: Vector2 = subject.get_meta("review_direction")
			subject.position += heading*24.0*delta
			subject.pose(true,heading,36)
		return
	if "--stride-compare" in OS.get_cmdline_user_args():
		for subject in stride_subjects:
			var motion := Vector2(1,-1).normalized()*18.75*delta
			subject.position += motion
			subject.pose(true,motion,72)
		return
	if "--sequence-review" in OS.get_cmdline_user_args():
		if sequence_walking:
			var review_speed := 18.75 if "--stride-trial" in OS.get_cmdline_user_args() else ride_speed
			var travel := Vector2(1,-1).normalized()*review_speed*delta
			player.position += travel
			player.pose(true,travel,review_speed)
		update_rope(delta)
		return
	if "--pose-review" in OS.get_cmdline_user_args() or "--herd-review" in OS.get_cmdline_user_args(): return
	elapsed += delta
	if companion != null: companion.advance_time(delta)
	shot_cooldown = maxf(0, shot_cooldown - delta)
	var controlled: Node2D = companion.active_actor() if companion != null else player
	var direction := Vector2.ZERO if qa_mode else keyboard()
	if direction.length() > 0:
		target = Vector2.INF
	elif target != Vector2.INF:
		direction = target - controlled.position
		if direction.length() < 4:
			direction = Vector2.ZERO
			target = Vector2.INF
	direction = direction.normalized()
	# These casts/shots use a planted mount. Resume the queued ride after recovery.
	if controlled.action_time > 0: direction = Vector2.ZERO
	if direction != Vector2.ZERO and controlled==player: facing = direction
	var previous_position: Vector2 = controlled.position
	controlled.position = limit_position(controlled.position + direction * (28.0 if controlled==eleanor else ride_speed) * delta)
	var actual_motion: Vector2 = controlled.position - previous_position
	controlled.pose(actual_motion.length() > 0.01, direction, actual_motion.length() / delta)
	for cow in cows:
		var velocity := Vector2.ZERO
		if companion != null and companion.lantern.owns_cow(cow): continue
		var away: Vector2 = cow.position - player.position
		if cow.secured:
			cow.pose(false)
			continue
		if cow == rope_target and rope_time > 0:
			var follow: Vector2 = player.position - facing * 64
			if CORRAL.has_point(player.position):
				var settling_area := CORRAL.grow(-12)
				follow = follow.clamp(settling_area.position,settling_area.end)
			if cow.position.distance_to(follow) > 8:
				velocity = cow.position.direction_to(follow) * minf(85, (cow.position.distance_to(follow)-8)*4)
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
	if companion != null and companion.lantern != null: companion.lantern.tick(delta)
	if companion != null: companion.sync_lantern_equipment()
	if companion != null and companion.mechanic != null: companion.mechanic.tick(delta)
	update_rope(delta)
	shot_time -= delta
	if shot_time <= 0: shot.clear_points()
	if escaped and rustler.action_time<=0:
		var escape_speed := float(manifest.sprites.rustler.get("locomotion",{}).get("escape_speed",48))
		rustler.position.x += escape_speed * delta
		rustler.pose(true, Vector2.RIGHT, escape_speed,"run")
		if rustler.position.x > 670:
			rustler.visible = false
			escaped = false
	if not won and talked and secured_count() == 6 and not rustler_active:
		won = true
		cash += 60
		message = "Eleanor: All six accounted for. Clear Fork is behind us. +$60"
		if companion != null: companion.say_event("all_cattle_safe","room_complete")
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
	if companion != null and companion.mechanic != null: result = companion.mechanic.limit_motion(result)
	return result.clamp(Vector2(24, 71), Vector2(616, 303))

func secured_count() -> int:
	var count := 0
	for cow in cows:
		if cow.secured: count += 1
	return count

func interact() -> void:
	if companion != null and companion.interact(): return
	if player.position.distance_to(eleanor.position) < 65:
		if not talked and player.action_time<=0 and rope_time<=0:
			player.action("greeting",eleanor.position-player.position)
		talked = true
		eleanor.action("talk", Vector2.RIGHT)
		if companion != null: companion.say_event("intro","eleanor_intro")
		message = "Eleanor: Spirits spooked the herd. Push from behind; rope strays. Clear that rustler first."
	else:
		message = "Ride near Eleanor by the wagon, then Talk. Click or tap the ground to ride."
	refresh()

func lasso() -> void:
	if companion != null and companion.mechanic.toggle_feed(): return
	if won and companion != null:
		companion.flirt()
		return
	if companion != null and companion.is_eleanor():
		message = "Eleanor steadies cattle with Talk. Switch back to the trail boss to use the lasso."
		refresh()
		return
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

func wait_for_lasso_resolution() -> void:
	var remaining := 2.0
	while (is_instance_valid(pending_lasso) or rope_flight_time>0) and remaining>0:
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	assert(remaining>0, "Lasso wind-up and flight must resolve within two seconds")

func shoot() -> void:
	if companion != null and companion.mechanic.toggle_vent(): return
	if companion != null and companion.is_eleanor(): return
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
		if player.uses_procedural_rope():
			rope_flight_target = caught
			rope_flight_time = ROPE_FLIGHT_SECONDS
		else: catch_rope(caught)
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

func catch_rope(caught: Node2D) -> void:
	if not is_instance_valid(caught): return
	rope_catch_age = 0.0
	if player.position.distance_to(caught.position) > 140:
		message = "The loop falls short. Ride closer and cast again."
	elif caught == rustler and rustler_active:
		rope_target = caught
		rope_time = 0.7
		clear_rustler("Your loop catches his gun arm. The rustler flees.")
	elif caught in cows and not caught.secured:
		rope_target = caught
		rope_time = LEAD_SECONDS + (companion.field_perk("lasso_follow_seconds") if companion != null else 0.0)
		message = "Roped! Keep a steady pace toward the east gathering."
		say_once("first_catch",player,"TRAIL BOSS","That's one opinionated steer.")
	refresh()

func update_rope(delta: float) -> void:
	var hand: Vector2 = player.socket_world("rope_hand",Vector2(8,-42))
	var points := PackedVector2Array()
	rope_far_wrap.clear_points()
	if rope_flight_time > 0 and is_instance_valid(rope_flight_target):
		rope_flight_time = maxf(0,rope_flight_time-delta)
		var progress := 1.0-rope_flight_time/ROPE_FLIGHT_SECONDS
		var neck: Vector2 = rope_flight_target.socket_world("rope_neck",Vector2(0,-22))
		var loop_center := hand.lerp(neck,progress) + Vector2(0,-sin(progress*PI)*12)
		append_rope_curve(points,hand,loop_center+Vector2(6,0),3)
		append_rope_loop(points,loop_center,Vector2(6,3))
		if rope_flight_time == 0:
			catch_rope(rope_flight_target)
			rope_flight_target = null
	elif rope_time > 0 and is_instance_valid(rope_target):
		rope_time -= delta
		rope_catch_age += delta
		var neck: Vector2 = rope_target.socket_world("rope_neck",Vector2(0,-22))
		var direction := String(rope_target.art.animation).get_slice("_",1)
		var cross_sections := {"east":Vector2(2,3),"west":Vector2(2,-3),"north":Vector2(4,0),"south":Vector2(4,0),"northeast":Vector2(3,2),"northwest":Vector2(3,-2),"southeast":Vector2(3,-2),"southwest":Vector2(3,2)}
		var cross_section: Vector2 = cross_sections.get(direction,Vector2(3,2))
		cross_section *= lerpf(1.5,1.0,clampf(rope_catch_age/0.15,0,1))
		if hand.distance_squared_to(neck-cross_section)<hand.distance_squared_to(neck+cross_section): cross_section = -cross_section
		# The lead approaches behind the body; only the near neck half crosses the sprite.
		# Drawing the whole lead in front produces a false rope stripe across the back.
		var far_points := PackedVector2Array()
		append_rope_curve(far_points,hand,neck+cross_section,clampf((90-hand.distance_to(neck))*0.12,1,8))
		for i in range(9):
			var angle := float(i)/8.0*PI
			points.append((neck+cross_section*cos(angle)+Vector2(0,1.5*sin(angle))).round())
			far_points.append((neck+cross_section*cos(angle)-Vector2(0,1.5*sin(angle))).round())
		rope_far_wrap.points = far_points
	elif is_instance_valid(pending_lasso) and player.uses_procedural_rope() and player.art.frame>0:
		var center := hand+Vector2(-11,-4)
		points.append(hand.round())
		append_rope_loop(points,center,Vector2(11,4))
	else:
		rope_target = null
	rope.points = points

func append_rope_curve(points: PackedVector2Array, start: Vector2, finish: Vector2, sag: float) -> void:
	for i in range(9):
		var t := float(i)/8.0
		points.append((start.lerp(finish,t)+Vector2(0,sin(t*PI)*sag)).round())

func append_rope_loop(points: PackedVector2Array, center: Vector2, radius: Vector2) -> void:
	for i in range(17):
		var angle := float(i)/16.0*TAU
		points.append((center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y)).round())

func clear_rustler(text: String) -> void:
	if not rustler_active: return
	if companion != null:
		companion.state.add_madness("player",8)
		companion.state.add_madness("rustler",20)
	say_once("rustler_retreat",rustler,"RUSTLER","All right! Keep your cattle!",1)
	rustler.action("yield_southwest",Vector2(-1,1))
	rustler_active = false
	escaped = true
	cash += 18
	message = text
	refresh()

func refresh() -> void:
	if not is_instance_valid(stats): return
	stats.text = "$%d    CATTLE %d/6    AMMO %d    %s" % [cash,secured_count(),ammo,companion.clock_label() if companion != null else "Day 1 12:00"]
	objective.text = "CLEAR FORK COMPLETE" if won else "Talk to Eleanor  /  Clear the rustler  /  Gather six cattle east"
	if not won and rope_time > 0 and rope_target in cows:
		objective.text = "STEER ROPED  /  %.1fs remaining  /  Ride toward the east gathering" % rope_time
	journal.text = message
	if companion != null: companion.decorate_ui()

func switch_companion() -> void:
	if companion != null: companion.switch_character()

func rest_companion() -> void:
	if companion != null: companion.rest_together()

func run_companion_qa() -> void:
	# Start at the verified room's completion boundary; exercise public companion actions.
	won = true
	talked = true
	rustler_active = false
	rustler.visible = false
	for index in range(6):
		cows[index].secured = true
		cows[index].position = Vector2(490+(index%3)*35,145+(index/3)*55)
	player.position = Vector2(181,152)
	interact()
	assert(companion.state.recruitment=="recruited")
	assert(companion.state.relationship_stage=="acquainted")
	switch_companion()
	assert(companion.is_eleanor())
	for index in range(3):
		await companion_walk_to(cows[index].position+Vector2(-14,12))
		interact()
		await get_tree().create_timer(0.9).timeout
	assert(companion.state.steadied_cattle.size()==3)
	assert(companion.save_game("user://companion-qa-save.json"))
	var saved_position: Vector2 = eleanor.position
	companion.state.cancel_adventure()
	eleanor.position = Vector2(150,140)
	assert(companion.load_game("user://companion-qa-save.json"))
	assert(companion.is_eleanor() and companion.state.steadied_cattle.size()==3 and eleanor.position.distance_to(saved_position)<0.01)
	DirAccess.remove_absolute("user://companion-qa-save.json")
	if FileAccess.file_exists("user://companion-qa-save.json.bak"): DirAccess.remove_absolute("user://companion-qa-save.json.bak")
	await companion_walk_to(Vector2(156,139))
	interact()
	assert(companion.state.adventure_status=="completed")
	assert(companion.state.relationship_stage=="trusted")
	companion.flirt()
	assert(companion.state.relationship_stage=="courting")
	companion.state.add_madness("player",30)
	var before: float = companion.state.madness.player
	rest_companion()
	assert(companion.state.madness.player==before-13)
	var after: float = companion.state.madness.player
	rest_companion()
	assert(companion.state.madness.player==after,"Rest cannot be farmed repeatedly")
	switch_companion()
	assert(not companion.is_eleanor())
	await get_tree().create_timer(4.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://companion-room.png")
	get_window().size = Vector2i(390,844)
	await get_tree().create_timer(0.3).timeout
	for button in buttons.get_children(): assert(button.get_global_rect().end.y<=size.y and button.get_global_rect().end.x<=size.x)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://companion-phone.png")
	print("COMPANION ROOM PASS: recruitment, actor switching, three cattle, camp completion, capped recovery, phone controls")
	get_tree().quit()

func companion_walk_to(destination: Vector2) -> void:
	target = destination
	var deadline := elapsed+25.0
	while eleanor.position.distance_to(destination)>4 and elapsed<deadline:
		await get_tree().physics_frame
	assert(eleanor.position.distance_to(destination)<=4,"Eleanor must reach the activity through actual walking")
	target = Vector2.INF

func reset_room() -> void:
	if not qa_mode:
		for path in [CompanionRoom.SAVE_PATH,CompanionRoom.SAVE_PATH+".bak"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	get_tree().reload_current_scene()

func run_pose_review() -> void:
	# Stationary animation inspection; separate from gameplay verification.
	for actor in actors.get_children():
		actor.visible = actor == player
	player.position = Vector2(380,245)
	var reference := Actor.new()
	var source_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	reference.configure("rider",source_art.sprites.rider)
	reference.position = Vector2(240,245)
	actors.add_child(reference)
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
		for action in ["walk","lasso","shoot"]:
			objective.text = "POSE REVIEW / " + action + " / " + player.direction_name(direction)
			journal.text = "Left: original approved rider. Right: selected rider. Fixed world anchors; movement paused."
			player.action(action,direction)
			await get_tree().create_timer(0.85).timeout
	print("POSE REVIEW PASS: 24 actual engine action/facing transitions rendered against original art")
	get_tree().quit()

func run_stride_compare() -> void:
	for actor in actors.get_children(): actor.visible = false
	var trial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/stride-trial.json"))
	var index := 0
	var comparison_keys := ["v5","v6_curated","v7_row"] if "--stride-v7" in OS.get_cmdline_user_args() else ["v5","v6_row","v6_curated"]
	if "--stride-v8" in OS.get_cmdline_user_args(): comparison_keys = ["v5","v6_curated","v8_row"]
	for key in comparison_keys:
		var subject := Actor.new()
		subject.configure("rider",trial.variants[key])
		subject.position = Vector2(110+index*175,275)
		actors.add_child(subject)
		stride_subjects.append(subject)
		index += 1
	objective.text = "STRIDE COMPARISON / left V5 / middle V6 row order / right V6 curated order"
	if "--stride-v7" in OS.get_cmdline_user_args(): objective.text = "STRIDE COMPARISON / left V5 / middle V6 curated / right V7 low-step edit"
	if "--stride-v8" in OS.get_cmdline_user_args(): objective.text = "STRIDE COMPARISON / left V5 / middle V6 curated / right V8 whole-sprite sequence"
	journal.text = "Same 18-pixel diagnostic stride and .96-second cycle. Compare foot support and loop continuity."
	await get_tree().create_timer(5.76).timeout
	print("STRIDE COMPARISON: three source sequences rendered over fixed ground; physical acceptance remains separate")
	get_tree().quit()

func run_movement_batch() -> void:
	for actor in actors.get_children(): actor.visible = false
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://kits/manifest.json"))
	var entries := [["rider","v9_walk_east","east",Vector2.RIGHT],["eleanor","v4_walk_northeast","northeast",Vector2(1,-1).normalized()],["rustler","v3_walk_northeast","northeast",Vector2(1,-1).normalized()]]
	for index in range(entries.size()):
		var entry: Array = entries[index]
		var spec: Dictionary = catalog.families[entry[0]].duplicate(true)
		spec.clips["walk_"+entry[2]] = spec.clips[entry[1]].duplicate(true)
		spec.clips.idle = {"frames":[spec.clips[entry[1]].frames[0]],"fps":1,"loop":true}
		spec.locomotion = {"nominal_speed":36}
		var subject := Actor.new()
		subject.configure(entry[0],spec)
		subject.position = Vector2(100+index*170,270)
		subject.set_meta("review_direction",entry[3])
		actors.add_child(subject)
		stride_subjects.append(subject)
	objective.text = "MOVEMENT BATCH / rider east / Eleanor northeast / rustler northeast"
	journal.text = "Whole-sprite movement candidates at native room scale."
	await get_tree().create_timer(5.0).timeout
	print("MOVEMENT BATCH: three new character sequences rendered at native room scale")
	get_tree().quit()

func run_neck_review() -> void:
	for actor in actors.get_children(): actor.visible = false
	player.visible = true
	player.position = Vector2(250,200)
	player.pose(false,Vector2.RIGHT)
	rustler_active = false
	var headings := {"east":Vector2.RIGHT,"southeast":Vector2(1,1),"south":Vector2.DOWN,"southwest":Vector2(-1,1),"west":Vector2.LEFT,"northwest":Vector2(-1,-1),"north":Vector2.UP,"northeast":Vector2(1,-1)}
	for steer in [cows[0],cows[1],cows[2]]:
		steer.visible = true
		steer.position = Vector2(340,200)
		rope_target = steer
		rope_time = 60
		rope_catch_age = 1
		for direction in headings:
			steer.pose(true,headings[direction],24)
			objective.text = "NECK WRAP / "+steer.kind+" / "+direction
			journal.text = "Actual front/back rope layers across each moving whole-sprite neck."
			await get_tree().create_timer(0.75).timeout
		steer.visible = false
	print("NECK REVIEW: three cattle appearances, eight moving facings each")
	get_tree().quit()

func run_motion_review() -> void:
	for actor in actors.get_children(): actor.visible = false
	stride_subjects = [player,cows[0],cows[1],cows[2]]
	for subject in stride_subjects: subject.visible = true
	var headings := {"east":Vector2.RIGHT,"southeast":Vector2(1,1).normalized(),"south":Vector2.DOWN,"southwest":Vector2(-1,1).normalized(),"west":Vector2.LEFT,"northwest":Vector2(-1,-1).normalized(),"north":Vector2.UP,"northeast":Vector2(1,-1).normalized()}
	for direction in headings:
		motion_review_heading = headings[direction]
		for index in range(stride_subjects.size()):
			var subject: Node2D = stride_subjects[index]
			subject.position = Vector2(95+index*145,200)
			subject.pose(true,motion_review_heading,ride_speed if index==0 else 24)
			assert(subject.art.animation=="walk_"+direction,"Every actor must select the requested actual facing")
		objective.text = "MOVING DIRECTIONS / "+direction+" / rider, longhorn, cream, spotted"
		journal.text = "Current gameplay sprites moving over fixed ground at their tuned pace."
		await get_tree().create_timer(2.0).timeout
	print("MOTION REVIEW PASS: all eight directions for rider and three cattle appearances")
	get_tree().quit()

func run_speech_review() -> void:
	player.position = Vector2(181,152)
	interact()
	await get_tree().create_timer(0.35).timeout
	assert(speech.visible,"Action comment must be visible")
	assert(view.get_rect().encloses(speech.get_rect()),"Desktop bubble stays within the world")
	get_viewport().get_texture().get_image().save_png("res://speech-room.png")
	get_window().size = Vector2i(390,844)
	await get_tree().create_timer(0.35).timeout
	assert(view.get_rect().encloses(speech.get_rect()),"Phone bubble stays within the world")
	get_viewport().get_texture().get_image().save_png("res://speech-phone.png")
	var before: Vector2 = player.position
	await get_tree().create_timer(player.action_time+0.05).timeout
	target = player.position+Vector2(30,0)
	await get_tree().create_timer(0.2).timeout
	assert(player.position.distance_to(before)>5,"Speech must not stop movement")
	get_window().size = Vector2i(1280,1000)
	speech.remaining = 0
	player.position = Vector2(490,190)
	target = Vector2.INF
	await get_tree().create_timer(0.3).timeout
	shoot()
	await get_tree().create_timer(0.5).timeout
	shoot()
	await get_tree().create_timer(0.3).timeout
	assert(not rustler_active and rustler.action_time>0,"Rustler must react before fleeing")
	get_viewport().get_texture().get_image().save_png("res://reaction-room.png")
	print("SPEECH REVIEW PASS: desktop and phone bounds, actor attachment, movement continues")
	get_tree().quit()

func run_sequence_review() -> void:
	# Focused animation evidence; this mode is distinct from full gameplay QA.
	for actor in actors.get_children(): actor.visible = actor == player
	for cow in cows: cow.position = Vector2(600,300)
	player.position = Vector2(160,275)
	var steer: Node2D = cows[0]
	steer.position = Vector2(320,170)
	steer.visible = true
	steer.pose(false,Vector2(1,-1))
	rustler_active = false
	objective.text = "SEQUENCE REVIEW / northeast walk / travel over fixed ground"
	journal.text = "Three moving cycles expose foot sliding; then two stationary cycles and timed lasso casts."
	if "--stride-trial" in OS.get_cmdline_user_args():
		objective.text = "STRIDE TRIAL / 18 px per cycle / diagnostic, not accepted"
	player.art.play("walk_northeast")
	var cycle_seconds := 0.0
	var walk_clip: Dictionary = manifest.sprites.rider.clips.walk_northeast
	for duration in walk_clip.durations: cycle_seconds += float(duration)
	var review_speed := 18.75 if "--stride-trial" in OS.get_cmdline_user_args() else ride_speed
	cycle_seconds /= review_speed/player.nominal_speed
	sequence_walking = true
	await get_tree().create_timer(cycle_seconds*3).timeout
	sequence_walking = false
	player.position = Vector2(240,230)
	await get_tree().create_timer(cycle_seconds*2).timeout
	player.pose(false,Vector2(1,-1))
	await get_tree().create_timer(0.6).timeout
	var review_directions := ["northwest","northwest","northwest"] if "--northwest-review" in OS.get_cmdline_user_args() else ["northeast","northeast","northeast"]
	if "--cast-review-all" in OS.get_cmdline_user_args(): review_directions = ["northeast","northwest","east","west","north","south","southeast","southwest"]
	var cast_offsets := {"northeast":Vector2(80,-60),"northwest":Vector2(-80,-60),"east":Vector2(80,0),"west":Vector2(-80,0),"north":Vector2(0,-80),"south":Vector2(0,65),"southeast":Vector2(70,60),"southwest":Vector2(-70,60)}
	for review_direction in review_directions:
		rope_time = 0
		rope_target = null
		steer.position = player.position + cast_offsets[review_direction]
		objective.text = "CAST REVIEW / " + review_direction + " / wind → cast → flight → catch → lead"
		lasso()
		var cast_recipe: Dictionary = manifest.sprites.rider.clips["lasso_"+review_direction]
		var release_ordinal: int = manifest.sprites.rider.action_events["lasso_"+review_direction].frame
		var release_time := 0.0
		for ordinal in range(release_ordinal): release_time += float(cast_recipe.durations[ordinal])
		await get_tree().create_timer(release_time+ROPE_FLIGHT_SECONDS*0.4).timeout
		assert(rope_target == null and rope_flight_time > 0, "Catch must wait for visible loop flight")
		assert(rope.get_point_count()>8, "The single rope must have a visible loop and hand tether")
		await get_tree().create_timer(0.25).timeout
		assert(rope_target == steer, "The loop must reach the neck before attachment")
		await get_tree().create_timer(1.5).timeout
		assert(player.art.animation == "idle_"+review_direction, "Completed cast must settle to low-hand lead")
	print("SEQUENCE REVIEW PASS: 5 walk cycles; ",review_directions.size()," timed single-rope casts, neck catches and low-hand recoveries")
	get_tree().quit()

func run_herd_review() -> void:
	# Compare native silhouettes and motion together at fixed, equal ground contacts.
	for actor in actors.get_children(): actor.visible = false
	var source_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites.json"))
	var subjects: Array[Node2D] = []
	var families := ["rider", "longhorn", "cream", "spotted"]
	for i in range(families.size()):
		var reference := Actor.new()
		reference.configure(families[i],source_art.sprites[families[i]])
		reference.position = Vector2(175 + i*105,155)
		actors.add_child(reference)
		subjects.append(spawn(families[i],Vector2(175 + i*105,265)))
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
		for action in ["idle","walk"]:
			objective.text = "HERD REVIEW / " + action + " / " + player.direction_name(direction)
			journal.text = "Top: approved original sprites. Bottom: selected rider and three cattle families."
			for subject in subjects: subject.action(action,direction)
			await get_tree().create_timer(0.85).timeout
	print("HERD REVIEW PASS: 64 native actor idle/walk facing strips rendered against originals")
	get_tree().quit()

func demo_ride(destination: Vector2, seconds: float = 18.0) -> bool:
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
	var deadline := elapsed + 240
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
		await wait_for_lasso_resolution()
		if rope_target in cows:
			var destination := Vector2(585,clampf(rope_target.position.y,145,225))
			await demo_ride(destination,LEAD_SECONDS)
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
	assert(player.position.x > initial.x + 10, "Tap movement must move the rider promptly")
	if player.directional:
		for direction in [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.RIGHT]:
			player.pose(true, direction)
			assert(str(player.art.animation) == "walk_" + player.direction_name(direction))
		for direction in [Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
			player.pose(true,direction)
			assert(str(player.art.animation) == "walk_" + player.direction_name(direction))
		player.art.set_frame_and_progress(2, 0.4)
		player.pose(true, Vector2.UP, 72)
		assert(player.art.frame == 2 and absf(player.art.frame_progress - 0.4) < 0.01, "Turning must retain gait phase")
		player.pose(true, Vector2(1,1.05), 72)
		assert(player.facing == "southeast")
		player.pose(true, Vector2(1.05,1), 72)
		assert(player.facing == "southeast", "Small diagonal variations must not chatter between facings")
		player.pose(true, Vector2.RIGHT, player.nominal_speed*0.5)
		assert(is_equal_approx(player.art.speed_scale, 0.5))
		player.action("lasso", Vector2.LEFT)
		assert(player.art.position == -Vector2(player.clip_anchors["lasso_west"][0],player.clip_anchors["lasso_west"][1]), "Action must use its measured ground anchor")
		assert(is_equal_approx(player.art.speed_scale, 1.0), "Action timing must not inherit walk speed")
		assert(player.art.animation == "lasso_west")
		player.pose(true, Vector2.RIGHT)
		assert(player.art.animation == "lasso_west", "Movement must not erase the lasso action")
		var planted_position: Vector2 = player.position
		target = planted_position + Vector2(70,0)
		await get_tree().create_timer(0.2).timeout
		assert(player.position.distance_to(planted_position)<0.1, "Planted cast must stop actual travel, not just hold its frame")
		await get_tree().create_timer(player.action_time+0.15).timeout
		assert(player.action_time == 0)
		assert(player.position.distance_to(planted_position)>1, "Queued ride must resume after cast recovery")
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
	await wait_for_lasso_resolution()
	assert(rope_target == cows[0])
	var old: Vector2 = cows[0].position
	target = Vector2(500, 190)
	await get_tree().create_timer(2).timeout
	assert(cows[0].position.distance_to(old) > 10, "Lasso must move a steer")
	target = Vector2.INF
	rope_time = 0
	# Bring every steer in using actual lasso following; never teleport cattle to win.
	var gathering_deadline := elapsed + 180.0
	while secured_count() < 6 and elapsed < gathering_deadline:
		var cow: Node2D
		for candidate in cows:
			if not candidate.secured:
				cow = candidate
				break
		player.position = cow.position - Vector2(30, 0)
		lasso()
		await wait_for_lasso_resolution()
		assert(is_instance_valid(rope_target))
		var selected: Node2D = rope_target
		target = Vector2(586, clampf(selected.position.y, 145, 225))
		var deadline := elapsed + LEAD_SECONDS+0.5
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
