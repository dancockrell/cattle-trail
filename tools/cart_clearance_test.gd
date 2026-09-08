extends SceneTree
const Room = preload("res://scripts/room.gd")
func _initialize():
	var room = Room.new()
	assert(room.limit_position(Vector2(0,250)).x==24)
	assert(room.limit_position(Vector2(0,250),15).x==39)
	var point: Vector2 = room.limit_position(Vector2(90,90),15)
	assert(not room.WAGON_FOOTPRINT.grow(15).has_point(point),"Cart exits must remain outside wagon after world clamping")
	room.solid_scenery=[{"position":[300,200],"collision_radius":10}]
	assert(is_equal_approx(room.limit_position(Vector2(301,200)).distance_to(Vector2(300,200)),17))
	assert(is_equal_approx(room.limit_position(Vector2(301,200),15).distance_to(Vector2(300,200)),32))
	for stop in [Vector2(330,300),Vector2(445,300),Vector2(405,235)]:
		assert(room.limit_position(stop,15).distance_to(stop)<24,"Route lantern remains reachable with cart clearance")
	room.free()
	print("CART CLEARANCE PASS: default footprints preserved, wagon exit, wider scenery clearance, reachable route; no rendering")
	quit()
