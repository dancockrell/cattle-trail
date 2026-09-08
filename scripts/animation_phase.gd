extends RefCounted
## Transfer elapsed cycle time between strips with different frame counts and holds.

static func phase_at(durations: Array, frame: int, progress: float) -> float:
	var total := 0.0
	var elapsed := 0.0
	for index in range(durations.size()):
		var duration := float(durations[index])
		total += duration
		if index < frame: elapsed += duration
		elif index == frame: elapsed += duration * clampf(progress,0.0,1.0)
	return fposmod(elapsed/total,1.0) if total>0 else 0.0

static func frame_at(durations: Array, phase: float) -> Vector2:
	var total := 0.0
	for duration in durations: total += float(duration)
	var remaining := fposmod(phase,1.0)*total
	for index in range(durations.size()):
		var duration := float(durations[index])
		if remaining < duration:
			return Vector2(index,remaining/duration)
		remaining -= duration
	return Vector2.ZERO
