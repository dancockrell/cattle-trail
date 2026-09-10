extends SceneTree
const Snapshot = preload("res://scripts/room_snapshot.gd")
const State = preload("res://scripts/companion_state.gd")
const Lantern = preload("res://scripts/lantern_adventure.gd")
const Ada = preload("res://scripts/ada_companion.gd")
const Roster = preload("res://scripts/generated_companion_roster.gd")
const Cart = preload("res://scripts/ada_cart_adventure.gd")
const Care = preload("res://scripts/camp_care_room.gd")
const RoomScript = preload("res://scripts/room.gd")
const CompanionRoom = preload("res://scripts/companion_room.gd")
const Storage = preload("res://scripts/save_storage.gd")

## A failed assert in a headless Godot script hangs instead of exiting, and the
## runner then reports a timeout rather than the failure. These cases report
## themselves and set an exit code.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error("ROOM SNAPSHOT FAIL: " + label)
	print("ROOM SNAPSHOT FAIL: " + label)

class StubTurn extends RefCounted:
	func cancel() -> void: pass

class StubActor extends Node2D:
	var action_time := 0.0
	var facing := "south"
	var art := Node2D.new()
	var turn := StubTurn.new()
	var secured := false
	func _init() -> void: add_child(art)
	func action(_name: String, _direction := Vector2.RIGHT) -> void: action_time = 0.5
	func pose(_moving: bool, _direction := Vector2.RIGHT, _speed := 0.0, _mode := "walk") -> void: pass

class StubSpeech extends Control:
	var remaining := 0.0
	var speaker: Node2D
	func say(_actor, _speaker, _line, _height, _importance := 0) -> bool: return false
	func tick(_delta, _view) -> void: pass

## The real room script with only the pieces a save touches: no scene, no
## rendering, no _ready. Every rule under test below is the shipping room's own
## and the shipping save code's own.
func fresh_room() -> Control:
	var room: Control = RoomScript.new()
	room.actors = Node2D.new()
	room.add_child(room.actors)
	for field in ["player","eleanor","rustler"]:
		var actor := StubActor.new()
		room.actors.add_child(actor)
		room.set(field, actor)
	room.player.position = Vector2(199,231)
	room.eleanor.position = Vector2(148,127)
	room.rustler.position = Vector2(550,164)
	for index in range(6):
		var cow := StubActor.new()
		cow.position = Vector2(290+index*24,180)
		room.actors.add_child(cow)
		room.cows.append(cow)
	room.speech = StubSpeech.new()
	room.add_child(room.speech)
	for field in ["rope","rope_far_wrap","shot"]:
		var line := Line2D.new()
		room.add_child(line)
		room.set(field, line)
	room.buttons = GridContainer.new()
	room.add_child(room.buttons)
	for index in range(6): room.buttons.add_child(room.make_button("stub"))
	return room

## Every sub-room holds its owner and the owner holds every sub-room, which is
## a reference cycle GDScript cannot collect. Left alone it leaks at exit and
## the verifier reads a leak as a failure, so a finished case takes the room
## apart rather than only freeing the Control.
func dispose(companion, room: Control) -> void:
	for field in ["lantern","mechanic","cart","camp_care","ines","birdie","companion_actors","lantern_equipment"]:
		companion.set(field, null)
	companion.simple_companions.clear()
	room.free()

func remove_save(path: String) -> void:
	for name in [path, path + ".bak"]:
		var absolute := ProjectSettings.globalize_path(name)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

## Each fate is decided on a real room, written, deliberately contradicted in
## memory, and read back. Contradicting the live room first is what makes this
## a test of the save rather than of the room still holding what it held.
func fate_roundtrip(choice: String) -> void:
	var path := "user://snapshot-test-fate-%s.json" % choice
	remove_save(path)
	var room := fresh_room()
	var companion = CompanionRoom.new(room)
	room.rustler_surrenders("He waits on your word.")
	check(room.choose_rustler(choice), "The room accepts the fate %s" % choice)
	var decided := {"cash":room.cash,"fate":room.rustler_fate,"hired":room.rustler_hired,
		"present":room.rustler_present,"surrendered":room.rustler_surrendered}
	check(companion.save_game(path), "A decided encounter can be saved (%s)" % choice)
	room.cash = 0
	room.rustler_fate = ""
	room.rustler_hired = false
	room.rustler_present = false
	room.rustler_surrendered = false
	room.rustler_active = true
	room.rustler.visible = false
	check(companion.load_game(path), "A decided encounter reloads (%s)" % choice)
	check(room.cash == decided.cash, "%s pays the same money after a reload" % choice)
	check(room.rustler_fate == decided.fate, "%s is still the fate after a reload" % choice)
	check(room.rustler_hired == decided.hired, "%s keeps its hired state after a reload" % choice)
	check(room.rustler_present == decided.present, "%s keeps its presence after a reload" % choice)
	check(room.rustler_surrendered, "%s remembers that he gave up" % choice)
	check(not room.rustler_active, "%s cannot leave him fighting" % choice)
	check(not room.rustler_choice_pending(), "%s is not asked again" % choice)
	# The reported bug: a man roped for the law or riding for wages is on this
	# ground and has to be on screen. Against the old one-line visibility rule
	# these two go red.
	check(room.rustler.visible == decided.present,
		"%s leaves the rustler visible exactly while he is present" % choice)
	remove_save(path)
	dispose(companion, room)

