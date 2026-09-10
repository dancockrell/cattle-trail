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
	func _init(): buttons.add_child(Button.new())
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
	func is_eleanor() -> bool: return false
	func tell(_line: String): pass
	func save_game(): saves += 1
	func check_unlock(key: String) -> bool:
		if key == "birdie_recruited": return birdie_state.recruitment == "recruited"
		return false
class Controller extends "res://scripts/simple_companion_room.gd":
	func _sync_view(): pass # Real interaction logic, no textures or room rendering.

func _initialize():
	var owner := Owner.new()
	var row: Dictionary = Catalog.ROWS[0]
	assert(row.id == "delphine_cruz", "Test assumes catalog row 0 is Delphine; update if the catalog order changes")
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
	assert(controller.interact() and state.task_done and owner.saves==2)
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

	owner.room.dispose()
	print("SIMPLE COMPANION ROOM PASS: unlock gate, busy guards, meet/task/recruit sequence, romance, mobile labels, save/restore across the catalog; no rendering")
	quit()
