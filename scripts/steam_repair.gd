extends RefCounted
## Fictional pressure units for Ada's regulator puzzle; no recruitment or rewards.
const VERSION := 1
const MACHINE_ID := "ada_agricultural_walker"
const FEED_RATE := 12.0
const VENT_RATE := 24.0
var pressure := 60.0
var feed_open := true
var vent_open := false
var regulator_recovered := false
var regulator_installed := false
var fault := false
var completed := false

func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok":ok,"reason":reason,"machine_id":MACHINE_ID}

func set_feed(open: bool) -> Dictionary:
	if completed: return _result(false,"already_completed")
	if open and fault: return _result(false,"vent_to_clear_fault")
	feed_open = open
	return _result(true,"feed_opened" if open else "feed_closed")

func set_vent(open: bool) -> Dictionary:
	if completed: return _result(false,"already_completed")
	vent_open = open
	return _result(true,"vent_opened" if open else "vent_closed")

func recover_regulator() -> Dictionary:
	if completed: return _result(false,"already_completed")
	if regulator_recovered: return _result(false,"already_recovered")
	regulator_recovered = true
	return _result(true,"regulator_recovered")

func install_regulator() -> Dictionary:
	if completed: return _result(false,"already_completed")
	if regulator_installed: return _result(false,"already_installed")
	if not regulator_recovered: return _result(false,"missing_regulator")
	if feed_open or pressure > 5.0 or fault: return _result(false,"depressurize_first")
	regulator_installed = true
	return _result(true,"regulator_installed")

func tick(delta: float) -> void:
	if completed or not is_finite(delta) or delta <= 0: return
	var rate := (FEED_RATE if feed_open else 0.0) - (VENT_RATE if vent_open else 0.0)
	# Event-driven threshold handling is independent of frame size. Crossing the
	# fault threshold closes feed immediately; pressure remains bounded.
	if rate > 0 and pressure + rate * delta > 85.0:
		pressure = 85.000001
		fault = true
		feed_open = false
	else:
		pressure = clampf(pressure + rate * delta,0.0,100.0)
	if fault and vent_open and not feed_open and pressure <= 5.0:
		fault = false

func test_machine() -> Dictionary:
	if completed: return _result(false,"already_completed")
	if not regulator_installed: return _result(false,"install_regulator_first")
	if fault or vent_open or feed_open: return _result(false,"isolate_stable_pressure")
	if pressure < 30.0 or pressure > 50.0: return _result(false,"target_pressure_30_to_50")
	completed = true
	return _result(true,"machine_repaired")

func to_dict() -> Dictionary:
	return {"version":VERSION,"machine_id":MACHINE_ID,"pressure":pressure,
		"feed_open":feed_open,"vent_open":vent_open,"regulator_recovered":regulator_recovered,
		"regulator_installed":regulator_installed,"fault":fault,"completed":completed}

func load_dict(data: Dictionary) -> bool:
	var d := data.duplicate(true)
	if d.size() != to_dict().size(): return false
	for key in to_dict():
		if not d.has(key): return false
	if not (d.version is int or d.version is float) or d.version != VERSION: return false
	if not d.machine_id is String or d.machine_id != MACHINE_ID: return false
	if not (d.pressure is int or d.pressure is float): return false
	if not is_finite(float(d.pressure)) or d.pressure < 0 or d.pressure > 100: return false
	for key in ["feed_open","vent_open","regulator_recovered","regulator_installed","fault","completed"]:
		if not d[key] is bool: return false
	if d.regulator_installed and not d.regulator_recovered: return false
	if d.fault and (d.feed_open or d.pressure <= 5): return false
	if d.pressure > 85 and not d.fault: return false
	if d.completed and (not d.regulator_installed or d.fault or d.feed_open or d.vent_open or d.pressure < 30 or d.pressure > 50): return false
	pressure = float(d.pressure)
	feed_open = d.feed_open
	vent_open = d.vent_open
	regulator_recovered = d.regulator_recovered
	regulator_installed = d.regulator_installed
	fault = d.fault
	completed = d.completed
	return true
