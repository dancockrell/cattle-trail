extends RefCounted
## Generic room controller for the "meet, one flavor task, invite" shape (see
## simple_companion_state.gd). One instance per companion, built from a data
## row in simple_companion_catalog.gd -- no new .gd file needed to bring
## another same-shaped companion into the game.
const Actor = preload("res://scripts/actor.gd")
const Clock = preload("res://scripts/trail_clock.gd")

## What a companion wants before her task beat will fire. The row picks one
## with "task_kind" and puts the numbers beside it, so a companion who is
## harder to please is still a row and a banter file, not a new script.
##   "talk"   nothing. The original shape, kept for the quiet ones.
##   "herd"   "task_herd" head secured in the east gathering.
##   "clock"  the trail clock past "task_after_minutes" (absolute, so waiting
##            always works and a satisfied gate never closes again).
##   "friend" "task_friend" recruited first, by catalog id or unlock key.
##   "spend"  "task_cash" out of the player's pocket, taken on completion.
## Ammunition is deliberately not a price: room.gd never gives a round back,
## so a player who emptied the pistol would be stranded on that companion.
const TASK_KINDS := ["talk","herd","clock","friend","spend"]
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

## Her authored words for a beat, "" if the row names no beat or the banter
## file has no such id.
func beat_line(beat_key: String) -> String:
	var event_id: String = str(config.get(beat_key,""))
	if event_id == "": return ""
	return str(remarks.get(event_id,""))

## The one rule for getting a beat in front of the player, and the reason this
## is a function rather than four call sites.
##
## A speech bubble needs a sprite actor to hang on, and these rows are
## art-optional by design (see _sync_view) -- nineteen of them have no bundle
## on disk, so _say() is a no-op for the whole cast and always will be until
## art exists. The journal (room.message, via owner.tell) needs no art and is
## where most of this game's prose already reaches the player, so it is the
## floor: every beat lands there whether or not a bubble was possible.
##
## The *_message rows are status summaries -- what changed -- and the banter
## file is the writing in her own voice. They are not alternatives, so both go
## out, summary first then her line quoted the way room.gd already quotes
## Eleanor ("SPEAKER: ..."). Neither silently replaces the other.
func journal_line(beat_key: String, message_key: String) -> String:
	var status: String = str(config.get(message_key,""))
	var spoken := beat_line(beat_key)
	if spoken == "":
		# Three states, not two: a beat that fired with nothing to say must say
		# so out loud rather than blanking the journal, or a missing line is
		# indistinguishable from a beat that never fired.
		return status if status != "" else "%s says nothing here (%s has no line)." % [str(config.get("speaker","She")), beat_key]
	var quoted: String = str(config.get("speaker","")) + ": " + spoken
	return quoted if status == "" else status + "  " + quoted

func _beat(beat_key: String, message_key: String) -> void:
	_say(beat_key)
	_changed(journal_line(beat_key,message_key))

func task_kind() -> String:
	var kind: String = str(config.get("task_kind","talk"))
	return kind if kind in TASK_KINDS else "talk"

## {"ok":bool,"reason":String}. When ok is false, reason is her own words and
## is never empty: a requirement she will not explain is worse than no
## requirement at all, so every refusal path here has to produce a line.
func task_requirement() -> Dictionary:
	match task_kind():
		"herd":
			var need := int(config.get("task_herd",6))
			var have := _secured_count()
			if have >= need: return {"ok":true,"reason":""}
			return _refused({"have":have,"need":need},"She wants %d head standing east. %d are." % [need,have])
		"clock":
			var due := float(config.get("task_after_minutes",0.0))
			var now := _minutes()
			if now >= due: return {"ok":true,"reason":""}
			return _refused({"time":Clock.label(due),"now":Clock.label(now)},"Not until %s. It is %s." % [Clock.label(due),Clock.label(now)])
		"friend":
			var friend: String = str(config.get("task_friend",""))
			if friend == "" or _recruited(friend): return {"ok":true,"reason":""}
			return _refused({"friend":friend},"She wants somebody else riding with the outfit first.")
		"spend":
			var price := int(config.get("task_cash",0))
			var purse := _cash()
			if purse >= price: return {"ok":true,"reason":""}
			return _refused({"price":price,"purse":purse},"It costs $%d. You are carrying $%d." % [price,purse])
	return {"ok":true,"reason":""}

func _refused(values: Dictionary, fallback: String) -> Dictionary:
	var line: String = str(config.get("task_refusal",""))
	if line == "": line = fallback
	return {"ok":false,"reason":line.format(values)}

## Paid on completion, not on the check, so a refused press never costs money.
func _charge_task() -> void:
	if task_kind() != "spend": return
	var price := int(config.get("task_cash",0))
	if price > 0 and _cash() >= price: owner.room.cash -= price

func _secured_count() -> int:
	return owner.room.secured_count() if owner.room.has_method("secured_count") else 0

func _cash() -> int:
	var purse: Variant = owner.room.get("cash")
	return int(purse) if (purse is int or purse is float) else 0

func _minutes() -> float:
	var now: Variant = owner.get("minutes")
	return float(now) if (now is int or now is float) else 0.0

## A catalog id first, since most friends are rows in the same catalog, then
## the owner's own unlock table for the hand-written companions.
func _recruited(companion_id: String) -> bool:
	var roster: Variant = owner.get("simple_companions")
	if roster is Array:
		for entry in roster:
			if entry is Dictionary and entry.get("id") == companion_id and entry.get("state") != null:
				return entry.state.recruitment == "recruited"
	return owner.check_unlock(companion_id)

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
		_beat("meet_beat","meet_message")
	elif not state.task_done:
		var want := task_requirement()
		if not want.ok:
			owner.tell(want.reason)
			return true
		if state.complete_task().get("ok",false):
			_charge_task()
			_beat("task_beat","task_message")
	elif state.recruitment != "recruited":
		if state.invite(true).get("ok",false):
			_beat("recruited_beat","recruited_message")
	else:
		owner.tell(config.get("idle_message","She's glad to be along."))
	return true

func flirt() -> bool:
	if not _available() or not _near_npc(): return false
	if _busy(): return true
	if state.acknowledge_romance(true).get("ok",false):
		_beat("romance_beat","romance_message")
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
	var goal := "Talk beside " + str(config.get("location_label","the camp edge"))
	if state.recruitment == "recruited": goal = "Camp company"
	elif state.met and not state.task_done and not task_requirement().ok: goal = str(config.get("task_want",goal))
	owner.room.objective.text = config.id.to_upper() + " / " + goal
	var speaker: String = config.speaker
	var tag_prefix := "  " + speaker + " "
	if not owner.room.stats.text.contains(tag_prefix):
		owner.room.stats.text += tag_prefix + str(int(state.madness))
