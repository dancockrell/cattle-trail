extends Node2D
const AnimationPhase = preload("res://scripts/animation_phase.gd")
const TurnTransition = preload("res://scripts/turn_transition.gd")

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
var clip_nominal_speeds: Dictionary = {}
var facing_bias := 1.2
var clip_events: Dictionary = {}
var active_clip := ""
var event_fired := false
var clip_anchors: Dictionary = {}
var clip_indices: Dictionary = {}
var frame_sockets: Dictionary = {}
var frame_anchors: Dictionary = {}
var procedural_rope_clips: Array = []
var turn = TurnTransition.new()
var turn_definitions: Dictionary = {}
var turn_target_clip := ""
var turn_target_speed := 1.0
var turn_phase_rate := 0.0
var pixels_per_world_unit := 1.0
var default_anchor := Vector2.ZERO

func configure(id: String, spec: Dictionary) -> void:
	kind = id
	facing = str(spec.get("default_facing", "east"))
	clip_events = spec.get("action_events", {})
	clip_anchors = spec.get("clip_anchors", {})
	frame_sockets = spec.get("frame_sockets", {})
	frame_anchors = spec.get("frame_anchors", {})
	procedural_rope_clips = spec.get("procedural_rope_clips", [])
	turn_definitions = spec.get("turn_transitions",{})
	nominal_speed = float(spec.get("locomotion", {}).get("nominal_speed", 72.0 if id == "rider" else 36.0))
	clip_nominal_speeds = spec.get("locomotion", {}).get("clip_nominal_speeds", {})
	facing_bias = float(spec.get("locomotion", {}).get("facing_bias", 1.2))
	# Atlas coordinates stay in source pixels; gameplay coordinates stay in trail units.
	var density: Variant = spec.get("pixels_per_world_unit", 1)
	pixels_per_world_unit = float(density) if (density is int or density is float) and is_finite(float(density)) and float(density)>=1.0 and float(density)<=8.0 and float(density)==floorf(float(density)) else 1.0
	default_anchor = Vector2(spec.anchor[0], spec.anchor[1])
	art = AnimatedSprite2D.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.centered = false
	art.scale = Vector2.ONE / pixels_per_world_unit
	art.position = -default_anchor / pixels_per_world_unit
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
	directional = bool(spec.get("directional", frames.has_animation("walk_east")))
	add_child(art)
	art.animation_changed.connect(update_anchor)
	art.frame_changed.connect(update_anchor)
	art.play("idle")
	update_anchor()

func update_anchor() -> void:
	var point := default_anchor
	if clip_anchors.has(str(art.animation)):
		var anchor: Array = clip_anchors[str(art.animation)]
		point = Vector2(anchor[0],anchor[1])
	var indices: Array = clip_indices.get(str(art.animation),[])
	if art.frame>=0 and art.frame<indices.size():
		var key := str(int(indices[art.frame]))
		if frame_anchors.has(key):
			var anchor: Array = frame_anchors[key]
			point = Vector2(anchor[0],anchor[1])
	# Returning from a special clip restores the default, including after a reflection.
	art.position = -point * art.scale

func socket_world(socket_name: String, fallback: Vector2) -> Vector2:
	var source_index: int = int(clip_indices[str(art.animation)][art.frame])
	var sockets: Dictionary = frame_sockets.get(str(source_index), {})
	if sockets.has(socket_name):
		var point: Array = sockets[socket_name]
		return art.to_global(Vector2(point[0],point[1]))
	return to_global(fallback)

func uses_procedural_rope() -> bool:
	return str(art.animation) in procedural_rope_clips

