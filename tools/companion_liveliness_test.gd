extends SceneTree
## What the nineteen static companion poses are allowed to do, asserted as
## properties rather than as mechanisms.
##
## The art is one frame per companion facing southeast (see the header of
## scripts/companion_actors.gd), so the only claims worth defending are: she
## never leaves her catalog spot, she wobbles by at most a few whole pixels,
## she has exactly two facings and picks the one toward the player, and the
## nineteen of them are not in step.
##
## Two shapes this file deliberately avoids. A failed assert() in headless Godot
## hangs the runner rather than failing it, so nothing here asserts. And quit()
## is deferred, so a check that called it and carried on would still reach the
## PASS line underneath: every check returns its reason up to _initialize
## instead, and only an empty reason prints PASS.

const Actors = preload("res://scripts/companion_actors.gd")
const Catalog = preload("res://scripts/simple_companion_catalog.gd")
const STEP := 1.0 / 60.0

class FakeRoom extends Control:
	var actors: Node2D
	var player: Node2D
	var eleanor: Node2D

var checks := 0
var cost_line := ""
var summary := ""

## Counts the check and hands back its result, so a failing line reads
## "if not ok(condition): return reason" and cannot fall through.
func ok(condition: bool) -> bool:
	checks += 1
	return condition

## A room with just enough of room.gd's shape for the sprites to attach to and
## to watch. Deliberately not added to the tree, so nothing processes until the
## test says so and every measurement below is taken at a fixed step.
func build() -> Dictionary:
	var room := FakeRoom.new()
	room.actors = Node2D.new()
	room.actors.y_sort_enabled = true
	room.add_child(room.actors)
	room.player = Node2D.new()
	room.player.position = Vector2(-4000, -4000)
	room.add_child(room.player)
	room.eleanor = Node2D.new()
	room.eleanor.position = Vector2(-4000, -4000)
	room.add_child(room.eleanor)
	var actors = Actors.new()
	var built: int = actors.populate(room, Catalog.ROWS)
	return {"room": room, "actors": actors, "built": built}

func _initialize() -> void:
	var problem: String = await run()
	if cost_line != "": print(cost_line)
	if problem != "":
		push_error("COMPANION LIVELINESS FAIL: " + problem)
		print("COMPANION LIVELINESS FAIL: ", problem)
		quit(1)
		return
	print(summary)
	quit(0)

