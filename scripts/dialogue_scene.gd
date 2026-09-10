extends RefCounted
## A conversation the player can lose something in.
##
## Pure logic, same shape as scripts/trade_negotiation.gd and
## scripts/companion_perks.gd: Dictionaries in, Dictionaries out, no scene
## tree, no autoload, nothing that needs a running room. The room decides
## which buttons carry which option; this file decides what the options are.
##
## The whole point is that the second scene costs a JSON file and no new
## script. A scene is an ordered set of nodes. A node either speaks and
## offers options, or it is terminal and yields an outcome the rest of the
## game reads. Three things the game did not have before are first class
## here: a player can refuse and land somewhere else; an option can be
## visible and unavailable with a stated reason; and an option taken now
## can close another option later.
##
## Gates come from the caller as a flat facts Dictionary
## ({"steadied_three": true}), because whether Eleanor's cattle-calming
## adventure is finished is companion_room's business, not this file's.

const SCHEMA_VERSION := 1
## The room shows options on the existing control row. Four is what fits,
## so a fifth option in a data file is a validation error and not a
## surprise at runtime with one choice silently missing.
const MAX_OPTIONS := 4
## Narrow layouts relabel the same six controls in two columns, so a long
## option text there pushes a button past the bottom of a phone window. Every
## option carries a short form for that width; the cap is a validation error
## rather than a promise to keep the writing brief.
const MAX_SHORT := 24

var scene: Dictionary = {}
var facts: Dictionary = {}
var node_id := ""
var finished := false
## Option IDs the player has actually chosen, in order. IDs repeat across
## nodes on purpose: "give_word" offered from three different places is one
## choice, and the game should be able to ask whether it was ever taken.
var taken: Array[String] = []
## Option ID -> the reason it is no longer on offer.
var closed: Dictionary = {}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {}
	return parsed


