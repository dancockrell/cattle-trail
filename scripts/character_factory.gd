extends RefCounted
## Stable identities select finished whole-character art; they never assemble body parts.
## Candidate art is available only to an explicitly requested production preview.
const FIRST_NAMES := ["Nell", "June", "Clara", "Lucia", "Mae", "Pearl", "Willa", "Celia", "Rose", "Tess", "Vera", "Lena", "Iris", "Alma", "Della", "Sofia"]
const LAST_NAMES := ["Bell", "Reed", "Flores", "Hart", "Voss", "Pike", "Santos", "Quinn", "Finch", "Hale", "Mercado", "West", "Bennett", "Marsh", "Cross", "Vega"]
const TEMPERAMENTS := ["dry wit", "bright curiosity", "quiet confidence", "playful daring", "warm directness", "patient mischief"]

func create_roster(catalog: Dictionary, world_seed: String, count: int, preview := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if count <= 0 or not catalog.get("variants") is Array: return result
	var pool: Array[Dictionary] = []
	var seen := {}
	for entry in catalog.variants:
		if not entry is Dictionary: continue
		if not entry.get("id") is String or entry.id.is_empty() or seen.has(entry.id): continue
		var age = entry.get("age")
		if not (age is int or age is float): continue
		if not is_finite(float(age)) or age < 18 or age > 100 or floorf(age) != age: continue
		if not entry.get("atlas") is String or entry.atlas.is_empty(): continue
		if not entry.get("rect") is Array or entry.rect.size() != 4: continue
		var status = entry.get("status", "candidate")
		if status != "approved" and (not preview or status != "candidate"): continue
		seen[entry.id] = true
		pool.append(entry.duplicate(true))
	# Hash rank avoids changing existing identity details when the catalog order changes.
	pool.sort_custom(func(a: Dictionary, b: Dictionary):
		var ar: String = (world_seed + "/" + a.id).sha256_text()
		var br: String = (world_seed + "/" + b.id).sha256_text()
		return ar < br if ar != br else a.id < b.id)
	for entry in pool.slice(0, mini(count, pool.size())):
		var digest: String = (world_seed + "/identity/" + entry.id).sha256_text()
		var index: int = digest.substr(0, 7).hex_to_int()
		var family: String = entry.get("family", "traveler")
		result.append({
			"id": "generated_" + digest.substr(0, 20), "origin": "generated", "art_id": entry.id,
			"name": FIRST_NAMES[index % FIRST_NAMES.size()] + " " + LAST_NAMES[(index / 16) % LAST_NAMES.size()],
			"age": int(entry.age), "family": family, "temperament": TEMPERAMENTS[(index / 256) % TEMPERAMENTS.size()],
			"sprite": {"atlas": entry.atlas, "rect": entry.rect.map(func(n): return int(n)), "anchor": entry.get("anchor", [32, 61]).map(func(n): return int(n))},
			"production_preview": entry.get("status", "candidate") != "approved",
			"recruitment": "available", "relationship": "unmet", "trust": 0, "affection": 0,
			"madness": 10, "romance_requires_mutual_acceptance": true,
			"perk_id": {"rancher":"steady_herd", "mechanic":"field_repairs", "spirit-scout":"spirit_sense"}.get(family, "trail_company"),
			"perk_status": "design_only", "animation_status": "static_identity_only"
		})
	return result
