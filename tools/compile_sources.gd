extends SceneTree
## Compile runtime scripts without constructing nodes, scenes, or gameplay objects.
## Run with: godot --headless --path <project> --script tools/compile_sources.gd

var failures: Array[String] = []


func _initialize() -> void:
	var paths: Array[String] = []
	_collect_scripts("res://scripts", paths)
	paths.sort()
	if paths.is_empty():
		failures.append("No runtime scripts found under res://scripts")
	for path in paths:
		var resource := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
		if not resource is Script:
			failures.append("Could not load runtime script: " + path)
			continue
		var script := resource as Script
		if not script.can_instantiate():
			failures.append("Runtime script did not compile: " + path)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		printerr("SOURCE COMPILATION FAILED: %d failure(s) across %d runtime script(s)" % [failures.size(), paths.size()])
		quit(1)
		return
	print("SOURCE COMPILATION PASS: %d runtime scripts loaded and can_instantiate() verified; no scenes instantiated" % paths.size())
	quit(0)


func _collect_scripts(folder: String, paths: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		failures.append("Could not inspect runtime source folder: " + folder)
		return
	for filename in directory.get_files():
		if filename.get_extension().to_lower() == "gd":
			paths.append(folder.path_join(filename))
	for child in directory.get_directories():
		_collect_scripts(folder.path_join(child), paths)
