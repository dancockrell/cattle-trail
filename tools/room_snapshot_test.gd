extends SceneTree
const Snapshot = preload("res://scripts/room_snapshot.gd")
const State = preload("res://scripts/companion_state.gd")

func _initialize() -> void:
	var cattle := []
	for index in range(6): cattle.append({"position":[300+index*30,180],"secured":false})
	var data := {"version":1,"player":[199,231],"eleanor":[148,127],"cattle":cattle,"cash":342,"ammo":6,"minutes":720,"hits":0,"won":false,"talked":false,"rustler_active":true,"spoken_beats":{},"companion":State.new().to_dict()}
	assert(Snapshot.validate(data))
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
	assert(Snapshot.validate(JSON.parse_string(JSON.stringify(data))),"JSON numeric conversion remains compatible")
	print("ROOM SNAPSHOT PASS: typed data, finite positions, encounter consistency and JSON roundtrip")
	quit()
