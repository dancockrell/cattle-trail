extends RefCounted
## Generic room controller for the "meet, one flavor task, invite" shape (see
## simple_companion_state.gd). One instance per companion, built from a data
## row in simple_companion_catalog.gd -- no new .gd file needed to bring
## another same-shaped companion into the game.
const Actor = preload("res://scripts/actor.gd")
var owner
var config: Dictionary
var state
var actor: Node2D
var remarks: Dictionary = {}

func _init(companion, p_config: Dictionary, p_state) -> void:
	owner = companion
	config = p_config
	state = p_state
	var path: String = config.get("banter_path","")
	if path != "" and FileAccess.file_exists(path):
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if source is Dictionary and source.get("events") is Array:
			for event in source.events:
				if event is Dictionary and event.get("id") is String and event.get("text") is String and event.get("speaker") == config.get("speaker",""):
					remarks[event.id] = event.text

## "unlock_key" is a plain string looked up by owner.check_unlock() rather than
## a Callable stored in the config dict -- easier to unit test with a fake
## owner, and avoids Callable-in-Dictionary literal quirks.
func unlocked() -> bool:
	var key: String = config.get("unlock_key","")
	if key == "": return true
	return owner.check_unlock(key)

func _available() -> bool:
	return unlocked() and not owner.is_eleanor() and not owner.cart.is_active()

func _busy() -> bool:
	return owner.room.player.action_time > 0 or owner.room.rope_time > 0 or owner.room.rope_flight_time > 0

func _near_npc() -> bool:
	return owner.room.player.position.distance_to(config.position) <= float(config.get("near_radius",36.0))

func _say(beat_key: String) -> void:
	var event_id: String = config.get(beat_key,"")
	if event_id != "" and is_instance_valid(actor) and remarks.has(event_id):
		owner.room.say_once(config.id+"_"+event_id,actor,config.speaker,remarks[event_id],2)

func _changed(line: String) -> void:
	owner.tell(line)
	owner.save_game()

## Art-optional by design, matching Ada's/Ines's/Birdie's own encounters: the
## interaction works on position alone, and gains a visible actor only once a
## sprite bundle path is supplied and actually exists on disk.
func _sync_view() -> void:
	if not unlocked():
		if is_instance_valid(actor): actor.visible = false
		return
	var art_path: String = config.get("art_bundle_path","")
	var art_key: String = config.get("art_key","")
	if not is_instance_valid(actor):
		if art_path == "" or not FileAccess.file_exists(art_path): return
		var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string(art_path))
		if not bundle is Dictionary or not bundle.get("sprites",{}) is Dictionary or not bundle.sprites.get(art_key) is Dictionary: return
		actor = Actor.new()
		actor.configure(art_key,bundle.sprites[art_key])
		actor.position = config.position
		owner.room.actors.add_child(actor)
	actor.visible = true

func sync_after_load() -> void:
	_sync_view()

func interact() -> bool:
	if not _available(): return false
	_sync_view()
	if not _near_npc(): return false
	if _busy(): return true
	if not state.met:
		state.meet()
		_say("meet_beat")
		_changed(config.get("meet_message",""))
	elif not state.task_done:
		if state.complete_task().get("ok",false):
			_say("task_beat")
			_changed(config.get("task_message",""))
	elif state.recruitment != "recruited":
		if state.invite(true).get("ok",false):
			_say("recruited_beat")
			_changed(config.get("recruited_message",""))
	else:
		owner.tell(config.get("idle_message","She's glad to be along."))
	return true

func flirt() -> bool:
	if not _available() or not _near_npc(): return false
	if _busy(): return true
	if state.acknowledge_romance(true).get("ok",false):
		_say("romance_beat")
		_changed(config.get("romance_message",""))
	else:
		owner.tell(config.get("romance_repeat_message","She's already given you that answer.") if state.romance_acknowledged else config.get("romance_too_soon_message","Not yet. Finish getting to know her first."))
	return true

func decorate_ui() -> void:
	_sync_view()
	if not _available() or not _near_npc(): return
	var label := "Talk"
	if state.recruitment == "recruited": label = "Talk"
	elif state.task_done: label = "Invite"
	elif state.met: label = config.get("task_label","Continue")
	owner.room.buttons.get_child(0).text = label if owner.room.size.x < 600 else label+" [E]"
	owner.room.objective.text = config.id.to_upper() + " / " + ("Camp company" if state.recruitment == "recruited" else "Talk beside " + str(config.get("location_label","the camp edge")))
	var speaker: String = config.speaker
	var tag_prefix := "  " + speaker + " "
	if not owner.room.stats.text.contains(tag_prefix):
		owner.room.stats.text += tag_prefix + str(int(state.madness))
