extends SceneTree
const Resolver = preload("res://scripts/cattle_drive_resolver.gd")

func _initialize() -> void:
	# Clear route: a clean drive costs nothing.
	var clear := Resolver.resolve_leg({"herd_count": 200, "route_hazard": "clear", "is_night_leg": false, "perks": {}})
	assert(clear.count_after == 200, "A clear route must not lose any head")
	assert(is_equal_approx(clear.condition, 1.0), "A clear route must leave the herd calm/well-handled")

	# Narrow Water crossing: loses head, and steady_herd measurably reduces that loss.
	var crossing_no_perk := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "narrow_water_crossing", "is_night_leg": false, "perks": {}})
	var crossing_with_perk := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "narrow_water_crossing", "is_night_leg": false, "perks": {"has_steady_herd": true}})
	assert(crossing_no_perk.count_after < 300, "The Narrow Water crossing must cost head with no mitigation")
	assert(crossing_with_perk.count_after > crossing_no_perk.count_after, "steady_herd must measurably reduce the crossing's loss compared to the same crossing without it")

	# stampede_risk with spirit_sense produces a better outcome than without it.
	var stampede_no_perk := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "stampede_risk", "is_night_leg": false, "perks": {}})
	var stampede_with_perk := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "stampede_risk", "is_night_leg": false, "perks": {"has_spirit_sense": true}})
	assert(stampede_with_perk.count_after >= stampede_no_perk.count_after, "spirit_sense's advance warning must not leave the drive worse off on a stampede")
	assert(stampede_with_perk.count_after > stampede_no_perk.count_after or stampede_with_perk.condition > stampede_no_perk.condition, "spirit_sense must produce a strictly better outcome (count or condition) on a stampede than the same hazard without it")

	# A hazard that is NOT tied to "late signs" (the river) must not be softened by spirit_sense,
	# matching DRIVES.md's point that the crossing is a physical hazard, not a late-sign warning.
	var crossing_with_spirit_sense := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "narrow_water_crossing", "is_night_leg": false, "perks": {"has_spirit_sense": true}})
	assert(crossing_with_spirit_sense.count_after == crossing_no_perk.count_after, "spirit_sense must not mitigate a purely physical hazard like the river crossing")

	# Night vs day: the Second Shadow (night-relevant) is measurably worse at night;
	# a non-night-relevant hazard (the river) gets no such penalty.
	var second_shadow_day := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "second_shadow_leg", "is_night_leg": false, "perks": {}})
	var second_shadow_night := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "second_shadow_leg", "is_night_leg": true, "perks": {}})
	assert(second_shadow_night.count_after < second_shadow_day.count_after or second_shadow_night.condition < second_shadow_day.condition, "A night leg on the Second Shadow's hazard must be measurably worse than the same hazard by day")

	var river_day := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "narrow_water_crossing", "is_night_leg": false, "perks": {}})
	var river_night := Resolver.resolve_leg({"herd_count": 300, "route_hazard": "narrow_water_crossing", "is_night_leg": true, "perks": {}})
	assert(river_day.count_after == river_night.count_after and is_equal_approx(river_day.condition, river_night.condition), "A hazard not tied to night (the river crossing) must not receive the night penalty")

	# Bounds: count_after never exceeds herd_count and never goes negative, even on an
	# adversarial tiny herd with a bad hazard and worst-case (night, no mitigation) conditions.
	var tiny := Resolver.resolve_leg({"herd_count": 1, "route_hazard": "stampede_risk", "is_night_leg": true, "perks": {}})
	assert(tiny.count_after >= 0 and tiny.count_after <= 1, "count_after must stay within [0, herd_count] on a tiny adversarial herd")
	var zero := Resolver.resolve_leg({"herd_count": 0, "route_hazard": "second_shadow_leg", "is_night_leg": true, "perks": {}})
	assert(zero.count_after == 0, "An empty herd must resolve to zero, never negative")
	var negative_input := Resolver.resolve_leg({"herd_count": -5, "route_hazard": "rustler_territory", "is_night_leg": false, "perks": {}})
	assert(negative_input.count_after == 0, "A malformed negative herd_count must clamp to zero rather than propagate")

	# Unknown hazard falls back to clear rather than crashing or silently losing head.
	var unknown := Resolver.resolve_leg({"herd_count": 50, "route_hazard": "not_a_real_hazard", "is_night_leg": false, "perks": {}})
	assert(unknown.count_after == 50, "An unrecognized hazard must fail safe to a clear-route outcome")

	print("CATTLE DRIVE RESOLVER PASS: clear route, Narrow Water crossing reduced by steady_herd, stampede improved by spirit_sense, physical hazard unaffected by spirit_sense, Second Shadow night penalty vs unaffected day-only hazard, and count_after bounds under adversarial and malformed input")
	quit()