func pose(moving: bool, direction: Vector2 = Vector2.ZERO, speed: float = -1.0, gait: String = "walk") -> void:
	if action_time > 0: return
	if directional:
		var previous_facing := facing
		if direction.length_squared() > 0.01:
			var desired := direction_name(direction)
			var vectors := {"east":Vector2.RIGHT,"west":Vector2.LEFT,"north":Vector2.UP,"south":Vector2.DOWN,"northeast":Vector2(1,-1).normalized(),"northwest":Vector2(-1,-1).normalized(),"southeast":Vector2(1,1).normalized(),"southwest":Vector2(-1,1).normalized()}
			var old_direction: Vector2 = vectors[facing]
			var new_direction: Vector2 = vectors[desired]
			var boundary := absf(old_direction.angle_to(new_direction)) * 0.5 + deg_to_rad(5)
			if desired == facing or absf(old_direction.angle_to(direction)) > boundary: facing = desired
		var name := (gait+"_" if moving else "idle_") + facing
		if not art.sprite_frames.has_animation(name): name = ("walk_" if moving else "idle_")+facing
		if not art.sprite_frames.has_animation(name): name = "idle_"+facing
		if not art.sprite_frames.has_animation(name): name = "idle"
		var clip_speed := float(clip_nominal_speeds.get(name,nominal_speed))
		var playback_speed := clampf(speed / clip_speed, 0.35, 1.8) if moving and speed >= 0 else 1.0
		if previous_facing!=facing or (turn.active and turn.moving!=moving):
			var phase: float = turn.phase if turn.active else AnimationPhase.phase_at(clip_durations(art.animation),art.frame,art.frame_progress)
			var source_facing: String = turn.source_direction if turn.active and previous_facing==facing else previous_facing
			var bridge: Dictionary = turn.request(source_facing,facing,moving,phase,turn_definitions)
			if not bridge.is_empty():
				if art.sprite_frames.has_animation(bridge.clip):
					art.play(bridge.clip)
				else:
					turn.cancel()
		if turn.active:
			turn_target_clip = name
			turn_target_speed = playback_speed
			var cycle_seconds := 0.0
			for duration in clip_durations(name): cycle_seconds += float(duration)/art.sprite_frames.get_animation_speed(name)
			turn_phase_rate = playback_speed/cycle_seconds if moving and cycle_seconds>0 else 0.0
			art.speed_scale = 1.0
			return
		art.speed_scale = playback_speed
		if art.animation != name:
			var keep_phase := moving and str(art.animation).begins_with("walk_")
			var phase := AnimationPhase.phase_at(clip_durations(art.animation),art.frame,art.frame_progress)
			art.play(name)
			if keep_phase:
				var destination := AnimationPhase.frame_at(clip_durations(name),phase)
				art.set_frame_and_progress(int(destination.x),destination.y)
		return
	if absf(direction.x) > 0.1:
		# Reflect the complete anchored sprite, not its texture within the atlas cell.
		art.scale.x = (-1.0 if direction.x < 0.0 else 1.0) / pixels_per_world_unit
		var anchor := absf(art.position.x)
		art.position.x = anchor if direction.x < 0.0 else -anchor
	var clip := "ride" if kind == "rider" else "walk"
	if not moving or not art.sprite_frames.has_animation(clip):
		clip = "idle"
	if art.animation != clip:
		art.play(clip)

func clip_durations(clip: StringName) -> Array:
	var durations := []
	for index in range(art.sprite_frames.get_frame_count(clip)):
		durations.append(art.sprite_frames.get_frame_duration(clip,index))
	return durations

func direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y) * 0.4142 and absf(direction.y) > absf(direction.x) * 0.4142:
		var diagonal := ("north" if direction.y < 0 else "south") + ("east" if direction.x >= 0 else "west")
		if art.sprite_frames.has_animation("walk_" + diagonal) or art.sprite_frames.has_animation("idle_" + diagonal): return diagonal
	if absf(direction.x) >= absf(direction.y):
		return "east" if direction.x >= 0 else "west"
	return "south" if direction.y >= 0 else "north"

func action(name: String, direction := Vector2.RIGHT) -> void:
	var clip := name + "_" + direction_name(direction) if directional else name
	if art.sprite_frames.has_animation(name): clip = name
	if not art.sprite_frames.has_animation(clip): return
	turn.cancel()
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
	if turn.active:
		turn.phase = fposmod(turn.phase+delta*turn_phase_rate,1.0)
		var completion: Dictionary = turn.step(delta)
		if not completion.is_empty():
			art.play(turn_target_clip)
			art.speed_scale = turn_target_speed
			if completion.moving:
				var selected := AnimationPhase.frame_at(clip_durations(turn_target_clip),completion.phase)
				art.set_frame_and_progress(int(selected.x),selected.y)
	if action_time > 0:
		if not event_fired and clip_events.has(active_clip):
			var event: Dictionary = clip_events[active_clip]
			if art.frame >= int(event.frame):
				event_fired = true
				action_event.emit(str(event.name))
		action_time = maxf(0, action_time - delta)
		if action_time == 0: pose(false)
