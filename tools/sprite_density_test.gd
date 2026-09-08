extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const Room = preload("res://scripts/room.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# A temporary texture resource exercises the real actor without importing art or a scene.
	var path := "user://density-fixture-%d.tres" % Time.get_ticks_usec()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	check(ResourceSaver.save(texture,path)==OK,"Fixture resource saved")
	var spec := {"texture":path,"anchor":[128,244],"pixels_per_world_unit":4,
		"frames":[{"atlas_rect":[0,0,256,256]},{"atlas_rect":[0,0,256,256]}],
		"clips":{"idle":{"frames":[0],"fps":1,"loop":true},
			"walk":{"frames":[0,1],"fps":6,"loop":true},
			"talk":{"frames":[0],"fps":2,"loop":false}},
		"clip_anchors":{"talk":[120,232]},"frame_sockets":{"0":{"hand":[160,100]}},
		"frame_anchors":{"1":[124,244]}}
	var actor = Actor.new()
	actor.configure("density_fixture",spec)
	actor.position = Vector2(200,150)
	check(actor.art.scale==Vector2(.25,.25),"Source density scales art only")
	check(actor.art.position==Vector2(-32,-61),"Default source pivot converts to world units")
	check(actor.art.to_global(Vector2(128,244))==actor.global_position,"Foot pivot remains actor origin")
	check(actor.socket_world("hand",Vector2.ZERO)==Vector2(208,114),"Authored source socket converts through density")
	check(actor.socket_world("missing",Vector2(8,-42))==Vector2(208,108),"Fallback sockets remain in world units")
	actor.pose(true,Vector2.LEFT,36)
	check(actor.art.scale==Vector2(-.25,.25),"Nondirectional reflection preserves density")
	check(actor.socket_world("hand",Vector2.ZERO)==Vector2(192,114),"Reflected hand remains registered")
	actor.art.set_frame_and_progress(1,.25)
	check(actor.art.position==Vector2(31,-61),"Per-frame foot anchor updates during animation")
	check(actor.art.to_global(Vector2(124,244))==actor.global_position,"Alternate contact stays at the world origin")
	actor.art.set_frame_and_progress(0,0)
	check(actor.art.position==Vector2(32,-61),"Frame without override restores the clip/default pivot")
	actor.action("talk",Vector2.LEFT)
	check(actor.art.position==Vector2(30,-58),"Special pivot respects reflection and density")
	actor.action_time = 0
	actor.pose(false)
	check(actor.art.position==Vector2(32,-61),"Leaving special clip restores default pivot")
	check(actor.position==Vector2(200,150),"Animation never rescales gameplay position")
	actor.free()
	spec.erase("pixels_per_world_unit")
	var legacy = Actor.new()
	legacy.configure("legacy_fixture",spec)
	check(legacy.art.scale==Vector2.ONE and legacy.art.position==Vector2(-128,-244),"Legacy metadata retains one source pixel per world unit")
	legacy.free()
	spec["pixels_per_world_unit"] = 4
	spec["directional"] = true
	spec.clips.erase("walk")
	spec.clips["idle_east"] = {"frames":[0],"fps":1,"loop":false}
	spec.clips["idle_northeast"] = {"frames":[1],"fps":1,"loop":false}
	var views = Actor.new()
	views.configure("static_endviews",spec)
	views.pose(false,Vector2(1,-1))
	check(views.art.animation=="idle_northeast","Authored static facing does not require a fake walk clip")
	views.pose(true,Vector2(1,-1),32)
	check(views.art.animation=="idle_northeast","Missing locomotion holds its real facing")
	views.free()
	var room = Room.new()
	room.viewport = SubViewport.new()
	root.add_child(room.viewport)
	room.view = TextureRect.new()
	room.view.size = Vector2(1280,720)
	for density in [1,2,4]:
		room.update_render_density(density)
		check(room.viewport.size==Vector2i(640,360)*density,"Viewport retains world aspect and display detail")
		check(room.viewport.canvas_transform*Vector2(120,90)==Vector2(120,90)*density,"Canvas density maps world coordinates to output pixels")
		var click := InputEventMouseButton.new()
		click.pressed = true
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = Vector2(600,280)
		room.world_input(click)
		check(room.target==Vector2(300,140),"Input mapping is independent of internal render density")
	room.update_render_density(.55)
	check(room.viewport.size==Vector2i(640,360),"Phone reduction keeps nearest source rendering")
	room.update_render_density(INF)
	check(room.viewport.size==Vector2i(640,360),"Invalid display density falls back safely")
	room.view.free()
	room.viewport.free()
	room.free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path))==OK,"Owned fixture removed")
	if failures==0: print("SPRITE DENSITY PASS: detailed and legacy scales, pivots, reflection, sockets, display density and input; no rendering")
	quit(0 if failures==0 else 1)
