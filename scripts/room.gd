extends Control

const Actor = preload("res://scripts/actor.gd")
const SpeechBubble = preload("res://scripts/speech_bubble.gd")
const CompanionRoom = preload("res://scripts/companion_room.gd")
const BanterQueue = preload("res://scripts/banter_queue.gd")
const Location = preload("res://scripts/location.gd")
const WORLD := Vector2(640, 360)
## The place this room opens on. Clear Fork is a file under data/locations like
## every other location; there is no hardcoded room left underneath it. If that
## file is missing or fails validation the room refuses to build and says why,
## rather than falling back to something that only looks right.
const HOME_LOCATION := "clear_fork"
## Both of these used to be constants describing Clear Fork. They are now read
## off the loaded location, so moving the gathering or the wagon is an edit to
## a JSON file. WAGON_FOOTPRINT keeps its old name because
## tools/cart_clearance_test.gd reads it by that name.
var CORRAL := Rect2()
var WAGON_FOOTPRINT := Rect2()
var blockers: Array[Rect2] = []
var location
const LEAD_SECONDS := 18.0
## Gunplay constants. Every one of these is a decision the player can feel:
## how far a round carries, how big a man is to hit, what a reload costs, and
## how long the rustler's aim hangs on you before he pulls.
const SHOT_RANGE := 200.0
const BODY_RADIUS := 9.0
const RELOAD_SECONDS := 1.6
const CYLINDER := 6
const RUSTLER_RANGE := 185.0
const TELL_SECONDS := 0.85
const RUSTLER_RELOAD := 1.9
const MAX_STRAIN := 3
const STRAIN_SECONDS := 9.0
const GUN_LIFT := Vector2(0, -26)
## The beaten rustler waits instead of running. Every row below is a durable
## difference the player can see afterwards: money, whether he is still on this
## ground, and whether the outfit is feeding him. Order is the button order.
const RUSTLER_CHOICES := ["loose", "law", "hire"]
const RUSTLER_FATES := {
	"loose": {
		"label": "Turn Him Loose",
		"short": "Loose",
		"cash": 0,
		"present": false,
		"hired": false,
		"rustler_line": "Then I walk. You will not see me on this water again.",
		"journal": "You let him keep his boots and nothing else. He walks off and does not look back. That is the last of him.",
		"eleanor_line": "Eleanor: You turned him loose. Some other outfit gets that argument.",
	},
	"law": {
		"label": "Rope Him for the Law",
		"short": "Law",
		"cash": 25,
		"present": true,
		"hired": false,
		"rustler_line": "Rope, then. I would sooner see Griffin than this grass.",
		"journal": "You tie his hands and sit him where you can watch him. He rides to Griffin when the wagon does. The county pays $25 for the trouble.",
		"eleanor_line": "Eleanor: The county has him. That is one letter I do not have to write.",
	},
	"hire": {
		"label": "Hire Him On",
		"short": "Hired",
		"cash": -10,
		"present": true,
		"hired": true,
		"rustler_line": "Wages? I will take wages. I know where your strays go.",
		"journal": "You feed him and put him on the book. Ten dollars for a saddle and a meal, and one more hand on the outfit.",
		"eleanor_line": "Eleanor: You hired the man who was stealing from us. He rides drag until I say different.",
	},
}
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
var bot
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
## The fight. aim_point is where the player is actually pointing; it is the
## only thing that decides where a round goes. strain is what being shot costs
## him: a shaking hand that widens his own aim and wears off on its own.
var rng := RandomNumberGenerator.new()
var aim_point := Vector2.INF
var strain := 0
var strain_time := 0.0
var reload_time := 0.0
var player_hits := 0
var rustler_tell := 0.0
var rustler_reload := 1.4
var rustler_aim := Vector2.LEFT
var tell_line: Line2D
var return_fire: Line2D
var return_fire_time := 0.0
var elapsed := 0.0
var escaped := false
## Set when he gives up and waits. rustler_fate stays empty until the player
## says what happens to him; it is the durable record of that decision.
var rustler_surrendered := false
var rustler_fate := ""
var rustler_hired := false
var rustler_present := true
var choice_buttons: Array = []
var qa_mode := false
var qa_done := false
var pending_lasso: Node2D
var pending_shot := false
var pending_aim := Vector2.RIGHT
var scenery: Node2D
var solid_scenery: Array = []
var ground_sprite: Sprite2D
## Everything populate_location() put in the world, so travel can take exactly
## that back out again and leave the rope, the shot line and the UI alone.
var location_nodes: Array[Node] = []
## Cast this location names that the art manifest has no sprite for.
var unrendered_cast: Array[String] = []
var sequence_walking := false
var stride_subjects: Array[Node2D] = []
var speech: Control
var spoken_beats := {}
var pending_banter = BanterQueue.new()
var motion_review_heading := Vector2.RIGHT
var companion: RefCounted

## The location is data, so it is read before any node exists. Headless checks
## that build a bare Room and call limit_position() get the same bounds and the
## same wagon the played room gets, from the same file.
func _init() -> void:
	adopt_location(Location.load_location(HOME_LOCATION))


