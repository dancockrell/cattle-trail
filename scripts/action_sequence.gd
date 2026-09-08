extends RefCounted
## One action clock owns the visible pose and its gameplay event, including skipped frames.
var durations: Array[float] = []
var total := 0.0
var elapsed := 0.0
var event_frame := -1
var event_at := INF
var emitted := false
var active := false

func start(holds: Array, release_frame := -1) -> bool:
	if holds.is_empty() or release_frame < -1 or release_frame >= holds.size(): return false
	var candidate: Array[float] = []
	var seconds := 0.0
	for hold in holds:
		if not (hold is int or hold is float) or not is_finite(float(hold)) or float(hold)<=0: return false
		candidate.append(float(hold))
		seconds += float(hold)
	if not is_finite(seconds): return false
	durations = candidate
	total = seconds
	elapsed = 0.0
	event_frame = release_frame
	event_at = INF
	if release_frame>=0:
		event_at = 0.0
		for index in range(release_frame): event_at += durations[index]
	emitted = false
	active = true
	return true

func advance(delta: float) -> Dictionary:
	if not active or not is_finite(delta) or delta<0: return {}
	elapsed = minf(total,elapsed+delta)
	var fire := event_frame>=0 and not emitted and elapsed>=event_at
	if fire: emitted = true
	var selected := durations.size()-1
	var progress := 1.0
	var remaining := elapsed
	for index in range(durations.size()):
		if remaining<durations[index]:
			selected = index
			progress = remaining/durations[index]
			break
		remaining -= durations[index]
	active = elapsed<total
	return {"frame":selected,"progress":progress,"done":not active,
		"event_frame":event_frame if fire else -1,"remaining":maxf(0,total-elapsed)}

func cancel() -> void:
	active = false
