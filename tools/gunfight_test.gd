extends SceneTree
## The Clear Fork gunfight. This check exists to prove the fight is decided by
## where the player points, what stands between the two men, and how many
## rounds are left, and not by how close anybody is standing.
##
## Every "does not hit" case below is paired with a control at the same
## geometry that does hit. A build that resolved shots by proximity, or that
## ignored cover, fails a named check here rather than passing quietly.
const Room = preload("res://scripts/room.gd")

class StubActor extends Node2D:
	var action_time := 0.0
	var last_action := ""
	var secured := false
	var directional := false
	func action(name: String, _direction := Vector2.RIGHT) -> void:
		last_action = name
	func pose(_moving: bool, _direction := Vector2.RIGHT, _speed := 0.0, _mode := "walk") -> void:
		pass

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("GUNFIGHT FAIL: " + label)
		print("GUNFIGHT FAIL: ", label)

## A room with the pieces a fight touches and nothing else. No scene, no
## rendering, no companion. Scenery is supplied per case so cover is a fact of
## the case instead of a fact of the map.
func fight_room(cover: Array = []) -> Control:
	var room: Control = Room.new()
	room.player = StubActor.new()
	room.rustler = StubActor.new()
	room.add_child(room.player)
	room.add_child(room.rustler)
	room.player.position = Vector2(300, 200)
	room.rustler.position = Vector2(400, 200)
	room.solid_scenery = cover
	room.rng.seed = 424242
	return room

func boulder(at: Vector2, radius := 12.0) -> Dictionary:
	return {"position": [at.x, at.y], "collision_radius": radius}

## Fraction of aimed shots that connect at a given range, measured through the
## same call the room fires through.
func hit_rate(distance: float, rounds: int, shake := 0) -> float:
	var room := fight_room()
	room.rustler.position = room.player.position + Vector2(distance, 0)
	var landed := 0
	for i in range(rounds):
		var origin: Vector2 = room.muzzle()
		var mark: Vector2 = room.rustler.position
		var bullet: Dictionary = room.resolve_bullet(origin, origin.direction_to(mark),
			room.aim_spread(distance, shake), room.rustler, Vector2.ZERO)
		if bullet.hit: landed += 1
	room.free()
	return float(landed) / float(rounds)

func fire_at(room: Control, aim: Vector2) -> void:
	room.shot_cooldown = 0.0
	room.aim_point = aim
	room.shoot()

func _initialize() -> void:
	aiming_is_a_choice()
	accuracy_falls_off_with_range()
	cover_stops_lead()
	he_shoots_back()
	being_hit_costs_something_recoverable()
	ammunition_is_a_decision()
	the_room_still_finishes()
	the_writing_holds()

	check(checks >= 55, "Instrument check: this suite must actually run its cases")
	if failures == 0:
		print("GUNFIGHT PASS: %d checks; aim decides the shot, range degrades it, cover stops it, he shoots back on a tell, a hit costs and recovers, and the room still finishes" % checks)
	quit(1 if failures else 0)

## 1. The shot goes where the player points. Standing close is not aiming.
func aiming_is_a_choice() -> void:
	var room := fight_room()
	room.rustler.position = room.player.position + Vector2(40, 0)
	# Forty units away: well inside any radius a proximity build would use.
	fire_at(room, room.player.position + Vector2(0, 300))
	check(room.hits == 0, "A shot aimed ninety degrees off cannot hit a man standing forty units away")
	check(room.ammo == 5, "A missed shot still spends the round")
	fire_at(room, room.rustler.position)
	check(room.hits == 1, "Control: the same range, aimed at him, connects")

	# Backwards is backwards, however near he is.
	var behind := fight_room()
	behind.rustler.position = behind.player.position + Vector2(30, 0)
	fire_at(behind, behind.player.position + Vector2(-200, 0))
	check(behind.hits == 0, "A shot fired away from him never finds him by proximity")
	behind.free()

	# With no pointer at all the shot follows the rider's facing, so a keyboard
	# player is aiming too.
	var keys := fight_room()
	keys.rustler.position = keys.player.position + Vector2(50, 0)
	keys.aim_point = Vector2.INF
	keys.facing = Vector2.UP
	keys.shot_cooldown = 0.0
	keys.shoot()
	check(keys.hits == 0, "Facing away from him misses when there is no pointer")
	keys.facing = Vector2.RIGHT
	keys.shot_cooldown = 0.0
	keys.shoot()
	check(keys.hits == 1, "Control: facing him with no pointer connects")
	keys.free()
	room.free()