## Take a loaded location as this room's ground truth. Refuses an invalid one
## by name: a location that failed validation must never be half applied.
##
## announce is false only in tools/location_test.gd, which exercises the
## refusal on purpose: tools/verify_godot.py treats any engine ERROR line as a
## failed run, so a deliberate refusal cannot shout through push_error. The
## return value is the same either way, and it is the return value the caller
## acts on.
func adopt_location(candidate, announce := true) -> bool:
	if candidate == null or not candidate.valid:
		var reason: String = "no location supplied" if candidate == null else str(candidate.fault_report())
		if announce: push_error("Room refused a location: " + reason)
		print("ROOM LOCATION REFUSED: ", reason)
		return false
	location = candidate
	CORRAL = location.goal_area
	blockers.clear()
	WAGON_FOOTPRINT = Rect2()
	for blocker in location.blockers:
		blockers.append(blocker.rect)
		if str(blocker.id) == "wagon": WAGON_FOOTPRINT = blocker.rect
	return true


func _ready() -> void:
	if "--kits" in OS.get_cmdline_user_args() and not get_tree().has_meta("kits_opened"):
		get_tree().set_meta("kits_opened", true)
		get_tree().change_scene_to_file.call_deferred("res://scenes/kit_browser.tscn")
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if location == null:
		push_error("Room cannot build: no valid location was loaded")
		return
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
	actors = Node2D.new()
	actors.y_sort_enabled = true
	populate_location()
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
	# His aim hangs on you before he fires, and it stops at whatever you put
	# between the two of you. That line is the whole warning.
	tell_line = Line2D.new()
	tell_line.width = 1.0
	tell_line.default_color = Color(0.85, 0.24, 0.18, 0.55)
	world.add_child(tell_line)
	return_fire = Line2D.new()
	return_fire.width = 1.0
	return_fire.default_color = Color("ffb27a")
	world.add_child(return_fire)
	rng.randomize()
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
	elif "--bot" in OS.get_cmdline_user_args():
		bot = preload("res://scripts/bot_api.gd").new()
		add_child(bot)
	elif not qa_mode and not "--smoke" in OS.get_cmdline_user_args():
		companion.load_game()

func spawn(id: String, at: Vector2) -> Node2D:
	var actor := Actor.new()
	actor.configure(id, manifest.sprites[id])
	actor.position = at
	actors.add_child(actor)
	location_nodes.append(actor)
	return actor


