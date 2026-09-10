extends SceneTree
## Properties, not mechanics. The questions this asks are the ones a player
## would notice: can I refuse and land somewhere else, is a locked door
## visible and explained, can a choice cost me a later choice, and is every
## line that was written actually reachable.
##
## The headline check is that every "next" resolves to a real node. A typo
## there does not crash: it truncates the scene, and the only symptom is a
## conversation shorter than the one that was authored. Nothing else in the
## project would catch that.
const Dialogue = preload("res://scripts/dialogue_scene.gd")
const SCENE_PATH := "res://data/eleanor_wagon_scene.json"

var checks := 0
var failures: Array[String] = []


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: failures.append(message)
	return condition


## Every property below the scene's own validity is measured by walking the
## authored data, and walking a scene that does not validate reads keys that
## are not there: in a --script run that raises, abandons _initialize() and
## leaves Godot idling until the harness kills it on a timeout. A timeout
## and a failure are not the same report, so stop at the first stage that
## went red and say which stage it was.
## Returns true when the caller must stop: quit() only flags the loop, it
## does not unwind the running function.
func _abort_if_failed(stage: String) -> bool:
	if failures.is_empty(): return false
	for problem in failures: printerr("DIALOGUE SCENE FAIL: ", problem)
	push_error("dialogue scene test: %d of %d checks failed at stage '%s'" % [failures.size(), checks, stage])
	quit(1)
	return true


