extends SceneTree
const Birdie = preload("res://scripts/birdie_companion.gd")
const SimpleState = preload("res://scripts/simple_companion_state.gd")
const SimpleRoom = preload("res://scripts/simple_companion_room.gd")
const Catalog = preload("res://scripts/simple_companion_catalog.gd")
class Subject extends Node2D:
	var action_time := 0.0
class Cart extends RefCounted:
	func is_active() -> bool: return false
class Room extends RefCounted:
	var player = Subject.new()
	var rope_time := 0.0
	var rope_flight_time := 0.0
	var size := Vector2(1280,720)
	var buttons := GridContainer.new()
	var objective := Label.new()
	var stats := Label.new()
	var cash := 342
	var secured := 0
	func _init(): buttons.add_child(Button.new())
	func secured_count() -> int: return secured
	func dispose():
		player.free()
		buttons.free()
		objective.free()
		stats.free()
class Owner extends RefCounted:
	var room = Room.new()
	var birdie_state = Birdie.new()
	var cart = Cart.new()
	var saves := 0
	var minutes := 720.0
	var last_line := ""
	var simple_companions: Array = []
	func is_eleanor() -> bool: return false
	func tell(line: String): last_line = line
	func save_game(): saves += 1
	func check_unlock(key: String) -> bool:
		if key == "birdie_recruited": return birdie_state.recruitment == "recruited"
		return false
class Controller extends "res://scripts/simple_companion_room.gd":
	func _sync_view(): pass # Real interaction logic, no textures or room rendering.

## A whole fake world, so a row can be run against a deliberately starved one.
func build_owner(cash: int, secured: int, minutes: float, friends: bool) -> Owner:
	var owner := Owner.new()
	owner.birdie_state.recruitment = "recruited"
	owner.room.cash = cash
	owner.room.secured = secured
	owner.minutes = minutes
	for row in Catalog.ROWS:
		var roster_state := SimpleState.new()
		roster_state.configure(row.id, row.age, row.perk_id)
		if friends:
			roster_state.met = true
			roster_state.task_done = true
			roster_state.recruitment = "recruited"
		owner.simple_companions.append({"id": row.id, "state": roster_state})
	return owner

func make_controller(owner: Owner, row: Dictionary) -> Controller:
	var state := SimpleState.new()
	state.configure(row.id, row.age, row.perk_id)
	var config: Dictionary = row.duplicate()
	config["position"] = Catalog.position_for(row)
	var controller := Controller.new(owner, config, state)
	owner.room.player.position = config.position
	return controller

## Meet, then press Talk once at the task step and report exactly what came of
## it: did the step complete, what did she say, what did it cost.
func attempt_task(owner: Owner, row: Dictionary) -> Dictionary:
	var controller := make_controller(owner, row)
	assert(controller.interact() and controller.state.met, "%s must meet on the first press" % row.id)
	var cash_before: int = owner.room.cash
	var saves_before: int = owner.saves
	owner.last_line = ""
	controller.decorate_ui()
	var goal: String = owner.room.objective.text
	controller.interact()
	return {"done": controller.state.task_done, "line": owner.last_line, "goal": goal,
		"spent": cash_before-owner.room.cash, "saved": owner.saves-saves_before}

