extends RefCounted

const State = preload("res://scripts/companion_state.gd")
const Storage = preload("res://scripts/save_storage.gd")
const Snapshot = preload("res://scripts/room_snapshot.gd")
const Clock = preload("res://scripts/trail_clock.gd")
const LanternAdventure = preload("res://scripts/lantern_adventure.gd")
const LanternRoom = preload("res://scripts/lantern_room.gd")
const LanternEquipment = preload("res://scripts/lantern_equipment.gd")
const AdaState = preload("res://scripts/ada_companion.gd")
const SAVE_PATH := "user://clear-fork-save.json"
const BANTER_PATH := "res://data/eleanor_banter.json"
var room: Control
var state = State.new()
var lantern_adventure = LanternAdventure.new()
var ada_state = AdaState.new()
var lantern
var lantern_equipment: Sprite2D

func sync_lantern_equipment() -> void:
	if lantern_equipment != null: lantern_equipment.sync_state(lantern_adventure)
var minutes := 720.0
var banter: Dictionary = {}

func advance_time(delta: float) -> void:
	minutes = Clock.advance(minutes,delta)

func clock_label() -> String:
	return Clock.label(minutes)

func _init(owner_room: Control) -> void:
	room = owner_room
	if FileAccess.file_exists(BANTER_PATH):
		var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANTER_PATH))
		if content is Dictionary and content.get("events") is Array:
			for event in content.events:
				if not event is Dictionary: continue
				if not event.get("id") is String or not event.get("text") is String: continue
				if event.id.is_empty() or event.text.is_empty() or event.get("speaker") != "ELEANOR": continue
				var priority: Variant = event.get("priority")
				if not (priority is int or priority is float) or priority not in [0,1,2]: continue
				banter[event.id] = event
	lantern = LanternRoom.new(self)
	lantern_equipment = LanternEquipment.new()
	lantern_equipment.configure(room.eleanor,load("res://assets/lantern/carried_lantern.png"),Vector2(16,8))
	room.eleanor.add_child(lantern_equipment)

func say_event(event_id: String, saved_beat_id: String) -> void:
	# Existing beat IDs stay authoritative across old saves and content rewrites.
	if not banter.has(event_id): return
	var event: Dictionary = banter[event_id]
	room.say_once(saved_beat_id,room.eleanor,event.speaker,event.text,int(event.priority))

func is_eleanor() -> bool:
	return state.controlled_actor == "eleanor" or lantern_adventure.controlled_actor == "eleanor"

func active_actor() -> Node2D:
	return room.eleanor if is_eleanor() else room.player

func tell(line: String) -> void:
	room.message = line
	room.refresh()

func switch_character() -> void:
	if state.adventure_status=="completed" and lantern.switch_character(): return
	if state.recruitment != "recruited":
		tell("After gathering the herd, return to Eleanor and invite her along.")
		return
	if room.player.action_time > 0 or room.rope_time > 0:
		tell("Finish the cast or lead before changing characters.")
		return
	if is_eleanor():
		state.cancel_adventure()
	else:
		if state.adventure_status == "completed":
			tell("Eleanor's adventure is complete. Meet her at the wagon for shared rest.")
			return
		var resuming: bool = state.adventure_status == "paused"
		var result: Dictionary = state.begin_adventure(false)
		if result.get("ok",false) and resuming:
			say_event("return_from_pause","eleanor_resume")
	room.target = Vector2.INF
	room.player.pose(false)
	room.eleanor.pose(false)
	tell("Playing Eleanor, 24 / Walk to a restless steer and Talk to steady it." if is_eleanor() else "Playing the trail boss / Eleanor's progress is kept.")

