extends SceneTree
const Ada = preload("res://scripts/ada_companion.gd")
const Lantern = preload("res://scripts/lantern_adventure.gd")
class Subject extends Node2D:
	var action_time := 0.0
class Room extends RefCounted:
	var player = Subject.new()
	var rope_time := 0.0
	var rope_flight_time := 0.0
	var buttons := GridContainer.new()
	var objective := Label.new()
	func _init() -> void:
		for index in range(3): buttons.add_child(Button.new())
	func dispose() -> void:
		player.free()
		buttons.free()
		objective.free()
class Owner extends RefCounted:
	var room = Room.new()
	var ada_state = Ada.new()
	var lantern_adventure = Lantern.new()
	var saves := 0
	func is_eleanor() -> bool: return false
	func tell(_line) -> void: pass
	func save_game() -> bool:
		saves += 1
		return true
class Controller extends "res://scripts/mechanic_room.gd":
	func _sync_view() -> void: pass # No room scene, texture loading or rendering.
func _initialize() -> void:
	var owner := Owner.new()
	var controller := Controller.new(owner)
	owner.room.player.position = Vector2(230,145)
	assert(not controller.interact())
	owner.lantern_adventure.status = "completed"
	assert(controller.interact() and owner.ada_state.met)
	owner.room.player.position = Vector2(148,127)
	assert(controller.interact() and owner.ada_state.repair.regulator_recovered)
	owner.room.player.position = Vector2(280,200)
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(1).text=="Feed [L]")
	assert(controller.toggle_vent())
	controller.tick(3)
	assert(controller.interact() and owner.ada_state.repair.regulator_installed)
	controller.toggle_vent()
	controller.toggle_feed()
	controller.tick(3)
	controller.toggle_feed()
	assert(controller.interact() and owner.ada_state.repair.completed)
	assert(not controller.toggle_feed(),"Completed machine must release contextual controls")
	owner.room.player.position = Vector2(230,145)
	controller.decorate_ui()
	assert(owner.room.buttons.get_child(0).text=="Invite [E]")
	assert(controller.interact() and owner.ada_state.recruitment=="recruited")
	var trust: int = owner.ada_state.trust
	controller.interact()
	assert(owner.ada_state.trust==trust)
	var restored := Ada.new()
	assert(restored.load_dict(owner.ada_state.to_dict()))
	owner.ada_state = restored
	controller.sync_after_load()
	assert(controller.state==restored and controller.repair.completed)
	owner.room.dispose()
	print("MECHANIC CONTROLLER PASS: unlock, retrieval, valve controls, repair, explicit invite, restore; no rendering")
	quit()
