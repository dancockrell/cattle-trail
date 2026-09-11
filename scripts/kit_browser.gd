extends Control

var catalog: Dictionary
var family_select: OptionButton
var clip_select: OptionButton
var description: Label
var frame_label: Label
var preview: AnimatedSprite2D
var atlas_view: TextureRect
var current: Dictionary
var families: Array
var clips: Array
var show_anchor := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://kits/manifest.json"))
	families = catalog.families.keys()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	var title := Label.new()
	title.text = "CATTLE TRAIL / RICH SPRITE KITS"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f4d69c"))
	stack.add_child(title)
	var info := Label.new()
	info.text = "%d extracted candidates | Original art references preserved | Visual acceptance pending" % int(catalog.total_extracted)
	stack.add_child(info)
	var toolbar := HBoxContainer.new()
	stack.add_child(toolbar)
	family_select = OptionButton.new()
	family_select.custom_minimum_size = Vector2(160,44)
	for family in families: family_select.add_item(family.capitalize())
	family_select.item_selected.connect(select_family)
	toolbar.add_child(family_select)
	clip_select = OptionButton.new()
	clip_select.custom_minimum_size = Vector2(190,44)
	clip_select.item_selected.connect(select_clip)
	toolbar.add_child(clip_select)
	for entry in [["Replay", replay], ["Pause / Play", pause_play], ["Play room", room], ["World map", func(): get_tree().change_scene_to_file("res://scenes/world_map.tscn")]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 44
		button.pressed.connect(entry[1])
		toolbar.add_child(button)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description)
	frame_label = Label.new()
	stack.add_child(frame_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	scroll.add_child(row)
	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(320,360)
	row.add_child(preview_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,360)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	preview_container.add_child(viewport)
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/room.png")
	ground.centered = false
	viewport.add_child(ground)
	preview = AnimatedSprite2D.new()
	preview.centered = false
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(preview)
	atlas_view = TextureRect.new()
	atlas_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(atlas_view)
	select_family(0)
	if "--kit-qa" in OS.get_cmdline_user_args() or "--kit-tour" in OS.get_cmdline_user_args():
		kit_qa.call_deferred()

func select_family(index: int) -> void:
	family_select.select(index)
	current = catalog.families[families[index]]
	var texture := load(current.texture) as Texture2D
	atlas_view.texture = texture
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	clips = current.clips.keys()
	clip_select.clear()
	for clip in clips:
		clip_select.add_item(clip)
		frames.add_animation(clip)
		frames.set_animation_speed(clip, current.clips[clip].fps)
		frames.set_animation_loop(clip, current.clips[clip].loop)
		for index_in_atlas in current.clips[clip].frames:
			var rect: Array = current.frames[int(index_in_atlas)].atlas_rect
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = Rect2(rect[0],rect[1],rect[2],rect[3])
			frames.add_frame(clip,region)
	preview.sprite_frames = frames
	var zoom := 2.0 if int(current.cell[0]) >= 96 else 3.0
	preview.scale = Vector2.ONE * zoom
	preview.position = Vector2(160,270) - Vector2(current.anchor[0],current.anchor[1]) * zoom
	description.text = "%s: %d frames | Cell %s | Ground anchor %s | Native atlas at right; integer enlarged animation at left.\nThese are extracted kit candidates. Check direction, anatomy, identity, cadence, and ground contact before admission." % [families[index].capitalize(),int(current.count),str(current.cell),str(current.anchor)]
	select_clip(0)
	for note in current.get("review_notes", []):
		description.text += "\n" + str(note)

func select_clip(index: int) -> void:
	clip_select.select(index)
	preview.play(clips[index])
	preview.set_frame_and_progress(0,0)

func _process(_delta: float) -> void:
	if preview and preview.sprite_frames:
		var clip: Dictionary = current.clips[preview.animation]
		frame_label.text = "%s | frame %d/%d | %s fps | loop: %s" % [preview.animation,preview.frame+1,clip.frames.size(),str(clip.fps),str(clip.loop)]

func replay() -> void:
	select_clip(clip_select.selected)

func pause_play() -> void:
	if preview.is_playing(): preview.pause()
	else: preview.play()

func room() -> void:
	get_tree().change_scene_to_file("res://scenes/room.tscn")

func kit_qa() -> void:
	for i in range(families.size()):
		select_family(i)
		for clip in clips:
			var frames: Array = current.clips[clip].frames
			assert(not frames.is_empty())
			for frame in frames: assert(int(frame) < int(current.count))
		if "--kit-tour" in OS.get_cmdline_user_args():
			for clip_index in range(mini(4, clips.size())):
				select_clip(clip_index)
				await get_tree().create_timer(0.8).timeout
		else:
			await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var output := "res://kits/reviews/godot-%s.png" % families[i]
		if not OS.has_feature("editor"):
			output = OS.get_executable_path().get_base_dir().path_join("kit-smoke-%s.png" % families[i])
		var saved := get_viewport().get_texture().get_image().save_png(output)
		if saved != OK:
			push_error("Kit capture failed: " + output)
			get_tree().quit(saved)
			return
	print("KIT QA PASS: %d families and %d extracted cells loaded, animation playback rendered" % [families.size(),int(catalog.total_extracted)])
	get_tree().quit()
