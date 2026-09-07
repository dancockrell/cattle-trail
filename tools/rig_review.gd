# REJECTED BY USER. Historical experiment only; do not integrate or extend.
extends SceneTree

var elapsed := 0.0
var rig: Node2D

func _initialize() -> void:
	root.set_deferred("size",Vector2i(1280,720))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var stage := Node2D.new()
	viewport.add_child(stage)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(1280,720)
	root.add_child(display)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/ground-v3.png")
	ground.centered = false
	stage.add_child(ground)
	rig = load("res://scripts/rig_trial.gd").new()
	rig.position = Vector2(230,260)
	stage.add_child(rig)
	var label := Label.new()
	label.text = "CUTOUT RIG TRIAL / real sprite parts / northeast only / not gameplay"
	label.position = Vector2(16,16)
	stage.add_child(label)
	# During each stance, world displacement cancels local hoof displacement.
	for leg in rig.legs:
		var t := fposmod(-float(leg.offset),1.0)*0.96+0.1
		var a: Vector2 = rig.foot_local(leg,t)+rig.heading*(18.0/0.96)*t
		var b: Vector2 = rig.foot_local(leg,t+0.1)+rig.heading*(18.0/0.96)*(t+0.1)
		assert(a.distance_to(b)<0.001,"Planted foot must hold world contact")

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 5.76:
		print("RIG TRIAL: four stance tracks hold world contact; visual assembly remains under review")
		quit()
	return false
