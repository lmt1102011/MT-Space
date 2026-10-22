extends Node2D
class_name Explosion

const PARTICLES := 6
const RINa_COLOR := Color(1.0, 0.95, 0.6, 0.9)

var size_mult: float = 1.0


func setup(mult: float) -> void:
	size_mult = maxf(mult, 0.1)


func _ready() -> void:
	var tw := create_tween().set_parallel(true)
	_make_ring(tw)
	_make_sparks(tw)
	await get_tree().create_timer(0.5 * size_mult).timeout
	queue_free()


func _make_ring(tw: Tween) -> void:
	var ring := Line2D.new()
	ring.width = 3.0 * size_mult
	ring.default_color = RINa_COLOR
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(Vector2.from_angle(TAU * i / 16.0) * 6.0 * size_mult)
	pts.append(pts[0])
	ring.points = pts
	add_child(ring)
	tw.tween_property(ring, "scale", Vector2.ONE * 4.0 * size_mult, 0.35 * size_mult).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4 * size_mult)


func _make_sparks(tw: Tween) -> void:
	var count := int(round(randi_range(PARTICLES - 3, PARTICLES + 4) * size_mult))
	for i in count:
		var spark := Line2D.new()
		spark.width = randf_range(1.0, 3.0) * size_mult
		spark.default_color = Color.from_hsv(randf_range(0.05, 0.16), randf_range(0.3, 0.8), 1.0)
		var length := randf_range(3.0, 10.0) * size_mult
		spark.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0)])
		add_child(spark)
		var dir := Vector2.from_angle(randf() * TAU)
		var dist := randf_range(12.0, 46.0) * size_mult
		var dur := randf_range(0.25, 0.55) * size_mult
		spark.rotation = dir.angle()
		tw.tween_property(spark, "position", dir * dist, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, dur)
		tw.tween_property(spark, "scale", Vector2(0.4, randf_range(0.7, 1.0)), dur)
