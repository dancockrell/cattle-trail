extends RefCounted
## Resolves one leg of a cattle drive per design/DRIVES.md ("What can go wrong
## on a drive" and "How companion perks and hands reduce these risks").
##
## Reuses the county's existing systems rather than inventing new ones:
## day/night comes from the trail clock (scripts/trail_clock.gd) as an input
## parameter, not owned here, and mitigation comes from the existing perk ids
## in scripts/companion_perks.gd (steady_herd, spirit_sense, steady_aim) as
## bools the caller has already resolved via CompanionPerks.value(...). This
## class does not touch the scene tree, an autoload, or the perk resolver
## directly -- it only consumes the already-resolved has_* flags so it stays
## pure and independently testable.
##
## ALL NUMERIC CONSTANTS BELOW ARE FIRST-PASS, UNTUNED PLACEHOLDERS.
## DRIVES.md's own "Unresolved" section says explicitly: "Exact numeric loss
## rates per risk ... none of this is specified, matching this project's
## standing rule against inventing balance." Every rate here is a small,
## clearly-commented guess picked only so the mechanic is *callable*, not a
## claim about correct balance. They should be replaced wholesale once the
## county has real playtesting data; nothing here should be read as design.

## Route hazards named in DRIVES.md's "What can go wrong on a drive" section.
## No hazard beyond what that section already names is introduced here.
const HAZARD_CLEAR := "clear"
const HAZARD_NARROW_WATER := "narrow_water_crossing"          ## The Narrow Water / The Ford Widow
const HAZARD_STAMPEDE := "stampede_risk"                       ## late signs spooking the herd
const HAZARD_RUSTLERS := "rustler_territory"                   ## Amos Ketch's crew
const HAZARD_DROVER_ISNT := "drover_isnt_trail"                ## The Drover Who Isn't, count skims
const HAZARD_SALT_FLATS := "salt_flats"                        ## harder terrain leg
const HAZARD_SECOND_SHADOW := "second_shadow_leg"              ## explicitly a night hunter

## Hazards DRIVES.md ties to the county's "late signs" / spirit warning,
## i.e. the ones spirit_sense's advance-notice framing actually applies to.
## The river crossing is a purely physical hazard (the ford itself, the
## water), so it is deliberately excluded per the brief.
const SPIRIT_WARNED_HAZARDS := [HAZARD_STAMPEDE, HAZARD_DROVER_ISNT]

## Hazards DRIVES.md names as night-relevant. Only the Second Shadow is
## "explicitly a night hunter" in the doc; night should not blanket-penalize
## every hazard, per DRIVES.md's own point that day/night should matter
## specifically where it is named.
const NIGHT_RELEVANT_HAZARDS := [HAZARD_SECOND_SHADOW]

## Base fraction of herd_count lost per hazard, before any mitigation.
## First-pass guesses only -- see file header.
const BASE_LOSS_FRACTION := {
	HAZARD_CLEAR: 0.0,
	HAZARD_NARROW_WATER: 0.03,      ## "a bad river crossing" -- ~3% of the herd to the water
	HAZARD_STAMPEDE: 0.05,          ## a spooked herd scatters wider than a bad ford
	HAZARD_RUSTLERS: 0.04,          ## Ketch's crew takes a cut rather than the whole herd
	HAZARD_DROVER_ISNT: 0.02,       ## "the count coming up wrong" -- a skim, not a stampede
	HAZARD_SALT_FLATS: 0.02,        ## terrain attrition, not an actor
	HAZARD_SECOND_SHADOW: 0.03,     ## base rate before the night multiplier below
}

## steady_herd ("fewer lost cattle") halves loss for the crossing/stampede
## risks it's framed against in DRIVES.md; applied to every hazard here since
## holding the herd together helps generally, but it is only ever a partial
## reduction, never a full negation, on any hazard.
const STEADY_HERD_LOSS_MULTIPLIER := 0.5

## spirit_sense gives *advance warning*, not immunity -- DRIVES.md is explicit
## that late signs "should be readable, not a surprise doom-roll," which reads
## as reduced severity rather than the risk vanishing outright.
const SPIRIT_SENSE_LOSS_MULTIPLIER := 0.6

## A night leg on a hazard DRIVES.md ties to night (the Second Shadow) makes
## that hazard notably worse. First-pass guess: +75% of its base loss.
const NIGHT_LOSS_MULTIPLIER := 1.75

