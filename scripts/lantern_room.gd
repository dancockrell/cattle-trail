extends RefCounted
## Optional authored crossing controller. Tick after the base secured-cattle loop.
## Uses existing dry trail art: placement is a crossing, not a painted water ford.
const LanternView = preload("res://scripts/lantern_view.gd")
const WAGON := Vector2(148,127)
const CROSSING := Vector2(400,220)
const DESTINATION := Vector2(480,220)
const STARTS := [Vector2(316,188),Vector2(330,224),Vector2(310,260)]
var owner
var room:
	get: return owner.room
var adventure:
	get: return owner.lantern_adventure
var view: Node2D
var following := -1
var banter: Dictionary = {}

func _init(companion) -> void:
	owner = companion
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lantern_ford_banter.json"))
	if data is Dictionary and data.get("events") is Array:
		for event in data.events:
			if event is Dictionary and event.get("id") is String and event.get("text") is String and event.get("speaker") in ["ELEANOR","TRAIL BOSS"] and event.get("priority") in [0,1,2]:
				banter[event.id] = event

func _busy() -> bool:
	return room.player.action_time > 0 or room.eleanor.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0

func _sync_view() -> void:
	if adventure.stage == "not_started":
		if is_instance_valid(view): view.visible = false
		return
	if not is_instance_valid(view):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lantern-art.json"))
		if not data is Dictionary or not data.get("sprites",{}).has("crossing_spirit"): return
		view = LanternView.new()
		view.configure(data.sprites.crossing_spirit)
		view.position = CROSSING
		room.actors.add_child(view)
	view.visible = true
	view.sync_state(adventure)

func _say(event_id: String, beat: String) -> void:
	if not banter.has(event_id): return
	var event: Dictionary = banter[event_id]
	room.say_once("lantern_"+beat,room.player if event.speaker == "TRAIL BOSS" else room.eleanor,event.speaker,event.text,int(event.priority))

func _changed(message: String) -> void:
	_sync_view()
	owner.tell(message)
	owner.save_game()

func _apply_spirit_stress() -> void:
	var result: Dictionary = adventure.expose_to_spirit()
	if result.get("ok",false):
		owner.state.add_madness("eleanor",result.madness_delta)
		owner.save_game()

func switch_character() -> bool:
	if owner.state.adventure_status != "completed": return false
	if adventure.status == "completed": return false
	if _busy():
		owner.tell("Finish the current action before changing companions.")
		return true
	if adventure.status == "active":
		adventure.pause()
		following = -1
		room.player.position = room.limit_position(WAGON + Vector2(20,30))
		room.eleanor.position = room.limit_position(WAGON + Vector2(4,20))
		room.target = Vector2.INF
		room.player.pose(false)
		room.eleanor.pose(false)
		_say("retry","pause")
		_changed("Lantern crossing paused. Your checkpoint is kept; Companion at the wagon resumes it.")
		return true
	if room.player.position.distance_to(WAGON) > 55:
		owner.tell("Meet Eleanor at the wagon to carry the lantern to the crossing.")
		return true
	var result: Dictionary
	if adventure.status == "not_started":
		if room.cows.size() < 3: return true
		result = adventure.begin(owner.state.recruitment == "recruited",false,["0","1","2"])
		if result.ok:
			for index in range(3):
				room.cows[index].position = room.limit_position(STARTS[index])
				room.cows[index].pose(false)
			_say("lantern_taken","start")
	elif adventure.status == "failed":
		result = adventure.retry(owner.state.recruitment == "recruited")
	else:
		result = adventure.resume(owner.state.recruitment == "recruited")
	if result.get("ok",false):
		room.target = Vector2.INF
		room.player.pose(false)
		_changed("Playing Eleanor / Carry the lantern to the pale crossing spirit, then Talk.")
	return true

