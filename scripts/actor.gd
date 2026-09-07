extends Node2D

var art: AnimatedSprite2D
var kind: String
var velocity := Vector2.ZERO
var secured := false
var base_speed := 36.0

func configure(id: String, spec: Dictionary) -> void:
	kind = id
	art = AnimatedSprite2D.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.centered = false
	art.position = -Vector2(spec.anchor[0], spec.anchor[1])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var texture := load(spec.texture) as Texture2D
	for clip_name in spec.clips:
		var clip: Dictionary = spec.clips[clip_name]
		frames.add_animation(clip_name)
		frames.set_animation_speed(clip_name, clip.fps)
		frames.set_animation_loop(clip_name, clip.loop)
		for index in clip.frames:
			var rect: Array = spec.frames[int(index)].atlas_rect
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(rect[0], rect[1], rect[2], rect[3])
			frames.add_frame(clip_name, region)
	art.sprite_frames = frames
	add_child(art)
	art.play("idle")

func pose(moving: bool, direction: Vector2 = Vector2.ZERO) -> void:
	if absf(direction.x) > 0.1:
		# Reflect the complete anchored sprite, not its texture within the atlas cell.
		art.scale.x = -1.0 if direction.x < 0.0 else 1.0
		var anchor := absf(art.position.x)
		art.position.x = anchor if direction.x < 0.0 else -anchor
	var clip := "ride" if kind == "rider" else "walk"
	if not moving or not art.sprite_frames.has_animation(clip):
		clip = "idle"
	if art.animation != clip:
		art.play(clip)
