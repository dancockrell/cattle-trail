extends RefCounted
## Data rows for scripts/simple_companion_room.gd -- the "meet, one flavor
## task, invite" recruitment shape. Adding another companion of this shape
## (see the note atop simple_companion_state.gd for which shapes qualify)
## means adding a row here and a data/<id>_banter.json file, not a new pair
## of .gd scripts. All three below are gated behind Birdie's recruitment,
## continuing the single existing unlock chain (Eleanor -> Ada -> Ines ->
## Birdie) rather than opening several branches from one companion at once.
const ROWS := [
	{
		"id": "delphine_cruz", "speaker": "DELPHINE", "age": 24, "perk_id": "trail_company",
		"position_x": 480.0, "position_y": 150.0, "near_radius": 36.0,
		"banter_path": "res://data/delphine_banter.json",
		"meet_beat": "intro", "task_beat": "won_fairly", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "DELPHINE, 24 / Beat her fairly at a hand of cards to earn her respect.",
		"task_message": "She deals a fresh hand. Talk to her once you've won it fairly.",
		"recruited_message": "Delphine joins the outfit. A card sharp with a straight deal, when she wants to use one.",
		"idle_message": "Delphine's already dealt in for the outfit.",
		"task_label": "Play a hand", "location_label": "her table",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "cleo_bannister", "speaker": "CLEO", "age": 23, "perk_id": "trail_company",
		"position_x": 350.0, "position_y": 240.0, "near_radius": 36.0,
		"banter_path": "res://data/cleo_banter.json",
		"meet_beat": "intro", "task_beat": "heard_something_useful", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "CLEO, 23 / Sit for a shave and hear what she's picked up this week.",
		"task_message": "Clean shave, and something worth knowing. Talk to her again to offer a place.",
		"recruited_message": "Cleo joins the outfit. The county's best barber, and its best listener.",
		"idle_message": "Cleo's already part of the outfit.",
		"task_label": "Sit for a shave", "location_label": "her chair",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "prisca_montaigne", "speaker": "PRISCA", "age": 24, "perk_id": "trail_company",
		"position_x": 520.0, "position_y": 240.0, "near_radius": 36.0,
		"banter_path": "res://data/prisca_banter.json",
		"meet_beat": "intro", "task_beat": "facts_verified", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "PRISCA, 24 / Confirm the outfit's actual story so she can print the true version.",
		"task_message": "Facts confirmed. Talk to her again once the true story's ready to go to press.",
		"recruited_message": "Prisca joins the outfit. An honest paper, and an honest source for it.",
		"idle_message": "Prisca's already riding with the outfit.",
		"task_label": "Verify the story", "location_label": "her press",
		"unlock_key": "birdie_recruited"
	},
]

static func position_for(row: Dictionary) -> Vector2:
	return Vector2(row.position_x, row.position_y)
