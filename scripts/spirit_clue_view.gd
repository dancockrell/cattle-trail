extends Node2D
## Static, authored landmark artwork. Encounter state controls visibility only.
var configured := false

func configure(bundle: Dictionary, positions: Dictionary) -> void:
	if configured: return
	var texture := load(str(bundle.get("texture", ""))) as Texture2D
	if texture == null: return
	var anchor: Array = bundle.get("anchor", [128,128])
	var density := float(bundle.get("pixels_per_world_unit", 8))
	if not is_finite(density) or density <= 0: return
	for id in bundle.get("clues", {}):
		if not positions.has(id): continue
		var entry: Dictionary = bundle.clues[id]
		var rect: Array = entry.region
		var region := AtlasTexture.new()
		region.atlas = texture
		region.region = Rect2(rect[0], rect[1], rect[2], rect[3])
		var sprite := Sprite2D.new()
		sprite.name = str(id)
		sprite.texture = region
		sprite.centered = false
		sprite.offset = -Vector2(anchor[0], anchor[1])
		sprite.scale = Vector2.ONE / density
		sprite.position = positions[id].position
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	configured = true
	visible = false

func sync_visible(show_landmarks: bool) -> void:
	visible = configured and show_landmarks
