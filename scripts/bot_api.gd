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
		"actors":
			# Probe 1. "Is anything actually there." An observation of positions
			# cannot tell a drawn character from a bare coordinate, and nineteen
			# companions shipped as coordinates with dialogue attached because
			# nothing here could ask the question.
			_emit(actor_report())
		"sabotage":
			# The injection point for probe 1. A branch nobody can execute on
			# purpose is a branch nobody can prove they fixed, and the branch
			# that matters here -- a character who is not on screen -- cannot be
			# reached from a healthy build at all. Only reachable in --bot.
			_emit(_sabotage(str(command.get("target", "")), str(command.get("how", "strip"))))
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

var _last_storage_ok := false

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
			# The answer is reported. room.gd refuses to save mid-action, and a
			# refused save is invisible from outside: the next load quietly
			# restores a much older world and every measurement taken from it is
			# a measurement of the wrong moment.
			_last_storage_ok = room.companion != null and room.companion.save_game(BOT_SAVE)
		"load":
			_last_storage_ok = room.companion != null and room.companion.load_game(BOT_SAVE)
		_:
			_emit({"type": "error", "message": "unknown action", "action": action})
			return
	# "changed" lets the bot notice an action that silently did nothing, which
	# is a real complaint category and invisible from a return value alone.
	var payload := {"type": "ok", "cmd": "act", "action": action,
		"changed": _fingerprint() != before, "message": room.message}
	if action == "save" or action == "load": payload["ok"] = _last_storage_ok
	_emit(payload)

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

# ---------------------------------------------------------------------------
# Probe 1: rendered presence.
#
# Every function below answers one question: is there something on screen where
# the game is asking the player to stand? A Node2D with no texture, a hidden
# node and a node that was never created all draw exactly the same thing, so
# "a node exists" is not the check. The check is a texture, visible in the
# tree, with a non-zero size and some alpha left in it.

## The texture a single node would draw this frame, or null if it draws nothing.
func _node_texture(node) -> Texture2D:
	if node is Sprite2D:
		return node.texture
	if node is AnimatedSprite2D:
		var frames: SpriteFrames = node.sprite_frames
		if frames == null: return null
		var clip: String = node.animation
		if not frames.has_animation(clip): return null
		var count: int = frames.get_frame_count(clip)
		if count <= 0: return null
		return frames.get_frame_texture(clip, clampi(node.frame, 0, count - 1))
	if node is TextureRect:
		return node.texture
	return null

## Walks a node and its descendants for the largest thing it actually draws.
## Actors keep their art on a child AnimatedSprite2D, so checking the node the
## game hands out would report every character as textureless.
func _drawn_part(node, best: Dictionary) -> Dictionary:
	if node is CanvasItem:
		var texture: Texture2D = _node_texture(node)
		if texture != null:
			var size: Vector2 = texture.get_size()
			var scale: Vector2 = (node as CanvasItem).get_global_transform().get_scale()
			var on_screen := Vector2(absf(size.x * scale.x), absf(size.y * scale.y))
			var area: float = on_screen.x * on_screen.y
			if area > float(best.get("area", -1.0)):
				best = {
					"area": area,
					"texture_size": {"w": int(size.x), "h": int(size.y)},
					"on_screen_size": {"w": snapped(on_screen.x, 0.1), "h": snapped(on_screen.y, 0.1)},
					"visible_in_tree": (node as CanvasItem).is_visible_in_tree(),
					"alpha": snapped((node as CanvasItem).get_modulate().a, 0.01),
				}
	for child in node.get_children():
		best = _drawn_part(child, best)
	return best

## Presence of one thing the player is meant to see. Three states, never two:
## drawn, not drawn with a reason, or no node at all.
func _presence(node) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {"exists": false, "visible": false, "visible_in_tree": false, "has_texture": false,
			"texture_size": {"w": 0, "h": 0}, "on_screen_size": {"w": 0.0, "h": 0.0},
			"alpha": 0.0, "drawn": false, "why_not_drawn": "no node exists at all"}
	var out := {
		"exists": true,
		"class": node.get_class(),
		"node_name": String(node.name),
		"visible": bool(node.visible) if node is CanvasItem else true,
		"visible_in_tree": (node as CanvasItem).is_visible_in_tree() if node is CanvasItem else true,
		"pos": _pos(node),
	}
	var best: Dictionary = _drawn_part(node, {})
	if best.is_empty():
		out["has_texture"] = false
		out["texture_size"] = {"w": 0, "h": 0}
		out["on_screen_size"] = {"w": 0.0, "h": 0.0}
		out["alpha"] = snapped((node as CanvasItem).get_modulate().a, 0.01) if node is CanvasItem else 1.0
		out["drawn"] = false
		out["why_not_drawn"] = "the node exists but nothing under it has a texture, so it draws nothing"
		return out
	out["has_texture"] = true
	out["texture_size"] = best["texture_size"]
	out["on_screen_size"] = best["on_screen_size"]
	out["alpha"] = best["alpha"]
	out["visible_in_tree"] = bool(out["visible_in_tree"]) and bool(best["visible_in_tree"])
	var wide: bool = float(best["on_screen_size"]["w"]) > 0.0 and float(best["on_screen_size"]["h"]) > 0.0
	var lit: bool = float(best["alpha"]) > 0.0
	out["drawn"] = bool(out["visible_in_tree"]) and wide and lit
	if out["drawn"]:
		out["why_not_drawn"] = ""
	elif not out["visible_in_tree"]:
		out["why_not_drawn"] = "the node has art but is hidden"
	elif not wide:
		out["why_not_drawn"] = "the node's texture has no size"
	else:
		out["why_not_drawn"] = "the node is fully transparent"
	return out