## Base condition (0.0-1.0 stress scale, 1.0 = calm/well-handled per
## ECONOMY.md) cost per hazard, independent of head lost. A hard leg without
## losing a single animal should still cost condition per DRIVES.md's
## "successful vs. bad drive" section.
const BASE_CONDITION_COST := {
	HAZARD_CLEAR: 0.0,
	HAZARD_NARROW_WATER: 0.10,
	HAZARD_STAMPEDE: 0.15,
	HAZARD_RUSTLERS: 0.12,
	HAZARD_DROVER_ISNT: 0.05,
	HAZARD_SALT_FLATS: 0.12,        ## "cattle refuse to cross... without a reason to trust the drover"
	HAZARD_SECOND_SHADOW: 0.10,
}

## steady_aim only matters "if a fight becomes the actual outcome" against
## Ketch's crew -- it reduces the condition cost of a rustler encounter (a
## fight handled well is less stressful on the herd) but has no effect on
## any other hazard, matching the doc's narrow framing of that perk.
const STEADY_AIM_CONDITION_MULTIPLIER := 0.6

## Extra condition cost added when a night-relevant hazard runs after dark.
const NIGHT_CONDITION_BONUS := 0.08


static func _is_valid_hazard(hazard: String) -> bool:
	return BASE_LOSS_FRACTION.has(hazard)


## params keys:
##   herd_count: int            -- head at the start of this leg
##   route_hazard: String       -- one of the HAZARD_* constants above
##   is_night_leg: bool         -- from the trail clock's day/night state
##   perks: Dictionary          -- has_steady_herd / has_spirit_sense / has_steady_aim bools
## Returns { count_after: int, condition: float, notes: Array[String] }
static func resolve_leg(params: Dictionary) -> Dictionary:
	var herd_count := int(params.get("herd_count", 0))
	var hazard: String = params.get("route_hazard", HAZARD_CLEAR)
	var is_night_leg := bool(params.get("is_night_leg", false))
	var perks: Dictionary = params.get("perks", {})
	var has_steady_herd := bool(perks.get("has_steady_herd", false))
	var has_spirit_sense := bool(perks.get("has_spirit_sense", false))
	var has_steady_aim := bool(perks.get("has_steady_aim", false))

	var notes: Array[String] = []

	if herd_count < 0:
		herd_count = 0
	if not _is_valid_hazard(hazard):
		notes.append("Unknown hazard '%s' treated as clear." % hazard)
		hazard = HAZARD_CLEAR

	if hazard == HAZARD_CLEAR:
		notes.append("Clear route: no hazard, herd arrives intact.")
		return {"count_after": herd_count, "condition": 1.0, "notes": notes}

	var loss_fraction: float = BASE_LOSS_FRACTION[hazard]
	var condition_cost: float = BASE_CONDITION_COST[hazard]
	var is_night_relevant := hazard in NIGHT_RELEVANT_HAZARDS
	var is_spirit_warned := hazard in SPIRIT_WARNED_HAZARDS

	notes.append("Hazard: %s (base loss %.1f%%, base condition cost %.2f)." % [hazard, loss_fraction * 100.0, condition_cost])

	if is_spirit_warned and has_spirit_sense:
		loss_fraction *= SPIRIT_SENSE_LOSS_MULTIPLIER
		notes.append("spirit_sense gave advance warning; severity reduced, not eliminated.")

	if has_steady_herd:
		loss_fraction *= STEADY_HERD_LOSS_MULTIPLIER
		notes.append("steady_herd held the herd together; loss reduced.")

	if hazard == HAZARD_RUSTLERS and has_steady_aim:
		condition_cost *= STEADY_AIM_CONDITION_MULTIPLIER
		notes.append("steady_aim made the fight with Ketch's crew go cleanly; less stress on the herd.")

	if is_night_relevant and is_night_leg:
		loss_fraction *= NIGHT_LOSS_MULTIPLIER
		condition_cost += NIGHT_CONDITION_BONUS
		notes.append("Night leg on a night-relevant hazard: worse loss and added stress.")
	elif is_night_leg:
		notes.append("Night leg, but this hazard is not night-relevant: no added penalty.")

	loss_fraction = clampf(loss_fraction, 0.0, 1.0)
	condition_cost = clampf(condition_cost, 0.0, 1.0)

	var lost := int(round(float(herd_count) * loss_fraction))
	lost = clampi(lost, 0, herd_count)
	var count_after := clampi(herd_count - lost, 0, herd_count)
	var condition := clampf(1.0 - condition_cost, 0.0, 1.0)

	notes.append("Result: %d head lost, %d arrived, condition %.2f." % [lost, count_after, condition])

	return {"count_after": count_after, "condition": condition, "notes": notes}
