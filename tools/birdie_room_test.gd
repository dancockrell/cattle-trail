extends SceneTree
const Ines = preload("res://scripts/ines_companion.gd")
const Birdie = preload("res://scripts/birdie_companion.gd")
class Subject extends Node2D:
	var action_time := 0.0
class Cart extends RefCounted:
	var active := false
	func is_active() -> bool: return active
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
	var ines_state = Ines.new()
	var birdie_state = Birdie.new()
	var cart = Cart.new()
	var controlled_eleanor := false
	var saves := 0
	var message := ""
	func is_eleanor() -> bool: return controlled_eleanor
	func tell(line: String): message = line
	func save_game(): saves += 1
class Controller extends "res://scripts/birdie_room.gd":
	func _sync_view(): pass # Real interaction logic, no textures or room rendering.
func _initialize():
	var owner := Owner.new()
	var controller := Controller.new(owner)
	owner.room.player.position = Vector2(110,180)
	assert(not controller.interact() and owner.saves==0,"Locked until Ines is recruited")
	owner.ines_state.recruitment = "recruited"
	owner.cart.active = true
	assert(not controller.interact(),"Locked while a companion outing is active")
	owner.cart.active = false
	owner.controlled_eleanor = true
	assert(not controller.interact(),"Locked while playing Eleanor")
	owner.controlled_eleanor = false
	owner.room.player.action_time = 1
	assert(controller.interact() and not owner.birdie_state.met and owner.saves==0,"Busy guard blocks the meet")
	owner.room.player.action_time = 0
	assert(controller.interact() and owner.birdie_state.met and owner.saves==1)
	assert(controller.flirt() and not owner.birdie_state.romance_acknowledged and owner.saves==1,"Flirt before singing is a no-op")
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Ask her to sing [E]")
	owner.room.rope_flight_time = 1
	assert(controller.interact() and not owner.birdie_state.sang,"Busy guard blocks the song")
	owner.room.rope_flight_time = 0
	assert(controller.interact() and owner.birdie_state.sang and owner.saves==2)
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Invite [E]")
	assert(controller.interact() and owner.birdie_state.recruitment=="recruited" and owner.saves==3)
	assert(owner.birdie_state.perk_record().party_assignment=="camp")
	owner.room.rope_time = 1
	assert(controller.flirt() and not owner.birdie_state.romance_acknowledged,"Busy guard blocks flirt")
	owner.room.rope_time = 0
	assert(controller.flirt() and owner.birdie_state.romance_acknowledged and owner.saves==4)
	assert(controller.flirt() and owner.saves==4 and owner.birdie_state.trust==25,"Repeated flirt must not re-save or re-award")
	owner.room.size.x = 390
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Talk")
	assert(owner.room.stats.text.contains("BIRDIE 10"))
	var restored := Birdie.new()
	assert(restored.load_dict(owner.birdie_state.to_dict()))
	owner.birdie_state = restored
	controller.sync_after_load()
	assert(controller.state==restored)
	assert(restored.sang and restored.trust==25 and owner.saves==4)
	owner.room.dispose()
	print("BIRDIE ROOM PASS: unlock, busy guards, meet/sing/recruit sequence, romance, mobile labels, save counts and restore; no rendering")
	quit()