func interact() -> bool:
	if lantern.interact(): return true
	if is_eleanor():
		if state.adventure_status == "active":
			var nearest: Node2D
			var distance := 40.0
			for index in range(room.cows.size()):
				if state.steadied_cattle.size() >= State.REQUIRED_CATTLE: break
				if str(index) in state.steadied_cattle: continue
				var cow: Node2D = room.cows[index]
				if room.eleanor.position.distance_to(cow.position) < distance:
					nearest = cow
					distance = room.eleanor.position.distance_to(cow.position)
			if nearest != null:
				var index: int = room.cows.find(nearest)
				state.steady_cattle(str(index))
				room.eleanor.action("talk", nearest.position-room.eleanor.position)
				var count: int = state.steadied_cattle.size()
				say_event("calm_"+str(count),"steady_"+str(index))
				tell("Eleanor steadied %d of 3 cattle. %s" % [count,"Return to the wagon and Talk." if count>=3 else "Find another restless steer."])
				save_game()
			elif state.steadied_cattle.size() >= 3 and room.eleanor.position.distance_to(Vector2(148,127))<55:
				state.finish_adventure()
				say_event("adventure_complete","eleanor_adventure")
				tell("Shared adventure complete. Eleanor trusts you. Rest together at the wagon; her Steady Company perk adds 3 recovery.")
				save_game()
			else:
				tell("Walk within a few steps of a restless steer and Talk." if state.steadied_cattle.size()<3 else "Return to the wagon and Talk to finish Eleanor's adventure.")
		else:
			tell("Eleanor's adventure is complete. Rest by the wagon, or switch back to the trail boss.")
		return true
	if room.won and room.player.position.distance_to(room.eleanor.position)<65:
		if state.recruitment != "recruited":
			state.recruit(true,true)
			say_event("recruited","eleanor_recruited")
			tell("Eleanor, 24, joins the outfit. Choose Companion [Tab] to play her short cattle-calming adventure.")
			save_game()
			return true
	return false

func rest_together() -> void:
	if lantern_adventure.status=="active":
		tell("Pause the lantern adventure and return to the wagon before resting.")
		return
	if active_actor().position.distance_to(Vector2(148,127))>55:
		tell("Return to the wagon for shared rest.")
		return
	var result: Dictionary = state.shared_rest(minutes,true)
	if result.get("ok",false):
		minutes += float(result.minutes_spent)
		say_event("shared_rest","shared_rest")
		tell("Tea and quiet company. Madness eased; Eleanor's Steady Company adds 3 recovery. Her story continues with your outfit.")
		save_game()
	else:
		if result.get("reason")=="rest_cooldown":
			tell("We've only just rested. Shared rest returns in %d trail minutes." % Clock.remaining_minutes(minutes,state.next_rest_minute))
		else:
			tell("Finish Eleanor's three-steer adventure first. Shared rest is available once each day.")

func flirt() -> void:
	if room.player.position.distance_to(room.eleanor.position)>55 or is_eleanor():
		tell("As the trail boss, meet Eleanor at the wagon for a quiet moment.")
		return
	var result: Dictionary = state.choose_romance(true)
	if result.get("ok",false):
		room.eleanor.action("talk",room.player.position-room.eleanor.position)
		say_event("mutual_flirt","mutual_flirt")
		tell("You choose to stay beside her. Eleanor's answering smile says enough. Relationship: courting. Shared rest remains available either way.")
		save_game()
	else:
		tell("Eleanor smiles: We already have a sunset to look forward to." if state.events.romance_chosen else "First share Eleanor's cattle-calming adventure. A little history makes a better invitation.")

func decorate_ui() -> void:
	room.stats.tooltip_text = Clock.label(minutes)
	if not room.won: return
	room.buttons.get_child(1).text = "Flirt" if room.size.x<600 else "Flirt [H]"
	if state.recruitment != "recruited":
		room.objective.text = "HERD SAFE / Return to Eleanor and invite her into the outfit"
	elif state.adventure_status != "completed":
		room.objective.text = "ELEANOR / %d of 3 steadied / %s" % [state.steadied_cattle.size(),"Playing Eleanor" if is_eleanor() else "Companion [Tab] to play"]
	else:
		var remaining := Clock.remaining_minutes(minutes,state.next_rest_minute)
		room.objective.text = "STEADY COMPANY / %s / %s" % [Clock.label(minutes),"Rest at wagon" if remaining==0 else "Rest in %dm" % remaining]
	room.stats.text = "$%d  HERD 6/6  MADNESS %d  ELEANOR %d" % [room.cash,int(state.madness.get("player",0)),int(state.madness.get("eleanor",0))]
	if lantern != null: lantern.decorate_ui()

