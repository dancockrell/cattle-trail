extends RefCounted
## Schedules authored whole-pose bridges; never loads textures or invents facings.
## definitions[from][to]["walk" or "idle"] = {"clip": String, "seconds": float}
## request() returns a snapshot or {} when no bridge is available.
## step() returns the completed snapshot ONCE, otherwise {}. Its preserved phase
## belongs to the destination gait, not to the bridge clip's animation progress.

const MIN_SECONDS := 0.02
const MAX_SECONDS := 0.20
const DEFAULT_SECONDS := 0.08

var active := false
var source_direction := ""
var target_direction := ""
var clip := ""
var moving := false
var phase := 0.0
var remaining := 0.0
var duration := 0.0

func request(from_direction: String, to_direction: String, is_moving: bool,
		normalized_phase: float, definitions: Dictionary) -> Dictionary:
	# A repeated input sample must not keep restarting a finite bridge.
	if active and source_direction == from_direction and target_direction == to_direction and moving == is_moving:
		return snapshot()
	# Retargeting always discards the old bridge, even if the new pair is missing.
	cancel()
	if from_direction == to_direction:
		return {}
	var destinations: Variant = definitions.get(from_direction, {})
	if not destinations is Dictionary:
		return {}
	var modes: Variant = destinations.get(to_direction, {})
	if not modes is Dictionary:
		return {}
	var definition: Variant = modes.get("walk" if is_moving else "idle", {})
	if not definition is Dictionary:
		return {}
	var selected: Variant = definition.get("clip", "")
	if not (selected is String or selected is StringName) or str(selected).is_empty():
		return {}
	var seconds: Variant = definition.get("seconds", DEFAULT_SECONDS)
	if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or float(seconds) <= 0.0:
		return {}
	source_direction = from_direction
	target_direction = to_direction
	clip = str(selected)
	moving = is_moving
	phase = fposmod(normalized_phase, 1.0) if is_finite(normalized_phase) else 0.0
	duration = clampf(float(seconds), MIN_SECONDS, MAX_SECONDS)
	remaining = duration
	active = true
	return snapshot()

func step(delta: float) -> Dictionary:
	if not active or not is_finite(delta) or delta <= 0.0:
		return {}
	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return {}
	var completed := snapshot()
	completed["completed"] = true
	cancel()
	return completed

func cancel() -> void:
	active = false
	source_direction = ""
	target_direction = ""
	clip = ""
	moving = false
	phase = 0.0
	remaining = 0.0
	duration = 0.0

func snapshot() -> Dictionary:
	if not active:
		return {}
	return {"from": source_direction, "to": target_direction, "clip": clip,
		"moving": moving, "phase": phase, "remaining": remaining,
		"duration": duration, "completed": false}
