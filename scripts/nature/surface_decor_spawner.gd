class_name SurfaceDecorSpawner
extends Node2D

## Спавнер декораций поверхности (деревья, корни вглубь земли, кусты, камни и цветы).
## Создает визуальный стиль как на референсе браузерной игры Ant Colony.

@export var surface_y: float = 256.0           ## Высота поверхности земли (Y = row 8 * 32)
@export var map_width: float = 1920.0          ## Ширина игровой зоны
@export var entrance_x: float = 976.0          ## Координата входа в муравейник (чтобы не перекрывать нору)
@export var entrance_clear_radius: float = 85.0 ## Радиус свободного пространства вокруг норы

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
	
	# 1. Расстановка деревьев с корнями вглубь земли (как на референсе)
	var tree_positions: Array[float] = [120.0, 300.0, 520.0, 740.0, 1220.0, 1440.0, 1660.0, 1840.0]
	for tx in tree_positions:
		if absf(tx - entrance_x) > entrance_clear_radius:
			_spawn_tree_with_roots(tx + randf_range(-20.0, 20.0), surface_y)
	
	# 2. Расстановка пней и крупных кустов между деревьями
	var current_x: float = randf_range(50.0, 120.0)
	while current_x < map_width - 60.0:
		if absf(current_x - entrance_x) > entrance_clear_radius:
			var tex_path: String = TEXTURES_LARGE.pick_random()
			_spawn_prop(tex_path, current_x, surface_y, 0.70, 1.0)
		current_x += randf_range(160.0, 240.0)
	
	# 3. Расстановка мелких объектов (камни, цветы, трава) для детализации
	current_x = randf_range(20.0, 50.0)
	while current_x < map_width - 30.0:
		if absf(current_x - entrance_x) > entrance_clear_radius * 0.6:
			var tex_path: String = TEXTURES_SMALL.pick_random()
			_spawn_prop(tex_path, current_x, surface_y, 0.65, 0.95)
		current_x += randf_range(40.0, 80.0)


## Создание дерева с кроной сверху и корнями, уходящими вглубь земли
func _spawn_tree_with_roots(pos_x: float, pos_y: float) -> void:
	var tree_node: Node2D = Node2D.new()
	tree_node.position = Vector2(pos_x, pos_y)
	
	# Корни дерева (Z-index = 0, уходят вниз в текстуру земли)
	var root_drawer: TreeRootVisual = TreeRootVisual.new()
	root_drawer.z_index = 0
	tree_node.add_child(root_drawer)
	
	# Ствол и крона дерева (Z-index = 2, возвышаются над землей)
	var crown_drawer: TreeCrownVisual = TreeCrownVisual.new()
	crown_drawer.z_index = 2
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
	
	var jitter_x: float = randf_range(-10.0, 10.0)
	var jitter_y: float = randf_range(-2.0, 2.0)
	sprite.position = Vector2(pos_x + jitter_x, pos_y + jitter_y)
	
	add_child(sprite)


# ---------------------------------------------------------------------------
# Вспомогательные визуальные классы для корней и кроны дерева
# ---------------------------------------------------------------------------

class TreeRootVisual extends Node2D:
	var root_color: Color = Color(0.44, 0.31, 0.20) # Woody brown #714f33
	
	func _draw() -> void:
		# Органические ветвящиеся корни, уходящие вниз в песок/землю
		var branch_left: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(-15, 30), Vector2(-35, 75), Vector2(-58, 130), Vector2(-75, 175)
		])
		var branch_left_sub: PackedVector2Array = PackedVector2Array([
			Vector2(-35, 75), Vector2(-22, 115), Vector2(-30, 160)
		])
		var branch_center: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(5, 45), Vector2(-2, 100), Vector2(12, 160), Vector2(8, 205)
		])
		var branch_right: PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(18, 35), Vector2(40, 80), Vector2(65, 135), Vector2(85, 185)
		])
		var branch_right_sub: PackedVector2Array = PackedVector2Array([
			Vector2(40, 80), Vector2(30, 120), Vector2(42, 165)
		])
		
		draw_polyline(branch_left, root_color, 4.0)
		draw_polyline(branch_left_sub, root_color, 2.5)
		draw_polyline(branch_center, root_color, 3.5)
		draw_polyline(branch_right, root_color, 4.0)
		draw_polyline(branch_right_sub, root_color, 2.5)


class TreeCrownVisual extends Node2D:
	var trunk_color: Color = Color(0.44, 0.31, 0.20)
	var trunk_height: float = 135.0
	var trunk_width: float = 14.0
	var canopy_radius: float = 55.0
	
	func _draw() -> void:
		# Ствол дерева вверх от уровня земли
		var trunk_rect: Rect2 = Rect2(-trunk_width * 0.5, -trunk_height, trunk_width, trunk_height)
		draw_rect(trunk_rect, trunk_color)
		draw_rect(trunk_rect, trunk_color.darkened(0.25), false, 1.5)
		
		# Пышная крона из перекрывающихся облаков листвы как на референсе
		var crown_center_y: float = -trunk_height - 12.0
		draw_circle(Vector2(0, crown_center_y), canopy_radius, Color(0.37, 0.59, 0.31))
		draw_circle(Vector2(-canopy_radius * 0.55, crown_center_y + 12.0), canopy_radius * 0.75, Color(0.42, 0.63, 0.35))
		draw_circle(Vector2(canopy_radius * 0.55, crown_center_y + 12.0), canopy_radius * 0.75, Color(0.42, 0.63, 0.35))
		draw_circle(Vector2(0, crown_center_y - 18.0), canopy_radius * 0.70, Color(0.48, 0.68, 0.39))
		
		# Маленькие белые/розовые цветки/ягодки на листве как в оригинале antcolony.gg
		var berry_color: Color = Color(0.95, 0.80, 0.82)
		var dots: Array[Vector2] = [
			Vector2(-22, crown_center_y - 12), Vector2(18, crown_center_y - 22),
			Vector2(-38, crown_center_y + 8), Vector2(32, crown_center_y + 6),
			Vector2(-12, crown_center_y + 24), Vector2(6, crown_center_y - 36),
			Vector2(24, crown_center_y + 24), Vector2(-28, crown_center_y - 28)
		]
		for dot in dots:
			draw_circle(dot, 2.5, berry_color)
