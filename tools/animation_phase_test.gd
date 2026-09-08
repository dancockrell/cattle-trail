extends SceneTree
const Phase = preload("res://scripts/animation_phase.gd")

func _initialize() -> void:
	var uneven := [0.1,0.4,0.1,0.4]
	var phase := Phase.phase_at(uneven,1,0.5)
	assert(is_equal_approx(phase,0.3),"Halfway through the long second hold is 30% of elapsed cycle time")
	var destination := Phase.frame_at([0.25,0.25,0.25,0.25],phase)
	assert(int(destination.x)==1 and is_equal_approx(destination.y,0.2))
	assert(Phase.frame_at([0.2,0.8],1.0)==Vector2.ZERO,"Completed cycle wraps cleanly")
	assert(Phase.frame_at([0.2,0.8],0.2)==Vector2(1,0),"Exact boundary selects next frame")
	for value in [0.0,0.01,0.1,0.3,0.49,0.7,0.99]:
		var selected := Phase.frame_at(uneven,value)
		assert(is_equal_approx(Phase.phase_at(uneven,int(selected.x),selected.y),value))
	print("ANIMATION PHASE PASS: unequal holds, directional remapping, cycle boundaries and roundtrip")
	quit()