## Breaks one thing on purpose so the presence probe can be proved to notice.
## "target" is "player", "eleanor", "rustler" or "companion:<id>"; "how" is
## "hide", "strip" (take the texture away, which is the failure that shipped) or
## "free" (remove the node entirely).
func _sabotage(target: String, how: String) -> Dictionary:
	var node: Node = null
	if target.begins_with("companion:"):
		node = room.actors.get_node_or_null("companion_" + target.substr(10)) if is_instance_valid(room.actors) else null
	elif target == "player": node = room.player
	elif target == "eleanor": node = room.eleanor
	elif target == "rustler": node = room.rustler
	if node == null or not is_instance_valid(node):
		# A sabotage that changed nothing must never read as a pass.
		return {"type": "error", "cmd": "sabotage", "target": target, "how": how,
			"applied": false, "message": "no such node, so nothing was broken"}
	match how:
		"hide":
			(node as CanvasItem).visible = false
		"strip":
			var stripped := _strip(node)
			if not stripped:
				return {"type": "error", "cmd": "sabotage", "target": target, "how": how,
					"applied": false, "message": "found nothing with a texture to take away"}
		"free":
			node.get_parent().remove_child(node)
			node.queue_free()
		_:
			return {"type": "error", "cmd": "sabotage", "message": "unknown sabotage", "how": how,
				"applied": false}
	return {"type": "ok", "cmd": "sabotage", "target": target, "how": how, "applied": true}

func _strip(node) -> bool:
	var done := false
	if node is Sprite2D and node.texture != null:
		node.texture = null
		done = true
	if node is AnimatedSprite2D and node.sprite_frames != null:
		node.sprite_frames = null
		done = true
	for child in node.get_children():
		if _strip(child): done = true
	return done

func actor_report() -> Dictionary:
	var out := {"type": "ok", "cmd": "actors"}
	if not is_instance_valid(room.actors):
		# Loud zero. A report with no denominator would read as a clean pass.
		out["layer_present"] = false
		out["examined"] = 0
		out["error"] = "room.actors does not exist, so nothing could be examined"
		return out
	out["layer_present"] = true
	var examined := 0
	var accounted := {}

	# The named actors the game itself holds a reference to.
	var named: Array = []
	for pair in [["player", room.player], ["eleanor", room.eleanor], ["rustler", room.rustler]]:
		var entry: Dictionary = _presence(pair[1])
		entry["name"] = str(pair[0])
		# Interactive means the player pressing a verb here does something.
		entry["interactive"] = true
		if pair[0] == "rustler":
			entry["interactive"] = bool(room.rustler_active) or (room.has_method("rustler_choice_pending") and room.rustler_choice_pending())
		named.append(entry)
		examined += 1
		if is_instance_valid(pair[1]): accounted[pair[1].get_instance_id()] = true
	out["named"] = named

	# The catalog companions: nineteen coordinates with dialogue attached. The
	# sprite for one is expected under room.actors as companion_<id>.
	var companions: Array = []
	if room.companion != null:
		for entry in room.companion.simple_companions:
			var config: Dictionary = entry.room.config
			var expects := "companion_" + String(entry.id)
			var node = room.actors.get_node_or_null(expects)
			var record: Dictionary = _presence(node)
			record["id"] = entry.id
			record["expects_node"] = expects
			record["interactive"] = true
			record["unlocked"] = entry.room.unlocked()
			record["near_radius"] = float(config.get("near_radius", 36.0))
			record["asked_to_stand_at"] = {"x": config.position.x, "y": config.position.y}
			companions.append(record)
			examined += 1
			if node != null and is_instance_valid(node): accounted[node.get_instance_id()] = true
	out["companions"] = companions

	# Cattle. Lassoable, so each one is an interactive target too.
	var cattle_drawn := 0
	var cattle_total := 0
	for cow in room.cows:
		if not is_instance_valid(cow): continue
		cattle_total += 1
		examined += 1
		accounted[cow.get_instance_id()] = true
		if bool(_presence(cow).get("drawn", false)): cattle_drawn += 1
	out["cattle"] = {"total": cattle_total, "drawn": cattle_drawn}

	# Everything else sitting on the actor layer: scenery, props, leftovers.
	# Counted so the denominator is the whole layer rather than the parts the
	# probe already knew to look for.
	var others: Array = []
	for child in room.actors.get_children():
		if accounted.has(child.get_instance_id()): continue
		var record: Dictionary = _presence(child)
		record["interactive"] = false
		others.append(record)
		examined += 1
	out["unaccounted"] = others
	out["examined"] = examined
	return out

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
	# Probe 2 needs to see everything the player owns that a fight could take.
	# Read defensively: room.gd is being rewritten around the rustler, and a
	# missing field must read as "this game has no such resource" rather than
	# crash the API the whole session depends on.
	for key in ["strain", "player_hits", "hits", "reload_time", "escaped",
			"rustler_surrendered", "rustler_fate", "rustler_hired", "rustler_present"]:
		if key in room:
			var value: Variant = room.get(key)
			data[key] = snapped(float(value), 0.01) if value is float else value
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