## Build the ground, the props, the cast and the map labels of whatever
## location this room has adopted. _ready and travel_to() both come through
## here; there is no second way to build a room, and no branch anywhere that
## knows the word "clear_fork".
func populate_location() -> void:
	ground_sprite = Sprite2D.new()
	ground_sprite.texture = load(location.ground_texture)
	ground_sprite.centered = false
	ground_sprite.modulate = location.ground_modulate
	world.add_child(ground_sprite)
	world.move_child(ground_sprite, 0)
	location_nodes.append(ground_sprite)
	if actors.get_parent() == null: world.add_child(actors)
	place_scenery()
	unrendered_cast.clear()
	for member in location.cast:
		var sprite_id := str(member.sprite)
		# The county is written well ahead of the art. A person with no sprite
		# in the art manifest is named out loud and left undrawn rather than
		# crashing the room or being quietly dropped; each location's art_gap
		# field is where that shortfall is meant to be recorded.
		if not manifest.sprites.has(sprite_id):
			unrendered_cast.append("%s (%s)" % [str(member.id), str(member.role)])
			continue
		var actor := spawn(sprite_id, member.position as Vector2)
		match str(member.role):
			"player":
				player = actor
				player.action_event.connect(on_player_action_event)
			"companion": eleanor = actor
			"rustler": rustler = actor
			"cattle": cows.append(actor)
	# A location need not list the player. When it does, that entry only says
	# where in the build order the rider goes; where he stands is arrivals,
	# either way, and there is one line that puts him there.
	if player == null:
		player = spawn("rider", location.arrival)
		player.action_event.connect(on_player_action_event)
	if not unrendered_cast.is_empty():
		print("LOCATION ART GAP: %s has no sprite for %s" % [location.id, ", ".join(unrendered_cast)])
	for marker in location.markers:
		var label := Label.new()
		label.text = str(marker.text)
		label.position = marker.position as Vector2
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("fff0c4"))
		label.add_theme_color_override("font_shadow_color", Color("382513"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		world.add_child(label)
		# Directly behind the actors node, where the hand-placed label sat.
		world.move_child(label, actors.get_index() + 1)
		location_nodes.append(label)


## The seam the travel system calls. Loads the named location, refuses it by
## name if it does not validate, and only then takes the old place apart. A
## rejected destination leaves the player standing where they were.
func travel_to(location_id: String) -> bool:
	var destination = Location.load_location(location_id)
	if destination == null or not destination.valid:
		message = "That road does not go anywhere yet."
		push_error("Travel refused: " + ("no location" if destination == null else destination.fault_report()))
		return false
	for node in location_nodes:
		if not is_instance_valid(node): continue
		# Out of the tree now, freed at idle. queue_free() alone would leave the
		# old place's props and people still counted as children of the world
		# for the rest of the frame, and the new location is built this frame.
		if node.get_parent() != null: node.get_parent().remove_child(node)
		node.queue_free()
	location_nodes.clear()
	solid_scenery.clear()
	cows.clear()
	player = null
	eleanor = null
	rustler = null
	adopt_location(destination)
	populate_location()
	target = Vector2.INF
	rope_target = null
	rope_time = 0.0
	talked = false
	spoken_beats.clear()
	if is_instance_valid(title): title.text = "CATTLE TRAIL  /  " + location.display_name.to_upper()
	refresh()
	return true

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
	if bot != null: bot.record_line(name_text, line)
	if spoken_beats.has(beat): return
	# A room built without its bubble (headless checks) still runs its logic.
	if not is_instance_valid(speech): return
	var height := 62 if actor==player else 42
	if speech.say(actor,name_text,line,height,importance):
		spoken_beats[beat] = true
	elif importance>=1:
		pending_banter.offer(beat,{"actor_id":actor.get_instance_id(),"speaker":name_text,"text":line,"height":height},importance,6.0)

func place_scenery() -> void:
	for entry in location.scenery:
		var prop := Sprite2D.new()
		var region := AtlasTexture.new()
		region.atlas = load(entry.texture)
		region.region = Rect2(entry.region[0], entry.region[1], entry.region[2], entry.region[3])
		prop.texture = region
		prop.centered = false
		prop.offset = -Vector2(entry.anchor[0], entry.anchor[1])
		prop.position = Vector2(entry.position[0], entry.position[1])
		var density := clampf(float(entry.get("pixels_per_world_unit", 1.0)), 1.0, 8.0)
		prop.scale = Vector2.ONE / density
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Ground-cover stays under hooves; tall props share the actors' ground Y sort.
		if entry.family == "grass" or bool(entry.get("ground_cover", false)):
			world.add_child(prop)
			world.move_child(prop, actors.get_index())
		else:
			actors.add_child(prop)
		location_nodes.append(prop)
		if float(entry.get("collision_radius", 0)) > 0:
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
	title.text = "CATTLE TRAIL  /  " + location.display_name.to_upper()
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
	# The first six keep their order: companion_room, mechanic_room, ada_cart_room
	# and the rest address these by index. Reload joins on the end.
	for entry in [["Talk [E]", interact], ["Lasso [L]", lasso], ["Shoot [F]", shoot], ["Companion [Tab]", switch_companion], ["Rest [G]", rest_companion], ["Reset [F2]", reset_room], ["Reload [R]", reload]]:
		var button := make_button(entry[0])
		button.pressed.connect(entry[1])
		buttons.add_child(button)

func make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
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
	return button

## The choice row lives after the six standing controls, so every existing
## index into buttons (companion_room.decorate_ui, the phone labels below)
## keeps meaning what it meant.
func build_choice_buttons() -> void:
	if not is_instance_valid(buttons) or not choice_buttons.is_empty(): return
	for index in range(RUSTLER_CHOICES.size()):
		var choice: String = RUSTLER_CHOICES[index]
		var button := make_button("%d. %s" % [index + 1, RUSTLER_FATES[choice].label])
		button.disabled = qa_mode
		button.pressed.connect(choose_rustler.bind(choice))
		buttons.add_child(button)
		choice_buttons.append(button)
	layout_ui()

## Hidden rather than freed: choose_rustler runs inside the pressed signal of
## one of these buttons, and the row costs nothing once it is out of the
## layout. Invisible children are skipped by the grid and by bot_api.
func hide_choice_buttons() -> void:
	for button in choice_buttons:
		if not is_instance_valid(button): continue
		button.visible = false
		button.disabled = true
	if is_instance_valid(buttons): layout_ui()

func choice_row_visible() -> bool:
	for button in choice_buttons:
		if is_instance_valid(button) and button.visible: return true
	return false

## The grid lays out visible children only, so the row arithmetic below has to
## count the same way or it reserves height for a row nobody can see.
func visible_control_count() -> int:
	if not is_instance_valid(buttons): return 7
	var count := 0
	for button in buttons.get_children():
		if button.visible: count += 1
	return maxi(count,1)

func layout_ui() -> void:
	if not is_instance_valid(view): return
	# Seven standing controls on one wide row, so the fate row lands underneath
	# it as its own row instead of sharing one with a stray Reload.
	var columns := 2 if size.x < 600 else 7
	var control_count: int = visible_control_count()
	var control_rows: int = int(ceil(float(maxi(control_count,1)) / float(columns)))
	# The choice row is real height. Give the world view less room while it is
	# on screen instead of letting a button land past the bottom of the window.
	var extra_rows: int = maxi(0, control_rows - (3 if size.x < 600 else 1))
	var available := Vector2(size.x, maxf(80,size.y - (326 if size.x<600 else 270) - extra_rows*52))
	var ratio := minf(available.x / WORLD.x, available.y / WORLD.y)
	# Whole-number enlargement; fractional reduction only when a phone cannot fit 640 pixels.
	var zoom := floorf(ratio) if ratio >= 1.0 else ratio
	view.size = WORLD * zoom
	view.position = Vector2(floorf((size.x - view.size.x) / 2), 83)
	update_render_density(zoom)
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
	buttons.columns = columns
	# Labels and font first: a Control never shrinks below the minimum size it
	# had when its size was assigned, and the desktop labels are wider.
	for button in buttons.get_children():
		button.add_theme_font_size_override("font_size", 13 if size.x < 600 else 17)
		var index: int = button.get_index()
		var choice_index: int = choice_buttons.find(button)
		if choice_index >= 0:
			var fate: Dictionary = RUSTLER_FATES[RUSTLER_CHOICES[choice_index]]
			button.text = "%d. %s" % [choice_index + 1, fate.short if size.x < 600 else fate.label]
		elif index < 7:
			button.text = ["Talk", "Lasso", "Shoot", "Companion", "Rest", "Reset", "Reload"][index] if size.x < 600 else ["Talk [E]", "Lasso [L]", "Shoot [F]", "Companion [Tab]", "Rest [G]", "Reset [F2]", "Reload [R]"][index]
		button.custom_minimum_size.x = 0 if size.x < 600 else 80
	buttons.position = Vector2(left, paper.position.y + paper.size.y + 9)
	buttons.size = Vector2(width, control_rows*46 + maxi(0,control_rows-1)*6)

func update_render_density(display_zoom: float) -> void:
	if not is_instance_valid(viewport): return
	# Render at display density instead of crushing detailed actors through 640x360.
	# Canvas scaling leaves positions, collisions, rope sockets and input in trail units.
	var density := clampi(int(floorf(display_zoom)),1,4) if is_finite(display_zoom) else 1
	viewport.size = Vector2i(WORLD) * density
	viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * density)

func world_input(event: InputEvent) -> void:
	if qa_mode: return
	# The cursor is the gun hand. Moving it aims; pressing rides. A player with
	# no pointer at all still aims, by facing, from the keys.
	if event is InputEventMouseMotion:
		aim_point = event.position / view.size * WORLD
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		target = event.position / view.size * WORLD
		aim_point = target
	if event is InputEventScreenTouch and event.pressed:
		target = event.position / view.size * WORLD
		aim_point = target

func _unhandled_key_input(event: InputEvent) -> void:
	if qa_mode: return
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_E or event.keycode == KEY_SPACE: interact()
	if event.keycode == KEY_L: lasso()
	if event.keycode == KEY_F: shoot()
	if event.keycode == KEY_R: reload()
	if event.keycode == KEY_F2: reset_room()
	if event.keycode == KEY_TAB: switch_companion()
	if event.keycode == KEY_G: rest_companion()
	if event.keycode == KEY_H and companion != null: companion.flirt()
	if event.keycode == KEY_F5 and companion != null: companion.save_game()
	if event.keycode == KEY_F9 and companion != null: companion.load_game()
	if event.keycode == KEY_K: get_tree().change_scene_to_file("res://scenes/kit_browser.tscn")
	for index in range(RUSTLER_CHOICES.size()):
		if event.keycode == KEY_1 + index: choose_rustler(RUSTLER_CHOICES[index])

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
	tick_gunfight(delta)
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
	var movement_speed := 28.0 if controlled==eleanor else ride_speed
	var cart_active: bool = companion != null and companion.cart != null and companion.cart.is_active()
	var controlled_velocity := direction * movement_speed
	if cart_active: controlled_velocity = companion.cart.drive_velocity(direction,delta)
	controlled.position = limit_position(controlled.position + controlled_velocity * delta,15.0 if cart_active else 0.0)
	var actual_motion: Vector2 = controlled.position - previous_position
	if cart_active:
		companion.cart.motion.collision(actual_motion / delta)
		direction = companion.cart.motion.heading
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
	if companion != null and companion.cart != null: companion.cart.tick(delta)
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
		message = "All six accounted for. +$60  " + eleanor_closing_line()
		if companion != null: companion.say_event("all_cattle_safe","room_complete")
	refresh()
	if qa_mode and not qa_done and elapsed > 0.3:
		qa_done = true
		run_qa()

func limit_position(at: Vector2, extra_clearance := 0.0) -> Vector2:
	var extra := clampf(extra_clearance,0,24) if is_finite(extra_clearance) else 0.0
	# The walkable ground is the location's, not this script's.
	var walkable: Rect2 = location.bounds
	var low := walkable.position+Vector2.ONE*extra
	var high := walkable.end-Vector2.ONE*extra
	var result := at.clamp(low, high)
	# All moving actors use the same solid footprints, including lassoed cattle.
	for footprint in blockers:
		var box := footprint.grow(extra)
		if not box.has_point(result): continue
		var exits := [Vector2(box.position.x-.1,result.y),Vector2(box.end.x+.1,result.y),Vector2(result.x,box.position.y-.1),Vector2(result.x,box.end.y+.1)]
		var closest := Vector2.INF
		for point in exits:
			if point != point.clamp(low,high): continue
			if result.distance_squared_to(point) < result.distance_squared_to(closest): closest = point
		result = closest
	for entry in solid_scenery:
		var center := Vector2(entry.position[0], entry.position[1])
		var delta := result - center
		var radius := float(entry.collision_radius) + 7.0 + extra
		if delta.length() < radius:
			var push := delta.normalized() if delta.length() > 0 else center.direction_to(WORLD / 2)
			var candidate := center + push * radius
			if candidate.x < low.x or candidate.x > high.x or candidate.y < low.y or candidate.y > high.y:
				candidate = center + center.direction_to(Vector2(320,187)) * radius
			result = candidate
	if companion != null and companion.mechanic != null: result = companion.mechanic.limit_motion(result,extra)
	return result.clamp(low, high)

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
	if companion != null and companion.cart != null and companion.cart.toggle_valve(0): return
	if companion != null and companion.mechanic.toggle_feed(): return
	if won and companion != null:
		companion.flirt()
		return
	if companion != null and companion.is_eleanor():
		message = "Eleanor steadies cattle with Talk. Switch back to the trail boss to use the lasso."
		refresh()
		return
	if won or player.action_time > 0: return
	# Rope or cartridges, not both. Reaching for the loop spills the reload.
	if reload_time > 0: reload_time = 0.0
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

## Every shot is resolved on the ground plan, where the props, the wagon and
## both men already live as positions. A round drawn from the shoulder but
## measured from the boots is how a boulder ends up stopping nothing.
## GUN_LIFT is presentation only: it raises the drawn line to gun height.
func muzzle() -> Vector2:
	return player.position

func rustler_muzzle() -> Vector2:
	return rustler.position

## Where the player is pointing. The pointer wins when there is one; otherwise
## the shot goes where he is facing. Nothing here looks at the rustler.
func aim_direction() -> Vector2:
	var origin := muzzle()
	if aim_point.is_finite() and origin.distance_to(aim_point) > 2.0:
		return origin.direction_to(aim_point)
	return facing.normalized() if facing.length() > 0 else Vector2.RIGHT

## Aim falls off with range instead of flipping a boolean at some radius, and a
## man who has been shot at shakes. Returned as a half-angle in radians.
func aim_spread(distance: float, shake: int) -> float:
	return deg_to_rad(1.6 + clampf(distance, 0.0, SHOT_RANGE) * 0.035 + float(shake) * 2.2)

## The first solid thing a round crosses, or INF. The wagon and every prop with
## a collision radius stop lead for whoever fired it.
func first_blocker(from: Vector2, to: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_distance := INF
	for entry in solid_scenery:
		var center := Vector2(entry.position[0], entry.position[1])
		var radius := float(entry.collision_radius)
		if radius <= 0: continue
		var contact := Geometry2D.segment_intersects_circle(from, to, center, radius)
		if contact < 0.0: continue
		var point: Vector2 = from.lerp(to, contact)
		if from.distance_to(point) < best_distance:
			best_distance = from.distance_to(point)
			best = point
	# Solid footprints stop a bullet the same way they stop a horse.
	for footprint in blockers:
		var corners := [footprint.position, Vector2(footprint.end.x, footprint.position.y),
			footprint.end, Vector2(footprint.position.x, footprint.end.y)]
		for index in range(4):
			var crossing = Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4])
			if crossing == null: continue
			var point: Vector2 = crossing
			if from.distance_to(point) < best_distance:
				best_distance = from.distance_to(point)
				best = point
	return best