## 2. Distance degrades the shot instead of flipping a boolean at some radius.
func accuracy_falls_off_with_range() -> void:
	var near := hit_rate(45.0, 240)
	var middle := hit_rate(110.0, 240)
	var far := hit_rate(185.0, 240)
	check(near > 0.95, "Pistol work at forty five units is reliable, measured %.2f" % near)
	check(middle < near, "A hundred and ten units is worse than forty five, measured %.2f" % middle)
	check(far < middle, "A hundred and eighty five units is worse again, measured %.2f" % far)
	check(far > 0.02 and far < 0.9, "Long range is a gamble, not a wall or a promise, measured %.2f" % far)
	check(middle > 0.15 and middle < 0.98, "Middle range is a real chance either way, measured %.2f" % middle)
	# The old build hit every time inside 190 and never outside it. Both halves
	# of that are false now.
	check(hit_rate(186.0, 120) > 0.0, "There is no radius past which a shot cannot land")
	check(hit_rate(150.0, 240) < 1.0, "There is no radius inside which a shot cannot miss")
	# A shaking hand is worse than a steady one at the same range.
	check(hit_rate(110.0, 240, 3) < middle, "Strain widens the player's own aim")

## 3. Solid ground stops lead, for him as well as for the player.
func cover_stops_lead() -> void:
	var open := fight_room()
	open.rustler.position = Vector2(400, 200)
	fire_at(open, open.rustler.position)
	check(open.hits == 1, "Control: with nothing in the way the aimed shot connects")
	open.free()

	var walled := fight_room([boulder(Vector2(350, 200))])
	walled.rustler.position = Vector2(400, 200)
	fire_at(walled, walled.rustler.position)
	check(walled.hits == 0, "A boulder between the two men stops the aimed shot")
	check(walled.message.contains("cover"), "A blocked shot says it went into cover")
	walled.free()

	# The same wall, from his side.
	var his := fight_room([boulder(Vector2(350, 200))])
	his.rustler.position = Vector2(400, 200)
	var blocked: Dictionary = his.resolve_bullet(his.rustler_muzzle(),
		his.rustler_muzzle().direction_to(his.muzzle()), 0.0, his.player, Vector2.ZERO)
	check(blocked.blocked and not blocked.hit, "His round stops in the same cover")
	his.solid_scenery = []
	var clear: Dictionary = his.resolve_bullet(his.rustler_muzzle(),
		his.rustler_muzzle().direction_to(his.muzzle()), 0.0, his.player, Vector2.ZERO)
	check(clear.hit and not clear.blocked, "Control: with the boulder gone his round reaches the rider")
	check(his.first_blocker(Vector2(300, 200), Vector2(400, 200)) == Vector2.INF, "Open ground blocks nothing")
	his.solid_scenery = [boulder(Vector2(350, 200))]
	check(his.first_blocker(Vector2(300, 200), Vector2(400, 200)).is_finite(), "A prop on the line is found")
	# Cover only counts when it is between them.
	his.solid_scenery = [boulder(Vector2(450, 200))]
	check(his.first_blocker(Vector2(300, 200), Vector2(400, 200)) == Vector2.INF, "A prop beyond the mark is not cover")
	his.free()

	# The wagon is solid without being listed as scenery.
	var yard := fight_room()
	check(yard.first_blocker(Vector2(20, 94), Vector2(200, 94)).is_finite(), "The wagon stops a round crossing it")
	check(yard.first_blocker(Vector2(20, 320), Vector2(200, 320)) == Vector2.INF, "Control: the same sweep clear of the wagon passes")
	yard.free()

