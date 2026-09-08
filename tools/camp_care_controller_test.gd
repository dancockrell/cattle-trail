extends SceneTree
const Care = preload("res://scripts/camp_care_room.gd")
const Recovery = preload("res://scripts/camp_recovery.gd")
const State = preload("res://scripts/companion_state.gd")
class Subject extends Node2D:
	var action_time := 0.0
class Room extends RefCounted:
	var player = Subject.new()
	var rope_time := 0.0
	var rope_flight_time := 0.0
	var buttons := GridContainer.new()
	var stats := Label.new()
	var cash := 342
	func _init():
		for i in range(5): buttons.add_child(Button.new())
	func say_once(_a,_b,_c,_d,_e): pass
	func dispose():
		player.free()
		buttons.free()
		stats.free()
class Owner extends RefCounted:
	var room = Room.new()
	var state = State.new()
	var camp_recovery = Recovery.new()
	var minutes := 720.0
	var cart_adventure = {"status":"completed"}
	var lantern_adventure = {"status":"completed"}
	var ada_state = {"recruitment":"recruited","madness":40.0}
	var mechanic = {"ada":Node2D.new()}
	var saves := 0
	func is_eleanor(): return false
	func active_actor(): return room.player
	func tell(_s): pass
	func say_event(_a,_b): pass
	func save_game(): saves+=1
func _initialize():
	var owner = Owner.new()
	var care = Care.new(owner)
	owner.state.recruitment="recruited"
	owner.state.party_assignment="camp"
	owner.state.adventure_status="completed"
	owner.state.events.adventure_completed=true
	owner.state.madness.player=50.0
	owner.state.madness.eleanor=40.0
	owner.mechanic.ada.position=Vector2(220,280)
	owner.room.player.position=owner.mechanic.ada.position
	assert(care.rest())
	assert(owner.minutes==750 and owner.state.madness.player==40 and owner.ada_state.madness==30)
	assert(owner.camp_recovery.next_available.has("ada_mercer"),"Canonical companion identity owns recovery cooldown")
	assert(owner.state.relationship_stage=="acquainted")
	assert(not care.rest())
	owner.room.player.position=Vector2(148,127)
	assert(not care.rest(),"Changing partner cannot bypass player cooldown")
	owner.minutes=2160
	assert(care.rest())
	assert(owner.state.madness.player==27 and owner.state.madness.eleanor==30)
	assert(owner.state.rest_count==1)
	var legacy := {"companion":owner.state.to_dict()}
	var migrated = Care.restored_recovery(legacy)
	assert(migrated!=null and migrated.next_available.player==owner.state.next_rest_minute and migrated.next_available.eleanor==owner.state.next_rest_minute)
	legacy.camp_recovery={"version":1,"next_available":{}}
	assert(Care.restored_recovery(legacy)==null,"Explicit save cannot drop prior Eleanor cooldown")
	legacy.camp_recovery=migrated.to_dict()
	assert(Care.restored_recovery(legacy)!=null)
	legacy.camp_recovery.next_available.player=NAN
	assert(Care.restored_recovery(legacy)==null)
	owner.minutes=4000
	owner.cart_adventure.status="paused"
	assert(not care.rest())
	owner.cart_adventure.status="completed"
	owner.lantern_adventure.status="paused"
	assert(not care.rest())
	owner.lantern_adventure.status="completed"
	owner.state.events.adventure_completed=false
	var before: Dictionary=owner.camp_recovery.to_dict()
	assert(not care.rest() and owner.camp_recovery.to_dict()==before,"Failed Eleanor rest does not spend generic cooldown")
	owner.room.player.position=owner.mechanic.ada.position
	care.decorate_ui()
	assert("Ada" in owner.room.buttons.get_child(4).text)
	assert("ADA 30" in owner.room.stats.text,"Show the nearby companion's current madness")
	owner.room.player.position=Vector2(148,127)
	care.decorate_ui()
	assert(not "Ada" in owner.room.buttons.get_child(4).text)
	owner.room.dispose()
	owner.mechanic.ada.free()
	print("CAMP CARE CONTROLLER PASS: Ada rest, shared partner cooldown, Eleanor bonus, staged failure, migration, pending outing, UI reset")
	quit()
