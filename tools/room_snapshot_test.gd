extends SceneTree
const Snapshot = preload("res://scripts/room_snapshot.gd")
const State = preload("res://scripts/companion_state.gd")
const Lantern = preload("res://scripts/lantern_adventure.gd")
const Ada = preload("res://scripts/ada_companion.gd")
const Roster = preload("res://scripts/generated_companion_roster.gd")
const Cart = preload("res://scripts/ada_cart_adventure.gd")

func _initialize() -> void:
	var cattle := []
	for index in range(6): cattle.append({"position":[300+index*30,180],"secured":false})
	var data := {"version":1,"player":[199,231],"eleanor":[148,127],"cattle":cattle,"cash":342,"ammo":6,"minutes":720,"hits":0,"won":false,"talked":false,"rustler_active":true,"spoken_beats":{},"companion":State.new().to_dict()}
	assert(Snapshot.validate(data))
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
	print("ROOM SNAPSHOT PASS: typed data, finite positions, encounter consistency and JSON roundtrip")
	quit()