## 4. He is dangerous, on a cadence the player can read and answer.
func he_shoots_back() -> void:
	var room := fight_room()
	room.player.position = Vector2(350, 200)
	room.rustler.position = Vector2(400, 200)
	room.rustler_reload = 0.0
	room.tick_gunfight(0.05)
	check(room.rustler_tell > 0.0, "He levels the gun before he uses it")
	check(room.player_hits == 0, "The tell comes before the round, not with it")
	var beat := 0.0
	while room.rustler_tell > 0.0 and beat < 3.0:
		room.tick_gunfight(0.05)
		beat += 0.05
	check(beat >= 0.5, "The tell lasts long enough to answer, measured %.2fs" % beat)
	check(room.player_hits == 1, "Control: a rider who stands there through the tell is hit")

	# He keeps working on a cadence, and the cadence has gaps a rider can use.
	var pounded := fight_room()
	pounded.player.position = Vector2(355, 200)
	pounded.rustler.position = Vector2(400, 200)
	pounded.rustler_reload = 0.0
	var gaps: Array = []
	var since := 0.0
	var sat := 0.0
	while sat < 9.0:
		pounded.tick_gunfight(0.05)
		sat += 0.05
		since += 0.05
		if pounded.player_hits > gaps.size():
			gaps.append(since)
			since = 0.0
	check(pounded.player_hits >= 2, "Standing in the open costs again and again, measured %d hits in nine seconds" % pounded.player_hits)
	check(gaps.size() >= 2 and float(gaps[1]) >= Room.TELL_SECONDS, "There is a workable gap between his rounds, measured %.2fs" % (float(gaps[1]) if gaps.size() > 1 else 0.0))
	check(pounded.strain > 0 and pounded.hits == 0, "His rounds cost the player and never help the player")
	pounded.free()

	# The same tell, answered by stepping behind a rock.
	var answered := fight_room()
	answered.player.position = Vector2(350, 200)
	answered.rustler.position = Vector2(400, 200)
	answered.rustler_reload = 0.0
	answered.tick_gunfight(0.05)
	check(answered.rustler_tell > 0.0, "He levels the gun on the rider in the open")
	answered.solid_scenery = [boulder(Vector2(375, 200))]
	var waited := 0.0
	while answered.rustler_tell > 0.0 and waited < 3.0:
		answered.tick_gunfight(0.05)
		waited += 0.05
	check(answered.player_hits == 0, "Reaching cover during the tell answers the shot")

	# Out of his range, and behind cover, he does not start one at all.
	var far := fight_room()
	far.player.position = Vector2(50, 200)
	far.rustler.position = Vector2(400, 200)
	far.rustler_reload = 0.0
	far.tick_gunfight(0.05)
	check(far.rustler_tell == 0.0, "He does not level on a rider out of range")
	far.player.position = Vector2(350, 200)
	far.solid_scenery = [boulder(Vector2(375, 200))]
	far.tick_gunfight(0.05)
	check(far.rustler_tell == 0.0, "He does not level on a rider he cannot see")
	far.solid_scenery = []
	far.tick_gunfight(0.05)
	check(far.rustler_tell > 0.0, "Control: he levels the moment the line is open")
	far.free()

	# He stops the moment he gives up.
	room.rustler_tell = 0.0
	room.rustler_reload = 0.0
	room.rustler_surrenders("beaten")
	room.tick_gunfight(0.5)
	check(room.rustler_tell == 0.0, "A beaten man does not level his gun again")
	var after: int = room.player_hits
	for i in range(80): room.tick_gunfight(0.05)
	check(room.player_hits == after, "A beaten man does not fire again")
	room.free()
	answered.free()

## 5. Losing an exchange costs the day, not the rider.
func being_hit_costs_something_recoverable() -> void:
	var room := fight_room()
	var loose := StubActor.new()
	var safe := StubActor.new()
	room.add_child(loose)
	room.add_child(safe)
	loose.position = Vector2(300, 250)
	safe.position = Vector2(560, 200)
	safe.secured = true
	room.cows.assign([loose, safe])
	room.rope_target = loose
	room.rope_time = 12.0
	var standing: Vector2 = room.player.position
	var loose_before: Vector2 = loose.position
	var safe_before: Vector2 = safe.position
	room.player_struck()
	check(room.player_hits == 1 and room.strain == 1, "A hit is recorded and leaves the hand shaking")
	check(room.rope_time == 0.0 and room.rope_target == null, "A hit puts the rope on the ground")
	check(loose.position != loose_before, "A hit breaks up the loose cattle")
	check(safe.position == safe_before and safe.secured, "Cattle already gathered stay gathered")
	check(room.player.position == standing, "A hit never moves the rider for him")
	check(room.player.last_action == "", "A hit never takes the reins out of the player's hands")
	check(room.message.length() > 0 and not room.message.contains(String.chr(0x2014)), "A hit says what it cost")

	# It wears off, and it has a floor as well as a ceiling.
	for i in range(3): room.player_struck()
	check(room.strain == Room.MAX_STRAIN, "Shaking is capped, so a bad fight cannot spiral")
	check(room.player_hits == 4, "Every hit is still counted")
	check(room.hits == 0, "Being shot at never advances the player's own tally")
	# Out of his reach, or the measurement is of him topping the strain up.
	room.player.position = Vector2(40, 300)
	var patience := 0.0
	while room.strain > 0 and patience < 120.0:
		room.tick_gunfight(0.1)
		patience += 0.1
	check(room.strain == 0, "The hand steadies again without any action from the player")
	check(patience < 60.0, "Recovery is measured in seconds, measured %.1fs" % patience)
	room.free()

