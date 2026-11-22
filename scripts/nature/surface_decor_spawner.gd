class_name SurfaceDecorSpawner
extends Node2D

## Спавнер декораций поверхности (деревья, пни, кусты, камни и цветы).
## Автоматически расставляет элементы вдоль линии земли при старте игры.

@export var surface_y: float = 256.0           ## Высота поверхности земли (Y = row 8 * 32)
@export var map_width: float = 1920.0          ## Ширина игровой зоны
@export var entrance_x: float = 976.0          ## Координата входа в муравейник (чтобы не перекрывать нору)
@export var entrance_clear_radius: float = 80.0 ## Радиус свободного пространства вокруг норы

# Текстуры для декораций
const TEXTURES_LARGE: Array[String] = [
	"res://assets/sprites_topdown/tree_stump.png",
	"res://assets/nature/bush_tall.png",
	"res://assets/nature/grass_bush.png",
]

const TEXTURES_SMALL: Array[String] = [
	"res://assets/nature/stone_medium.png",
	"res://assets/nature/stone_small.png",
	"res://assets/nature/stone_pebble.png",
	"res://assets/nature/flower_white.png",
	"res://assets/nature/flower_yellow.png",
	"res://assets/nature/flower_pink.png",
	"res://assets/nature/clover.png",
]


func _ready() -> void:
	z_index = 1
	generate_surface_decorations()


## Генерация декораций вдоль поверхности карты
func generate_surface_decorations() -> void:
	# Очищаем старые дочерние узлы, если уже генерировали
	for child in get_children():
		child.queue_free()
	
	# 1. Расстановка крупных объектов (деревья, пни, крупные кусты) с шагом ~140-200px
	var current_x: float = randf_range(40.0, 100.0)
	while current_x < map_width - 60.0:
		# Пропускаем зону входа в муравейник
		if absf(current_x - entrance_x) > entrance_clear_radius:
			var tex_path: String = TEXTURES_LARGE.pick_random()
			_spawn_prop(tex_path, current_x, surface_y, 0.75, 1.15)
		current_x += randf_range(130.0, 210.0)
	
	# 2. Расстановка мелких объектов (камни, цветы, трава) для детализации
	current_x = randf_range(20.0, 60.0)
	while current_x < map_width - 30.0:
		if absf(current_x - entrance_x) > entrance_clear_radius * 0.6:
			var tex_path: String = TEXTURES_SMALL.pick_random()
			_spawn_prop(tex_path, current_x, surface_y, 0.65, 1.0)
		current_x += randf_range(50.0, 95.0)


## Создание экземпляра Sprite2D с выравниванием pivot по основанию (внизу по центру)
func _spawn_prop(texture_path: String, pos_x: float, pos_y: float, min_scale: float, max_scale: float) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	
	var tex: Texture2D = load(texture_path)
	if tex == null:
		return
	
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	
	# Смещаем pivot так, чтобы точка привязки была у основания (внизу по центру)
	# В Godot Sprite2D при centered = true origin находится в (0, 0),
	# а offset.y = -height / 2 поднимает спрайт ровно над базовой линией Y.
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.5)
	
	# Случайный масштаб (scale) и отражение по горизонтали
	var s: float = randf_range(min_scale, max_scale)
	sprite.scale = Vector2(s, s)
	sprite.flip_h = randf() > 0.5
	
	# Небольшое случайное смещение по X и Y для естественности
	var jitter_x: float = randf_range(-12.0, 12.0)
	var jitter_y: float = randf_range(-2.0, 2.0)
	sprite.position = Vector2(pos_x + jitter_x, pos_y + jitter_y)
	
	add_child(sprite)