func save_game(test_path := "") -> bool:
	if room.qa_mode and test_path.is_empty(): return false
	if room.player.action_time>0 or room.rope_time>0 or room.rope_flight_time>0: return false
	var cattle := []
	for cow in room.cows: cattle.append({"position":[cow.position.x,cow.position.y],"secured":cow.secured})
	var data := {"version":1,"companion":state.to_dict(),"minutes":minutes,"player":[room.player.position.x,room.player.position.y],"eleanor":[room.eleanor.position.x,room.eleanor.position.y],"cattle":cattle,"cash":room.cash,"ammo":room.ammo,"won":room.won,"talked":room.talked,"rustler_active":room.rustler_active,"hits":room.hits,"spoken_beats":room.spoken_beats}
	data["lantern_adventure"] = lantern_adventure.to_dict()
	data["ada_companion"] = ada_state.to_dict()
	return Storage.write(SAVE_PATH if test_path.is_empty() else test_path,data)

func load_game(test_path := "") -> bool:
	var path: String = SAVE_PATH if test_path.is_empty() else test_path
	if room.qa_mode and test_path.is_empty(): return false
	var data: Dictionary = Storage.read(path,Snapshot.validate)
	if data.is_empty(): return false
	var restored_ada = AdaState.new()
	if not restored_ada.load_dict(data.get("ada_companion",restored_ada.to_dict())): return false
	var restored_lantern = LanternAdventure.new()
	if not restored_lantern.load_dict(data.get("lantern_adventure",restored_lantern.to_dict())): return false
	if not state.load_dict(data.get("companion",{})): return false
	lantern_adventure = restored_lantern
	ada_state = restored_ada
	minutes = float(data.get("minutes",720))
	room.player.position = room.limit_position(Vector2(data.player[0],data.player[1]))
	room.eleanor.position = room.limit_position(Vector2(data.eleanor[0],data.eleanor[1]))
	for index in range(6):
		room.cows[index].position = room.limit_position(Vector2(data.cattle[index].position[0],data.cattle[index].position[1]))
		room.cows[index].secured = bool(data.cattle[index].secured)
	room.cash = int(data.get("cash",342))
	room.ammo = int(data.get("ammo",6))
	room.won = bool(data.get("won",false))
	room.talked = bool(data.get("talked",false))
	room.rustler_active = bool(data.get("rustler_active",true))
	room.rustler.visible = room.rustler_active
	room.escaped = false
	room.rustler.position = Vector2(550,164)
	room.rustler.action_time = 0
	room.rustler.turn.cancel()
	room.rustler.pose(false)
	room.hits = int(data.get("hits",0))
	room.spoken_beats = data.get("spoken_beats",{})
	room.speech.remaining = 0
	room.speech.visible = false
	room.speech.speaker = null
	room.pending_banter.clear()
	room.target = Vector2.INF
	room.rope_time = 0
	room.rope_flight_time = 0
	room.rope_target = null
	room.pending_lasso = null
	room.pending_shot = false
	room.shot_time = 0
	room.shot_cooldown = 0
	room.shot.clear_points()
	room.rope.clear_points()
	room.rope_far_wrap.clear_points()
	room.player.action_time = 0
	room.eleanor.action_time = 0
	room.player.turn.cancel()
	room.eleanor.turn.cancel()
	room.player.pose(false)
	room.eleanor.pose(false)
	lantern.sync_after_load()
	sync_lantern_equipment()
	tell("Outfit restored. Your companions and completed actions are remembered.")
	return true
