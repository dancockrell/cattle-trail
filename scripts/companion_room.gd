extends RefCounted

const State = preload("res://scripts/companion_state.gd")
const SAVE_PATH := "user://clear-fork-save.json"
var room: Control
var state = State.new()
var minutes := 720.0

func _init(owner_room: Control) -> void:
	room = owner_room

func is_eleanor() -> bool:
	return state.controlled_actor == "eleanor"

func active_actor() -> Node2D:
	return room.eleanor if is_eleanor() else room.player

func tell(line: String) -> void:
	room.message = line
	room.refresh()

func switch_character() -> void:
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
		state.begin_adventure(false)
	room.target = Vector2.INF
	room.player.pose(false)
	room.eleanor.pose(false)
	tell("Playing Eleanor, 24 / Walk to a restless steer and Talk to steady it." if is_eleanor() else "Playing the trail boss / Eleanor's progress is kept.")

func interact() -> bool:
	if is_eleanor():
		if state.adventure_status == "active":
			var nearest: Node2D
			var distance := 40.0
			for index in range(room.cows.size()):
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
				room.say_once("steady_"+str(index),room.eleanor,"ELEANOR",["Easy. The dead can wait their turn.","There. Much better company without the snorting.","Three quiet souls. Now I could use some tea."][mini(count-1,2)],1)
				tell("Eleanor steadied %d of 3 cattle. %s" % [count,"Return to the wagon and Talk." if count>=3 else "Find another restless steer."])
				save_game()
			elif state.steadied_cattle.size() >= 3 and room.eleanor.position.distance_to(Vector2(148,127))<55:
				state.finish_adventure()
				room.say_once("eleanor_adventure",room.eleanor,"ELEANOR","You kept the kettle warm for me? I could get used to that.",2)
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
			room.say_once("eleanor_recruited",room.eleanor,"ELEANOR","A place in your outfit? Yes. Someone has to keep you sensible.",2)
			tell("Eleanor, 24, joins the outfit. Choose Companion [Tab] to play her short cattle-calming adventure.")
			save_game()
			return true
	return false

func rest_together() -> void:
	if active_actor().position.distance_to(Vector2(148,127))>55:
		tell("Return to the wagon for shared rest.")
		return
	var result: Dictionary = state.shared_rest(minutes,true)
	if result.get("ok",false):
		minutes += 30
		room.say_once("shared_rest",room.eleanor,"ELEANOR","Sit beside me. For once, the world can look after itself.",2)
		tell("Tea and quiet company. Madness eased; Eleanor's Steady Company adds 3 recovery. Her story continues with your outfit.")
		save_game()
	else:
		tell("Finish Eleanor's three-steer adventure first. Shared rest is available once each day.")

func flirt() -> void:
	if room.player.position.distance_to(room.eleanor.position)>55 or is_eleanor():
		tell("As the trail boss, meet Eleanor at the wagon for a quiet moment.")
		return
	var result: Dictionary = state.choose_romance(true)
	if result.get("ok",false):
		room.eleanor.action("talk",room.player.position-room.eleanor.position)
		room.say_once("mutual_flirt",room.eleanor,"ELEANOR","Stay for the sunset. And yes, that was an invitation.",2)
		tell("You choose to stay beside her. Eleanor's answering smile says enough. Relationship: courting. Shared rest remains available either way.")
		save_game()
	else:
		tell("Eleanor smiles: We already have a sunset to look forward to." if state.events.romance_chosen else "First share Eleanor's cattle-calming adventure. A little history makes a better invitation.")

func decorate_ui() -> void:
	if not room.won: return
	room.buttons.get_child(1).text = "Flirt" if room.size.x<600 else "Flirt [H]"
	if state.recruitment != "recruited":
		room.objective.text = "HERD SAFE / Return to Eleanor and invite her into the outfit"
	elif state.adventure_status != "completed":
		room.objective.text = "ELEANOR / %d of 3 steadied / %s" % [state.steadied_cattle.size(),"Playing Eleanor" if is_eleanor() else "Companion [Tab] to play"]
	else:
		room.objective.text = "STEADY COMPANY / Adventure complete / Shared rest at the wagon"
	room.stats.text = "$%d  HERD 6/6  MADNESS %d  ELEANOR %d" % [room.cash,int(state.madness.get("player",0)),int(state.madness.get("eleanor",0))]

func save_game(test_path := "") -> bool:
	if room.qa_mode and test_path.is_empty(): return false
	if room.player.action_time>0 or room.rope_time>0 or room.rope_flight_time>0: return false
	var cattle := []
	for cow in room.cows: cattle.append({"position":[cow.position.x,cow.position.y],"secured":cow.secured})
	var data := {"version":1,"companion":state.to_dict(),"minutes":minutes,"player":[room.player.position.x,room.player.position.y],"eleanor":[room.eleanor.position.x,room.eleanor.position.y],"cattle":cattle,"cash":room.cash,"ammo":room.ammo,"won":room.won,"talked":room.talked,"rustler_active":room.rustler_active,"hits":room.hits,"spoken_beats":room.spoken_beats}
	var file := FileAccess.open(SAVE_PATH if test_path.is_empty() else test_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	return true

func load_game(test_path := "") -> bool:
	var path: String = SAVE_PATH if test_path.is_empty() else test_path
	if (room.qa_mode and test_path.is_empty()) or not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0)!=1 or not data.get("cattle",[]) is Array or data.cattle.size()!=6: return false
	for key in ["player","eleanor"]:
		if not valid_point(data.get(key)): return false
	for cow in data.cattle:
		if not cow is Dictionary or not valid_point(cow.get("position")) or not cow.get("secured") is bool: return false
	for key in ["cash","ammo","minutes","hits"]:
		if not data.get(key) is float and not data.get(key) is int: return false
		if not is_finite(float(data[key])) or float(data[key])<0: return false
	for key in ["won","talked","rustler_active"]:
		if not data.get(key) is bool: return false
	if not data.get("spoken_beats") is Dictionary: return false
	if not state.load_dict(data.get("companion",{})): return false
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
	room.hits = int(data.get("hits",0))
	room.spoken_beats = data.get("spoken_beats",{})
	room.target = Vector2.INF
	room.rope_time = 0
	room.rope_flight_time = 0
	room.rope_target = null
	room.pending_lasso = null
	room.pending_shot = false
	room.player.action_time = 0
	room.eleanor.action_time = 0
	room.player.pose(false)
	room.eleanor.pose(false)
	tell("Outfit restored. Your companions and completed actions are remembered.")
	return true

func valid_point(value) -> bool:
	if not value is Array or value.size()!=2: return false
	for coordinate in value:
		if not coordinate is int and not coordinate is float: return false
		if not is_finite(float(coordinate)): return false
	return true
