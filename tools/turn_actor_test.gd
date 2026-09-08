extends SceneTree
const Actor = preload("res://scripts/actor.gd")
const Phase = preload("res://scripts/animation_phase.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var path := "user://turn-actor-fixture-%d.tres" % Time.get_ticks_usec()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	check(ResourceSaver.save(texture,path)==OK,"Fixture saved")
	var spec := {"texture":path,"anchor":[128,244],"pixels_per_world_unit":4,"directional":true,
		"frames":[{"atlas_rect":[0,0,256,256]},{"atlas_rect":[0,0,256,256]},
			{"atlas_rect":[0,0,256,256]},{"atlas_rect":[0,0,256,256]}],
		"clips":{"idle":{"frames":[0],"fps":1,"loop":true},
			"idle_east":{"frames":[0],"fps":1,"loop":true},
			"idle_north":{"frames":[3],"fps":1,"loop":true},
			"walk_east":{"frames":[0,1],"fps":8,"loop":true},
			"walk_north":{"frames":[2,3],"fps":8,"loop":true},
			"bridge":{"frames":[0,1,2],"fps":2,"loop":false},
			"talk":{"frames":[1],"fps":2,"loop":false}},
		"turn_transitions":{"east":{"north":{
			"idle":{"clip":"bridge","seconds":.12},"walk":{"clip":"bridge","seconds":.12}}}}}
	var actor = Actor.new()
	actor.configure("fixture",spec)
	actor.pose(false,Vector2.UP)
	check(actor.turn.active and actor.art.animation=="bridge" and not actor.art.is_playing(),"Finite turn clock owns bridge playback")
	actor._process(.05)
	check(actor.art.frame==1 and is_equal_approx(actor.art.frame_progress,.25),"Middle pose appears within declared turn duration despite slow clip FPS")
	actor._process(.05)
	check(actor.art.frame==2 and is_equal_approx(actor.art.frame_progress,.5),"Last bridge pose is not silently truncated")
	actor._process(.03)
	check(not actor.turn.active and actor.art.animation=="idle_north" and actor.art.is_playing(),"Completed turn resumes its real destination")
	actor.facing = "east"
	actor.art.play("walk_east")
	actor.art.set_frame_and_progress(1,.5)
	actor.pose(true,Vector2.UP,36)
	actor._process(.13)
	var phase := Phase.phase_at(actor.clip_durations("walk_north"),actor.art.frame,actor.art.frame_progress)
	check(actor.art.animation=="walk_north" and is_equal_approx(phase,.27),"Moving turn preserves and advances gait phase through a hitch")
	actor.facing = "east"
	actor.pose(false,Vector2.UP)
	actor._process(.02)
	actor.pose(false,Vector2.RIGHT)
	check(not actor.turn.active and actor.art.animation=="idle_east" and actor.art.is_playing(),"Retargeting to a missing bridge does not leave a frozen sprite")
	actor.pose(false,Vector2.UP)
	actor.action("talk")
	actor._process(.15)
	check(not actor.turn.active and actor.art.animation=="talk" and is_equal_approx(actor.action_time,.35),"Action interrupts turn without stale completion")
	var before: float = actor.action_time
	actor._process(NAN)
	check(actor.action_time==before,"Invalid elapsed time cannot poison action or turn clocks")
	actor.free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path))==OK,"Owned fixture removed")
	if failures==0: print("TURN ACTOR PASS: full bridge poses, authored timing, preserved gait, retarget, action interruption and finite clocks; no rendering")
	quit(0 if failures==0 else 1)
