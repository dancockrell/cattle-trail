extends SceneTree
const Ines = preload("res://scripts/ines_companion.gd")
const Perks = preload("res://scripts/companion_perks.gd")
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
	var cart_adventure := {"status":"available"}
	var cart = Cart.new()
	var controlled_eleanor := false
	var saves := 0
	var message := ""
	func is_eleanor() -> bool: return controlled_eleanor
	func tell(line: String): message = line
	func save_game(): saves += 1
	func field_perk(stat: String) -> float:
		return Perks.value([ines_state.perk_record()],"field",stat,0.0)
class Controller extends "res://scripts/ines_room.gd":
	func _sync_view(): pass # Real interaction logic, no textures or room rendering.
func _initialize():
	var owner := Owner.new()
	var controller := Controller.new(owner)
	owner.room.player.position = Vector2(405,105)
	assert(not controller.interact() and owner.saves==0)
	owner.cart_adventure.status = "completed"
	owner.cart.active = true
	assert(not controller.interact())
	owner.cart.active = false
	owner.controlled_eleanor = true
	assert(not controller.interact())
	owner.controlled_eleanor = false
	owner.room.player.action_time = 1
	assert(controller.interact() and not owner.ines_state.met and owner.saves==0)
	owner.room.player.action_time = 0
	assert(controller.interact() and owner.ines_state.met and owner.saves==1)
	assert(controller.interact() and not owner.ines_state.trail_completed and owner.saves==1)
	assert(controller.flirt() and not owner.ines_state.romance_acknowledged and owner.saves==1)
	owner.room.player.position = Vector2(445,285)
	owner.room.rope_flight_time = 1
	assert(controller.interact() and owner.ines_state.clues.is_empty())
	owner.room.rope_flight_time = 0
	for point in [Vector2(445,285),Vector2(340,90),Vector2(580,285)]:
		owner.room.player.position = point
		var before: int = owner.saves
		assert(controller.interact() and owner.saves==before+1)
		assert(controller.interact() and owner.saves==before+1,"Repeated clue must not save or award twice")
	assert(owner.ines_state.clues.size()==3 and not owner.ines_state.trail_completed)
	owner.room.player.position = Vector2(405,105)
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Compare clues [E]")
	assert(controller.interact() and owner.ines_state.trail_completed and owner.saves==5)
	assert(owner.ines_state.recruitment=="available","Return completion must not silently recruit")
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Welcome [E]")
	assert(controller.interact() and owner.ines_state.recruitment=="recruited" and owner.saves==6)
	assert(owner.ines_state.party_assignment=="camp" and not owner.ines_state.romance_acknowledged)
	assert(controller.notice_radius()==24)
	assert(controller.interact() and owner.ines_state.party_assignment=="field" and owner.saves==7)
	assert(controller.notice_radius()==36,"Authored Spirit Sense must extend warning distance")
	owner.room.player.position = Vector2(475,285)
	controller.decorate_ui()
	assert(owner.room.objective.text.begins_with("SPIRIT SENSE"))
	assert(not controller.interact(),"Warning range must not extend clue interaction reach")
	owner.room.player.position = Vector2(405,105)
	owner.room.rope_time = 1
	assert(controller.flirt() and not owner.ines_state.romance_acknowledged)
	owner.room.rope_time = 0
	assert(controller.flirt() and owner.ines_state.romance_acknowledged and owner.saves==8)
	assert(controller.flirt() and owner.saves==8 and owner.ines_state.trust==35)
	assert(controller.interact() and owner.ines_state.party_assignment=="camp" and owner.saves==9)
	owner.room.size.x = 390
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Assign field")
	var restored := Ines.new()
	assert(restored.load_dict(owner.ines_state.to_dict()))
	owner.ines_state = restored
	controller.sync_after_load()
	assert(controller.state==restored and controller.notice_radius()==24)
	assert(restored.clues.size()==3 and restored.trust==35 and owner.saves==9)
	owner.room.dispose()
	print("INES ROOM PASS: unlock, busy guards, distinct clues, explicit recruitment and romance, field warnings, mobile labels, save counts and restore; no rendering")
	quit()
