class_name SurfaceDecorSpawner
extends Node2D

## Спавнер декораций поверхности (величественные деревья, корни вглубь земли, цветы и трава).
## Создает визуальный стиль как на референсе браузерной игры Ant Colony (antcolony.gg).
##
## Система координат:
##   - position Y=surface_y — уровень земли (линия раздела небо/земля)
##   - Крона и ствол: Y < 0 (вверх от линии земли)
##   - Корни: Y > 0 (вниз в текстуру земли)
## Это гарантирует стык ствол↔корни точно на поверхности.

@export var surface_y: float = 256.0           ## Высота поверхности земли (Y = row 8 * 32)
@export var map_width: float = 1920.0          ## Ширина игровой зоны
@export var entrance_x: float = 976.0          ## Координата входа в муравейник
@export var entrance_clear_radius: float = 65.0 ## Зона вокруг входа в муравейник

# Текстуры для цветов и мелких деталей поверхности
const TEXTURES_SMALL: Array[String] = [
	"res://assets/nature/flower_white.png",
	"res://assets/nature/flower_yellow.png",
	"res://assets/nature/flower_pink.png",
	"res://assets/nature/clover.png",
	"res://assets/nature/stone_small.png",
	"res://assets/nature/stone_pebble.png",
	"res://assets/nature/grass_bush.png",
]


func _ready() -> void:
	z_index = 1
	generate_surface_decorations()


## Генерация декораций вдоль поверхности карты
func generate_surface_decorations() -> void:
	for child in get_children():
		child.queue_free()

	# 1. Деревья с ветвящимися корнями вглубь земли (в стиле antcolony.gg)
	# Позиция дерева = (tx, surface_y): ствол рисует вверх, корни вниз от этой точки
	var tree_xs: Array[float] = [
		110.0, 290.0, 480.0, 680.0, 870.0, 1100.0, 1290.0, 1490.0, 1690.0, 1860.0
	]
	for tx in tree_xs:
		if absf(tx - entrance_x) > entrance_clear_radius:
			_spawn_tree_with_roots(tx + randf_range(-15.0, 15.0), surface_y)

	# 2. Полевые цветы и пучки травы вдоль линии горизонта
	var current_x: float = randf_range(15.0, 40.0)
	while current_x < map_width - 20.0:
		if absf(current_x - entrance_x) > 25.0:
			var tex_path: String = TEXTURES_SMALL.pick_random()
			_spawn_prop(tex_path, current_x, surface_y, 0.65, 0.95)
		current_x += randf_range(30.0, 65.0)


## Создание дерева с кроной сверху и корнями, уходящими вглубь земли.
## pos_y = surface_y: Y=0 внутри дочерних узлов = линия поверхности.
## TreeCrownVisual рисует ствол вверх (y < 0) и крону ещё выше.
## TreeRootVisual рисует корни вниз (y > 0) в текстуру земли.
## Оба узла начинаются с position = Vector2.ZERO, стык точный.
func _spawn_tree_with_roots(pos_x: float, pos_y: float) -> void:
	var tree_node: Node2D = Node2D.new()
	tree_node.position = Vector2(pos_x, pos_y)

	# Корни уходят вниз (z_index=0, рисуются под деревьями)
	var root_drawer: TreeRootVisual = TreeRootVisual.new()
	root_drawer.position = Vector2.ZERO
	root_drawer.z_index = 0
	tree_node.add_child(root_drawer)

	# Ствол идёт вверх, крона над стволом (z_index=2, над землёй)
	var crown_drawer: TreeCrownVisual = TreeCrownVisual.new()
	crown_drawer.position = Vector2.ZERO
	crown_drawer.z_index = 2
	var sc: float = randf_range(0.9, 1.15)
	crown_drawer.scale = Vector2(sc, sc)
	tree_node.add_child(crown_drawer)

	add_child(tree_node)


## Создание экземпляра Sprite2D с выравниванием pivot по основанию (внизу по центру)
func _spawn_prop(texture_path: String, pos_x: float, pos_y: float, min_scale: float, max_scale: float) -> void:
	if not ResourceLoader.exists(texture_path):
		return

	var tex: Texture2D = load(texture_path)
	if tex == null:
		return

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.5)

	var s: float = randf_range(min_scale, max_scale)
	sprite.scale = Vector2(s, s)
	sprite.flip_h = randf() > 0.5

	var jitter_x: float = randf_range(-6.0, 6.0)
	sprite.position = Vector2(pos_x + jitter_x, pos_y)

	add_child(sprite)


