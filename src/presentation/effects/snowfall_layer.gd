class_name SnowfallLayer
extends Node2D

const SNOWFLAKE_TEXTURE := preload("res://artwork/snowflake.png")
const SEED := 2026

var _design_size: Vector2
var _snowflake_count: int
var _snowflakes: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()


static func create(design_size: Vector2, snowflake_count: int) -> SnowfallLayer:
	var layer := SnowfallLayer.new()
	layer._design_size = design_size
	layer._snowflake_count = snowflake_count
	return layer


func _ready() -> void:
	name = "Snowfall"
	_random.seed = SEED
	for index in _snowflake_count:
		var snowflake := Sprite2D.new()
		snowflake.name = "Snowflake%d" % (index + 1)
		snowflake.texture = SNOWFLAKE_TEXTURE
		snowflake.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		snowflake.position = Vector2(
			_random.randf_range(-40.0, _design_size.x + 40.0),
			_random.randf_range(-80.0, _design_size.y + 40.0)
		)
		snowflake.rotation = _random.randf_range(0.0, TAU)
		var snowflake_scale := _random.randf_range(0.035, 0.08)
		snowflake.scale = Vector2.ONE * snowflake_scale
		add_child(snowflake)
		(
			_snowflakes
			. append(
				{
					"node": snowflake,
					"velocity":
					Vector2(_random.randf_range(-3.0, 7.0), _random.randf_range(24.0, 36.0)),
					"spin": _random.randf_range(-0.2, 0.2),
				}
			)
		)


func _process(delta: float) -> void:
	for snowflake_data in _snowflakes:
		var snowflake: Sprite2D = snowflake_data.node
		snowflake.position += snowflake_data.velocity * delta
		snowflake.rotation += snowflake_data.spin * delta
		if snowflake.position.y > _design_size.y + 50.0:
			snowflake.position = Vector2(_random.randf_range(-40.0, _design_size.x + 40.0), -50.0)
