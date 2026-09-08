extends SceneTree
const Motion = preload("res://scripts/cart_motion.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var c := Motion.new()
	check(c.heading == Vector2.RIGHT and c.speed == 0.0,"Initial state")
	var v := c.step(Vector2.RIGHT,0.1)
	check(is_equal_approx(v.x,4.8) and is_zero_approx(v.y),"Acceleration")
	c.step(Vector2.RIGHT,10.0)
	check(is_equal_approx(c.speed,32.0),"Long frame consumes all time and caps speed")
	var before := c.heading
	c.step(Vector2.DOWN,0.1)
	check(absf(before.angle_to(c.heading)) <= 0.25001 and c.heading.y > 0.0,"Steering rate")
	check(is_equal_approx(c.heading.length(),1.0),"Unit heading")
	var held := c.heading
	c.step(Vector2.ZERO,0.1)
	check(is_equal_approx(c.speed,25.6) and c.heading.is_equal_approx(held),"Brake without steering")
	c.step(Vector2.ZERO,100.0)
	check(c.speed == 0.0 and c.heading.is_equal_approx(held),"Long brake holds heading")
	c = Motion.new()
	c.step(Vector2.RIGHT,1.0)
	c.step(Vector2.LEFT,0.1)
	check(c.heading.x > 0.9 and absf(c.heading.angle()) <= 0.25001,"Reverse input turns gradually")
	c.step(Vector2.LEFT,10.0)
	check(c.heading.is_equal_approx(Vector2.LEFT),"Long elapsed turn reaches target")
	var saved_speed := c.speed
	var saved_heading := c.heading
	for delta in [0.0,-1.0,NAN,INF]:
		v = c.step(Vector2.UP,delta)
		check(c.speed == saved_speed and c.heading == saved_heading and is_finite(v.x) and is_finite(v.y),"Invalid delta safely ignored")
	v = c.step(Vector2(NAN,1),0.1)
	check(is_equal_approx(c.speed,25.6) and is_finite(v.x) and is_finite(v.y),"Invalid input safely brakes")
	v = c.step(Vector2(INF,0),0.1)
	check(is_equal_approx(c.speed,19.2) and is_finite(v.x),"Infinite input safely brakes")
	c.collision(c.heading * 8.0)
	check(is_equal_approx(c.speed,8.0) and c.heading == saved_heading,"Collision adopts reduced forward speed")
	c.collision(c.heading * 100.0)
	check(is_equal_approx(c.speed,8.0),"Collision cannot accelerate")
	c.collision(-c.heading * 5.0)
	check(c.speed == 0.0 and c.heading == saved_heading,"Collision cannot reverse heading")
	c.step(Vector2.LEFT,0.2)
	c.collision(Vector2(INF,0))
	check(c.speed == 0.0,"Invalid collision stops safely")
	c.step(Vector2.LEFT,0.2)
	var stop_heading := c.heading
	c.stop()
	check(c.speed == 0.0 and c.heading == stop_heading,"Explicit stop preserves heading")
	var large := Motion.new()
	var small := Motion.new()
	large.step(Vector2.DOWN,1.0)
	for i in range(10): small.step(Vector2.DOWN,0.1)
	check(is_equal_approx(large.speed,small.speed) and large.heading.is_equal_approx(small.heading),"Fixed target endpoint independent of subdivision")
	if failures == 0: print("CART MOTION PASS: %d checks; acceleration, braking, steering, reverse, finite input and collision" % checks)
	quit(1 if failures else 0)