func _initialize():
	var scene: Dictionary = Dialogue.load_file(SCENE_PATH)
	_check(not scene.is_empty(), "The authored scene file must parse")

	# --- Denominator first. Every property below is measured against this
	# file, so a truncated or empty file must fail here and not sail through
	# a suite that finds nothing wrong with nothing.
	var nodes: Array = scene.get("nodes", [])
	var option_total := 0
	var terminal_total := 0
	for node in nodes:
		option_total += (node.get("options", []) as Array).size()
		if bool(node.get("terminal", false)): terminal_total += 1
	_check(nodes.size() >= 10, "The scene must be a real scene: at least 10 nodes, found %d" % nodes.size())
	_check(option_total >= 15, "The scene must offer real choices: at least 15 options, found %d" % option_total)
	_check(terminal_total >= 4, "The scene must have at least 4 endings, found %d" % terminal_total)
	# The room relabels six existing controls; a long label at phone width
	# pushes a button off the bottom of the window, which is a layout bug
	# nothing in this suite would otherwise see.
	var shorts := 0
	for node in nodes:
		for option in node.get("options", []):
			shorts += 1
			_check(String(option.get("short", "")).length() <= Dialogue.MAX_SHORT and not String(option.get("short", "")).is_empty(),
				"%s/%s: short label must fit a narrow button" % [node.id, option.get("id", "?")])
	_check(shorts == option_total, "Every option must carry a short label, %d of %d" % [shorts, option_total])

	# --- Every next resolves, every node is reachable, no speaking node is
	# a dead end. validate() returns the list of problems.
	var problems: Array = Dialogue.validate(scene)
	_check(problems.is_empty(), "The authored scene must validate clean, got: %s" % str(problems))
	if _abort_if_failed("authored data"): return

	# --- Sabotage. A validator nobody has made fail is a validator that may
	# not be running. Each case must be caught, and caught by name, so a
	# validator gutted down to "return []" cannot pass this file.
	_sabotage_caught(scene, "dangling next", func(copy):
		_node_in(copy, "promise").options[0].next = "promissed")
	_sabotage_caught(scene, "speaking node with no options", func(copy):
		_node_in(copy, "why").options.clear())
	_sabotage_caught(scene, "terminal that offers options", func(copy):
		_node_in(copy, "promised").options = [{"id": "x", "text": "x", "next": "left"}])
	_sabotage_caught(scene, "more options than the room can show", func(copy):
		_node_in(copy, "gave_up").options.append({"id": "spare1", "text": "a", "next": "left"})
		_node_in(copy, "gave_up").options.append({"id": "spare2", "text": "b", "next": "left"}))
	_sabotage_caught(scene, "closes naming no option", func(copy):
		_node_in(copy, "tool_ask").options[0].closes = ["ask_bakc"])
	_sabotage_caught(scene, "gate with no stated reason", func(copy):
		_node_in(copy, "why").options[1].erase("unavailable"))
	_sabotage_caught(scene, "unreachable authored node", func(copy):
		for option in _node_in(copy, "why").options:
			if option.next == "asked_back": option.next = "left"
		for option in _node_in(copy, "gave_up").options:
			if option.next == "asked_back": option.next = "left")
	_sabotage_caught(scene, "start naming no node", func(copy):
		copy.start = "opne")
	_sabotage_caught(scene, "duplicate node id", func(copy):
		copy.nodes.append(_node_in(copy, "left").duplicate(true)))
	_sabotage_caught(scene, "short label too long for a phone", func(copy):
		_node_in(copy, "open").options[0].short = "a".repeat(Dialogue.MAX_SHORT + 1))
	_sabotage_caught(scene, "missing short label", func(copy):
		_node_in(copy, "open").options[0].erase("short"))
	if _abort_if_failed("sabotage"): return

	# A configure() call on a broken scene must refuse rather than half-start.
	var broken: Dictionary = scene.duplicate(true)
	_node_in(broken, "promise").options[0].next = "nowhere"
	var refused = Dialogue.new()
	_check(not refused.configure(broken), "configure must reject a scene that does not validate")
	_check(not refused.is_configured(), "A rejected scene must leave nothing half-configured")

	# --- Refusing is a real path, not a nag loop back to the same question.
	var accepted: Dictionary = _play(scene, {"steadied_three": true}, ["hear_it", "give_word"])
	var refused_run: Dictionary = _play(scene, {"steadied_three": true}, ["hear_it", "refuse"])
	_check(accepted.finished and refused_run.finished, "Both the yes and the no must actually end the scene")
	_check(accepted.outcome.id != refused_run.outcome.id,
		"Refusing must reach a different ending than accepting, got %s both times" % accepted.outcome.id)
	_check(accepted.outcome.line != refused_run.outcome.line, "The two endings must not say the same words")
	_check(accepted.outcome.flags != refused_run.outcome.flags, "The two endings must leave different flags behind")
	_check(accepted.outcome.trust != refused_run.outcome.trust, "The two endings must be worth different amounts of trust")
	_check(not (refused_run.outcome.flags as Array).is_empty(), "Refusing must still record that it happened")

	# Walking out without answering is a third thing again, not a quiet yes.
	var walked: Dictionary = _play(scene, {"steadied_three": true}, ["defer"])
	_check(walked.finished, "Declining to have the conversation must end it")
	_check(walked.outcome.id != accepted.outcome.id and walked.outcome.id != refused_run.outcome.id,
		"Leaving must be its own ending")
	_check((walked.outcome.flags as Array).is_empty() and walked.outcome.trust == 0,
		"Leaving without answering must cost and grant nothing")

	# --- The gate. Unavailable before the requirement, available after, and
	# in both cases the option is still on screen with a reason attached.
	var ungated = Dialogue.new()
	_check(ungated.configure(scene, {"steadied_three": false}), "The scene must configure")
	_check(ungated.choose(_index_of(ungated, "hear_it")).ok, "Opening choice must advance")
	_check(ungated.choose(_index_of(ungated, "ask_why")).ok, "Asking why must advance")
	var locked: Dictionary = _option_named(ungated, "ask_back")
	_check(locked.id == "ask_back", "The gated option must still be listed, not hidden")
	_check(not locked.available, "The gated option must be unavailable before the adventure is done")
	_check(not String(locked.reason).is_empty(), "An unavailable option must state why")
	var blocked: Dictionary = ungated.choose(int(locked.index))
	_check(not blocked.ok and blocked.reason == "unavailable", "Pressing a locked option must refuse")
	_check(blocked.note == locked.reason, "The refusal must hand back the same stated reason")
	_check(ungated.current().id == "why", "A refused press must not move the conversation")

	var gated = Dialogue.new()
	gated.configure(scene, {"steadied_three": true})
	gated.choose(_index_of(gated, "hear_it"))
	gated.choose(_index_of(gated, "ask_why"))
	var unlocked: Dictionary = _option_named(gated, "ask_back")
	_check(unlocked.available, "The same option must be available once the adventure is done")
	_check(String(unlocked.reason).is_empty(), "An available option carries no refusal reason")
	_check(gated.choose(int(unlocked.index)).ok, "The unlocked option must advance the scene")
	_check(gated.current().id == "asked_back", "The unlocked option must reach the node it names")

	# The gate is a real gate and not decoration: the ending behind it is
	# unreachable with the requirement unmet.
	var reachable_ungated: Dictionary = _reachable_endings(scene, {"steadied_three": false})
	var reachable_gated: Dictionary = _reachable_endings(scene, {"steadied_three": true})
	_check(not reachable_ungated.has("sent_for"), "The gated ending must be unreachable before the adventure")
	_check(reachable_gated.has("sent_for"), "The gated ending must be reachable after the adventure")
	_check(reachable_gated.size() > reachable_ungated.size(), "Doing the adventure must open at least one ending")
	_check(reachable_gated.size() >= 5, "Every authored ending must be reachable, found %d" % reachable_gated.size())

	# --- One choice closes another. Taken with the requirement already met,
	# so a pass here cannot be the gate doing the work.
	var closer = Dialogue.new()
	closer.configure(scene, {"steadied_three": true})
	closer.choose(_index_of(closer, "ask_tool"))
	closer.choose(_index_of(closer, "push_tool"))
	closer.choose(_index_of(closer, "stand_down"))
	_check(closer.current().id == "promise", "Standing down must return to her own question")
	closer.choose(_index_of(closer, "ask_why"))
	var shut: Dictionary = _option_named(closer, "ask_back")
	_check(shut.id == "ask_back" and not shut.available,
		"Pushing her about the crossing must close the option she was going to offer")
	_check(String(shut.reason) != String(locked.reason),
		"A closed option must say it was closed, not repeat the not-yet reason")
	_check(closer.taken.has("push_tool"), "Taken options must be recorded for the rest of the game to read")
	_check(not _reachable_endings_from(scene, {"steadied_three": true}, closer).has("sent_for"),
		"With the option closed, the ending behind it must be out of reach")

	# --- No node can strand the player, even with every fact false and
	# every closable option closed. This is the worst case a save can be in.
	var worst = Dialogue.new()
	worst.configure(scene, {})
	worst.closed["ask_back"] = "closed"
	var speaking := 0
	for node in nodes:
		if bool(node.get("terminal", false)): continue
		speaking += 1
		worst.node_id = String(node.id)
		worst.finished = false
		_check(worst.available_count() >= 1, "%s: every speaking node must leave a pressable way out" % node.id)
		_check(worst.options().size() >= 1, "%s: every speaking node must list options" % node.id)
	_check(speaking >= 6, "The worst-case sweep must cover the speaking nodes, covered %d" % speaking)

	# Every walk terminates: no ring of options that can loop forever.
	var longest: int = _longest_path(scene, {"steadied_three": true})
	_check(longest > 0, "Every path through the scene must end")
	_check(longest >= 4, "The longest conversation must be worth having, got %d exchanges" % longest)

	# --- The save record. A scene still running records nothing, so an
	# interrupted conversation cannot pay out a relationship beat.
	var mid = Dialogue.new()
	mid.configure(scene, {"steadied_three": true})
	mid.choose(_index_of(mid, "hear_it"))
	_check(not mid.record().visited, "An unfinished conversation must record nothing")
	_check(mid.outcome().is_empty(), "An unfinished conversation must yield no outcome")
	mid.choose(_index_of(mid, "give_word"))
	var saved: Dictionary = mid.record()
	_check(saved.visited and saved.terminal == "burial_promise", "A finished conversation records its ending")
	_check(Dialogue.valid_record(saved), "The record it writes must be one it accepts back")
	_check(Dialogue.valid_record(Dialogue.blank_record()), "The blank record must be valid")
	_check(not Dialogue.valid_record({"visited": false, "terminal": "burial_promise", "flags": [], "taken": []}),
		"A record claiming an ending it never reached must be rejected")
	_check(not Dialogue.valid_record({"visited": true, "terminal": "x", "flags": [1], "taken": []}),
		"A record with a non-string flag must be rejected")

	if not failures.is_empty():
		for problem in failures: printerr("DIALOGUE SCENE FAIL: ", problem)
		push_error("dialogue scene test: %d of %d checks failed" % [failures.size(), checks])
		quit(1)
		return
	print("DIALOGUE SCENE PASS: %d checks; %d nodes and %d options validated, every next resolves, every node reachable, no speaking node strands the player, refusing and leaving reach endings distinct from accepting, the adventure gate opens an otherwise unreachable ending, pushing her about the crossing closes a later option with its own reason, and 11 sabotages of the authored data are each caught by name" % [checks, nodes.size(), option_total])
	quit()


