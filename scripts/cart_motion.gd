extends RefCounted
## Velocity integrator. Caller performs collision movement and returns actual velocity.
const MAX_SPEED := 32.0
const ACCELERATION := 48.0
const BRAKING := 64.0
const TURN_RATE := 2.5
var heading := Vector2.RIGHT
var speed := 0.0

func _finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

func step(input: Vector2, delta: float) -> Vector2:
	if not is_finite(delta) or delta <= 0.0: return heading * speed
	# Analytical integration consumes the full elapsed time without an unbounded loop.
	# Invalid input behaves like released controls, permitting safe braking.
	var magnitude := input.length() if _finite_vector(input) else 0.0
	if not is_finite(magnitude) or magnitude <= 0.00001:
		speed = maxf(0.0, speed - BRAKING * minf(delta, speed / BRAKING))
		return heading * speed
	var desired := input / magnitude
	var turn := heading.angle_to(desired)
	var max_turn := TURN_RATE * minf(delta, PI / TURN_RATE)
	heading = heading.rotated(clampf(turn, -max_turn, max_turn)).normalized()
	speed = minf(MAX_SPEED, speed + ACCELERATION * minf(delta, MAX_SPEED / ACCELERATION))
	return heading * speed

func stop() -> void:
	speed = 0.0

func collision(actual_velocity: Vector2) -> void:
	if not _finite_vector(actual_velocity):
		speed = 0.0
		return
	# Keep steering heading; backward/sideways collision response cannot turn the cart.
	# Projection makes blocked motion stop and sliding motion reduce forward speed.
	var forward := actual_velocity.dot(heading)
	speed = clampf(forward, 0.0, speed) if is_finite(forward) else 0.0
