extends SceneTree
const Repair = preload("res://scripts/steam_repair.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var r := Repair.new()
	check(r.load_dict(JSON.parse_string(JSON.stringify(r.to_dict()))),"Default JSON roundtrip")
	check(not r.install_regulator().ok and not r.test_machine().ok,"Cannot install or test missing part")
	check(r.recover_regulator().ok and not r.recover_regulator().ok,"Part recovery once")
	check(not r.install_regulator().ok,"Cannot install hot live machine")
	r.set_feed(false)
	r.tick(10)
	check(r.pressure == 60,"Closing feed alone cannot depressurize")
	r.set_vent(true)
	r.tick(2)
	check(r.pressure == 12 and not r.install_regulator().ok,"Partial vent insufficient")
	r.tick(0.5)
	check(r.pressure == 0 and r.install_regulator().ok,"Vented installation")
	check(not r.install_regulator().ok,"No duplicate installation")
	r.set_feed(true)
	r.tick(5)
	check(r.pressure == 0 and not r.test_machine().ok,"Open vent defeats feed and test")
	r.set_vent(false)
	r.tick(3)
	check(r.pressure == 36 and not r.test_machine().ok,"Target pressure must be isolated stable")
	r.set_feed(false)
	r.tick(3)
	check(r.pressure == 36 and r.test_machine().ok,"Stable target completes")
	var finished := r.to_dict()
	check(not r.test_machine().ok and not r.set_feed(true).ok and not r.set_vent(true).ok,"Completion once and controls locked")
	r.tick(100)
	check(r.to_dict() == finished,"Completed state remains stable")
	var restored := Repair.new()
	check(restored.load_dict(JSON.parse_string(JSON.stringify(finished))) and not restored.test_machine().ok,"Saved completion remains one-shot")
	var faulted := Repair.new()
	faulted.recover_regulator()
	faulted.tick(100000)
	check(faulted.fault and not faulted.feed_open and faulted.pressure > 85 and faulted.pressure <= 100,"Overpressure closes feed at threshold even for huge step")
	check(not faulted.set_feed(true).ok,"Fault blocks feeding")
	var retry := Repair.new()
	check(retry.load_dict(JSON.parse_string(JSON.stringify(faulted.to_dict()))),"Fault checkpoint roundtrip")
	retry.set_vent(true)
	retry.tick(10)
	check(not retry.fault and retry.pressure == 0 and retry.regulator_recovered,"Vent safely clears fault without losing regulator")
	check(retry.install_regulator().ok,"Retry can install recovered identity")
	var before := retry.to_dict()
	for delta in [-1.0,NAN,INF,-INF]: retry.tick(delta)
	check(retry.to_dict() == before,"Invalid delta ignored")
	var coarse := Repair.new()
	var fine := Repair.new()
	coarse.tick(8)
	for i in range(80): fine.tick(0.1)
	check(is_equal_approx(coarse.pressure,fine.pressure) and coarse.fault == fine.fault,"Fault behavior independent of frame partition")
	for mutation in ["extra","missing","version","bool_version","fraction_version","foreign","nan","negative","overflow","type","part","fault_feed","fault_low","hot_clear","completed_live"]:
		var bad := finished.duplicate(true)
		match mutation:
			"extra": bad.extra = 1
			"missing": bad.erase("fault")
			"version": bad.version = 2
			"bool_version": bad.version = true
			"fraction_version": bad.version = 1.1
			"foreign": bad.machine_id = "other"
			"nan": bad.pressure = NAN
			"negative": bad.pressure = -1
			"overflow": bad.pressure = 101
			"type": bad.feed_open = 0
			"part": bad.regulator_recovered = false
			"fault_feed":
				bad.completed = false
				bad.fault = true
				bad.feed_open = true
			"fault_low":
				bad.completed = false
				bad.fault = true
				bad.pressure = 0
			"hot_clear":
				bad.completed = false
				bad.pressure = 90
			"completed_live": bad.feed_open = true
		check(not r.load_dict(bad) and r.to_dict() == finished,"Atomic rejection " + mutation)
	print("STEAM REPAIR %s: %d checks" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(1 if failures else 0)
