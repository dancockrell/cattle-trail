extends SceneTree
const RoomScript = preload("res://scripts/room.gd")
class Bubble extends Control:
	var remaining := 0.0
	var lines: Array[String] = []
	func say(_actor, _name, text: String, _height, _importance) -> bool:
		if remaining>0: return false
		lines.append(text)
		remaining = 2.0
		return true
	func tick(delta: float,_view) -> void: remaining = maxf(0,remaining-delta)

func _initialize() -> void:
	# Do not add the room to a SceneTree: exercise speech delivery without _ready,
	# asset loading, scene creation, gameplay simulation or rendering.
	var room = RoomScript.new()
	var speaker := Node2D.new()
	var bubble := Bubble.new()
	room.speech = bubble
	room.say_once("first",speaker,"ELEANOR","First",2)
	room.say_once("second",speaker,"ELEANOR","Second",2)
	room.say_once("second",speaker,"ELEANOR","Duplicate",2)
	assert(room.spoken_beats.has("first") and not room.spoken_beats.has("second"))
	room._process(2.1)
	assert(bubble.lines==["First","Second"] and room.spoken_beats.has("second"))
	room._process(2.1)
	assert(bubble.lines.size()==2,"Pending duplicate must never deliver")
	room.say_once("third",speaker,"ELEANOR","Third",2)
	room.say_once("stale",speaker,"ELEANOR","Stale",2)
	room._process(7.0)
	assert(not room.spoken_beats.has("stale") and bubble.lines.size()==3)
	room.say_once("fourth",speaker,"ELEANOR","Fourth",2)
	var gone := Node2D.new()
	room.say_once("gone",gone,"RUSTLER","Gone",2)
	gone.free()
	room._process(2.1)
	assert(not room.spoken_beats.has("gone"),"Expired speaker cannot be dereferenced or marked spoken")
	room.free()
	speaker.free()
	bubble.free()
	print("BANTER DELIVERY PASS: deferred history, deduplication, expiry, missing speaker; no rendering")
	quit()
