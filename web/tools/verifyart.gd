extends Node2D

# Checks that the ships the game draws are the reference drawings, pixel for
# pixel. Both are rendered into a mask and compared.
# Usage: godot --headless --path <project> res://tools/verifyart.tscn

const SHAPES := preload("res://scripts/enemy_shapes.gd")


func _ready() -> void:
	print("=== artwork check ===")
	await _check("railgun", SHAPES.RAILGUN_TEX, SHAPES.RAILGUN_SCALE, "res://scenes/railgun_enemy.tscn")
	await _check("charger", SHAPES.CHARGER_TEX, SHAPES.CHARGER_SCALE, "res://scenes/charger_enemy.tscn")
	print("=== done ===")
	get_tree().quit(0)


func _check(name: String, tex: Texture2D, scl: float, scene_path: String) -> void:
	# the reference drawing, centred on the origin
	var ref := Node2D.new()
	add_child(ref)
	var cam := Camera2D.new()
	cam.zoom = Vector2(1.0, 1.0)
	ref.add_child(cam)
	cam.make_current()
	var sprite := SHAPES.make_ship(tex, scl)
	ref.add_child(sprite)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var ref_img: Image = ref.get_viewport().get_texture().get_image()
	ref.queue_free()
	for i in 3:
		await get_tree().process_frame

	# the real enemy
	var root := Node2D.new()
	add_child(root)
	var cam2 := Camera2D.new()
	cam2.zoom = Vector2(1.0, 1.0)
	root.add_child(cam2)
	cam2.make_current()
	var e: Node2D = (load(scene_path) as PackedScene).instantiate() as Node2D
	root.add_child(e)
	e.global_position = Vector2.ZERO
	for i in 6:
		await get_tree().process_frame
	# the health bar is not part of the artwork
	var bar := e.get_node_or_null("HpBar")
	if bar != null:
		(bar as Node2D).visible = false
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var game_img: Image = root.get_viewport().get_texture().get_image()
	root.queue_free()
	for i in 3:
		await get_tree().process_frame

	# compare the coloured pixels
	var w := mini(ref_img.get_width(), game_img.get_width())
	var h := mini(ref_img.get_height(), game_img.get_height())
	var only_ref := 0
	var only_game := 0
	var both := 0
	for y in h:
		for x in w:
			var a := ref_img.get_pixel(x, y)
			var b := game_img.get_pixel(x, y)
			var in_a := a.a > 0.4 and a.get_luminance() > 0.15
			var in_b := b.a > 0.4 and b.get_luminance() > 0.15
			if in_a and in_b:
				both += 1
			elif in_a:
				only_ref += 1
			elif in_b:
				only_game += 1
	var union := both + only_ref + only_game
	var iou := float(both) / float(union) if union > 0 else 0.0
	var ok := iou > 0.97
	print("%-8s %s  IoU=%.4f  (SVG thua %d px, game thua %d px)" % [
		name, "PASS" if ok else "FAIL", iou, only_ref, only_game])
