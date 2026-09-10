extends RefCounted
## Stable identities select finished whole-character art; they never assemble body parts.
## Candidate art is available only to an explicitly requested production preview.
const FIRST_NAMES := ["Nell", "June", "Clara", "Lucia", "Mae", "Pearl", "Willa", "Celia", "Rose", "Tess", "Vera", "Lena", "Iris", "Alma", "Della", "Sofia",
	"Ada", "Beulah", "Cora", "Dot", "Effie", "Fannie", "Georgia", "Hazel", "Ida", "Josie", "Kate", "Lettie", "Minnie", "Nora", "Opal", "Piper",
	"Queenie", "Ruby", "Sallie", "Tilda", "Ursula", "Verna", "Winnie", "Ximena", "Yolanda", "Zora", "Beatriz", "Carmen", "Dolores", "Esperanza", "Flora", "Guadalupe"]
const LAST_NAMES := ["Bell", "Reed", "Flores", "Hart", "Voss", "Pike", "Santos", "Quinn", "Finch", "Hale", "Mercado", "West", "Bennett", "Marsh", "Cross", "Vega",
	"Alvarado", "Boone", "Carver", "Dade", "Ellison", "Farrow", "Gable", "Holt", "Ibarra", "Jacoby", "Kellerman", "Lowe", "Munroe", "Navarro", "Osgood", "Prescott",
	"Quintero", "Rourke", "Sawyer", "Tanner", "Underhill", "Vance", "Whitfield", "Yates", "Zamora", "Ashford", "Briggs", "Calloway", "Delgado", "Escobar", "Fenwick", "Graves"]
## Family archetype -> temperament pool. Each family draws from a distinct slice
## of flavor so a rancher and a spirit-scout never sound interchangeable even
## when hashed to the same index. Falls back to the shared pool for any family
## not listed here (see DEFAULT_TEMPERAMENTS).
const DEFAULT_TEMPERAMENTS := ["dry wit", "bright curiosity", "quiet confidence", "playful daring", "warm directness", "patient mischief",
	"stubborn cheer", "watchful calm", "restless energy", "unhurried patience", "sharp practicality", "gentle stubbornness",
	"guarded warmth", "loud confidence", "quiet intensity", "easy humor", "careful precision", "reckless generosity",
	"skeptical kindness", "steady nerve", "wry patience", "open curiosity", "measured pride", "hard-won calm"]
const FAMILY_TEMPERAMENTS := {
	"rancher": ["stubborn cheer", "unhurried patience", "steady nerve", "dry wit", "hard-won calm", "sharp practicality"],
	"mechanic": ["sharp practicality", "careful precision", "restless energy", "wry patience", "reckless generosity", "bright curiosity"],
	"spirit-scout": ["watchful calm", "quiet intensity", "guarded warmth", "measured pride", "skeptical kindness", "patient mischief"],
	"healer": ["warm directness", "gentle stubbornness", "quiet confidence", "steady nerve", "hard-won calm", "open curiosity"],
	"gunhand": ["quiet intensity", "guarded warmth", "watchful calm", "hard-won calm", "measured pride", "steady nerve"],
	"singer": ["easy humor", "loud confidence", "open curiosity", "playful daring", "reckless generosity", "bright curiosity"],
	"teamster": ["unhurried patience", "sharp practicality", "dry wit", "steady nerve", "stubborn cheer", "skeptical kindness"]
}
## Family archetype -> a short encounter-flavor fragment, combined with the
## drawn name/temperament to give each generated companion a specific reason
## for being on this trail rather than a bare label. Not a full authored
## encounter (see design/characters.json's named companions for that level of
## detail) -- this is the procedural layer's equivalent, sized to scale.
const FAMILY_HOOKS := {
	"rancher": "grew up breaking horses and mending fence on someone else's spread before deciding to ride for wages that came with a say in the work.",
	"mechanic": "learned steam and brass from a relative who couldn't get credit for it, and has been quietly better at the trade ever since.",
	"spirit-scout": "reads what a place remembers the way most people read a trail sign, and has learned not to explain that gift to strangers.",
	"healer": "picked up practical medicine from necessity, not a school, and trusts a working remedy over a impressive-sounding one.",
	"gunhand": "carried a gun for pay before deciding to carry it for a reason instead.",
	"singer": "worked saloons and camp fires for tips before an outfit finally offered a wage instead of a hat passed around.",
	"teamster": "has driven freight over worse roads than this trail and judges every wagon by whether it would have survived them."
}

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
		var temperaments: Array = FAMILY_TEMPERAMENTS.get(family, DEFAULT_TEMPERAMENTS)
		result.append({
			"id": "generated_" + digest.substr(0, 20), "origin": "generated", "art_id": entry.id,
			"name": FIRST_NAMES[index % FIRST_NAMES.size()] + " " + LAST_NAMES[(index / 16) % LAST_NAMES.size()],
			"age": int(entry.age), "family": family, "temperament": temperaments[(index / 256) % temperaments.size()],
			"hook": FAMILY_HOOKS.get(family, "took up trail work for reasons of her own, and hasn't explained them yet."),
			"sprite": {"atlas": entry.atlas, "rect": entry.rect.map(func(n): return int(n)), "anchor": entry.get("anchor", [32, 61]).map(func(n): return int(n))},
			"production_preview": entry.get("status", "candidate") != "approved",
			"recruitment": "available", "relationship": "unmet", "trust": 0, "affection": 0,
			"madness": 10, "romance_requires_mutual_acceptance": true,
			"perk_id": {"rancher":"steady_herd", "mechanic":"field_repairs", "spirit-scout":"spirit_sense",
				"healer":"eleanor_perk", "gunhand":"steady_aim", "singer":"camp_song", "teamster":"trail_company"}.get(family, "trail_company"),
			"perk_status": "design_only", "animation_status": "static_identity_only"
		})
	return result