func verify_rustler_persistence() -> void:
	for choice in RoomScript.RUSTLER_CHOICES: fate_roundtrip(choice)

	# A choice the player never answered is a question the reload has to ask
	# again, buttons and all.
	var pending_path := "user://snapshot-test-fate-pending.json"
	remove_save(pending_path)
	var room := fresh_room()
	var companion = CompanionRoom.new(room)
	room.rustler_surrenders("He waits on your word.")
	check(room.rustler_choice_pending(), "An unanswered surrender is pending before the save")
	check(companion.save_game(pending_path), "A pending decision can be saved")
	# Answer it in memory, so a reload that failed to restore the question would
	# come back settled rather than merely looking untouched.
	check(room.choose_rustler("loose"), "The pending decision is answered in memory")
	check(companion.load_game(pending_path), "A pending decision reloads")
	check(room.rustler_choice_pending(), "The unanswered question is asked again after a reload")
	check(room.rustler_fate.is_empty(), "A reload does not invent an answer")
	var offered := 0
	for button in room.choice_buttons:
		if is_instance_valid(button) and button.visible and not button.disabled: offered += 1
	check(offered == RoomScript.RUSTLER_CHOICES.size(),
		"All %d answers are offered again after a reload, not %d" % [RoomScript.RUSTLER_CHOICES.size(), offered])
	remove_save(pending_path)
	dispose(companion, room)

	# Saves written before the decision existed carry none of these fields.
	var legacy_path := "user://snapshot-test-fate-legacy.json"
	remove_save(legacy_path)
	var old_room := fresh_room()
	var old_companion = CompanionRoom.new(old_room)
	check(old_companion.save_game(legacy_path), "A save is written to strip back to an older schema")
	var legacy: Dictionary = Storage.read(legacy_path)
	check(not legacy.is_empty(), "The written save can be read back for editing")
	for key in ["rustler_fate","rustler_hired","rustler_present","rustler_surrendered"]:
		check(legacy.has(key), "A current save carries %s" % key)
		legacy.erase(key)
	legacy.rustler_active = false
	remove_save(legacy_path)
	check(Snapshot.validate(legacy.duplicate(true)), "An older save without the fate fields still validates")
	check(Storage.write(legacy_path, legacy), "The older-schema save is written")
	old_room.rustler_fate = "hire"
	old_room.rustler_hired = true
	old_room.rustler_surrendered = true
	check(old_companion.load_game(legacy_path), "An older save still loads")
	check(old_room.rustler_fate.is_empty() and not old_room.rustler_hired and not old_room.rustler_surrendered,
		"An older save defaults to an undecided rustler instead of erroring")
	check(old_room.rustler_present == old_room.rustler_active,
		"An older save leaves presence exactly where it left activity")
	check(old_room.rustler.visible == old_room.rustler_active,
		"An older save keeps its original visibility")
	remove_save(legacy_path)

	# Tampering. The validator is the gate, so it is measured directly and then
	# once more through the loader with no backup to fall through to.
	var sound: Dictionary = legacy.duplicate(true)
	sound.rustler_active = false
	sound.rustler_surrendered = true
	sound.rustler_fate = "hire"
	sound.rustler_hired = true
	sound.rustler_present = true
	check(Snapshot.validate(sound.duplicate(true)), "Positive control: an honest hired rustler validates")
	var unknown := sound.duplicate(true)
	unknown.rustler_fate = "shot_him"
	check(not Snapshot.validate(unknown), "An unauthored fate is refused")
	var numeric := sound.duplicate(true)
	numeric.rustler_fate = 3
	check(not Snapshot.validate(numeric), "A fate that is not even a string is refused")
	var fighting := sound.duplicate(true)
	fighting.rustler_active = true
	check(not Snapshot.validate(fighting), "A decided fate cannot leave the rustler active")
	var unbeaten := sound.duplicate(true)
	unbeaten.rustler_surrendered = false
	check(not Snapshot.validate(unbeaten), "A fate cannot be handed to a man who never gave up")
	var wrong_hire := sound.duplicate(true)
	wrong_hire.rustler_fate = "law"
	check(not Snapshot.validate(wrong_hire), "The county does not put him on the payroll")
	var ghost := sound.duplicate(true)
	ghost.rustler_present = false
	check(not Snapshot.validate(ghost), "A hired hand cannot be off the ground")
	var freeloader := legacy.duplicate(true)
	freeloader.rustler_hired = true
	check(not Snapshot.validate(freeloader), "Nobody draws wages without a decision that hired him")
	var surrendered_and_fighting := legacy.duplicate(true)
	surrendered_and_fighting.rustler_surrendered = true
	surrendered_and_fighting.rustler_active = true
	check(not Snapshot.validate(surrendered_and_fighting), "A surrendered rustler is not still fighting")

	var tampered_path := "user://snapshot-test-fate-tampered.json"
	remove_save(tampered_path)
	check(Storage.write(tampered_path, unknown), "The tampered save is written to a path with no backup")
	check(not old_companion.load_game(tampered_path), "The loader refuses a tampered fate outright")
	remove_save(tampered_path)
	dispose(old_companion, old_room)