## One bullet, resolved the same way for both shooters: a line from the muzzle,
## bent by the spread, cut short by the first solid thing, and a hit only if it
## passes within a body's width of the mark. There is no distance test.
func resolve_bullet(from: Vector2, aim: Vector2, spread: float, mark: Node2D, mark_offset: Vector2) -> Dictionary:
	var deviation := rng.randf_range(-spread, spread)
	var finish := from + aim.normalized().rotated(deviation) * SHOT_RANGE
	var result := {"origin": from, "end": finish, "hit": false, "blocked": false, "miss_by": INF}
	var wall := first_blocker(from, finish)
	if wall.is_finite():
		result.blocked = true
		result.end = wall
		finish = wall
	if is_instance_valid(mark):
		var center: Vector2 = mark.position + mark_offset
		var closest := Geometry2D.get_closest_point_to_segment(center, from, finish)
		result.miss_by = closest.distance_to(center)
		# A mark standing behind the wall is behind it, however near the wall
		# the round happened to strike.
		var short_of_cover: bool = not result.blocked or from.distance_to(closest) < from.distance_to(wall) - 0.5
		if result.miss_by <= BODY_RADIUS and short_of_cover:
			result.hit = true
			result.blocked = false
			result.end = closest
	return result

func reload() -> void:
	if companion != null and companion.is_eleanor(): return
	if won or reload_time > 0: return
	if ammo >= CYLINDER:
		message = "Cylinder is full."
		refresh()
		return
	reload_time = RELOAD_SECONDS
	message = "Thumbing rounds in. Keep something between you and him."
	refresh()

