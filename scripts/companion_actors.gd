extends RefCounted
## Puts the simple companions on screen and keeps them alive there.
##
## Until recently these nineteen women existed only as coordinates in
## simple_companion_catalog.gd with dialogue attached, so the player walked to
## an empty patch of dirt and read a line in the journal. Nothing was drawn and
## there was no actor for a speech bubble to point at.
##
## The art already existed and was sitting unused: kits/character-families holds
## 96 extracted 64x64 identity variants across three families, each with its
## atlas rect and a bottom-center anchor. data/companion_art.json says which
## variant stands in for which companion.
##
## What the art can and cannot do, checked against
## kits/character-families/catalog.json rather than assumed: all 96 variants
## carry animation_status "static_identity_only", every clip in the catalog has
## exactly one frame, and every variant that records a facing records
## "southeast". So there is one pose per companion and no walk or turn frames.
## Nothing here invents any. A horizontal mirror is the one honest extra view a
## single pose gives, so a companion has TWO facings, southeast and southwest,
## and no more. Everything else below moves the sprite by whole pixels without
## touching what is drawn: no stretching, no shearing, no interpolated frames.
##
## The motion budget is deliberately tiny because the camera is fixed and the
## world is 640x360. A breath is one pixel. A weight shift is one pixel. Noticing
## the player is a three pixel hop and a turn. At that size it reads as somebody
## standing there rather than as animation, which is the honest ceiling for one
## frame of art.

const ART_PATH := "res://data/companion_art.json"

## A companion notices the player inside ENTER and stops noticing outside EXIT.
## Two radii, not one, so riding along the boundary cannot strobe her.
const NOTICE_ENTER := 86.0
const NOTICE_EXIT := 122.0
## Below this horizontal gap she keeps the facing she has. Riding straight at
## her must not flap her back and forth over a pixel of drift.
const FLIP_DEADBAND := 6.0
const BOB_PIXELS := 1.0
const SWAY_PIXELS := 1.0
const HOP_PIXELS := 3.0
const HOP_SECONDS := 0.42
## Attention quickens the breath rather than enlarging it. Enlarging it would be
## the thing that looks wrong at this scale.
const ATTENTIVE_RATE := 1.55

var sprites := {}

## One sprite per companion, drawn and animated by itself.
##
## It animates itself because there is nowhere else to do it from: room.gd's
## physics loop and companion_room.gd both belong to other work right now, and
## a per-frame hook added there would be a second owner of the same nineteen
## nodes. A node that knows how to stand still convincingly is the smaller
## interface.
class CompanionSprite extends Sprite2D:
	## Where the feet sit in the sprite's own pixels. Every wobble below is an
	## offset from this; position itself never moves, because position is what
	## the y-sorted actor layer sorts on and what the player walks to.
	var base_offset := Vector2.ZERO
	var watched: Array = []
	var bob_phase := 0.0
	var sway_phase := 0.0
	var bob_rate := 1.8
	var sway_rate := 0.9
	var bob_cycle := 0.0
	var sway_cycle := 0.0
	var hop_left := 0.0
	var attentive := false

	func _process(delta: float) -> void:
		tick(delta)

	## Separated from _process so a headless test can drive it at a fixed step
	## instead of racing the engine's frame rate.
	func tick(delta: float) -> void:
		var target: Node2D = _nearest()
		var gap := INF
		if target != null: gap = position.distance_to(target.position)
		var was_attentive := attentive
		if attentive:
			if gap > NOTICE_EXIT: attentive = false
		elif gap < NOTICE_ENTER:
			attentive = true
		if attentive and not was_attentive: hop_left = HOP_SECONDS
		if attentive and target != null: _face(target.position.x - position.x)
		# Phase accumulates rather than being read off a clock, so quickening
		# the breath when she notices you cannot jump her mid-cycle.
		bob_cycle += delta * bob_rate * (ATTENTIVE_RATE if attentive else 1.0)
		sway_cycle += delta * sway_rate
		var breath := sin(bob_cycle + bob_phase)
		# Rounded to whole pixels on purpose. A fractional offset on a nearest
		# filtered sprite shimmers instead of moving.
		var bob := -roundf(maxf(breath, 0.0) * BOB_PIXELS)
		var sway := roundf(sin(sway_cycle + sway_phase) * SWAY_PIXELS)
		var hop := 0.0
		if hop_left > 0.0:
			hop_left = maxf(hop_left - delta, 0.0)
			hop = -roundf(sin((1.0 - hop_left / HOP_SECONDS) * PI) * HOP_PIXELS)
		offset = base_offset + Vector2(sway, bob + hop)

	## The art is drawn facing southeast. scale.x of -1 mirrors it about the
	## node origin, which is the anchor, which is her feet, so the mirrored pose
	## stands in exactly the same spot. That gives southwest. There is no third
	## facing available and this must not be described as one.
	func _face(dx: float) -> void:
		if absf(dx) < FLIP_DEADBAND: return
		scale.x = -1.0 if dx < 0.0 else 1.0

	func _nearest() -> Node2D:
		var best: Node2D = null
		var best_gap := INF
		for node in watched:
			if not is_instance_valid(node): continue
			var gap: float = position.distance_squared_to(node.position)
			if gap < best_gap:
				best_gap = gap
				best = node
		return best

