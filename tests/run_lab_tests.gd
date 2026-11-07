extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var lab: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(lab)
	await physics_frame
	await physics_frame
	check(lab._vessels.size() == 3, "three vessels ready")
	check(lab._zone.overlaps_area(lab._receiver), "receiver in actual Area2D zone")
	var first: LabVessel = lab._vessels[0]
	var second: LabVessel = lab._vessels[1]
	# Feed real mouse events through the viewport to exercise picking and dragging.
	await drag(first.position + Vector2(0, -60), lab._receiver.position + Vector2(0, -60))
	near(lab._receiver.mixture.get_volume_l(), 0.01, "first manual drag pours 10ml")
	await drag(second.position + Vector2(0, -60), lab._receiver.position + Vector2(0, -60))
	near(lab._receiver.mixture.get_volume_l(), 0.02, "second manual drag pours 10ml")
	near(float(lab._receiver.mixture.get_released_products().get("carbon_dioxide", 0)), 0.001, "UI flow releases CO2")
	check(lab._product_info.text.contains("1.000"), "visible result updated")
	check(lab._receiver._bubble_time > 0, "committed reaction starts bubbles")
	# Direct adapter call isolates capacity rejection from pointer mechanics.
	check(lab.pour(first, 0.09) == &"capacity_exceeded", "capacity feedback")
	near(lab._receiver.mixture.get_volume_l(), 0.02, "rejected UI action atomic")
	# Capture real render only in graphical test mode; headless has no framebuffer.
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot: Image = root.get_texture().get_image()
		check(screenshot.save_png("res://builds/laboratory-preview.png") == OK, "render saved")
	lab._reset()
	await process_frame
	near(lab._receiver.mixture.get_volume_l(), 0, "reset clears state")
	check(lab._receiver.mixture.get_released_products().is_empty(), "reset clears gas ledger")
	lab.queue_free()
	await process_frame
	print("Lab tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func drag(start: Vector2, finish: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = start
	motion.global_position = start
	Input.parse_input_event(motion)
	await physics_frame
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frame
	await physics_frame
	await process_frame

	motion = InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await physics_frame
	await process_frame
	await physics_frame
	var release := InputEventMouseButton.new()
	release.position = finish
	release.global_position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	for index: int in range(5):
		await process_frame
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func near(actual: float, expected: float, description: String) -> void:
	check(absf(actual - expected) <= 1e-12, description)
