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
	{
		"id": "winnie_doyle", "speaker": "WINNIE", "age": 23, "perk_id": "trail_company",
		"position_x": 280.0, "position_y": 150.0, "near_radius": 36.0,
		"banter_path": "res://data/winnie_banter.json",
		"meet_beat": "intro", "task_beat": "mended_well", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "WINNIE, 23 / Bring her a torn coat or dress that matters to someone.",
		"task_message": "Mending's finished, and better than the original. Talk to her again to offer a place.",
		"recruited_message": "Winnie joins the outfit. Good cloth, kept in good repair.",
		"idle_message": "Winnie's already riding with the outfit.",
		"task_label": "Bring mending", "location_label": "her stall",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "louisa_okoye", "speaker": "LOUISA", "age": 22, "perk_id": "trail_company",
		"position_x": 600.0, "position_y": 150.0, "near_radius": 36.0,
		"banter_path": "res://data/louisa_banter.json",
		"meet_beat": "intro", "task_beat": "lesson_given", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "LOUISA, 22 / Volunteer an outfit hand to learn his letters.",
		"task_message": "He read his own letter out loud, badly, and finished it. Talk to her again to offer a place.",
		"recruited_message": "Louisa joins the outfit. A schoolteacher with nowhere else that would have her.",
		"idle_message": "Louisa's already riding with the outfit.",
		"task_label": "Sit for a lesson", "location_label": "her books",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "faustina_achebe", "speaker": "FAUSTINA", "age": 23, "perk_id": "trail_company",
		"position_x": 280.0, "position_y": 320.0, "near_radius": 36.0,
		"banter_path": "res://data/faustina_banter.json",
		"meet_beat": "intro", "task_beat": "hives_recovered", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "FAUSTINA, 23 / Help her recover hives a storm knocked loose.",
		"task_message": "Hives recovered, no one stung. Talk to her again to offer a place.",
		"recruited_message": "Faustina joins the outfit. Bees and all.",
		"idle_message": "Faustina's already riding with the outfit.",
		"task_label": "Recover the hives", "location_label": "her hives",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "constance_whitlock", "speaker": "CONSTANCE", "age": 27, "perk_id": "trail_company",
		"position_x": 600.0, "position_y": 320.0, "near_radius": 36.0,
		"banter_path": "res://data/constance_banter.json",
		"meet_beat": "intro", "task_beat": "error_found", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "CONSTANCE, 27 / Let her find the error in the outfit's own books.",
		"task_message": "Error found and named plainly. Talk to her again to offer a place.",
		"recruited_message": "Constance joins the outfit. The books balance now.",
		"idle_message": "Constance's already riding with the outfit.",
		"task_label": "Check the ledger", "location_label": "her desk",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "beatrix_lowe", "speaker": "BEATRIX", "age": 25, "perk_id": "trail_company",
		"position_x": 150.0, "position_y": 150.0, "near_radius": 36.0,
		"banter_path": "res://data/beatrix_banter.json",
		"meet_beat": "intro", "task_beat": "boundary_resurveyed", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "BEATRIX, 25 / Help her resurvey a boundary line two outfits are ready to fight over.",
		"task_message": "Line resurveyed and the numbers written plain. Talk to her again to offer a place.",
		"recruited_message": "Beatrix joins the outfit. Nobody argues with a chain and a transit for long.",
		"idle_message": "Beatrix's already riding with the outfit.",
		"task_label": "Resurvey the line", "location_label": "her transit",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "roisin_dunmore", "speaker": "ROISIN", "age": 24, "perk_id": "trail_company",
		"position_x": 750.0, "position_y": 150.0, "near_radius": 36.0,
		"banter_path": "res://data/roisin_banter.json",
		"meet_beat": "intro", "task_beat": "job_secured", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "ROISIN, 24 / Line up honest locksmithing work before she takes the crooked kind.",
		"task_message": "Legitimate job secured, paid in full. Talk to her again to offer a place.",
		"recruited_message": "Roisin joins the outfit. Every lock in camp sleeps easier for it.",
		"idle_message": "Roisin's already riding with the outfit.",
		"task_label": "Line up honest work", "location_label": "her workbench",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "modesty_kane", "speaker": "MODESTY", "age": 23, "perk_id": "trail_company",
		"position_x": 150.0, "position_y": 320.0, "near_radius": 36.0,
		"banter_path": "res://data/modesty_banter.json",
		"meet_beat": "intro", "task_beat": "plate_developed", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "MODESTY, 23 / Sit still for a photograph and mind her equipment through the trouble that follows.",
		"task_message": "Plate developed clean, camera intact. Talk to her again to offer a place.",
		"recruited_message": "Modesty joins the outfit. She's got a plate of you now, and it came out honest.",
		"idle_message": "Modesty's already riding with the outfit.",
		"task_label": "Sit for the plate", "location_label": "her camera",
		"unlock_key": "birdie_recruited"
	},
	{
		"id": "clementine_osei", "speaker": "CLEMENTINE", "age": 28, "perk_id": "trail_company",
		"position_x": 750.0, "position_y": 320.0, "near_radius": 36.0,
		"banter_path": "res://data/clementine_banter.json",
		"meet_beat": "intro", "task_beat": "emergency_handled", "recruited_beat": "recruited", "romance_beat": "romance_acknowledged",
		"meet_message": "CLEMENTINE, 28 / Give her a steady pair of hands during an actual medical emergency.",
		"task_message": "Emergency handled, patient stable. Talk to her again to offer a place.",
		"recruited_message": "Clementine joins the outfit. Steadiest hands this side of the fort.",
		"idle_message": "Clementine's already riding with the outfit.",
		"task_label": "Steady the patient", "location_label": "her kit",
		"unlock_key": "birdie_recruited"
	},
]

static func position_for(row: Dictionary) -> Vector2:
	return Vector2(row.position_x, row.position_y)
