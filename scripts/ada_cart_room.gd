extends RefCounted
## A short playable outing: route three valves, drive the trail, return together.
const Actor = preload("res://scripts/actor.gd")
const Motion = preload("res://scripts/cart_motion.gd")
var motion = Motion.new()
const PARK := Vector2(220,280)
const STOPS := [Vector2(330,300), Vector2(445,300), Vector2(405,235)]
var owner
var vehicle: Node2D
var markers: Array[Sprite2D] = []
var saved_position := PARK
var room:
	get: return owner.room
var state:
	get: return owner.cart_adventure

func _init(companion): owner = companion
func is_active() -> bool: return state.status == "active"
func unlocked() -> bool: return owner.ada_state.recruitment == "recruited"
func movement_speed() -> float: return 32.0 if state.stage in ["drive", "return_to_camp"] else 0.0
func drive_velocity(input: Vector2, delta: float) -> Vector2:
	if not is_active() or movement_speed()==0:
		motion.stop()
		return Vector2.ZERO
	return motion.step(input,delta)
func position_for_save() -> Vector2: return vehicle.position if is_active() and is_instance_valid(vehicle) else saved_position
func sync_after_load():
	motion.stop()
	sync_view()
	if is_active() and is_instance_valid(vehicle): vehicle.position = saved_position
func _near() -> bool: return room.player.position.distance_to(PARK) <= 50
func _busy() -> bool: return room.player.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0
func _say(beat: String, line: String):
	if is_instance_valid(vehicle): room.say_once("ada_cart_"+beat,vehicle,"ADA",line,2)
func _changed(line: String):
	sync_view()
	owner.tell(line)
	owner.save_game()

func sync_view():
	if not unlocked():
		if is_instance_valid(vehicle): vehicle.visible = false
		for marker in markers: marker.visible = false
		room.player.visible = true
		if is_instance_valid(owner.mechanic.ada): owner.mechanic.ada.position = Vector2(230,145)
		return
	if not is_instance_valid(vehicle):
		var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ada-cart-art.json"))
		if not source is Dictionary: return
		vehicle = Actor.new()
		vehicle.configure("ada_cart",source.sprites.ada_cart)
		vehicle.position = saved_position
		room.actors.add_child(vehicle)
		for point in STOPS:
			var marker := Sprite2D.new()
			marker.texture = load("res://assets/lantern/carried_lantern.png")
			marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			marker.position = point
			marker.offset = Vector2(0,-10)
			room.actors.add_child(marker)
			markers.append(marker)
	vehicle.visible = true
	room.player.visible = not is_active()
	if is_instance_valid(owner.mechanic.ada):
		owner.mechanic.ada.visible = not is_active()
		owner.mechanic.ada.position = PARK+Vector2(-32,-2) if state.status!="not_started" else Vector2(230,145)
	if not is_active():
		vehicle.position = PARK
		vehicle.art.play("parked")
	elif state.stage not in ["drive", "return_to_camp"]: vehicle.pose(false)
	for i in markers.size():
		markers[i].visible = is_active() and state.stage == "drive" and i == state.checkpoints.size()

func interact() -> bool:
	if not unlocked(): return false
	if not is_active():
		if not _near() or owner.is_eleanor(): return false
		if state.status == "completed":
			owner.tell("A good ride. Ada waits beside the cart; choose Kiss if you want that moment together.")
			return true
		if _busy(): return true
		sync_view()
		if not is_instance_valid(vehicle): return true
		var result: Dictionary = state.resume(true,false) if state.status == "paused" else state.begin(true,false)
		if not result.ok: return true
		motion.stop()
		vehicle.position = saved_position
		room.target = Vector2.INF
		_say("board","You get the second seat. Try to look impressed before we start moving.")
		_changed("PLAYING ADA / Inspect the regulator [E]. Tab pauses the outing.")
		return true
	if state.stage == "inspect":
		state.inspect()
		_say("valves","Outer feeds open. Middle bypass shut. Simple—until somebody improves it.")
		_changed("ROUTE PRESSURE / Open A and C; close B. L toggles A, F toggles B, G toggles C. E tests.")
	elif state.stage == "route_pressure":
		var result: Dictionary = state.confirm_routing()
		if result.ok:
			room.target = Vector2.INF
			_say("ready","That's our heartbeat. Follow the lanterns. I'll do the steering; you enjoy the view.")
			_changed("DRIVE / Playing Ada. Follow each brass lantern, then return to the cart stop.")
		else:
			owner.ada_state.madness = minf(100,owner.ada_state.madness+float(result.get("strain_delta",0)))
			_changed("A sharp hiss, nothing broken. Open the two outside feeds; shut the middle bypass.")
	elif state.stage == "drive":
		motion.stop()
		room.target = Vector2.INF
		owner.tell("Cart braked. Steer toward the next lantern when you're ready.")
	elif state.stage == "return_to_camp":
		var result: Dictionary = state.finish_at_camp(vehicle.position.distance_to(PARK)<=32)
		if result.ok:
			owner.ada_state.trust = mini(100,owner.ada_state.trust+15)
			motion.stop()
			saved_position = PARK
			room.player.position = PARK+Vector2(0,20)
			room.target = Vector2.INF
			_say("home","There. Two seats, one regulator, and not a single apology to the laws of nature.")
			_changed("OUTING COMPLETE / Ada +15 trust. Shared adventure complete; an optional Kiss is a separate choice.")
		else: owner.tell("Bring the cart back to its stop on the lower trail, then Talk.")
	return true

