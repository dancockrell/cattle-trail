extends Sprite2D
## Whole carry performance faces east; other facings retain belt equipment.
const Actor = preload("res://scripts/actor.gd")
const Phase = preload("res://scripts/animation_phase.gd")
const BELT_OFFSETS := {"east":Vector2(-5,-18),"west":Vector2(5,-18),
	"north":Vector2(5,-19),"south":Vector2(-5,-19)}
var carrier: Node2D
var east_performance: Node2D

func configure(actor: Node2D, sprite_texture: Texture2D, grip_anchor: Vector2) -> void:
	carrier = actor
	texture = sprite_texture
	centered = false
	offset = -grip_anchor
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false
	east_performance = Actor.new()
	east_performance.configure("eleanor_lantern",JSON.parse_string(FileAccess.get_file_as_string("res://assets/lantern/eleanor_carry_east.json")))
	carrier.add_child(east_performance)
	east_performance.visible = false

func sync_state(adventure) -> void:
	if not is_instance_valid(carrier): return
	var active: bool = adventure.status=="active"
	var show_east: bool = active and carrier.facing=="east"
	var entering: bool = show_east and not east_performance.visible
	east_performance.visible = show_east
	carrier.art.visible = not show_east
	visible = active and not show_east
	if show_east:
		var moving: bool = str(carrier.art.animation).begins_with("walk_")
		var speed: float = carrier.art.speed_scale*carrier.nominal_speed
		east_performance.pose(moving,Vector2.RIGHT,speed)
		if entering and moving:
			var phase: float = Phase.phase_at(carrier.clip_durations(carrier.art.animation),carrier.art.frame,carrier.art.frame_progress)
			var frame: Vector2 = Phase.frame_at(east_performance.clip_durations("walk_east"),phase)
			east_performance.art.set_frame_and_progress(int(frame.x),frame.y)
	if visible:
		position = BELT_OFFSETS.get(carrier.facing,Vector2(-5,-18))
