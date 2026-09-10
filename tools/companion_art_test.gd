extends SceneTree
func _initialize():
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/companion_art.json")).companions
	var Actors = load("res://scripts/companion_actors.gd")
	var Catalog = load("res://scripts/simple_companion_catalog.gd")
	var ok := 0
	for row in Catalog.ROWS:
		var e: Dictionary = art.get(row.id, {})
		assert(not e.is_empty(), "no art assigned for %s" % row.id)
		assert(ResourceLoader.exists(e.atlas), "atlas missing for %s: %s" % [row.id, e.atlas])
		var tex = load(e.atlas)
		assert(tex != null, "atlas failed to load for %s" % row.id)
		var r: Array = e.rect
		assert(int(r[2]) > 0 and int(r[3]) > 0, "empty rect for %s" % row.id)
		assert(int(r[0]) + int(r[2]) <= tex.get_width(), "rect off atlas for %s" % row.id)
		assert(int(r[1]) + int(r[3]) <= tex.get_height(), "rect off atlas for %s" % row.id)
		ok += 1
	assert(ok == Catalog.ROWS.size(), "denominator: %d of %d" % [ok, Catalog.ROWS.size()])
	print("COMPANION ART PASS: %d of %d companions have a loadable atlas and an in-bounds rect" % [ok, Catalog.ROWS.size()])
	quit()