## 6. Six rounds, and getting six more is an act with a clock on it.
func ammunition_is_a_decision() -> void:
	var room := fight_room()
	room.rustler.position = room.player.position + Vector2(400, 0)
	check(room.ammo == Room.CYLINDER, "The cylinder starts full")
	for i in range(Room.CYLINDER):
		fire_at(room, room.player.position + Vector2(0, 200))
	check(room.ammo == 0, "Six shots empty it")
	fire_at(room, room.player.position + Vector2(0, 200))
	check(room.ammo == 0 and room.message.contains("Reload"), "An empty gun says so and names the rope")
	room.reload()
	check(room.reload_time > 0.0 and room.ammo == 0, "Reloading does not pay out the moment it starts")
	fire_at(room, room.player.position + Vector2(0, 200))
	check(room.ammo == 0, "A man with his hands full of cartridges cannot fire")
	room.tick_gunfight(Room.RELOAD_SECONDS * 0.5)
	check(room.ammo == 0, "Half a reload is no reload")
	room.tick_gunfight(Room.RELOAD_SECONDS * 0.6)
	check(room.ammo == Room.CYLINDER and room.reload_time == 0.0, "A finished reload fills the cylinder")
	# Rope or cartridges. Reaching for the loop spills the reload.
	room.ammo = 1
	room.reload()
	check(room.reload_time > 0.0, "The reload is running")
	room.lasso()
	check(room.reload_time == 0.0 and room.ammo == 1, "Going for the rope spills the reload")
	# Being shot during a reload spills it too, which is what cover is for.
	room.reload()
	room.player_struck()
	check(room.reload_time == 0.0 and room.ammo == 1, "A round through the coat spills the reload")
	room.free()

## 7. However badly the fight goes, the ground is still workable.
func the_room_still_finishes() -> void:
	# A player who never lands a shot can still take him with the rope.
	var roped := fight_room()
	for i in range(6): roped.player_struck()
	roped.player.position = roped.rustler.position + Vector2(-40, 0)
	roped.catch_rope(roped.rustler)
	check(not roped.rustler_active, "A rider who lost every exchange can still rope him")
	check(roped.rustler_surrendered and roped.rustler_choice_pending(), "The rope reaches the same decision the gun does")
	check(roped.choose_rustler("law"), "The decision is still the player's after a bad fight")
	roped.free()

	# And a player who never fires at all is not stuck either.
	var pacifist := fight_room()
	pacifist.player.position = pacifist.rustler.position + Vector2(-40, 0)
	pacifist.catch_rope(pacifist.rustler)
	check(not pacifist.rustler_active and pacifist.ammo == Room.CYLINDER, "The rope alone ends the encounter")
	check(pacifist.player_hits == 0, "Nothing forces a rider to take a hit first")
	pacifist.free()

	# Two aimed rounds is still the gun answer, and it is still only two.
	var shot := fight_room()
	shot.rustler.position = shot.player.position + Vector2(40, 0)
	for i in range(2):
		fire_at(shot, shot.rustler.position)
	check(shot.hits == 2 and not shot.rustler_active, "Two aimed rounds put him down")
	check(shot.hits <= 2, "The hit tally stays inside what a save can hold")
	fire_at(shot, shot.rustler.position)
	check(shot.hits == 2, "A beaten man cannot be shot again")
	shot.free()

## 8. House voice, and nothing that reads like a menu.
func the_writing_holds() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/room.gd")
	check(source.length() > 1000, "Instrument check: the room source was actually read")
	check(not source.contains(String.chr(0x2014)), "No em dash anywhere in the room")
	var sample := fight_room()
	sample.rustler.position = sample.player.position + Vector2(140, 0)
	fire_at(sample, sample.player.position + Vector2(0, 300))
	check(sample.message.length() > 0 and sample.message.length() < 140, "A miss is reported short")
	sample.rustler.position = sample.player.position + Vector2(40, 0)
	fire_at(sample, sample.rustler.position)
	check(sample.message.contains("him") or sample.message.contains("he"), "A hit is reported as a man taking it")
	sample.free()