func run() -> String:
	var rig := build()
	var actors = rig.actors
	var room: FakeRoom = rig.room
	var expected: int = Catalog.ROWS.size()
	if not ok(expected >= 19): return "the catalog shrank below the nineteen companions this test is about: %d" % expected
	if not ok(rig.built == expected): return "populate drew %d of %d companions" % [rig.built, expected]

	# The rhythm has to differ per companion or nineteen women breathe as one.
	var phases := {}
	var rates := {}
	for row in Catalog.ROWS:
		var sprite = actors.actor_for(row.id)
		if not ok(sprite != null): return "no sprite was built for %s" % row.id
		phases[sprite.bob_phase] = true
		rates[sprite.bob_rate] = true
	if not ok(phases.size() == expected): return "only %d distinct breath phases across %d companions" % [phases.size(), expected]
	if not ok(rates.size() > 1): return "every companion breathes at the identical rate, so they cannot fall out of step"

	# Fifteen seconds with nobody near: pure ambient motion. Her feet must never
	# move, because position is what the actor layer y-sorts on and what the
	# player walks to, and the wobble must stay inside one pixel each way.
	var home := {}
	var base := {}
	for row in Catalog.ROWS:
		home[row.id] = actors.actor_for(row.id).position
		base[row.id] = actors.actor_for(row.id).base_offset
	var seen_bobs := {}
	var ambient := Vector2.ZERO
	var pinned := 0
	for step in range(900):
		for row in Catalog.ROWS:
			var sprite = actors.actor_for(row.id)
			sprite.tick(STEP)
			var wobble: Vector2 = sprite.offset - base[row.id]
			ambient.x = maxf(ambient.x, absf(wobble.x))
			ambient.y = maxf(ambient.y, absf(wobble.y))
			if sprite.position != home[row.id]: return "%s drifted off her catalog position, which is what the actor layer y-sorts on" % row.id
			pinned += 1
		if step == 240:
			for row in Catalog.ROWS: seen_bobs[actors.actor_for(row.id).offset.y] = true
	if not ok(pinned == 900 * expected): return "the position check ran %d times, not %d" % [pinned, 900 * expected]
	if not ok(ambient.y > 0.0 and ambient.x > 0.0): return "fifteen seconds of ambient motion moved nobody, so there is nothing left to bound"
	if not ok(ambient.y <= 1.0): return "the idle breath reached %.1f px; at this scale it is meant to be one" % ambient.y
	if not ok(ambient.x <= 1.0): return "the idle sway reached %.1f px; at this scale it is meant to be one" % ambient.x
	if not ok(seen_bobs.size() > 1): return "all nineteen held the identical breath offset at one instant, so they are in unison"

	# Facing. The art is southeast only, so there are exactly two of these and
	# the test must not be able to pass while claiming more.
	var subject = actors.actor_for(Catalog.ROWS[0].id)
	var spot: Vector2 = subject.position
	var facings := {}
	room.player.position = spot + Vector2(-30, 0)
	subject.tick(STEP)
	facings[subject.scale.x] = true
	if not ok(subject.scale.x < 0.0): return "a companion did not turn toward a player standing to her west"
	if not ok(subject.hop_left > 0.0): return "arriving beside a companion did not start her notice hop"
	room.player.position = spot + Vector2(30, 0)
	subject.tick(STEP)
	facings[subject.scale.x] = true
	if not ok(subject.scale.x > 0.0): return "a companion did not turn back east when the player crossed her"
	# The deadband is only observable where the wrong answer is available: she
	# is facing east, and the player is a hair to the west. Without the band she
	# flips; with it she holds.
	room.player.position = spot + Vector2(-2, 0)
	subject.tick(STEP)
	if not ok(subject.scale.x > 0.0): return "a player two pixels to her west flipped her, so the deadband does not hold"
	room.player.position = spot + Vector2(-30, 0)
	subject.tick(STEP)
	if not ok(subject.scale.x < 0.0): return "she stopped tracking the player once the deadband had held her"
	room.player.position = spot + Vector2(-4000, 0)
	for step in range(120):
		subject.tick(STEP)
		facings[subject.scale.x] = true
	if not ok(subject.scale.x < 0.0): return "she snapped back to her drawn facing once the player left, instead of holding where she was looking"
	if not ok(facings.size() == 2): return "%d facings observed; the art is one southeast pose and a mirror, so two is the honest ceiling" % facings.size()
	for value in facings:
		if not ok(absf(absf(value) - 1.0) < 0.0001): return "a facing used scale %.3f; anything but a clean mirror is stretched art" % value

	# The notice hop: it fires on arrival, it finishes, it lifts her further than
	# the breath does, and it does not fire again while she is already looking.
	room.player.position = spot + Vector2(-30, 0)
	var near := 0.0
	var hopping := 0
	for step in range(120):
		subject.tick(STEP)
		if subject.hop_left > 0.0: hopping += 1
		near = maxf(near, absf(subject.offset.y - subject.base_offset.y))
	if not ok(hopping > 0 and hopping < 120): return "the notice hop ran for %d of 120 frames; it is either absent or never ends" % hopping
	if not ok(subject.hop_left == 0.0): return "the notice hop never finished, so it is not a hop"
	if not ok(near > 1.0): return "noticing the player lifted her %.1f px, no further than her ordinary breath" % near
	if not ok(near <= 4.0): return "noticing the player lifted her %.1f px, past the three pixel hop plus one pixel breath" % near
	# Riding out past the notice radius and straight back in must not re-fire it.
	# With one radius instead of two she notices you again every time you cross
	# the line, which is the twitch this gap exists to prevent, so the trip out
	# has to land between the two radii for the wrong answer to be available.
	room.player.position = spot + Vector2(-100, 0)
	subject.tick(STEP)
	room.player.position = spot + Vector2(-30, 0)
	subject.tick(STEP)
	if not ok(subject.hop_left == 0.0): return "stepping just past the notice radius and back re-triggered the hop, so the hysteresis gap is not holding"
	room.player.position = spot + Vector2(-4000, 0)
	subject.tick(STEP)
	room.player.position = spot + Vector2(-30, 0)
	subject.tick(STEP)
	if not ok(subject.hop_left > 0.0): return "leaving properly and coming back did not produce a fresh hop"

	# Cost. Nineteen sprites, one frame, measured rather than reasoned about.
	var frames := 2000
	var started := Time.get_ticks_usec()
	for step in range(frames):
		for row in Catalog.ROWS:
			actors.actor_for(row.id).tick(STEP)
	cost_line = "COMPANION LIVELINESS COST: %.1f us per frame for %d companions" % [float(Time.get_ticks_usec() - started) / float(frames), expected]

	# Everything above drove tick() by hand. Prove the engine drives it too,
	# otherwise a deleted _process would leave every check above green.
	var live := build()
	get_root().add_child(live.room)
	var subject_live = live.actors.actor_for(Catalog.ROWS[0].id)
	var offsets := {}
	for step in range(150):
		await process_frame
		offsets[subject_live.offset.y] = true
	var engine_driven: bool = offsets.size() > 1
	# Freed by hand: Godot reports leaked nodes and textures at exit as ERROR
	# lines, and the verifier treats any of those as a failure despite exit zero.
	get_root().remove_child(live.room)
	live.room.free()
	room.free()
	if not ok(engine_driven): return "a companion inside a running tree never moved, so _process is not driving her"

	summary = "COMPANION LIVELINESS PASS: %d checks; %d companions drawn, distinct breath phases, feet pinned to the y-sort position, idle wobble within %.0f px, notice hop to %.0f px with hysteresis, two facings and no more, engine-driven" % [checks, expected, ambient.y, near]
	return ""
