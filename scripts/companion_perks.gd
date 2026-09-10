extends RefCounted
## Authored values only: saved character data selects IDs, never supplies power.
## Multipliers accumulate their excess over 1 before the shared cap is applied.
const DEFINITIONS := {
	"eleanor_perk": {"label":"Steady Company", "activation":"camp", "stat":"rest_madness_recovery", "operation":"add", "value":3.0, "cap":6.0},
	"steady_herd": {"label":"Trail Hand", "activation":"recruited", "stat":"lasso_follow_seconds", "operation":"add", "value":2.0, "cap":4.0},
	"field_repairs": {"label":"Sure-Handed Tuning", "activation":"field", "stat":"machine_repair_efficiency", "operation":"multiply", "value":1.1, "cap":1.25},
	"ada_mercer_perk": {"label":"Sure-Handed Tuning", "activation":"field", "stat":"machine_repair_efficiency", "operation":"multiply", "value":1.1, "cap":1.25},
	"spirit_sense": {"label":"Between the Footprints", "activation":"field", "stat":"trail_hazard_notice", "operation":"add", "value":1.0, "cap":2.0},
	"steady_aim": {"label":"Steady Aim", "activation":"field", "stat":"shot_range_bonus", "operation":"add", "value":20.0, "cap":40.0},
	"camp_song": {"label":"Camp Song", "activation":"camp", "stat":"rest_madness_recovery", "operation":"add", "value":2.0, "cap":6.0},
	"trail_company": {"label":"Good Company", "activation":"camp", "stat":"rest_madness_recovery", "operation":"add", "value":1.0, "cap":6.0}
}

static func resolve(companions: Array, context: String) -> Dictionary:
	var result := {"bonuses":{}, "sources":[]}
	if context not in ["camp", "field"]: return result
	var seen := {}
	for member in companions:
		if not member is Dictionary: continue
		var id = member.get("id")
		if not id is String or id.is_empty() or seen.has(id): continue
		seen[id] = true
		if member.get("recruitment") != "recruited" or member.get("production_preview", false): continue
		var perk_id = member.get("perk_id", "")
		if not perk_id is String or not DEFINITIONS.has(perk_id): continue
		var perk: Dictionary = DEFINITIONS[perk_id]
		if perk.activation != "recruited" and (perk.activation != context or member.get("party_assignment") != context): continue
		var baseline := 1.0 if perk.operation == "multiply" else 0.0
		var current := float(result.bonuses.get(perk.stat, baseline))
		result.bonuses[perk.stat] = minf(float(perk.cap), current + float(perk.value) - baseline)
		result.sources.append({"character_id":id, "perk_id":perk_id, "label":perk.label, "stat":perk.stat})
	return result

static func value(companions: Array, context: String, stat: String, baseline := 0.0) -> float:
	return float(resolve(companions, context).bonuses.get(stat, baseline))
