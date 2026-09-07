extends Node2D

signal action_event(event_name: String)

var art: AnimatedSprite2D
var kind: String
var velocity := Vector2.ZERO
var secured := false
var base_speed := 36.0
var facing := "east"
var directional := false
var action_time := 0.0
var nominal_speed := 36.0
var facing_bias := 1.2
var clip_events: Dictionary = {}
var active_clip := ""
var event_fired := false

func configure(id: String, spec: Dictionary) -> void:
	kind = id
	clip_events = spec.get("action_events", {})
	nominal_speed = float(spec.get("locomotion", {}).get("nominal_speed", 72.0 if id == "rider" else 36.0))
	facing_bias = float(spec.get("locomotion", {}).get("facing_bias", 1.2))
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
	directional = frames.has_animation("walk_east")
	add_child(art)
	art.play("idle")

func pose(moving: bool, direction: Vector2 = Vector2.ZERO, speed: float = -1.0) -> void:
	if action_time > 0: return
	if directional:
		if direction.length_squared() > 0.01:
			# Retain the current axis near diagonals to avoid one-frame facing chatter.
			var horizontal := facing in ["east", "west"]
			if horizontal and absf(direction.y) <= absf(direction.x) * facing_bias:
				facing = "east" if direction.x >= 0 else "west"
			elif not horizontal and absf(direction.x) <= absf(direction.y) * facing_bias:
				facing = "south" if direction.y >= 0 else "north"
			else:
				facing = direction_name(direction)
		var name := ("walk_" if moving else "idle_") + facing
		art.speed_scale = clampf(speed / nominal_speed, 0.35, 1.8) if moving and speed >= 0 else 1.0
		if art.animation != name:
			var keep_phase := moving and str(art.animation).begins_with("walk_")
			var old_frame := art.frame
			var old_progress := art.frame_progress
			art.play(name)
			if keep_phase: art.set_frame_and_progress(old_frame, old_progress)
		return
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

func direction_name(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "east" if direction.x >= 0 else "west"
	return "south" if direction.y >= 0 else "north"

func action(name: String, direction := Vector2.RIGHT) -> void:
	var clip := name + "_" + direction_name(direction) if directional else name
	if not art.sprite_frames.has_animation(clip): return
	facing = direction_name(direction)
	art.speed_scale = 1.0
	active_clip = clip
	event_fired = false
	art.play(clip)
	art.set_frame_and_progress(0,0)
	action_time = float(art.sprite_frames.get_frame_count(clip)) / art.sprite_frames.get_animation_speed(clip)

func _process(delta: float) -> void:
	if action_time > 0:
		if not event_fired and clip_events.has(active_clip):
			var event: Dictionary = clip_events[active_clip]
			if art.frame >= int(event.frame):
				event_fired = true
				action_event.emit(str(event.name))
		action_time = maxf(0, action_time - delta)
		if action_time == 0: pose(false)