## Returns the list of problems, so an empty Array means valid. A returned
## reason names the node and the offending value: a typo in a "next" id is
## the failure that would otherwise truncate a scene in silence, with the
## player simply finding a shorter conversation than the one that was
## written.
static func validate(source: Dictionary) -> Array:
	var problems: Array[String] = []
	if int(source.get("version", 0)) != SCHEMA_VERSION:
		problems.append("version must be %d" % SCHEMA_VERSION)
	if not source.get("id") is String or String(source.get("id", "")).is_empty():
		problems.append("scene needs a non-empty id")
	var nodes: Variant = source.get("nodes")
	if not nodes is Array or (nodes as Array).is_empty():
		problems.append("scene needs a non-empty nodes array")
		return problems
	var by_id := {}
	for entry in nodes:
		if not entry is Dictionary:
			problems.append("every node must be a dictionary")
			continue
		var id: Variant = entry.get("id")
		if not id is String or String(id).is_empty():
			problems.append("every node needs a non-empty id")
			continue
		if by_id.has(id):
			problems.append("duplicate node id: %s" % id)
			continue
		by_id[id] = entry
	var start: Variant = source.get("start")
	if not start is String or not by_id.has(start):
		problems.append("start must name an existing node, got: %s" % str(start))
	# Every option id anywhere, so a "closes" entry cannot point at nothing.
	var option_ids := {}
	for id in by_id:
		var node: Dictionary = by_id[id]
		for option in _options_of(node):
			if option is Dictionary and option.get("id") is String:
				option_ids[option.id] = true
	var terminals := 0
	for id in by_id:
		var node: Dictionary = by_id[id]
		if not node.get("speaker") is String or String(node.get("speaker", "")).is_empty():
			problems.append("%s: needs a speaker" % id)
		if not node.get("line") is String or String(node.get("line", "")).is_empty():
			problems.append("%s: needs a spoken line" % id)
		var options: Array = _options_of(node)
		if bool(node.get("terminal", false)):
			terminals += 1
			if not options.is_empty():
				problems.append("%s: a terminal node cannot offer options" % id)
			var outcome: Variant = node.get("outcome")
			if not outcome is Dictionary or not (outcome as Dictionary).get("id") is String:
				problems.append("%s: a terminal node needs an outcome with an id" % id)
			else:
				if not (outcome as Dictionary).get("flags") is Array:
					problems.append("%s: outcome flags must be an array" % id)
				var trust: Variant = (outcome as Dictionary).get("trust", 0)
				if not (trust is int or trust is float) or not is_finite(float(trust)):
					problems.append("%s: outcome trust must be a finite number" % id)
			continue
		# A speaking node with nothing to press is a dead end: the player is
		# left holding a conversation with no way out of it.
		if options.is_empty():
			problems.append("%s: a non-terminal node must offer at least one option" % id)
		if options.size() > MAX_OPTIONS:
			problems.append("%s: %d options exceeds the %d the room can show" % [id, options.size(), MAX_OPTIONS])
		var seen_here := {}
		for option in options:
			if not option is Dictionary:
				problems.append("%s: every option must be a dictionary" % id)
				continue
			var option_id: Variant = option.get("id")
			if not option_id is String or String(option_id).is_empty():
				problems.append("%s: every option needs a non-empty id" % id)
				continue
			if seen_here.has(option_id):
				problems.append("%s: duplicate option id: %s" % [id, option_id])
			seen_here[option_id] = true
			if not option.get("text") is String or String(option.get("text", "")).is_empty():
				problems.append("%s/%s: needs option text" % [id, option_id])
			var short: Variant = option.get("short")
			if not short is String or String(short).is_empty():
				problems.append("%s/%s: needs a short label for narrow layouts" % [id, option_id])
			elif String(short).length() > MAX_SHORT:
				problems.append("%s/%s: short label is %d characters, cap is %d" % [id, option_id, String(short).length(), MAX_SHORT])
			var next: Variant = option.get("next")
			if not next is String or not by_id.has(next):
				problems.append("%s/%s: next does not name a node: %s" % [id, option_id, str(next)])
			if option.has("requires") and String(option.get("unavailable", "")).is_empty():
				problems.append("%s/%s: a gated option must say why it is unavailable" % [id, option_id])
			if option.has("requires_taken") and String(option.get("unavailable", "")).is_empty():
				problems.append("%s/%s: a gated option must say why it is unavailable" % [id, option_id])
			var closes: Variant = option.get("closes", [])
			if not closes is Array:
				problems.append("%s/%s: closes must be an array" % [id, option_id])
			else:
				for closed_id in closes:
					if not closed_id is String or not option_ids.has(closed_id):
						problems.append("%s/%s: closes names no option: %s" % [id, option_id, str(closed_id)])
	if terminals == 0:
		problems.append("scene has no terminal node")
	# An unreachable node is authored writing nobody will ever hear, which is
	# the same defect as a dangling next seen from the other side.
	if by_id.has(start):
		var reached := {start: true}
		var frontier: Array[String] = [String(start)]
		while not frontier.is_empty():
			var current: String = frontier.pop_back()
			for option in _options_of(by_id[current]):
				if not option is Dictionary: continue
				var next: Variant = option.get("next")
				if next is String and by_id.has(next) and not reached.has(next):
					reached[next] = true
					frontier.append(String(next))
		for id in by_id:
			if not reached.has(id):
				problems.append("%s: no option anywhere reaches this node" % id)
	return problems


static func _options_of(node: Dictionary) -> Array:
	var options: Variant = node.get("options", [])
	return options if options is Array else []


## Returns false and leaves this object unconfigured if the data is bad, so a
## broken file cannot half-start a conversation.
func configure(source: Dictionary, world_facts: Dictionary = {}) -> bool:
	if not validate(source).is_empty(): return false
	scene = source.duplicate(true)
	facts = world_facts.duplicate(true)
	restart()
	return true


func restart() -> void:
	node_id = String(scene.get("start", ""))
	finished = bool(_node(node_id).get("terminal", false))
	taken.clear()
	closed.clear()


func update_facts(world_facts: Dictionary) -> void:
	facts = world_facts.duplicate(true)


func is_configured() -> bool:
	return not scene.is_empty() and not node_id.is_empty()


func _node(id: String) -> Dictionary:
	for entry in scene.get("nodes", []):
		if entry is Dictionary and entry.get("id") == id: return entry
	return {}


func current() -> Dictionary:
	var node: Dictionary = _node(node_id)
	if node.is_empty(): return {}
	return {"id": node.id, "speaker": node.speaker, "line": node.line,
		"terminal": bool(node.get("terminal", false))}