## Applies one deliberate break to a copy of the real scene and requires the
## validator to report something. A sabotage that changes nothing would pass
## this silently, so the copy is compared against the original first.
func _sabotage_caught(scene: Dictionary, label: String, damage: Callable) -> void:
	var copy: Dictionary = scene.duplicate(true)
	damage.call(copy)
	if copy == scene:
		checks += 1
		failures.append("sabotage '%s' changed nothing, so it proves nothing" % label)
		return
	_check(not Dialogue.validate(copy).is_empty(), "sabotage '%s' must be caught by validate()" % label)


func _node_in(scene: Dictionary, id: String) -> Dictionary:
	for node in scene.nodes:
		if node.id == id: return node
	failures.append("test bug: no node named %s" % id)
	return {}


func _index_of(runner, option_id: String) -> int:
	for option in runner.options():
		if option.id == option_id: return int(option.index)
	failures.append("test bug: %s offers no option %s" % [runner.current().get("id", "?"), option_id])
	return -1


func _option_named(runner, option_id: String) -> Dictionary:
	for option in runner.options():
		if option.id == option_id: return option
	# A found-nothing sentinel rather than {}, so a missing option fails the
	# named check below instead of raising on a key read and hanging the run.
	return {"index": -1, "id": "", "text": "", "short": "", "available": false, "reason": "", "next": ""}