func shoot() -> void:
	if companion != null and companion.cart != null and companion.cart.toggle_valve(1): return
	if companion != null and companion.mechanic.toggle_vent(): return
	if companion != null and companion.is_eleanor(): return
	if won or shot_cooldown > 0 or player.action_time > 0: return
	if reload_time > 0:
		message = "Hands full of cartridges."
		refresh()
		return
	if ammo == 0:
		message = "Empty. Reload [R], or take him with the rope."
		refresh()
		return
	ammo -= 1
	shot_cooldown = 0.4
	pending_shot = true
	pending_aim = aim_direction()
	player.action("shoot", pending_aim)
	if not player.directional: on_player_action_event("fire")
	refresh()

## Reload, shake and the rustler's own trigger, all on the same clock. Called
## once a physics frame from play, and directly by the checks.
func tick_gunfight(delta: float) -> void:
	if reload_time > 0:
		reload_time = maxf(0.0, reload_time - delta)
		if reload_time == 0:
			ammo = CYLINDER
			message = "Six in the cylinder."
	if strain > 0:
		strain_time -= delta
		if strain_time <= 0:
			strain -= 1
			strain_time = STRAIN_SECONDS
			if strain == 0: message = "Hand is steady again."
	return_fire_time = maxf(0.0, return_fire_time - delta)
	if return_fire_time == 0 and is_instance_valid(return_fire): return_fire.clear_points()
	if won or not rustler_active or not is_instance_valid(rustler) or not is_instance_valid(player): return
	var sighting := first_blocker(rustler_muzzle(), muzzle())
	if rustler_tell > 0:
		rustler_tell -= delta
		rustler_aim = rustler_muzzle().direction_to(muzzle())
		# The warning line breaks against whatever the player puts in the way.
		if is_instance_valid(tell_line):
			tell_line.points = PackedVector2Array([rustler_muzzle() + GUN_LIFT, (sighting if sighting.is_finite() else muzzle()) + GUN_LIFT])
		if rustler_tell <= 0:
			rustler_tell = 0.0
			if is_instance_valid(tell_line): tell_line.clear_points()
			rustler_fires()
		return
	if is_instance_valid(tell_line): tell_line.clear_points()
	rustler_reload = maxf(0.0, rustler_reload - delta)
	if rustler_reload > 0: return
	if rustler_muzzle().distance_to(muzzle()) > RUSTLER_RANGE: return
	if sighting.is_finite(): return
	rustler_tell = TELL_SECONDS
	rustler_aim = rustler_muzzle().direction_to(muzzle())
	say_once("rustler_first_shot", rustler, "RUSTLER", "Ride off. I will not say it twice.", 1)

