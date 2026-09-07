# REJECTED BY USER. Historical experiment only; do not integrate or extend.
extends Node2D

# Diagnostic only: rigid source textures and explicit foot contact, never stand-in shapes.
var clock_time := 0.0
var textures := {}
var heading := Vector2(1,-1).normalized()
const CYCLE := 0.96
const STRIDE := 18.0
const DUTY := 0.75
var legs := [
	{"id":"far_hind","root":Vector2(-18,-24),"ground":Vector2(-21,-4),"offset":0.5},
	{"id":"far_fore","root":Vector2(5,-29),"ground":Vector2(5,-10),"offset":0.25},
	{"id":"near_hind","root":Vector2(-10,-22),"ground":Vector2(-12,0),"offset":0.0},
	{"id":"near_fore","root":Vector2(14,-27),"ground":Vector2(15,-6),"offset":0.75}]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rig-trial/rig.json"))
	for key in spec.parts: textures[key] = load(spec.parts[key].texture)

func foot_local(leg: Dictionary, seconds: float) -> Vector2:
	var phase := fposmod(seconds/CYCLE+float(leg.offset),1.0)
	var travel: float
	var lift := 0.0
	if phase < DUTY:
		travel = STRIDE*(DUTY*0.5-phase)
	else:
		var recovery := (phase-DUTY)/(1.0-DUTY)
		travel = lerpf(-STRIDE*DUTY*0.5,STRIDE*DUTY*0.5,recovery)
		lift = sin(recovery*PI)*4.0
	return Vector2(leg.ground)+heading*travel+Vector2(0,-lift)

func _process(delta: float) -> void:
	clock_time += delta
	position += heading*(STRIDE/CYCLE)*delta
	queue_redraw()

func segment(key: String, start: Vector2, finish: Vector2, width: float) -> void:
	var delta := finish-start
	draw_set_transform(start.round(),delta.angle()-PI/2)
	draw_texture_rect(textures[key],Rect2(-width/2,-1,width,delta.length()+2),false)
	draw_set_transform(Vector2.ZERO)

func draw_leg(leg: Dictionary) -> void:
	var hip: Vector2 = leg.root
	var foot := foot_local(leg,clock_time)
	# Projected pixel-art joints: a long 2D equal-bone solver exaggerates bends
	# because the source is foreshortened. Keep support legs almost straight.
	var phase := fposmod(clock_time/CYCLE+float(leg.offset),1.0)
	var recovery_bend := sin((phase-DUTY)/(1.0-DUTY)*PI)*3.0 if phase>DUTY else 0.0
	var bend := Vector2(-2,0) if "hind" in leg.id else Vector2(1.5,-0.5)
	var knee := hip.lerp(foot,0.52)+bend+heading*recovery_bend
	segment(leg.id+"_upper",hip,knee,6.0)
	segment(leg.id+"_lower",knee,foot,4.5)

func _draw() -> void:
	if textures.is_empty(): return
	draw_leg(legs[0]); draw_leg(legs[1])
	draw_leg(legs[2]); draw_leg(legs[3])
	draw_texture_rect(textures.body,Rect2(-26,-64,52,54),false)
