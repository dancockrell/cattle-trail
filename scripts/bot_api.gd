extends Node
## Headless play API. Added to the room by scripts/room.gd when --bot is passed.
## Speaks newline-delimited JSON over stdin/stdout so an external agent can play
## the real game: it calls the same room functions the key handlers call, and
## reports the same text a player would read on screen.
##
## Responses carry the marker below so the caller can ignore Godot's own stdout
## noise without parsing it.

const MARK := "@@BOT@@ "
## Bot saves go here, never to the player's real user://clear-fork-save.json.
const BOT_SAVE := "user://bot-save.json"

var room: Control
var transcript: Array = []
var tick := 0

# OS.read_string_from_stdin() blocks, so it cannot live on the main loop: a
# "step" command awaits frames, and a main loop blocked on stdin never delivers
# them. The read sits on its own thread and hands whole lines to _process.
var _reader: Thread
var _mutex := Mutex.new()
var _inbox: Array = []
var _buffer := ""
var _closing := false
var _busy := false

func _ready() -> void:
	room = get_parent()
	# Uncapped so a step costs CPU time rather than wall-clock time. The bot is
	# the point of this mode and should run as fast as the machine allows.
	Engine.max_fps = 0
	_reader = Thread.new()
	_reader.start(_read_loop)
	_emit({"type": "hello", "protocol": 1, "game": "cattle-trail"})

func _read_loop() -> void:
	while not _closing:
		var chunk := OS.read_string_from_stdin()
		if chunk == "":
			continue
		_mutex.lock()
		_buffer += chunk
		while true:
			var newline := _buffer.find("\n")
			if newline < 0: break
			var line := _buffer.substr(0, newline).strip_edges()
			_buffer = _buffer.substr(newline + 1)
			if line != "": _inbox.append(line)
		_mutex.unlock()

func _process(_delta: float) -> void:
	tick += 1
	if _busy: return
	var line := ""
	_mutex.lock()
	if not _inbox.is_empty(): line = str(_inbox.pop_front())
	_mutex.unlock()
	if line == "": return
	_busy = true
	await _handle(line)
	_busy = false