func rustler_fires() -> void:
	rustler_reload = RUSTLER_RELOAD
	var origin := rustler_muzzle()
	var bullet := resolve_bullet(origin, rustler_aim, aim_spread(origin.distance_to(muzzle()), 0), player, Vector2.ZERO)
	if is_instance_valid(return_fire): return_fire.points = PackedVector2Array([origin + GUN_LIFT, bullet.end + GUN_LIFT])
	return_fire_time = 0.12
	if bullet.hit:
		player_struck()
	elif bullet.blocked:
		message = "His round goes into the cover you picked. Good ground."
	else:
		message = "His round goes by you close enough to hear."

## What losing an exchange costs: a shaking hand for a while, the rope on the
## ground, the herd broken up again, and the strain of it. Never control, never
## the day itself. Every one of those is worked back in a minute.
func player_struck() -> void:
	player_hits += 1
	strain = mini(strain + 1, MAX_STRAIN)
	strain_time = STRAIN_SECONDS
	var lost_rope := false
	if rope_time > 0 and is_instance_valid(rope_target):
		lost_rope = true
		rope_time = 0.0
		rope_target = null
	if reload_time > 0:
		reload_time = 0.0
	for cow in cows:
		if not is_instance_valid(cow) or cow.secured: continue
		var away := player.position.direction_to(cow.position) if player.position.distance_to(cow.position) > 0.1 else Vector2.LEFT
		cow.position = limit_position(cow.position + away * rng.randf_range(16.0, 30.0))
	if companion != null: companion.state.add_madness("player", 10)
	message = "He puts one through your coat. The rope goes down, the herd breaks, and your hand will not sit still."
	if lost_rope: message = "Hit. You drop the rope, that steer is gone again, and your hand is shaking."
	if is_instance_valid(speech): say_once("player_struck", player, "TRAIL BOSS", "That one was close.", 1)
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
	shot_time = 0.12
	var origin := muzzle()
	var mark: Node2D = rustler if rustler_active and is_instance_valid(rustler) else null
	var range_to_mark := origin.distance_to(rustler.position) if is_instance_valid(rustler) else SHOT_RANGE
	var bullet := resolve_bullet(origin, pending_aim, aim_spread(range_to_mark, strain), mark, Vector2.ZERO)
	if bullet.hit:
		hits += 1
		message = "It takes him high and turns him. One more and he is done."
		if hits >= 2: rustler_surrenders("The second round puts him on his knees with his hands up. He waits on your word.")
	elif bullet.blocked:
		message = "The round hammers into cover and stops there."
	elif rustler_choice_pending():
		message = "He is already beaten and waiting. Say what happens to him."
	elif float(bullet.miss_by) < 26.0:
		message = "It cracks past his ear and he gets smaller behind that gun."
	else:
		message = "Wide. Steady the horse and get on him."
	if is_instance_valid(shot): shot.points = PackedVector2Array([origin + GUN_LIFT, bullet.end + GUN_LIFT])
	refresh()

