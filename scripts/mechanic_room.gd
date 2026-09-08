extends RefCounted
## Ada's optional first repair; keeps recruitment separate from romance.
const Actor = preload("res://scripts/actor.gd")
const ADA_POSITION := Vector2(230,145)
const MACHINE_POSITION := Vector2(280,165)
const WAGON := Vector2(148,127)
var owner
var room:
	get: return owner.room
var state:
	get: return owner.ada_state
var repair:
	get: return owner.ada_state.repair
var ada: Node2D
var machine: Node2D
var _decorated := false

func _init(companion) -> void:
	owner = companion

func _unlocked() -> bool:
	return owner.lantern_adventure.status == "completed"

func _near(point: Vector2, radius: float) -> bool:
	return _unlocked() and not owner.is_eleanor() and room.player.position.distance_to(point) <= radius

func near_machine() -> bool:
	return state.met and _near(machine.position if is_instance_valid(machine) else MACHINE_POSITION,50)

func _busy() -> bool:
	return room.player.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0

func _say(beat: String, line: String) -> void:
	if is_instance_valid(ada): room.say_once("ada_"+beat,ada,"ADA",line,2)

func _changed(message: String) -> void:
	_sync_view()
	owner.tell(message)
	owner.save_game()

func _sync_view() -> void:
	if not _unlocked():
		if is_instance_valid(ada): ada.visible = false
		if is_instance_valid(machine): machine.visible = false
		return
	if not is_instance_valid(ada) or not is_instance_valid(machine):
		if not FileAccess.file_exists("res://assets/mechanic-art.json"): return
		var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mechanic-art.json"))
		if not bundle is Dictionary or not bundle.get("sprites",{}).has("ada_mercer") or not bundle.sprites.has("steam_handler"): return
		if not is_instance_valid(ada):
			ada = Actor.new()
			ada.configure("ada_mercer",bundle.sprites.ada_mercer)
			ada.position = room.limit_position(ADA_POSITION)
			room.actors.add_child(ada)
		if not is_instance_valid(machine):
			machine = Actor.new()
			machine.configure("steam_handler",bundle.sprites.steam_handler)
			machine.position = room.limit_position(MACHINE_POSITION)
			room.actors.add_child(machine)
	ada.visible = true
	machine.visible = true
	var clip := "repaired" if repair.completed else "stalled"
	if machine.art.sprite_frames.has_animation(clip) and str(machine.art.animation) != clip:
		machine.art.play(clip)

func interact() -> bool:
	if not _unlocked() or owner.is_eleanor(): return false
	_sync_view()
	var ada_at: Vector2 = ada.position if is_instance_valid(ada) else ADA_POSITION
	if _near(ada_at,40) and (not state.met or repair.completed):
		if _busy(): return true
		if not state.met:
			state.meet()
			_say("met","Ada Mercer. My walker lost its regulator; there's a spare packed at your wagon.")
			_changed("Meet Ada / Retrieve the regulator from the wagon, then vent the walker before installing it.")
		elif state.recruitment != "recruited":
			var result: Dictionary = state.invite(true)
			if result.get("ok",false):
				_say("invited","A place in your outfit? You've seen my work. I'll take it.")
				_changed("Ada joins the outfit as your steam mechanic. Her repaired walker is ready.")
		else: owner.tell("Ada and her walker are ready to travel with the outfit.")
		return true
	if not state.met: return false
	if not repair.regulator_recovered and _near(WAGON,40):
		if _busy(): return true
		repair.recover_regulator()
		_changed("Spare regulator recovered from the packed wagon. Vent the walker to 5 or below before fitting it.")
		return true
	if not near_machine(): return false
	if _busy(): return true
	if repair.completed:
		owner.tell("The walker is repaired. Talk to Ada to invite her into the outfit.")
		return true
	if not repair.regulator_installed:
		var result: Dictionary = repair.install_regulator()
		if result.ok:
			_say("installed","A clean fit. Close the vent, build pressure, then shut the feed before testing.")
			_changed("Regulator fitted / Close vent, open feed to 30–50, close feed, then Test.")
		else:
			owner.tell("Retrieve the spare regulator from the wagon first." if not repair.regulator_recovered else "Close the feed and open the vent. Install only when pressure is 5 or below.")
	else:
		var result: Dictionary = repair.test_machine()
		if result.ok:
			_say("repaired","Listen to that. A steady heartbeat, and not a hoof out of place.")
			_changed("Walker repaired / Talk to Ada to invite her into the outfit.")
		else: owner.tell("For the test, close both valves and hold pressure at 30–50. Vent a fault down to 5 before retrying.")
	return true