func toggle_valve(index: int) -> bool:
	if not is_active(): return false
	if state.stage == "route_pressure":
		state.toggle_valve(index)
		_changed("Valve %s %s." % ["ABC"[index],"open" if state.valves[index] else "closed"])
	return true

func pause_or_resume() -> bool:
	if is_active():
		motion.stop()
		saved_position = position_for_save()
		state.pause()
		room.player.position = PARK+Vector2(0,20)
		room.target = Vector2.INF
		_changed("Cart outing paused. Board at the lower-trail stop to resume your route.")
		return true
	if unlocked() and state.status == "paused" and _near(): return interact()
	return false

func flirt() -> bool:
	if is_active(): return true
	if not unlocked() or state.status != "completed" or not _near(): return false
	var result: Dictionary = state.choose_romance(true)
	if result.ok:
		owner.ada_state.trust = mini(100,owner.ada_state.trust+5)
		_say("kiss","One more thing before we call that a successful test drive.")
		_changed("You lean closer; Ada meets you with a quick, laughing kiss. The outing is remembered.")
	else: owner.tell("Ada grins at the memory of your ride. That moment is already yours.")
	return true

func tick(_delta: float):
	sync_view()
	if not is_active() or state.stage != "drive" or not is_instance_valid(vehicle): return
	var index: int = state.checkpoints.size()
	if index < STOPS.size() and vehicle.position.distance_to(STOPS[index])<=24:
		var result: Dictionary = state.checkpoint_arrived(index)
		if result.ok:
			_say("stop%d"%index,["See? Perfectly civilized machinery.","If the kettle whistles, pretend that was deliberate.","Now home. We should stop while we're still excellent at this."][index])
			_changed("Lantern %d of 3 reached. %s" % [index+1,"Return to the lower-trail cart stop and Talk." if index==2 else "Follow the next lantern."])

func decorate_ui():
	# The companion UI restores its base labels before this last decorator.
	if not unlocked(): return
	if is_active():
		room.stats.text = "$%d  HERD 6/6  MADNESS %d  ADA %d" % [room.cash,int(owner.state.madness.player),int(owner.ada_state.madness)]
		room.buttons.get_child(0).text = "Test [E]" if state.stage=="route_pressure" else "Inspect [E]" if state.stage=="inspect" else "Finish [E]"
		room.buttons.get_child(3).text = "Pause [Tab]"
		for index in [1,2,4]: room.buttons.get_child(index).disabled = state.stage!="route_pressure"
		if state.stage=="drive":
			room.buttons.get_child(0).text = "Brake [E]"
		if state.stage=="route_pressure":
			for pair in [[1,0,"A [L]"],[2,1,"B [F]"],[4,2,"C [G]"]]:
				room.buttons.get_child(pair[0]).text = pair[2]+(": Open" if state.valves[pair[1]] else ": Closed")
		room.objective.text = "ADA / "+("Outer feeds OPEN; middle bypass CLOSED" if state.stage=="route_pressure" else "Inspect the regulator" if state.stage=="inspect" else "Return to cart stop / Talk" if state.stage=="return_to_camp" else "Drive to lantern %d/3"%(state.checkpoints.size()+1))
	elif _near():
		room.buttons.get_child(0).text = "Board [E]" if state.status!="completed" else "Talk [E]"
		if state.status=="completed" and not state.romance_chosen: room.buttons.get_child(1).text = "Kiss [H]"
		room.objective.text = "TWO SEATS, ONE REGULATOR / "+("A quiet moment together" if state.status=="completed" else "Board Ada's cart")