func catch_rope(caught: Node2D) -> void:
	if not is_instance_valid(caught): return
	rope_catch_age = 0.0
	if player.position.distance_to(caught.position) > 140:
		message = "The loop falls short. Ride closer and cast again."
	elif caught == rustler and rustler_active:
		rope_target = caught
		rope_time = 0.7
		rustler_surrenders("Your loop takes his gun arm and he quits fighting it. He waits on your word.")
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

## He is beaten, not gone. rustler_active drops here so the herd can be
## gathered whatever the player decides, and the decision stays open until it
## is made. A player who shoots twice and rides off still finishes the room.
func rustler_surrenders(text: String) -> void:
	if not rustler_active: return
	if companion != null:
		companion.state.add_madness("player",8)
		companion.state.add_madness("rustler",20)
	say_once("rustler_retreat",rustler,"RUSTLER","All right! I am done. Do not shoot.",1)
	if is_instance_valid(rustler): rustler.action("yield_southwest",Vector2(-1,1))
	rustler_active = false
	rustler_surrendered = true
	rustler_tell = 0.0
	if is_instance_valid(tell_line): tell_line.clear_points()
	escaped = false
	message = text
	build_choice_buttons()
	refresh()

func rustler_choice_pending() -> bool:
	return rustler_surrendered and rustler_fate == ""

## Pure lookup so the outcomes can be compared without a running room.
static func rustler_fate_for(choice: String) -> Dictionary:
	if not RUSTLER_FATES.has(choice): return {}
	return (RUSTLER_FATES[choice] as Dictionary).duplicate(true)

## The one place a fate is applied. Returns false when there is nothing to
## decide, so a stray press cannot pay a second bounty.
func choose_rustler(choice: String) -> bool:
	if not rustler_choice_pending(): return false
	var fate := rustler_fate_for(choice)
	if fate.is_empty(): return false
	rustler_fate = choice
	cash += int(fate.cash)
	rustler_hired = bool(fate.hired)
	rustler_present = bool(fate.present)
	message = str(fate.journal)
	if is_instance_valid(speech) and is_instance_valid(rustler):
		say_once("rustler_fate_"+choice,rustler,"RUSTLER",str(fate.rustler_line),1)
	if is_instance_valid(rustler):
		if rustler_present:
			rustler.visible = true
			rustler.pose(false,Vector2.LEFT)
		else:
			# He walks himself off the ground on the existing exit path.
			escaped = true
	hide_choice_buttons()
	refresh()
	return true

## Observable outcome for saves, the bot and tests.
func rustler_outcome() -> Dictionary:
	return {"fate":rustler_fate,"hired":rustler_hired,"present":rustler_present,
		"surrendered":rustler_surrendered,"pending":rustler_choice_pending()}

func eleanor_closing_line() -> String:
	if rustler_fate != "": return str(RUSTLER_FATES[rustler_fate].eleanor_line)
	if rustler_surrendered: return "Eleanor: That rustler is still sitting out there waiting on you. Say your piece."
	return "Eleanor: %s is behind us." % location.display_name

