extends Node2D
class_name Explosion

const SPARK_CAPACITY := 18
const DEFAULT_TINT := Color(1.0, 0.95, 0.6, 0.9)

var size_mult: float = 1.0
var _age: float = 0.0
var _duration: float = 0.5
var _active: bool = false
var _spark_count: int = 0
var _ring: Line2D
var _sparks: Array[Line2D] = []
var _spark_directions: Array[Vector2] = []
var _spark_distances: Array[float] = []
var _spark_durations: Array[float] = []


func _ready() -> void:
	z_index = 40
	_ring = Line2D.new()
	_ring.points = _circle_points(6.0)
	add_child(_ring)
	for _index in SPARK_CAPACITY:
		var spark := Line2D.new()
		spark.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT])
		add_child(spark)
		_sparks.append(spark)
		_spark_directions.append(Vector2.RIGHT)
		_spark_distances.append(0.0)
		_spark_durations.append(0.0)
	setup(1.0)


func setup(mult: float, tint: Color = DEFAULT_TINT) -> void:
	size_mult = maxf(mult, 0.1)
	_age = 0.0
	_duration = 0.5 * size_mult
	_spark_count = clampi(
		int(round(randi_range(3, 10) * size_mult)), 1, SPARK_CAPACITY)
	_active = true
	_ring.width = 3.0 * size_mult
	_ring.default_color = tint
	_ring.points = _circle_points(6.0 * size_mult)
	_ring.scale = Vector2.ONE
	_ring.modulate.a = 0.9
	_ring.show()
	for index in SPARK_CAPACITY:
		var spark := _sparks[index]
		var active := index < _spark_count
		spark.visible = active
		if not active:
			continue
		var length := randf_range(3.0, 10.0) * size_mult
		spark.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
		spark.width = randf_range(1.0, 3.0) * size_mult
		spark.default_color = tint.lightened(randf_range(0.05, 0.35))
		_spark_directions[index] = Vector2.from_angle(randf() * TAU)
		_spark_distances[index] = randf_range(12.0, 46.0) * size_mult
		_spark_durations[index] = randf_range(0.25, 0.55) * size_mult
		spark.position = Vector2.ZERO
		spark.rotation = _spark_directions[index].angle()
		spark.scale = Vector2.ONE
		spark.modulate.a = 1.0
	show()
	set_process(true)


func pool_activate() -> void:
	setup(1.0)


func pool_deactivate() -> void:
	_active = false


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	var ring_t := clampf(_age / maxf(_duration, 0.001), 0.0, 1.0)
	_ring.scale = Vector2.ONE * lerpf(1.0, 4.0, ease_out_cubic(ring_t))
	_ring.modulate.a = 0.9 * (1.0 - ring_t)
	for index in _spark_count:
		var spark_t := clampf(_age / maxf(_spark_durations[index], 0.001),
			0.0, 1.0)
		var eased := 1.0 - pow(1.0 - spark_t, 3.0)
		var spark := _sparks[index]
		spark.position = _spark_directions[index] * _spark_distances[index] * eased
		spark.modulate.a = 1.0 - spark_t
		spark.scale = Vector2(0.4, lerpf(1.0, 0.7, spark_t))
	if _age >= _duration:
		Pool.release(self)


func recycle() -> void:
	Pool.release(self)


func _circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 16:
		points.append(Vector2.from_angle(TAU * index / 16.0) * radius)
	points.append(points[0])
	return points


func ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)