## Every option the node holds, in authored order, each already judged.
## Unavailable options are still returned: the player is meant to see the
## door and be told why it will not open, not to find a shorter menu.
func options() -> Array:
	var result: Array[Dictionary] = []
	var node: Dictionary = _node(node_id)
	if node.is_empty() or bool(node.get("terminal", false)): return result
	for index in range(_options_of(node).size()):
		var option: Dictionary = _options_of(node)[index]
		var judged: Dictionary = _judge(option)
		result.append({"index": index, "id": option.id, "text": option.text,
			"short": option.short,
			"available": judged.available, "reason": judged.reason,
			"next": option.next})
	return result


func _judge(option: Dictionary) -> Dictionary:
	if closed.has(option.id):
		return {"available": false, "reason": String(closed[option.id])}
	var stated: String = String(option.get("unavailable", "Not yet."))
	var requirement: String = String(option.get("requires", ""))
	if not requirement.is_empty() and not bool(facts.get(requirement, false)):
		return {"available": false, "reason": stated}
	var needed: String = String(option.get("requires_taken", ""))
	if not needed.is_empty() and not taken.has(needed):
		return {"available": false, "reason": stated}
	return {"available": true, "reason": ""}


## Number of options the player could actually press right now. Zero on a
## speaking node is the stranding case; validate() rejects a node with no
## options at all, and a caller can use this to catch a facts Dictionary
## that has gated every door shut.
func available_count() -> int:
	var count := 0
	for option in options():
		if option.available: count += 1
	return count


## The one place a choice is applied. Returns
## {ok, reason, node, finished} so the room can print the refusal reason
## for an unavailable press without asking twice.
func choose(index: int) -> Dictionary:
	if finished or not is_configured():
		return {"ok": false, "reason": "scene_finished", "note": ""}
	var listed: Array = options()
	if index < 0 or index >= listed.size():
		return {"ok": false, "reason": "no_such_option", "note": ""}
	var chosen: Dictionary = listed[index]
	if not chosen.available:
		return {"ok": false, "reason": "unavailable", "note": chosen.reason}
	var node: Dictionary = _node(node_id)
	var option: Dictionary = _options_of(node)[index]
	if not taken.has(option.id): taken.append(String(option.id))
	for shut in option.get("closes", []):
		if shut is String and not closed.has(shut):
			closed[shut] = String(option.get("closes_reason", "That is no longer on offer."))
	node_id = String(option.next)
	finished = bool(_node(node_id).get("terminal", false))
	return {"ok": true, "reason": "advanced", "note": "", "node": current(), "finished": finished}


## Empty until a terminal node is reached, so a caller cannot pay out a
## relationship beat for a conversation that is still running.
func outcome() -> Dictionary:
	if not finished: return {}
	var node: Dictionary = _node(node_id)
	var authored: Dictionary = node.get("outcome", {})
	return {"id": String(authored.get("id", "")),
		"summary": String(authored.get("summary", "")),
		"trust": int(authored.get("trust", 0)),
		"flags": (authored.get("flags", []) as Array).duplicate(),
		"line": String(node.get("line", "")),
		"taken": taken.duplicate()}


## Runtime record for a save file. Deliberately small: which ending was
## reached, which flags it set and which options were taken, because that is
## everything a later scene needs to know about this one.
static func blank_record() -> Dictionary:
	return {"visited": false, "terminal": "", "flags": [], "taken": []}


static func valid_record(record: Variant) -> bool:
	if not record is Dictionary: return false
	var data: Dictionary = record
	for key in blank_record():
		if not data.has(key): return false
	if not data.visited is bool or not data.terminal is String: return false
	for key in ["flags", "taken"]:
		if not data[key] is Array: return false
		for value in data[key]:
			if not value is String or String(value).is_empty() or String(value).length() > 128: return false
	if not data.visited and (not data.terminal.is_empty() or not (data.flags as Array).is_empty()): return false
	return true


func record() -> Dictionary:
	if not finished: return blank_record()
	var result: Dictionary = outcome()
	return {"visited": true, "terminal": result.id, "flags": result.flags, "taken": result.taken}