func _initialize():
	# The cast must not be one companion with nineteen names. Count the kinds
	# first: this is the assertion that goes red if every row shares a kind,
	# old or new, and the per-kind counts below are what stops one kind from
	# quietly swallowing the catalog.
	var kinds := {}
	for r in Catalog.ROWS:
		var kind: String = r.get("task_kind","talk")
		assert(kind in SimpleRoom.TASK_KINDS, "%s uses an unknown task kind '%s'" % [r.id, kind])
		kinds[kind] = int(kinds.get(kind,0))+1
		if kind != "talk":
			assert(str(r.get("task_refusal","")) != "", "%s must carry the words she refuses with" % r.id)
			assert(str(r.get("task_want","")) != "", "%s must say what it is waiting for on the objective" % r.id)
	assert(Catalog.ROWS.size() == 19, "Expected the 19 authored rows, found %d" % Catalog.ROWS.size())
	assert(kinds.size() >= 5, "The catalog uses only %d task kind(s): %s" % [kinds.size(), str(kinds)])
	for kind in SimpleRoom.TASK_KINDS:
		assert(int(kinds.get(kind,0)) > 0, "No companion uses task kind '%s'" % kind)
		assert(int(kinds.get(kind,0)) < Catalog.ROWS.size(), "Every row is task kind '%s'" % kind)

	var owner := Owner.new()
	var row: Dictionary = Catalog.ROWS[0]
	assert(row.id == "delphine_cruz", "Test assumes catalog row 0 is Delphine; update if the catalog order changes")
	assert(row.task_kind == "spend", "Row 0's sequence assertions below assume Delphine asks for an ante")
	var state := SimpleState.new()
	state.configure(row.id, row.age, row.perk_id)
	var config: Dictionary = row.duplicate()
	config["position"] = Catalog.position_for(row)
	var controller := Controller.new(owner, config, state)
	owner.room.player.position = config.position

	assert(not controller.interact() and owner.saves==0,"Locked until Birdie is recruited")
	owner.birdie_state.recruitment = "recruited"
	owner.room.player.action_time = 1
	assert(controller.interact() and not state.met and owner.saves==0,"Busy guard blocks the meet")
	owner.room.player.action_time = 0
	assert(controller.interact() and state.met and owner.saves==1)
	assert(controller.flirt(),"Flirt is 'handled' (in range, available) even before recruitment")
	assert(not state.romance_acknowledged,"...but must not grant romance before she's actually recruited")
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text == config.task_label+" [E]")
	owner.room.rope_flight_time = 1
	assert(controller.interact() and not state.task_done,"Busy guard blocks the task")
	owner.room.rope_flight_time = 0

	# Her price, not a second press of the same button. Short of it she refuses,
	# says so, charges nothing, and saves nothing.
	owner.room.cash = int(row.task_cash)-1
	owner.last_line = ""
	assert(controller.interact() and not state.task_done,"An unpaid ante must not finish the task")
	assert(owner.last_line != "" and owner.last_line.contains("$%d" % (int(row.task_cash)-1)),
		"A refusal must name the shortfall in her own words, got: '%s'" % owner.last_line)
	assert(owner.room.cash == int(row.task_cash)-1 and owner.saves==1,"A refused press costs nothing and saves nothing")
	controller.decorate_ui()
	assert(owner.room.objective.text.contains(str(row.task_want)),"The objective must name what she is waiting for")
	owner.room.cash = 342
	assert(controller.interact() and state.task_done and owner.saves==2,"Paid, the same press works")
	assert(owner.room.cash == 342-int(row.task_cash),"The ante actually leaves the player's pocket")
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text == "Invite [E]")
	assert(controller.interact() and state.recruitment=="recruited" and owner.saves==3)
	assert(state.perk_record().party_assignment=="camp")
	owner.room.rope_time = 1
	assert(controller.flirt() and not state.romance_acknowledged,"Busy guard blocks flirt")
	owner.room.rope_time = 0
	assert(controller.flirt() and state.romance_acknowledged and owner.saves==4)
	assert(controller.flirt() and owner.saves==4 and state.trust==25,"Repeated flirt must not re-save or re-award")
	owner.room.size.x = 390
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text == "Talk")
	assert(owner.room.stats.text.contains("DELPHINE 10"))

	var restored := SimpleState.new()
	restored.configure(row.id, row.age, row.perk_id)
	assert(restored.load_dict(state.to_dict()))
	controller.state = restored
	controller.sync_after_load()
	assert(controller.state==restored)
	assert(restored.task_done and restored.trust==25 and owner.saves==4)
	owner.room.dispose()

	# Every catalog row must actually resolve to a real, distinct beat id in its own banter file,
	# not just a plausible-looking string -- this is the check, not the claim.
	for r in Catalog.ROWS:
		var path: String = r.banter_path
		assert(FileAccess.file_exists(path), "Missing banter file for %s: %s" % [r.id, path])
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(source is Dictionary and source.get("events") is Array, "Malformed banter file for %s" % r.id)
		var ids := {}
		for event in source.events: ids[event.id] = true
		for beat_key in ["meet_beat","task_beat","recruited_beat","romance_beat"]:
			assert(ids.has(r[beat_key]), "%s missing beat '%s' referenced by catalog row %s" % [path, r[beat_key], r.id])


	# Starve one axis at a time. Every row of that kind must refuse in words,
	# and every "talk" row must sail through the same world untouched, so a
	# blanket failure cannot be mistaken for a working requirement.
	# [cash, cattle secured, trail minutes, friends recruited]
	var starved := {"herd":[342,0,100000.0,true], "clock":[342,6,0.0,true],
		"friend":[342,6,100000.0,false], "spend":[0,6,100000.0,true]}
	var refusals := {}
	var refused_count := 0
	var free_count := 0
	for kind in starved:
		var setup: Array = starved[kind]
		for r in Catalog.ROWS:
			var world := build_owner(int(setup[0]), int(setup[1]), float(setup[2]), bool(setup[3]))
			var result := attempt_task(world, r)
			var row_kind: String = r.get("task_kind","talk")
			if row_kind == kind:
				assert(not result.done, "%s (%s) completed with its requirement unmet" % [r.id, kind])
				assert(result.line != "", "%s refused silently, which is worse than no requirement" % r.id)
				assert(not result.line.contains("{"), "%s left a placeholder unfilled: %s" % [r.id, result.line])
				assert(result.spent == 0 and result.saved == 0, "%s charged or saved on a refusal" % r.id)
				assert(result.goal.contains(str(r.task_want)), "%s does not show what it wants on the objective" % r.id)
				refusals[result.line] = true
				refused_count += 1
			elif row_kind == "talk":
				assert(result.done, "%s asks for nothing and must not be blocked by the '%s' world" % [r.id, kind])
				free_count += 1
			world.room.dispose()
	assert(refused_count == Catalog.ROWS.size()-int(kinds.get("talk",0)),
		"Expected every non-talk row to be blocked once, saw %d" % refused_count)
	assert(refusals.size() >= 4, "Only %d distinct refusal line(s) across the cast" % refusals.size())

	# ...and the same rows finish once the world gives them what they asked for,
	# so nothing above has traded a uniform cast for an uncompletable one.
	var generous := build_owner(9999, 6, 100000.0, true)
	var completed := 0
	var charged := 0
	for r in Catalog.ROWS:
		var result := attempt_task(generous, r)
		assert(result.done, "%s cannot be completed by a player who does what she asks" % r.id)
		assert(result.saved == 1, "%s must save exactly once on the task beat" % r.id)
		assert(result.spent == int(r.get("task_cash",0)), "%s charged %d, row says %d" % [r.id, result.spent, int(r.get("task_cash",0))])
		charged += result.spent
		completed += 1
	generous.room.dispose()

	print("SIMPLE COMPANION ROOM PASS: unlock gate, busy guards, meet/task/recruit sequence, romance, mobile labels, save/restore across the catalog; no rendering; %d rows across %d task kinds %s; %d refusals in words (%d distinct), %d talk rows unblocked, %d completed when asked, $%d taken" % [Catalog.ROWS.size(), kinds.size(), str(kinds), refused_count, refusals.size(), free_count, completed, charged])
	quit()
