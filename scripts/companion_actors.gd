extends RefCounted
## Puts the simple companions on screen.
##
## Until now these nineteen women existed only as coordinates in
## simple_companion_catalog.gd with dialogue attached, so the player walked to
## an empty patch of dirt and read a line in the journal. Nothing was drawn and
## there was no actor for a speech bubble to point at.
##
## The art already existed and was sitting unused: kits/character-families holds
## 96 extracted 64x64 identity variants across three families, each with its
## atlas rect and a bottom-center anchor. data/companion_art.json says which
## variant stands in for which companion. These are static idle poses, so a
## companion stands where she is rather than walking; that is honest for now and
## the sprite can gain clips later without changing this file.

const ART_PATH := "res://data/companion_art.json"

var sprites := {}

## Builds one sprite per companion under the room's y-sorted actor layer, so a
## companion standing further down the trail correctly overlaps one behind her.
func populate(room: Control, rows: Array) -> int:
	var art: Dictionary = _load_art()
	if art.is_empty(): return 0
	var built := 0
	for row in rows:
		var entry: Dictionary = art.get(row.id, {})
		if entry.is_empty(): continue
		var texture: Texture2D = _atlas_texture(entry)
		if texture == null: continue
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		# The anchor is the figure's feet in source pixels. Offsetting by it puts
		# her feet on her catalog position, which is the spot the player walks to.
		var anchor: Array = entry.get("anchor", [32, 61])
		sprite.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
		sprite.position = Vector2(float(row.position_x), float(row.position_y))
		sprite.name = "companion_" + String(row.id)
		room.actors.add_child(sprite)
		sprites[row.id] = sprite
		built += 1
	return built

func actor_for(id: String) -> Node2D:
	var sprite = sprites.get(id)
	return sprite if is_instance_valid(sprite) else null

func _load_art() -> Dictionary:
	if not FileAccess.file_exists(ART_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_PATH))
	if not parsed is Dictionary: return {}
	var companions: Variant = parsed.get("companions", {})
	return companions if companions is Dictionary else {}

func _atlas_texture(entry: Dictionary) -> Texture2D:
	var path: String = String(entry.get("atlas", ""))
	if path == "" or not ResourceLoader.exists(path): return null
	var source = load(path)
	if source == null: return null
	var rect: Array = entry.get("rect", [0, 0, 64, 64])
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	return atlas
