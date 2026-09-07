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
var clip_anchors: Dictionary = {}
var clip_indices: Dictionary = {}
var frame_sockets: Dictionary = {}
var procedural_rope_clips: Array = []

func configure(id: String, spec: Dictionary) -> void:
	kind = id
	facing = str(spec.get("default_facing", "east"))
	clip_events = spec.get("action_events", {})
	clip_anchors = spec.get("clip_anchors", {})
	frame_sockets = spec.get("frame_sockets", {})
	procedural_rope_clips = spec.get("procedural_rope_clips", [])
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
		clip_indices[clip_name] = clip.frames
		frames.add_animation(clip_name)
		frames.set_animation_speed(clip_name, clip.fps)
		frames.set_animation_loop(clip_name, clip.loop)
		for ordinal in range(clip.frames.size()):
			var index: int = int(clip.frames[ordinal])
			var rect: Array = spec.frames[int(index)].atlas_rect
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(rect[0], rect[1], rect[2], rect[3])
			var duration_weight := float(clip.get("durations", [])[ordinal]) * float(clip.fps) if clip.has("durations") else 1.0
			frames.add_frame(clip_name, region, duration_weight)
	art.sprite_frames = frames
	directional = frames.has_animation("walk_east")
	add_child(art)
	art.animation_changed.connect(update_anchor)
	art.play("idle")
	update_anchor()

func update_anchor() -> void:
	if clip_anchors.has(str(art.animation)):
		var anchor: Array = clip_anchors[str(art.animation)]
		art.position = -Vector2(anchor[0],anchor[1])

func socket_world(socket_name: String, fallback: Vector2) -> Vector2:
	var source_index: int = int(clip_indices[str(art.animation)][art.frame])
	var sockets: Dictionary = frame_sockets.get(str(source_index), {})
	if sockets.has(socket_name):
		var point: Array = sockets[socket_name]
		return art.to_global(Vector2(point[0],point[1]))
	return to_global(fallback)

func uses_procedural_rope() -> bool:
	return str(art.animation) in procedural_rope_clips

func pose(moving: bool, direction: Vector2 = Vector2.ZERO, speed: float = -1.0) -> void:
	if action_time > 0: return
	if directional:
		if direction.length_squared() > 0.01:
			var desired := direction_name(direction)
			var vectors := {"east":Vector2.RIGHT,"west":Vector2.LEFT,"north":Vector2.UP,"south":Vector2.DOWN,"northeast":Vector2(1,-1).normalized(),"northwest":Vector2(-1,-1).normalized(),"southeast":Vector2(1,1).normalized(),"southwest":Vector2(-1,1).normalized()}
			var old_direction: Vector2 = vectors[facing]
			var new_direction: Vector2 = vectors[desired]
			var boundary := absf(old_direction.angle_to(new_direction)) * 0.5 + deg_to_rad(5)
			if desired == facing or absf(old_direction.angle_to(direction)) > boundary: facing = desired
		var name := ("walk_" if moving else "idle_") + facing
		art.speed_scale = clampf(speed / nominal_speed, 0.35, 1.8) if moving and speed >= 0 else 1.0
		if art.animation != name:
			var keep_phase := moving and str(art.animation).begins_with("walk_")
			var old_frame := art.frame
			var old_progress := art.frame_progress
			var phase := (old_frame + old_progress) / art.sprite_frames.get_frame_count(art.animation)
			art.play(name)
			if keep_phase:
				var new_phase := phase * art.sprite_frames.get_frame_count(name)
				art.set_frame_and_progress(int(new_phase), fmod(new_phase,1.0))
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
	if absf(direction.x) > absf(direction.y) * 0.4142 and absf(direction.y) > absf(direction.x) * 0.4142:
		var diagonal := ("north" if direction.y < 0 else "south") + ("east" if direction.x >= 0 else "west")
		if art.sprite_frames.has_animation("walk_" + diagonal): return diagonal
	if absf(direction.x) >= absf(direction.y):
		return "east" if direction.x >= 0 else "west"
	return "south" if direction.y >= 0 else "north"

func action(name: String, direction := Vector2.RIGHT) -> void:
	var clip := name + "_" + direction_name(direction) if directional else name
	if art.sprite_frames.has_animation(name): clip = name
	if not art.sprite_frames.has_animation(clip): return
	facing = direction_name(direction)
	art.speed_scale = 1.0
	active_clip = clip
	event_fired = false
	art.play(clip)
	art.set_frame_and_progress(0,0)
	action_time = 0.0
	for index in range(art.sprite_frames.get_frame_count(clip)):
		action_time += art.sprite_frames.get_frame_duration(clip,index) / art.sprite_frames.get_animation_speed(clip)

func _process(delta: float) -> void:
	if action_time > 0:
		if not event_fired and clip_events.has(active_clip):
			var event: Dictionary = clip_events[active_clip]
			if art.frame >= int(event.frame):
				event_fired = true
				action_event.emit(str(event.name))
		action_time = maxf(0, action_time - delta)
		if action_time == 0: pose(false)
