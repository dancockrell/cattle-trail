extends Sprite2D
## A real sprite prop carried on Eleanor's belt while existing walk clips play.
## Whole-character lantern animations can replace this equipment presentation later.
const BELT_OFFSETS := {"east":Vector2(-5,-18),"west":Vector2(5,-18),
	"north":Vector2(5,-19),"south":Vector2(-5,-19)}
var carrier: Node2D

func configure(actor: Node2D, sprite_texture: Texture2D, grip_anchor: Vector2) -> void:
	carrier = actor
	texture = sprite_texture
	centered = false
	offset = -grip_anchor
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	visible = false

func sync_state(adventure) -> void:
	visible = adventure.status=="active" and is_instance_valid(carrier)
	if visible:
		position = BELT_OFFSETS.get(carrier.facing,Vector2(-5,-18))
