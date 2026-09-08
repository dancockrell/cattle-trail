extends SceneTree
const Sequence = preload("res://scripts/action_sequence.gd")
const Actor = preload("res://scripts/actor.gd")
var failures := 0
var events: Array = []
var replace_on_event := false
var subject

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func record_event(name: String) -> void:
	events.append({"name":name,"frame":subject.art.frame,"hand":subject.socket_world("hand",Vector2.ZERO)})
	if replace_on_event: subject.action("talk")

func _initialize() -> void:
	var clock = Sequence.new()
	check(clock.start([.1,.2,.05,.15],2),"Unequal authored holds accepted")
	var step: Dictionary = clock.advance(.15)
	check(step.frame==1 and is_equal_approx(step.progress,.25) and step.event_frame==-1,"Long second pose is sampled by elapsed time")
	check(not clock.start([.1,NAN],0) and is_equal_approx(clock.elapsed,.15),"Invalid replacement leaves current action intact")
	check(clock.advance(NAN).is_empty() and clock.advance(-1).is_empty(),"Invalid elapsed time does not advance action")
	step = clock.advance(.16)
	check(step.event_frame==2 and step.frame==2,"Release belongs to the third authored pose")
	step = clock.advance(10)
	check(step.done and step.event_frame==-1 and step.frame==3,"Completion does not wrap or repeat release")
	check(clock.advance(.1).is_empty(),"Finished action has no residual event")
	clock.start([.1,.2,.05,.15],2)
	step = clock.advance(5)
	check(step.done and step.event_frame==2,"A hitch across the entire clip still releases exactly once")
	clock.start([.1],0)
	check(clock.advance(0).event_frame==0,"First-frame actions release at time zero")
	clock.cancel()
	check(clock.advance(2).is_empty(),"Cancelled action cannot release later")

	# Real Actor dispatch, with a temporary non-rendered texture resource.
	var path := "user://action-sequence-fixture-%d.tres" % Time.get_ticks_usec()
	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	check(ResourceSaver.save(texture,path)==OK,"Fixture resource saved")
	var spec := {"texture":path,"anchor":[128,244],"pixels_per_world_unit":4,
		"frames":[{"atlas_rect":[0,0,256,256]},{"atlas_rect":[0,0,256,256]},
			{"atlas_rect":[0,0,256,256]},{"atlas_rect":[0,0,256,256]}],
		"clips":{"idle":{"frames":[0],"fps":1,"loop":true},
			"lasso":{"frames":[0,1,2,3],"fps":10,"loop":false,"durations":[.1,.2,.05,.15]},
			"talk":{"frames":[1],"fps":2,"loop":false}},
		"action_events":{"lasso":{"frame":2,"name":"rope_release"}},
		"frame_sockets":{"2":{"hand":[160,100]}}}
	subject = Actor.new()
	subject.configure("fixture",spec)
	subject.position = Vector2(200,150)
	subject.action_event.connect(record_event)
	subject.art.speed_scale = .35
	subject.action("lasso")
	check(not subject.art.is_playing() and subject.art.speed_scale==1,"One clock owns action playback, independent of walk speed")
	subject._process(.15)
	check(subject.art.frame==1 and events.is_empty(),"Visible pose and release agree before event")
	subject._process(.16)
	check(events.size()==1 and events[0].frame==2 and events[0].hand==Vector2(208,114),"Listeners see the exact release pose and scaled socket")
	subject._process(5)
	check(events.size()==1 and subject.action_time==0 and subject.art.animation=="idle" and subject.art.is_playing(),"Action returns to playing idle once")
	events.clear()
	subject.action("lasso")
	subject._process(5)
	check(events.size()==1 and events[0].frame==2,"Actor does not swallow release on an oversized frame")
	events.clear()
	subject.action("lasso")
	subject._process(.1)
	subject.action_time = 0
	subject.pose(false)
	subject._process(5)
	check(events.is_empty(),"Load/reset cancellation cannot emit the previous throw")
	replace_on_event = true
	subject.action("lasso")
	subject._process(5)
	check(subject.art.animation=="talk" and is_equal_approx(subject.action_time,.5),"An event-started replacement is not overwritten by the old completion")
	subject.free()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path))==OK,"Owned fixture removed")
	if failures==0: print("ACTION SEQUENCE PASS: weighted poses, hitch-safe release, exact sockets, cancellation, reentrant replacement and idle; no rendering")
	quit(0 if failures==0 else 1)