func refresh() -> void:
	if not is_instance_valid(stats): return
	var gun_state := "  RELOADING" if reload_time > 0 else ("  SHAKING %d" % strain if strain > 0 else "")
	stats.text = "$%d    CATTLE %d/6    AMMO %d%s    %s" % [cash,secured_count(),ammo,gun_state,companion.clock_label() if companion != null else "Day 1 12:00"]
	objective.text = location.display_name.to_upper() + " COMPLETE" if won else "Talk to Eleanor  /  Clear the rustler  /  Gather six cattle east"
	if rustler_tell > 0:
		objective.text = "HE IS LINING UP ON YOU  /  Break his line or put the wagon between you"
	if rustler_choice_pending():
		objective.text = "RUSTLER BEATEN  /  Say what happens to him  /  Loose, law, or wages"
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
	print("STRIDE COMPARISON: three source sequences rendered over fixed ground")
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
		objective.text = "CAST REVIEW / " + review_direction + " / wind â†’ cast â†’ flight â†’ catch â†’ lead"
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
	# Close to pistol work, aim, and keep working him. Riding in under his gun
	# is the point; a scripted pair of shots from out of range never was.
	assert(await demo_ride(Vector2(496,172)))
	var fight_deadline := elapsed + 40.0
	while rustler_active and elapsed < fight_deadline:
		aim_point = rustler.position
		if ammo == 0 and reload_time <= 0: reload()
		shoot()
		await get_tree().create_timer(0.55).timeout
	aim_point = Vector2.INF
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
	# The fight, in the running room. A seeded generator so a pass here means
	# the geometry decided the shot and not the roll of the day.
	rng.seed = 20250910
	player.position = Vector2(505, 166)
	target = Vector2.INF
	var struck_deadline := elapsed + 8.0
	while player_hits == 0 and elapsed < struck_deadline:
		await get_tree().physics_frame
	assert(player_hits >= 1, "Standing in his open ground must actually cost the player")
	assert(strain > 0, "A hit must leave something behind on the player")
	# The boulder on the north approach breaks his line. Same test his own
	# trigger uses, so cover is not a separate story from the one he reads.
	player.position = Vector2(420, 106)
	await get_tree().physics_frame
	assert(first_blocker(rustler_muzzle(), muzzle()).is_finite(), "Cover must break his line of sight")
	player.position = Vector2(505, 166)
	await get_tree().create_timer(0.5).timeout
	var wasted: int = ammo
	aim_point = Vector2(90, 300)
	shoot()
	await get_tree().create_timer(0.2).timeout
	assert(ammo == wasted - 1 and hits == 0, "A shot aimed away from him spends a round and hits nothing")
	await get_tree().create_timer(0.4).timeout
	aim_point = rustler.position
	shoot()
	assert(ammo == wasted - 2)
	if player.directional: assert(hits == 0 and pending_shot, "Damage waits for the visible firing pose")
	await get_tree().create_timer(0.2).timeout
	assert(hits == 1 and not pending_shot, "An aimed shot inside pistol work connects")
	if player.directional: assert(str(player.art.animation).begins_with("shoot_"))
	await get_tree().create_timer(0.4).timeout
	aim_point = rustler.position
	shoot()
	await get_tree().create_timer(0.5).timeout
	assert(not rustler_active, "Two aimed rounds put him down")
	# Reloading is an act with a clock on it, not a free refill.
	ammo = 2
	reload()
	assert(reload_time > 0 and ammo == 2, "Reloading takes time before it gives rounds")
	await get_tree().create_timer(RELOAD_SECONDS + 0.2).timeout
	assert(ammo == CYLINDER and reload_time == 0, "A finished reload fills the cylinder")
	aim_point = Vector2.INF
	# The beaten rustler waits for a decision, and the decision is the player's.
	assert(rustler_surrendered and rustler_choice_pending(), "Two hits must end in a surrender, not a disappearance")
	assert(choice_row_visible() and choice_buttons.size() == RUSTLER_CHOICES.size(), "Every fate must be offered on screen")
	# The choice row adds a row of controls. Prove it fits a phone while it is
	# actually on screen, which the end-of-run phone check cannot: by then the
	# decision is made and the row is gone.
	var desktop_window := get_window().size
	get_window().size = Vector2i(390,844)
	await get_tree().create_timer(0.2).timeout
	var offered := 0
	for button in buttons.get_children():
		if not button.visible: continue
		offered += 1
		var rect: Rect2 = button.get_global_rect()
		if rect.end.x > size.x or rect.end.y > size.y:
			print("CHOICE ROW QA: ", button.text, " rect=", rect, " window=", size, " grid=", buttons.get_global_rect())
		assert(rect.end.x <= size.x and rect.end.y <= size.y, "The choice row must fit a phone window")
	assert(offered == 7 + RUSTLER_CHOICES.size(), "Standing controls and every fate must be reachable at once")
	get_window().size = desktop_window
	await get_tree().create_timer(0.2).timeout
	var cash_before_choice: int = cash
	assert(choose_rustler("nonsense") == false and rustler_choice_pending(), "Only authored fates resolve the encounter")
	assert(choose_rustler("law"), "The law option must resolve a pending encounter")
	assert(cash == cash_before_choice + 25 and rustler_present and not rustler_hired)
	assert(not choose_rustler("hire") and cash == cash_before_choice + 25, "A settled fate cannot be paid twice")
	assert(not choice_row_visible(), "The choice row leaves once the decision is made")
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
	assert(won and cash == 427, "Start 342, the county's 25 for the rustler, 60 for the herd")
	assert(message.contains(RUSTLER_FATES.law.eleanor_line), "Eleanor closes on the fate the player chose")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://room-complete.png")
	get_window().size = Vector2i(390,844)
	await get_tree().create_timer(0.3).timeout
	for width in [360,390]:
		get_window().size = Vector2i(width,844)
		await get_tree().create_timer(0.15).timeout
		var measured := 0
		for button in buttons.get_children():
			# A hidden button keeps its last rect and is not on screen; the
			# claim is about controls a thumb can reach.
			if not button.visible: continue
			measured += 1
			assert(button.get_global_rect().end.x <= size.x and button.get_global_rect().end.y <= size.y, "Phone controls must fit in the window")
		assert(measured >= 7, "Phone control check must actually measure the standing controls")
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
