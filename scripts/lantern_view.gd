extends Node2D
## Optional encounter view. Caller supplies the ford placement and authoritative
## adventure; this node never changes control, progress, rewards or dialogue.
const Actor = preload("res://scripts/actor.gd")
const Presentation = preload("res://scripts/lantern_presentation.gd")
var spirit: Node2D
var current_view: Dictionary = {}

func configure(spirit_spec: Dictionary) -> void:
	if is_instance_valid(spirit):
		remove_child(spirit)
		spirit.queue_free()
	spirit = Actor.new()
	spirit.configure("crossing_spirit",spirit_spec)
	add_child(spirit)
	spirit.visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func sync_state(adventure) -> Dictionary:
	current_view = Presentation.describe(adventure)
	if is_instance_valid(spirit):
		spirit.visible = current_view.spirit_visible
		var clip: String = current_view.spirit_clip
		if spirit.art.sprite_frames.has_animation(clip) and str(spirit.art.animation)!=clip:
			spirit.art.play(clip)
	return current_view.duplicate(true)