func _play(scene: Dictionary, facts: Dictionary, option_ids: Array) -> Dictionary:
	var runner = Dialogue.new()
	runner.configure(scene, facts)
	for option_id in option_ids:
		var index: int = _index_of(runner, option_id)
		if index < 0: break
		runner.choose(index)
	return {"finished": runner.finished, "outcome": runner.outcome(), "runner": runner}


## Walks every branch from the start under the given facts and returns the
## set of endings actually arrivable. This is what proves a gate opens
## something rather than merely relabelling a button.
func _reachable_endings(scene: Dictionary, facts: Dictionary) -> Dictionary:
	var runner = Dialogue.new()
	runner.configure(scene, facts)
	return _reachable_endings_from(scene, facts, runner)


func _reachable_endings_from(scene: Dictionary, facts: Dictionary, seed_runner) -> Dictionary:
	var found := {}
	var seen := {}
	var frontier: Array = [{"node": seed_runner.node_id, "taken": seed_runner.taken.duplicate(), "closed": seed_runner.closed.duplicate()}]
	while not frontier.is_empty():
		var state: Dictionary = frontier.pop_back()
		var runner = Dialogue.new()
		runner.configure(scene, facts)
		runner.node_id = state.node
		runner.taken.assign(state.taken)
		runner.closed = state.closed
		runner.finished = runner.current().get("terminal", false)
		if runner.finished:
			found[runner.outcome().id] = true
			continue
		for option in runner.options():
			if not option.available: continue
			var key: String = "%s|%s|%s" % [state.node, option.id, str(state.closed.keys())]
			if seen.has(key): continue
			seen[key] = true
			var step = Dialogue.new()
			step.configure(scene, facts)
			step.node_id = state.node
			step.taken.assign(state.taken)
			step.closed = state.closed.duplicate()
			step.choose(int(option.index))
			frontier.append({"node": step.node_id, "taken": step.taken.duplicate(), "closed": step.closed.duplicate()})
	return found


## Depth of the longest terminating walk, and 0 if any walk fails to end.
func _longest_path(scene: Dictionary, facts: Dictionary) -> int:
	return _walk_depth(scene, facts, String(scene.start), {}, 0)


func _walk_depth(scene: Dictionary, facts: Dictionary, node_id: String, visiting: Dictionary, depth: int) -> int:
	if depth > 64: return 0
	var runner = Dialogue.new()
	runner.configure(scene, facts)
	runner.node_id = node_id
	if runner.current().get("terminal", false): return depth
	if visiting.has(node_id): return depth
	var next_visiting: Dictionary = visiting.duplicate()
	next_visiting[node_id] = true
	var longest := 0
	for option in runner.options():
		if not option.available: continue
		var reached: int = _walk_depth(scene, facts, String(option.next), next_visiting, depth + 1)
		if reached == 0: return 0
		longest = maxi(longest, reached)
	return longest