# ---------------------------------------------------------------------------
# Вспомогательные визуальные классы для корней и кроны дерева (стиль antcolony.gg)
# ---------------------------------------------------------------------------

## Класс рисует ветвящиеся корни вниз от Y=0 (уровня поверхности) в глубь земли.
class TreeRootVisual extends Node2D:
	## Цвет корней: тёмно-коричневый, близкий к тонам antcolony.gg
	var root_color: Color = Color(0.38, 0.25, 0.14)

	func _draw() -> void:
		# Органические ветвящиеся корни, начинающиеся от Y=0 (поверхности)
		# и уходящие вниз на ~200px в текстуру земли
		var branch_left: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(-18, 35), Vector2(-42, 85), Vector2(-70, 145), Vector2(-92, 195)
		])
		var branch_left_sub: PackedVector2Array = PackedVector2Array([
			Vector2(-42, 85), Vector2(-28, 130), Vector2(-36, 175)
		])
		var branch_center: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(4, 50), Vector2(-3, 110), Vector2(14, 175), Vector2(9, 215)
		])
		var branch_right: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(20, 40), Vector2(46, 90), Vector2(74, 150), Vector2(98, 205)
		])
		var branch_right_sub: PackedVector2Array = PackedVector2Array([
			Vector2(46, 90), Vector2(34, 135), Vector2(48, 180)
		])

		draw_polyline(branch_left, root_color, 4.5)
		draw_polyline(branch_left_sub, root_color, 2.5)
		draw_polyline(branch_center, root_color, 3.8)
		draw_polyline(branch_right, root_color, 4.5)
		draw_polyline(branch_right_sub, root_color, 2.5)


## Класс рисует ствол вверх от Y=0 и пышную крону над ним.
## Вся отрисовка идёт в y <= 0, поэтому стыкуется с корнями без смещений.
class TreeCrownVisual extends Node2D:
	var trunk_color: Color = Color(0.44, 0.31, 0.20)
	var trunk_height: float = 145.0
	var trunk_width: float = 16.0
	var canopy_radius: float = 68.0

	func _draw() -> void:
		# Ствол рисуется ВВЕРХ от Y=0: Rect2 от -trunk_height до 0
		# Это означает что основание ствола (Y=0) стыкуется с корнями (Y=0)
		var trunk_rect: Rect2 = Rect2(-trunk_width * 0.5, -trunk_height, trunk_width, trunk_height)
		draw_rect(trunk_rect, trunk_color)
		draw_rect(trunk_rect, trunk_color.darkened(0.25), false, 1.5)

		# Массивная пышная крона (широкие перекрывающиеся облака листвы как в antcolony.gg)
		var cy: float = -trunk_height - 20.0
		# Задние тёмные слои кроны для объёма
		draw_circle(Vector2(0, cy), canopy_radius, Color(0.33, 0.54, 0.28))
		draw_circle(Vector2(-canopy_radius * 0.6, cy + 12.0), canopy_radius * 0.75, Color(0.33, 0.54, 0.28))
		draw_circle(Vector2(canopy_radius * 0.6, cy + 12.0), canopy_radius * 0.75, Color(0.33, 0.54, 0.28))
		# Передние светлые слои кроны
		draw_circle(Vector2(-canopy_radius * 0.3, cy - 6.0), canopy_radius * 0.85, Color(0.39, 0.60, 0.33))
		draw_circle(Vector2(canopy_radius * 0.3, cy - 6.0), canopy_radius * 0.85, Color(0.39, 0.60, 0.33))
		draw_circle(Vector2(0, cy - 22.0), canopy_radius * 0.75, Color(0.46, 0.66, 0.38))

		# Мелкие цветки и ягоды на листве в стиле referens
		var dot_color_white: Color = Color(0.96, 0.94, 0.90)
		var dot_color_pink: Color = Color(0.94, 0.68, 0.72)
		var dot_offsets: Array[Vector2] = [
			Vector2(-28, cy - 18), Vector2(22, cy - 26),
			Vector2(-48, cy + 8), Vector2(42, cy + 4),
			Vector2(-14, cy + 28), Vector2(8, cy - 42),
			Vector2(30, cy + 26), Vector2(-34, cy - 32),
			Vector2(-58, cy + 22), Vector2(56, cy + 18),
			Vector2(0, cy + 6), Vector2(-10, cy - 14)
		]
		for i in range(dot_offsets.size()):
			var col: Color = dot_color_pink if (i % 2 == 0) else dot_color_white
			draw_circle(dot_offsets[i], 2.5, col)