func _initialize() -> void:
	var cattle := []
	for index in range(6): cattle.append({"position":[300+index*30,180],"secured":false})
	var data := {"version":1,"player":[199,231],"eleanor":[148,127],"cattle":cattle,"cash":342,"ammo":6,"minutes":720,"hits":0,"won":false,"talked":false,"rustler_active":true,"spoken_beats":{},"companion":State.new().to_dict()}
	assert(Snapshot.validate(data))
	var care_save := data.duplicate(true)
	care_save.camp_recovery = {"version":1,"next_available":{"player":2160,"ada_mercer":2160}}
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(care_save))),"Shared care ledger survives outer JSON validation")
	care_save.camp_recovery.next_available.player = NAN
	assert(not Snapshot.validate(care_save),"Nonfinite care deadline fails before live loading")
	care_save.camp_recovery = []
	assert(not Snapshot.validate(care_save),"Wrong care type cannot reach a typed loader")
	var orphaned_cart := data.duplicate(true)
	orphaned_cart.ada_cart_position = "bad position"
	assert(not Snapshot.validate(orphaned_cart))
	orphaned_cart = data.duplicate(true)
	orphaned_cart.ada_cart_heading = [0,0]
	assert(not Snapshot.validate(orphaned_cart))
	data["generated_companions"] = Roster.new().to_dict()
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(data))))
	var bad_roster := data.duplicate(true)
	bad_roster.generated_companions.records = [null]
	assert(not Snapshot.validate(bad_roster))
	data.erase("generated_companions")
	data["ada_companion"] = Ada.new().to_dict()
	assert(Snapshot.validate(data))
	var bad_ada := data.duplicate(true)
	bad_ada.ada_companion = []
	assert(not Snapshot.validate(bad_ada))
	data.erase("ada_companion")
	data["lantern_adventure"] = Lantern.new().to_dict()
	assert(Snapshot.validate(data),"New saves include an untouched lantern adventure")
	var bad_lantern := data.duplicate(true)
	bad_lantern.lantern_adventure = []
	assert(not Snapshot.validate(bad_lantern),"Reject wrong adventure type before typed loading")
	data.erase("lantern_adventure")
	assert(Snapshot.validate(data),"Older room saves remain supported")
	var invalid := data.duplicate(true)
	invalid.companion = []
	assert(not Snapshot.validate(invalid),"Wrong companion type must not invoke a typed load method")
	invalid = data.duplicate(true)
	invalid.won = true
	assert(not Snapshot.validate(invalid),"Completion cannot contradict cattle/rustler state")
	invalid = data.duplicate(true)
	invalid.player = [NAN,20]
	assert(not Snapshot.validate(invalid))
	invalid = data.duplicate(true)
	invalid.ammo = 2.5
	assert(not Snapshot.validate(invalid))
	invalid = data.duplicate(true)
	invalid.spoken_beats = {"first_catch":"false"}
	assert(not Snapshot.validate(invalid))
	var companion := State.new()
	companion.recruit(true,true)
	data.companion = companion.to_dict()
	assert(not Snapshot.validate(data),"Recruitment requires completed encounter in the outer save")
	for cow in data.cattle: cow.secured = true
	data.won = true
	data.talked = true
	data.rustler_active = false
	assert(Snapshot.validate(data))
	var lantern := Lantern.new()
	assert(lantern.begin(true,false,["0","1","2"]).ok)
	data["lantern_adventure"] = lantern.to_dict()
	assert(not Snapshot.validate(data),"Lantern activity requires first companion activity completion")
	companion.begin_adventure()
	for id in ["0","1","2"]: companion.steady_cattle(id)
	companion.finish_adventure()
	data.companion = companion.to_dict()
	assert(Snapshot.validate(data),"Persist an active lantern checkpoint alongside recruited companion")
	var rested_save := data.duplicate(true)
	assert(companion.shared_rest(720,true).ok)
	rested_save.companion = companion.to_dict()
	assert(Snapshot.validate(rested_save),"Old save with Eleanor rest remains readable")
	var restored = Care.restored_recovery(rested_save)
	assert(restored.next_available.player==2160 and restored.next_available.eleanor==2160)
	rested_save.camp_recovery = {"version":1,"next_available":{}}
	assert(not Snapshot.validate(rested_save),"Explicit ledger cannot erase a prior partner cooldown")
	rested_save.camp_recovery = restored.to_dict()
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(rested_save))))
	var wrong_owner := data.duplicate(true)
	wrong_owner.companion = State.new().to_dict()
	assert(not Snapshot.validate(wrong_owner),"An unrecruited companion cannot own an adventure checkpoint")
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(data))),"JSON numeric conversion remains compatible")
	var cart = Cart.new()
	data.ada_cart_adventure = cart.to_dict()
	data.ada_cart_position = [220,280]
	assert(Snapshot.validate(data))
	cart.begin(true,false)
	data.ada_cart_adventure = cart.to_dict()
	assert(not Snapshot.validate(data),"Cart requires Ada recruitment and completed crossing")
	lantern.settle_spirit()
	lantern.begin_guiding()
	for id in ["0","1","2"]: lantern.guide_cattle(id)
	lantern.finish_at_wagon(true)
	data.lantern_adventure = lantern.to_dict()
	var ada = Ada.new()
	ada.meet()
	ada.repair.recover_regulator()
	ada.repair.set_vent(true)
	ada.repair.tick(3)
	ada.repair.install_regulator()
	ada.repair.set_vent(false)
	ada.repair.set_feed(true)
	ada.repair.tick(3)
	ada.repair.set_feed(false)
	ada.repair.test_machine()
	ada.invite(true)
	data.ada_companion = ada.to_dict()
	data.ada_cart_heading = [0,-1]
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(data))),"Active cart restores with real prerequisite states")
	var bad_heading := data.duplicate(true)
	bad_heading.ada_cart_heading = [0,0]
	assert(not Snapshot.validate(bad_heading))
	var bad_cart := data.duplicate(true)
	bad_cart.ada_cart_position = [INF,280]
	assert(not Snapshot.validate(bad_cart))
	var ines = load("res://scripts/ines_companion.gd").new()
	data.ines_companion = ines.to_dict()
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(data))),"Optional Ines state survives JSON roundtrip")
	var premature_ines := data.duplicate(true)
	ines.meet()
	premature_ines.ines_companion = ines.to_dict()
	assert(not Snapshot.validate(premature_ines),"Ines encounter cannot precede completed cart outing")
	cart.inspect()
	cart.set_valve(0,true)
	cart.set_valve(2,true)
	cart.confirm_routing()
	for checkpoint in range(3): cart.checkpoint_arrived(checkpoint)
	assert(cart.finish_at_camp(true).ok)
	premature_ines.ada_cart_adventure = cart.to_dict()
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(premature_ines))),"Met Ines restores after the real prerequisite outing")
	var bad_ines := data.duplicate(true)
	bad_ines.ines_companion.age = 17
	assert(not Snapshot.validate(bad_ines),"Named adult identity is fixed")
	bad_ines = data.duplicate(true)
	bad_ines.ines_companion = []
	assert(not Snapshot.validate(bad_ines),"Ines save must be a typed record")
	verify_rustler_persistence()
	# The denominator: a run that silently checked nothing must not read as a pass.
	check(checks >= 40, "Instrument check: the rustler cases must actually run")
	if failures > 0:
		push_error("ROOM SNAPSHOT FAIL: %d of %d checks failed" % [failures, checks])
		print("ROOM SNAPSHOT FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)
		return
	print("ROOM SNAPSHOT PASS: typed data, finite positions, encounter consistency and JSON roundtrip / %d rustler fate checks: three fates round-trip with money, presence, hired state and visibility, a pending choice is re-offered, older saves default, impossible fates refused" % checks)
	quit()
