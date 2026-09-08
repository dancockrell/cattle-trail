extends SceneTree
const Factory = preload("res://scripts/character_factory.gd")
class Room extends "res://scripts/room.gd":
	func refresh() -> void: pass
	func say_once(_beat: String, _actor: Node2D, _speaker: String, _text: String, _importance := 1) -> void: pass
class Companion extends "res://scripts/companion_room.gd":
	func _init(owner_room: Control): room = owner_room
class Cow extends Node2D:
	var secured := false
func _initialize():
	# Actual catch and perk dispatch methods, without adding a room to the tree.
	var room = Room.new()
	room.player = Node2D.new()
	var cow = Cow.new()
	room.cows.append(cow)
	room.companion = Companion.new(room)
	room.catch_rope(cow)
	assert(room.rope_time==18)
	var variants := []
	for i in 3:
		variants.append({"id":"fixture_rancher%d"%i,"age":24,"family":"rancher","atlas":"res://fixture.png","rect":[i*64,0,64,64],"status":"approved"})
	var records = Factory.new().create_roster({"variants":variants},"test",3)
	assert(room.companion.generated_roster.import_records(records))
	room.catch_rope(cow)
	assert(room.rope_time==18, "Available companions grant no perk")
	room.companion.generated_roster.recruit(records[0].id,true)
	room.catch_rope(cow)
	assert(room.rope_time==20)
	for record in records: room.companion.generated_roster.recruit(record.id,true)
	room.catch_rope(cow)
	assert(room.rope_time==22, "Three helpers still obey the four-second cap")
	var saved = room.companion.generated_roster.to_json()
	assert(room.companion.generated_roster.load_json(saved))
	room.catch_rope(cow)
	assert(room.rope_time==22)
	room.player.free()
	cow.free()
	room.companion.room = null
	room.free()
	print("FIELD PERK CONTROLLER PASS: actual catch duration, recruitment, stacking cap, persisted roster; no rendering")
	quit()