## Builds one sprite per companion under the room's y-sorted actor layer, so a
## companion standing further down the trail correctly overlaps one behind her.
func populate(room: Control, rows: Array) -> int:
	var art: Dictionary = _load_art()
	if art.is_empty(): return 0
	var watched: Array = _watch_targets(room)
	var built := 0
	for row in rows:
		var entry: Dictionary = art.get(row.id, {})
		if entry.is_empty(): continue
		var texture: Texture2D = _atlas_texture(entry)
		if texture == null: continue
		var sprite := CompanionSprite.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		# The anchor is the figure's feet in source pixels. Offsetting by it puts
		# her feet on her catalog position, which is the spot the player walks to.
		var anchor: Array = entry.get("anchor", [32, 61])
		sprite.base_offset = Vector2(-float(anchor[0]), -float(anchor[1]))
		sprite.offset = sprite.base_offset
		sprite.position = Vector2(float(row.position_x), float(row.position_y))
		sprite.name = "companion_" + String(row.id)
		sprite.watched = watched
		_seed_rhythm(sprite, String(row.id))
		room.actors.add_child(sprite)
		sprites[row.id] = sprite
		built += 1
	return built

func actor_for(id: String) -> Node2D:
	var sprite = sprites.get(id)
	return sprite if is_instance_valid(sprite) else null

## Nineteen women breathing in step would read as one machine driving them, so
## each takes her phase and her period from her own id. Deriving it from the id
## rather than from randf() means the same camp looks the same every run, which
## is what makes a captured frame worth comparing against the last one.
static func _seed_rhythm(sprite: CompanionSprite, id: String) -> void:
	var hash_value := absi(int(id.hash()))
	sprite.bob_phase = float(hash_value % 997) / 997.0 * TAU
	sprite.sway_phase = float((hash_value / 997) % 991) / 991.0 * TAU
	# Periods land between about 3.1s and 4.7s for the breath and 6.0s to 9.8s
	# for the weight shift. Unequal periods keep them from drifting into step.
	sprite.bob_rate = TAU / (3.1 + float(hash_value % 17) * 0.1)
	sprite.sway_rate = TAU / (6.0 + float((hash_value / 17) % 20) * 0.2)

## Who a companion watches. The rider and Eleanor are the two actors the player
## can be riding as; whichever is closer is the one she turns toward.
static func _watch_targets(room: Control) -> Array:
	var targets: Array = []
	for property in ["player", "eleanor"]:
		var node = room.get(property)
		if node is Node2D: targets.append(node)
	return targets

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