func _handle(line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if not parsed is Dictionary:
		_emit({"type": "error", "message": "unparseable command", "raw": line})
		return
	var command: Dictionary = parsed
	var name: String = str(command.get("cmd", ""))
	match name:
		"obs":
			_emit(observation())
		"move":
			room.target = Vector2(float(command.get("x", 0.0)), float(command.get("y", 0.0)))
			_emit({"type": "ok", "cmd": "move"})
		"act":
			_act(str(command.get("name", "")))
		"step":
			await _step(int(command.get("frames", 1)))
		"choose":
			# The room's numbered answers (the rustler's fate, and any future
			# numbered reply) are not reachable through the verb list, so the
			# bot could not exercise the game's only real decision without this.
			var picked: String = str(command.get("option", ""))
			var taken := false
			if room.has_method("choose_rustler"): taken = room.choose_rustler(picked)
			_emit({"type": "ok", "cmd": "choose", "option": picked, "taken": taken,
				"message": room.message})
		"options":
			var choices: Array = []
			if "RUSTLER_CHOICES" in room and room.has_method("rustler_choice_pending") and room.rustler_choice_pending():
				for choice in room.RUSTLER_CHOICES: choices.append(str(choice))
			_emit({"type": "ok", "cmd": "options", "options": choices})
		"speed":
			# Scales in-game time so timers (an 18s lasso lead, camp cooldowns)
			# cost the bot frames rather than wall-clock seconds.
			Engine.time_scale = clampf(float(command.get("scale", 1.0)), 0.1, 50.0)
			_emit({"type": "ok", "cmd": "speed", "scale": Engine.time_scale})
		"quit":
			_emit({"type": "bye"})
			_closing = true
			get_tree().quit(0)
		_:
			_emit({"type": "error", "message": "unknown cmd", "cmd": name})

func _act(action: String) -> void:
	var before := _fingerprint()
	match action:
		"interact": room.interact()
		"lasso": room.lasso()
		"shoot": room.shoot()
		"switch": room.switch_companion()
		"rest": room.rest_companion()
		"flirt":
			if room.companion != null: room.companion.flirt()
		"reset": room.reset_room()
		"save":
			if room.companion != null: room.companion.save_game(BOT_SAVE)
		"load":
			if room.companion != null: room.companion.load_game(BOT_SAVE)
		_:
			_emit({"type": "error", "message": "unknown action", "action": action})
			return
	# "changed" lets the bot notice an action that silently did nothing, which
	# is a real complaint category and invisible from a return value alone.
	_emit({"type": "ok", "cmd": "act", "action": action, "changed": _fingerprint() != before,
		"message": room.message})

func _step(frames: int) -> void:
	var count: int = clampi(frames, 1, 600)
	for i in range(count):
		await get_tree().process_frame
	_emit(observation())

## A cheap summary of everything an action could plausibly move. Used only to
## answer "did anything happen at all", so it need not be exhaustive.
func _fingerprint() -> String:
	var companion = room.companion
	var parts: Array = [room.message, room.won, room.ammo, room.cash, room.secured_count(),
		snapped(room.player.position.x, 1), snapped(room.player.position.y, 1),
		room.rope_time > 0, room.rustler_active]
	if companion != null:
		parts.append(companion.state.recruitment)
		parts.append(companion.state.relationship_stage)
		parts.append(companion.state.trust)
		for entry in companion.simple_companions:
			parts.append("%s:%s:%s:%s" % [entry.state.met, entry.state.task_done, entry.state.recruitment, entry.state.romance_acknowledged])
	var text: Array = []
	for value in parts: text.append(str(value))
	return "|".join(text)

func observation() -> Dictionary:
	var companion = room.companion
	var data := {
		"type": "obs",
		"tick": tick,
		"message": room.message,
		"objective": room.objective.text if is_instance_valid(room.objective) else "",
		"stats": room.stats.text if is_instance_valid(room.stats) else "",
		"won": room.won,
		"cash": room.cash,
		"ammo": room.ammo,
		"cattle_secured": room.secured_count(),
		"rustler_active": room.rustler_active,
		"talked": room.talked,
		"rope_time": snapped(room.rope_time, 0.01),
		"rope_flight": snapped(room.rope_flight_time, 0.01),
		"player": _pos(room.player),
		"player_busy": room.player.action_time > 0.0,
		"eleanor": _pos(room.eleanor),
		"buttons": _buttons(),
		"transcript": transcript.slice(maxi(0, transcript.size() - 12)),
	}
	if companion != null:
		data["clock"] = companion.clock_label()
		data["controlling"] = "eleanor" if companion.is_eleanor() else "trail_boss"
		data["eleanor_state"] = {
			"recruitment": companion.state.recruitment,
			"stage": companion.state.relationship_stage,
			"trust": companion.state.trust,
			"madness": companion.state.madness,
			"adventure": companion.state.adventure_status,
		}
		data["companions"] = _companions(companion)
		data["cattle"] = _cattle()
	return data

func _companions(companion) -> Array:
	var out: Array = []
	for entry in companion.simple_companions:
		var config: Dictionary = entry.room.config
		out.append({
			"id": entry.id,
			"kind": "simple",
			"pos": {"x": config.position.x, "y": config.position.y},
			"unlocked": entry.room.unlocked(),
			"near": entry.room._near_npc(),
			"met": entry.state.met,
			"task_done": entry.state.task_done,
			"recruitment": entry.state.recruitment,
			"romance": entry.state.romance_acknowledged,
			"trust": entry.state.trust,
			"madness": entry.state.madness,
		})
	out.append({"id": "birdie_calloway", "kind": "bespoke",
		"recruitment": companion.birdie_state.recruitment,
		"met": companion.birdie_state.met,
		"sang": companion.birdie_state.sang,
		"romance": companion.birdie_state.romance_acknowledged,
		"trust": companion.birdie_state.trust})
	out.append({"id": "ada_mercer", "kind": "bespoke",
		"recruitment": companion.ada_state.recruitment,
		"trust": companion.ada_state.trust})
	out.append({"id": "ines_vale", "kind": "bespoke",
		"recruitment": companion.ines_state.recruitment,
		"trust": companion.ines_state.trust})
	return out

func _cattle() -> Array:
	var out: Array = []
	for cow in room.cows:
		if not is_instance_valid(cow): continue
		out.append({"pos": _pos(cow), "secured": cow.secured})
	return out

func _buttons() -> Array:
	var labels: Array = []
	if not is_instance_valid(room.buttons): return labels
	for child in room.buttons.get_children():
		if child is Button and child.visible:
			labels.append({"text": child.text, "disabled": child.disabled})
	return labels

func _pos(node) -> Dictionary:
	if not is_instance_valid(node): return {}
	return {"x": snapped(node.position.x, 0.1), "y": snapped(node.position.y, 0.1)}

## Called by room.say_once so the bot reads exactly the lines a player sees.
func record_line(speaker: String, text: String) -> void:
	transcript.append({"tick": tick, "speaker": speaker, "text": text})

func _emit(payload: Dictionary) -> void:
	print(MARK + JSON.stringify(payload))
