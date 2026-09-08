extends SceneTree
const Adventure = preload("res://scripts/ada_cart_adventure.gd")
const Ada = preload("res://scripts/ada_companion.gd")
class Subject extends Node2D:
	var action_time := 0.0
class Room extends RefCounted:
	var player = Subject.new()
	var rope_time := 0.0
	var rope_flight_time := 0.0
	var target := Vector2.INF
	var buttons = GridContainer.new()
	var objective = Label.new()
	var stats = Label.new()
	var cash := 402
	func _init():
		for i in 6: buttons.add_child(Button.new())
class Owner extends RefCounted:
	var room = Room.new()
	var cart_adventure = Adventure.new()
	var ada_state = Ada.new()
	var state = {"madness":{"player":10}}
	var last_position := Vector2.ZERO
	var cart
	func is_eleanor(): return false
	func tell(_line): pass
	func save_game(): last_position=cart.position_for_save()
class Controller extends "res://scripts/ada_cart_room.gd":
	func sync_view():
		if not is_instance_valid(vehicle): vehicle=Subject.new()
		if not is_active(): vehicle.position=PARK
	func _say(_beat: String,_line: String): pass
func _initialize():
	var owner = Owner.new()
	var controller = Controller.new(owner)
	owner.cart = controller
	owner.room.player.position=controller.PARK
	assert(not controller.interact())
	owner.ada_state.recruitment="recruited"
	owner.room.player.action_time=1
	controller.interact()
	assert(owner.cart_adventure.status=="not_started")
	owner.room.player.action_time=0
	assert(controller.interact() and controller.is_active())
	assert(controller.movement_speed()==0)
	controller.interact()
	controller.interact()
	assert(owner.ada_state.madness==11)
	controller.toggle_valve(0)
	controller.toggle_valve(2)
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(4).text.contains("Open"))
	controller.interact()
	assert(owner.cart_adventure.stage=="drive" and controller.movement_speed()==32)
	controller.vehicle.position=controller.STOPS[1]
	controller.tick(0)
	assert(owner.cart_adventure.checkpoints.is_empty())
	controller.vehicle.position=controller.STOPS[0]
	controller.tick(0)
	assert(owner.cart_adventure.checkpoints==[0])
	controller.vehicle.position=Vector2(350,300)
	controller.pause_or_resume()
	assert(owner.last_position==Vector2(350,300),"Parking the empty vehicle must not overwrite the saved driving point")
	controller.interact()
	assert(controller.vehicle.position==Vector2(350,300))
	for index in [1,2]:
		controller.vehicle.position=controller.STOPS[index]
		controller.tick(0)
	assert(owner.cart_adventure.stage=="return_to_camp")
	controller.interact()
	assert(owner.cart_adventure.status=="active")
	controller.vehicle.position=controller.PARK
	controller.interact()
	assert(owner.cart_adventure.status=="completed" and owner.ada_state.trust==15)
	assert(not owner.cart_adventure.romance_chosen)
	controller.interact()
	assert(owner.ada_state.trust==15)
	controller.flirt()
	controller.flirt()
	assert(owner.cart_adventure.romance_chosen and owner.ada_state.trust==20)
	assert(not controller.toggle_valve(0))
	controller.vehicle.free()
	owner.room.player.free()
	owner.room.buttons.free()
	owner.room.objective.free()
	owner.room.stats.free()
	owner.cart=null
	print("ADA CART CONTROLLER PASS: boarding, valves, physical checkpoints, pause position, one reward, separate kiss; no rendering")
	quit()
