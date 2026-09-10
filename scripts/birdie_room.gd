extends RefCounted
## Birdie's stationary camp-edge encounter: meet, hear her sing, invite. No puzzle --
## the point is the conversation, not a challenge. Uses existing dry-camp ground;
## no new scenery art is required for this pass.
const Actor = preload("res://scripts/actor.gd")
const POSITION := Vector2(110,180)
var owner
var birdie: Node2D
var remarks: Dictionary = {}
var room:
	get: return owner.room
var state:
	get: return owner.birdie_state

func _init(companion) -> void:
	owner = companion
	if FileAccess.file_exists("res://data/birdie_banter.json"):
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/birdie_banter.json"))
		if source is Dictionary and source.get("events") is Array:
			for event in source.events:
				if event is Dictionary and event.get("id") is String and event.get("text") is String and event.get("speaker") == "BIRDIE":
					remarks[event.id] = event.text

## Gated behind Ines's trail so new companions surface one at a time.
func unlocked() -> bool:
	return owner.ines_state.recruitment == "recruited"

func _available() -> bool:
	return unlocked() and not owner.is_eleanor() and not owner.cart.is_active()

func _busy() -> bool:
	return room.player.action_time > 0 or room.rope_time > 0 or room.rope_flight_time > 0

func _near_npc() -> bool:
	return room.player.position.distance_to(POSITION) <= 36

func _say(beat: String) -> void:
	if is_instance_valid(birdie) and remarks.has(beat):
		room.say_once("birdie_"+beat,birdie,"BIRDIE",remarks[beat],2)

func _changed(line: String) -> void:
	owner.tell(line)
	owner.save_game()

## Art-optional by design, matching Ines's and Ada's pattern: the encounter works
## on position alone, and gains a visible actor only once a sprite bundle exists.
func _sync_view() -> void:
	if not unlocked():
		if is_instance_valid(birdie): birdie.visible = false
		return
	if not is_instance_valid(birdie):
		if not FileAccess.file_exists("res://assets/birdie-art.json"): return
		var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/birdie-art.json"))
		if not bundle is Dictionary or not bundle.get("sprites",{}) is Dictionary or not bundle.sprites.get("birdie_calloway") is Dictionary: return
		birdie = Actor.new()
		birdie.configure("birdie_calloway",bundle.sprites.birdie_calloway)
		birdie.position = POSITION
		room.actors.add_child(birdie)
	birdie.visible = true

func sync_after_load() -> void:
	_sync_view()

func interact() -> bool:
	if not _available(): return false
	_sync_view()
	if not _near_npc(): return false
	if _busy(): return true
	if not state.met:
		state.meet()
		_say("intro")
		_changed("BIRDIE, 20 / Talk again to hear her sing.")
	elif not state.sang:
		if state.sing().get("ok",false):
			_say("song")
			_changed("The camp is a little easier for it. Talk to Birdie to offer her a place.")
	elif state.recruitment != "recruited":
		if state.invite(true).get("ok",false):
			_say("recruited")
			_changed("Birdie joins the outfit as camp cook. Rest beside her adds to camp recovery; Flirt is a separate choice.")
	else:
		owner.tell("Birdie hums something half-finished and keeps at the fire.")
	return true

func flirt() -> bool:
	if not _available() or not _near_npc(): return false
	if _busy(): return true
	if state.acknowledge_romance(true).get("ok",false):
		_say("romance_acknowledged")
		_changed("You sit with her past the last verse. Birdie leans into the quiet after, and does not pull away.")
	else:
		owner.tell("Birdie smiles: that song's already yours." if state.romance_acknowledged else "Hear her sing and welcome her into the outfit first.")
	return true

func decorate_ui() -> void:
	_sync_view()
	if not _available() or not _near_npc(): return
	var label := "Talk"
	if state.recruitment == "recruited": label = "Talk"
	elif state.sang: label = "Invite"
	elif state.met: label = "Ask her to sing"
	room.buttons.get_child(0).text = label if room.size.x < 600 else label+" [E]"
	room.objective.text = "BIRDIE / " + ("Camp company" if state.recruitment == "recruited" else "Talk beside the camp edge")
	if not room.stats.text.contains("  BIRDIE "):
		room.stats.text += "  BIRDIE %d" % int(state.madness)