func interact() -> bool:
	if adventure.status != "active": return false
	if _busy(): return true
	match adventure.stage:
		"carry_lantern":
			if room.eleanor.position.distance_to(CROSSING) <= 45:
				_apply_spirit_stress()
				adventure.settle_spirit()
				_say("spirit_settled","spirit")
				_changed("The spirit listens. Talk again to begin guiding the three stranded cattle.")
			else: owner.tell("Walk to the pale spirit on the crossing and Talk.")
		"spirit_settled":
			if room.eleanor.position.distance_to(CROSSING) <= 50:
				adventure.begin_guiding()
				_say("crossing_started","guiding")
				_changed("Talk beside one stranded steer, then walk east across the trail with it.")
			else: owner.tell("Return to the crossing spirit to begin guiding.")
		"guide_cattle":
			if following >= 0:
				owner.tell("Your steer is following. Lead it east of the spirit; stay close until it arrives.")
				return true
			var nearest := 42.0
			for index in range(3):
				if str(index) in adventure.guided_cattle: continue
				var distance: float = room.eleanor.position.distance_to(room.cows[index].position)
				if distance < nearest:
					nearest = distance
					following = index
			owner.tell("A steer follows Eleanor. Walk east past the pale spirit to the open trail." if following >= 0 else "Walk beside a stranded steer and Talk to invite it to follow.")
		"return_to_wagon":
			if room.eleanor.position.distance_to(WAGON) > 55:
				owner.tell("All three are across. Return to the wagon and Talk.")
			else:
				var result: Dictionary = adventure.finish_at_wagon(true)
				if result.has("completion"):
					# Flag and trust enter the same outer snapshot; no romance mutation.
					owner.state.trust = mini(100,owner.state.trust + 10)
					room.player.position = room.limit_position(WAGON + Vector2(20,30))
					room.target = Vector2.INF
					_say("returned_to_wagon","complete")
					_changed("Lanterns at the Ford complete. Three cattle safely across; Eleanor's trust +10.")
	return true

func owns_cow(cow: Node2D) -> bool:
	return adventure.status=="active" and adventure.stage=="guide_cattle" and following>=0 and room.cows[following]==cow

func tick(delta: float) -> void:
	_sync_view()
	if adventure.status == "active" and adventure.stage == "carry_lantern" and room.eleanor.position.distance_to(CROSSING) < 80:
		_apply_spirit_stress()
		_say("spirit_agitated","approach")
	if adventure.status != "active" or adventure.stage != "guide_cattle" or following < 0 or delta <= 0: return
	var cow: Node2D = room.cows[following]
	var distance: float = cow.position.distance_to(room.eleanor.position)
	var before: Vector2 = cow.position
	if distance > 20 and distance < 110:
		var direction: Vector2 = cow.position.direction_to(room.eleanor.position)
		cow.position = room.limit_position(cow.position + direction * minf(25 * delta,distance - 20))
	var motion: Vector2 = cow.position - before
	cow.pose(motion.length() > 0.01,motion,motion.length()/delta)
	if cow.position.distance_to(DESTINATION) <= 35 and room.eleanor.position.distance_to(DESTINATION) <= 55:
		var result: Dictionary = adventure.guide_cattle(str(following))
		if result.ok:
			following = -1
			var count: int = adventure.guided_cattle.size()
			if count == 1: _say("first_cow_guided","guided_1")
			elif count == 3: _say("crossing_complete","guided_3")
			_changed("%d of 3 cattle across. %s" % [count,"Return to the wagon and Talk." if count == 3 else "Return for another stranded steer."])

func decorate_ui() -> void:
	if owner.state.adventure_status != "completed": return
	if adventure.status == "completed": return
	if adventure.stage == "not_started":
		room.objective.text = "LANTERNS AT THE FORD / Companion [Tab] at the wagon"
	elif adventure.status != "active":
		room.objective.text = "LANTERN CHECKPOINT KEPT / Companion [Tab] at wagon to resume"
	else:
		var hints := {"carry_lantern":"Talk to the crossing spirit", "spirit_settled":"Talk again to guide cattle", "guide_cattle":"Talk beside a steer; lead it east of the spirit", "return_to_wagon":"Return to wagon and Talk"}
		room.objective.text = "LANTERN / %d of 3 across / %s" % [adventure.guided_cattle.size(),hints.get(adventure.stage,"")]

func sync_after_load() -> void:
	# Following is transient. Saved physical positions and checkpoint remain exact;
	# Talk beside the same steer safely reacquires it without awarding progress.
	following = -1
	_sync_view()
