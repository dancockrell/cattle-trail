extends RefCounted
## Simulation time, saved as total minutes since the first trail day began.
## Provisional pace: one trail minute per real second; no offline catch-up.
const MINUTES_PER_SECOND := 1.0

static func advance(minutes: float, delta: float, paused := false) -> float:
	if paused or not is_finite(delta) or delta<=0: return minutes
	var result := minutes+delta*MINUTES_PER_SECOND
	return result if is_finite(result) else minutes

static func label(minutes: float) -> String:
	var whole := maxi(0,int(minutes))
	var day := whole/1440+1
	var hour := (whole%1440)/60
	return "Day %d %02d:%02d" % [day,hour,whole%60]

static func remaining_minutes(now: float, available: float) -> int:
	return maxi(0,int(ceil(available-now)))
