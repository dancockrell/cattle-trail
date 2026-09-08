extends RefCounted
## Ines's three-landmark trail overlays authored spirit clues on Clear Fork.
const Actor = preload("res://scripts/actor.gd")
const SpiritClueView = preload("res://scripts/spirit_clue_view.gd")
const POSITION := Vector2(405,105)
const CLUES := {
	"bell_tracks": {"position":Vector2(445,285),"label":"southern trail grass","hint":"A bell rings over hoofprints that double back."},
	"cold_ashes": {"position":Vector2(340,90),"label":"northern trail stones","hint":"Smoke curls over stones cold enough to frost."},
	"wrong_shadow": {"position":Vector2(580,285),"label":"southeast scrub","hint":"A crow's shadow waits in the scrub. No bird overhead."}
}
var owner
var ines: Node2D
var clue_view: Node2D
var remarks: Dictionary = {}
var room:
	get: return owner.room
var state:
	get: return owner.ines_state

func _init(companion) -> void:
	owner = companion
	if FileAccess.file_exists("res://data/ines_banter.json"):
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ines_banter.json"))
		if source is Dictionary and source.get("events") is Array:
			for event in source.events:
				if event is Dictionary and event.get("id") is String and event.get("text") is String and event.get("speaker") == "INES":
					remarks[event.id] = event.text

func unlocked() -> bool:
	return owner.cart_adventure.status == "completed"

func _available() -> bool:
	return unlocked() and not owner.is_eleanor() and not owner.cart.is_active()

func _busy() -> bool:
	return room.player.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0

func _near_npc() -> bool:
	return room.player.position.distance_to(POSITION) <= 36

func notice_radius() -> float:
	return 24.0 + 12.0 * owner.field_perk("trail_hazard_notice")

func nearby_clue(radius: float) -> String:
	var nearest := ""
	var distance := radius
	for id in CLUES:
		var candidate: float = room.player.position.distance_to(CLUES[id].position)
		if candidate <= distance:
			nearest = id
			distance = candidate
	return nearest

func _say(beat: String) -> void:
	if is_instance_valid(ines) and remarks.has(beat):
		room.say_once("ines_"+beat,ines,"INES",remarks[beat],2)

func _changed(line: String) -> void:
	owner.tell(line)
	owner.save_game()

func _sync_view() -> void:
	if not unlocked():
		if is_instance_valid(ines): ines.visible = false
		if is_instance_valid(clue_view): clue_view.sync_visible(false)
		return
	if not is_instance_valid(ines):
		if not FileAccess.file_exists("res://assets/ines-art.json"): return
		var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ines-art.json"))
		if not bundle is Dictionary or not bundle.get("sprites",{}) is Dictionary or not bundle.sprites.get("ines_vale") is Dictionary: return
		ines = Actor.new()
		ines.configure("ines_vale",bundle.sprites.ines_vale)
		ines.position = POSITION
		room.actors.add_child(ines)
	ines.visible = true
	if not is_instance_valid(clue_view) and FileAccess.file_exists("res://assets/spirit-clues.json"):
		var clues: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/spirit-clues.json"))
		if clues is Dictionary:
			clue_view = SpiritClueView.new()
			clue_view.configure(clues,CLUES)
			room.world.add_child(clue_view)
			room.world.move_child(clue_view,room.actors.get_index())
	if is_instance_valid(clue_view): clue_view.sync_visible(state.met)

func sync_after_load() -> void:
	_sync_view()

func interact() -> bool:
	if not _available(): return false
	_sync_view()
	if _near_npc():
		if _busy(): return true
		if not state.met:
			state.meet()
			_say("intro")
			_changed("INES, 23 / Read the southern trail grass, northern trail stones, and southeast scrub [E]. Return here with all three clues.")
		elif not state.trail_completed:
			if state.complete_trail().get("ok",false):
				_say("trail_completed")
				_changed("Impossible trail understood. Ines offers to scout for the outfit. Talk [E] to accept her offer; romance is a separate choice.")
			else:
				owner.tell("INES / %d of 3 clues. Read the southern trail grass, northern trail stones, and southeast scrub [E], then return." % state.clues.size())
		elif state.recruitment != "recruited":
			if state.invite(true).get("ok",false):
				_say("recruited")
				_changed("You accept Ines's offer to join. She is assigned to camp. Talk [E] to assign field scouting; Flirt [H] is optional.")
		else:
			var assignment := "camp" if state.party_assignment == "field" else "field"
			state.assign_party(assignment)
			_changed("Ines is assigned to field scouting. Spirit Sense gives earlier warnings near the strange trail landmarks." if assignment == "field" else "Ines is assigned to camp. Her field warning bonus rests until you assign her to scout again.")
		return true
	if not state.met: return false
	var clue := nearby_clue(24.0)
	if clue.is_empty(): return false
	if _busy(): return true
	var result: Dictionary = state.discover_clue(clue)
	if result.get("ok",false):
		_say(clue)
		_changed("%s / %d of 3 clues. %s" % [CLUES[clue].hint,state.clues.size(),"Return to Ines on the northern trail." if state.clues.size()==3 else "Read the other strange landmarks [E]."])
	else:
		owner.tell("%s Already recorded; the trail yields no second reward." % CLUES[clue].hint)
	return true

func flirt() -> bool:
	if not _available() or not _near_npc(): return false
	if _busy(): return true
	if state.acknowledge_romance(true).get("ok",false):
		_say("romance_acknowledged")
		_changed("You ask Ines to spend the evening with you; she takes your hand. Your shared trail becomes the start of something personal.")
	else:
		owner.tell("Ines squeezes your hand: We already have an evening to look forward to." if state.romance_acknowledged else "Get to know Ines on her spirit trail and welcome her into the outfit first.")
	return true

func decorate_ui() -> void:
	_sync_view()
	if not _available(): return
	if _near_npc():
		var label := "Talk"
		if state.recruitment == "recruited":
			label = "Assign camp" if state.party_assignment == "field" else "Assign field"
		elif state.trail_completed: label = "Welcome"
		elif state.met and state.clues.size()==3: label = "Compare clues"
		room.buttons.get_child(0).text = label if room.size.x < 600 else label+" [E]"
		room.objective.text = "INES / "+("Scouting" if state.party_assignment == "field" else "Camp company") if state.recruitment == "recruited" else "INES / %d of 3 clues / Talk beside the northern trail" % state.clues.size()
		if not room.stats.text.contains("  INES "):
			room.stats.text += "  INES %d" % int(state.madness)
		return
	if not state.met: return
	var clue := nearby_clue(notice_radius())
	if clue.is_empty(): return
	room.objective.text = "SPIRIT TRAIL / "+CLUES[clue].hint
	if room.player.position.distance_to(CLUES[clue].position) <= 24:
		room.buttons.get_child(0).text = ("Revisit" if clue in state.clues else "Read clue") + ("" if room.size.x < 600 else " [E]")
	else:
		room.objective.text = "SPIRIT SENSE / "+CLUES[clue].hint+" Approach to read it."
