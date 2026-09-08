extends SceneTree
const State = preload("res://scripts/companion_state.gd")
const Adventure = preload("res://scripts/lantern_adventure.gd")

class Subject extends Node2D:
	var action_time := 0.0
	func pose(_moving: bool, _heading := Vector2.ZERO, _speed := 0.0) -> void: pass

class Room extends RefCounted:
	var player = Subject.new()
	var eleanor = Subject.new()
	var cows := [Subject.new(),Subject.new(),Subject.new()]
	var rope_time := 0.0
	var rope_flight_time := 0.0
	var target := Vector2.INF
	func limit_position(p: Vector2) -> Vector2: return p
	func say_once(_id, _actor, _speaker, _text, _priority) -> void: pass
	func dispose() -> void:
		player.free()
		eleanor.free()
		for cow in cows: cow.free()

class Owner extends RefCounted:
	var room = Room.new()
	var state = State.new()
	var lantern_adventure = Adventure.new()
	var saves := 0
	func tell(_text: String) -> void: pass
	func save_game() -> bool:
		saves += 1
		return true

class Controller extends "res://scripts/lantern_room.gd":
	func _sync_view() -> void: pass # Exercise controller only: no scene or texture loads.

func _initialize() -> void:
	var owner := Owner.new()
	owner.state.recruit(true,true)
	owner.state.begin_adventure()
	for id in ["0","1","2"]: owner.state.steady_cattle(id)
	owner.state.finish_adventure()
	var controller := Controller.new(owner)
	owner.room.player.position = Vector2(148,127)
	assert(controller.switch_character())
	assert(owner.lantern_adventure.controlled_actor=="eleanor")
	owner.room.eleanor.position = Vector2(400,220)
	controller.interact()
	controller.interact()
	assert(owner.state.madness.eleanor==16.0,"Spirit approach applies one saved stress event")
	controller.tick(0.1)
	assert(owner.state.madness.eleanor==16.0,"Settling cannot apply the approach event again")
	assert(owner.lantern_adventure.stage=="guide_cattle")
	for index in range(3):
		var cow: Node2D = owner.room.cows[index]
		owner.room.eleanor.position = cow.position+Vector2(20,0)
		controller.interact()
		assert(controller.owns_cow(cow),"Base herd update must not reset follower animation")
		assert(owner.lantern_adventure.guided_cattle.size()==index,"Talk selects; it does not award crossing")
		for step in range(600):
			owner.room.eleanor.position = owner.room.eleanor.position.move_toward(Vector2(500,220),28.0/30)
			controller.tick(1.0/30)
			if owner.lantern_adventure.guided_cattle.size()>index: break
		assert(owner.lantern_adventure.guided_cattle.size()==index+1,"Physical follow travel must reach east arrival")
		assert(not controller.owns_cow(cow))
	assert(owner.lantern_adventure.stage=="return_to_wagon")
	assert(controller.switch_character())
	assert(owner.lantern_adventure.status=="paused")
	controller.sync_after_load()
	assert(controller.switch_character())
	owner.room.eleanor.position = Vector2(148,127)
	var before: int = owner.state.trust
	controller.interact()
	assert(owner.lantern_adventure.milestone_completed and owner.state.trust==before+10)
	controller.interact()
	assert(owner.state.trust==before+10 and owner.state.relationship_stage=="trusted")
	owner.room.dispose()
	print("LANTERN CONTROLLER PASS: entry, physical following, animation ownership, pause resume, one reward; no rendering")
	quit()
