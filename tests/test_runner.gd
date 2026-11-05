extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/test_runner.gd
## Runs every test_* method of tests/unit/test_*.gd on a fresh instance, synchronously (after one initial frame).

const TestCase := preload("res://tests/test_case.gd")
const UNIT_DIR := "res://tests/unit"


func _initialize() -> void:
	# Scenes added to root during _initialize don't get _ready until the first frame.
	await process_frame
	var passed := 0
	var failed := 0
	var load_errors := 0
	var files := Array(DirAccess.get_files_at(UNIT_DIR)).filter(
		func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var script := load("%s/%s" % [UNIT_DIR, file]) as GDScript
		if script == null or not script.can_instantiate():
			print("ERROR  %s: failed to load" % file)
			load_errors += 1
			continue
		var methods: Array[String] = []
		for m in script.new().get_method_list():
			if String(m["name"]).begins_with("test_") and not methods.has(m["name"]):
				methods.append(m["name"])
		methods.sort()
		for method in methods:
			var t: TestCase = script.new()
			t.root = root
			t.before_each()
			t.call(method)
			t.after_each()
			if t.failures.is_empty():
				passed += 1
				print("PASS  %s::%s" % [file, method])
			else:
				failed += 1
				print("FAIL  %s::%s" % [file, method])
				for f in t.failures:
					print("      " + f)
	print("%d passed, %d failed" % [passed, failed])
	if load_errors > 0:
		print("%d test file(s) failed to load" % load_errors)
	quit(1 if failed > 0 or load_errors > 0 else 0)