func toggle_feed() -> bool:
	if not near_machine() or repair.completed: return false
	if _busy(): return true
	var result: Dictionary = repair.set_feed(not repair.feed_open)
	_changed(("Feed opened." if repair.feed_open else "Feed closed.") if result.ok else ("The machine is already repaired." if repair.completed else "Open the vent and lower pressure to 5 to clear the fault."))
	return true

func toggle_vent() -> bool:
	if not near_machine() or repair.completed: return false
	if _busy(): return true
	var result: Dictionary = repair.set_vent(not repair.vent_open)
	_changed(("Vent opened." if repair.vent_open else "Vent closed.") if result.ok else "The machine is already repaired.")
	return true

func tick(delta: float) -> void:
	_sync_view()
	if not _unlocked() or not state.met or repair.completed: return
	var was_faulted: bool = repair.fault
	repair.tick(delta)
	if repair.fault != was_faulted:
		if repair.fault:
			_say("fault","Feed's shut itself. Open the vent; we'll give it another try.")
			_changed("Pressure fault / Feed shut automatically. Open vent to lower pressure to 5.")
		else: _changed("Fault cleared. Your regulator is kept; close the vent when ready to retry.")

func decorate_ui() -> void:
	if _decorated:
		# Restore only labels still owned by this controller; preserve other contexts.
		for pair in [[0,"Talk [E]"],[1,"Flirt [H]"],[2,"Shoot [F]"]]:
			var button = room.buttons.get_child(pair[0])
			if button.text.begins_with("Feed") or button.text.begins_with("Vent") or button.text.begins_with("Install") or button.text.begins_with("Test") or button.text.begins_with("Invite") or button.text.begins_with("Retrieve"):
				button.text = pair[1]
		_decorated = false
	if not _unlocked() or owner.is_eleanor(): return
	var ada_at: Vector2 = ada.position if is_instance_valid(ada) else ADA_POSITION
	if repair.completed and state.recruitment != "recruited" and _near(ada_at,40):
		room.buttons.get_child(0).text = "Invite [E]"
		room.objective.text = "ADA / Walker repaired / Invite Ada into the outfit"
		_decorated = true
	elif state.met and not repair.regulator_recovered and _near(WAGON,40):
		room.buttons.get_child(0).text = "Retrieve [E]"
		room.objective.text = "ADA / Spare regulator packed in the wagon"
		_decorated = true
	elif near_machine() and not repair.completed:
		room.buttons.get_child(0).text = "Test [E]" if repair.regulator_installed else "Install [E]"
		room.buttons.get_child(1).text = "Feed [L]"
		room.buttons.get_child(2).text = "Vent [F]"
		room.objective.text = "WALKER / %.0f pressure / Feed %s / Vent %s / %s" % [repair.pressure,"open" if repair.feed_open else "closed","open" if repair.vent_open else "closed","FAULT: vent to 5" if repair.fault else ("Target 30–50; close both; Test" if repair.regulator_installed else "Vent to 5; fit regulator")]
		_decorated = true
	elif _near(ada_at,40) and not state.met:
		room.objective.text = "ADA MERCER / Talk to the mechanic beside her stalled walker"

func sync_after_load() -> void:
	_sync_view()

func limit_motion(point: Vector2, extra_clearance := 0.0) -> Vector2:
	if not _unlocked() or not is_instance_valid(machine): return point
	var away := point-machine.position
	var radius := 30.0+extra_clearance
	if away.length()>=radius: return point
	return machine.position+(away.normalized() if away.length()>0 else Vector2.DOWN)*radius
