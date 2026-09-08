extends SceneTree
const Factory = preload("res://scripts/character_factory.gd")
func _initialize():
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://kits/character-families/catalog.json"))
	if not catalog is Dictionary:
		push_error("Build the character catalog before exporting a roster")
		quit(1)
		return
	var roster = Factory.new().create_roster(catalog, "clear-fork-production-v1", catalog.variants.size(), true)
	if roster.size() != catalog.variants.size():
		push_error("Catalog contains characters the factory cannot produce")
		quit(1)
		return
	var file = FileAccess.open("res://kits/character-families/preview-roster.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not save preview roster")
		quit(1)
		return
	file.store_string(JSON.stringify({"version":1,"status":"production_preview_not_saved_game","seed":"clear-fork-production-v1","characters":roster},"\t") + "\n")
	file.close()
	print("CHARACTER ROSTER PASS: %d distinct visual identities bound to deterministic adult character records" % roster.size())
	quit()
