class_name MainController
extends Node2D

# Root controller for the main scene orchestrating the camera, world, and HUD.

signal world_initialized()

@onready var camera: CameraController = $Camera2D
@onready var queen: QueenController = $Queen
@onready var ants_container: Node2D = $Ants
@onready var grid_cursor: GridCursor = $GridCursor
@onready var build_menu: BuildMenuController = $UILayer/BuildMenuController
@onready var top_bar: TopBarHUD = $UILayer/TopBarHUD
@onready var ant_roster: Control = $UILayer/AntRosterController

var ant_scene: PackedScene = preload("res://scenes/entities/ant.tscn")

# Линия поверхности (Y = 8 строк * 32px = 256)
const SURFACE_Y: float = 256.0

func _ready() -> void:
	# === ВИЗУАЛЬНЫЕ ИСПРАВЛЕНИЯ (запускаются на старте без редактора) ===
	_fix_earth_background()
	_fix_grid_opacity()
	_fix_tree_root_joints()
	# ==================================================================

	if build_menu != null and grid_cursor != null:
		build_menu.tool_selected.connect(func(tool_id: int) -> void:
			grid_cursor.select_tool(tool_id)
		)
	if top_bar != null and ant_roster != null:
		top_bar.roster_toggled.connect(func() -> void:
			if ant_roster.has_method("toggle_roster"):
				ant_roster.toggle_roster()
		)
	initialize_world()


## Шаг 1: Убирает серый фон, ставит тёплую земляную текстуру позади всего.
func _fix_earth_background() -> void:
	var bg: Node = get_node_or_null("Background")
	if bg == null:
		return

	# Удаляем старый EarthSoil (может быть ColorRect или TextureRect с неправильным цветом)
	var old_soil: Node = bg.get_node_or_null("EarthSoil")
	if old_soil != null:
		old_soil.queue_free()

	# Загружаем тёплую земляную текстуру
	var tex_path: String = "res://assets/tiles/smooth_earth_bg.png"
	if not ResourceLoader.exists(tex_path):
		# Запасной вариант — рисуем ColorRect тёплым коричневым
		var fallback: ColorRect = ColorRect.new()
		fallback.name = "EarthSoil"
		fallback.offset_left   = -400.0
		fallback.offset_top    = SURFACE_Y
		fallback.offset_right  = 2400.0
		fallback.offset_bottom = 1400.0
		fallback.color = Color(0.65, 0.44, 0.27)   # #A67045 — тёплая земля
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.z_index = -10
		bg.add_child(fallback)
		bg.move_child(fallback, 0)
		return

	var tex: Texture2D = load(tex_path)
	var soil_rect: TextureRect = TextureRect.new()
	soil_rect.name = "EarthSoil"
	soil_rect.texture = tex
	soil_rect.stretch_mode = TextureRect.STRETCH_TILE          # тайлинг
	soil_rect.offset_left   = -400.0
	soil_rect.offset_top    = SURFACE_Y
	soil_rect.offset_right  = 2400.0
	soil_rect.offset_bottom = 1400.0
	soil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soil_rect.z_index = -10
	bg.add_child(soil_rect)
	# Перемещаем самым нижним среди дочерних узлов Background,
	# чтобы небо, холмы и трава были поверх него
	bg.move_child(soil_rect, 0)


## Шаг 2: Делает сетку (GridView / TileMap / TileMapLayer) почти прозрачной.
func _fix_grid_opacity() -> void:
	# GridView — наш кастомный рендерер сетки
	var grid_view: Node = get_node_or_null("GridView")
	if grid_view != null:
		grid_view.modulate = Color(1.0, 1.0, 1.0, 0.05)

	# На случай если в сцене есть TileMap или TileMapLayer
	var tilemap: Node = get_node_or_null("TileMap")
	if tilemap == null:
		tilemap = find_child("TileMap", true, false)
	if tilemap == null:
		tilemap = find_child("TileMapLayer", true, false)
	if tilemap != null and tilemap is CanvasItem:
		(tilemap as CanvasItem).modulate = Color(1.0, 1.0, 1.0, 0.05)


## Шаг 3: Выравнивает стволы и корни деревьев — стык точно на SURFACE_Y.
## SurfaceDecorSpawner размещает tree_node на position.y = surface_y.
## Внутри tree_node: TreeCrownVisual рисует ствол вверх (y<0),
## TreeRootVisual рисует корни вниз (y>0) — оба от Vector2.ZERO.
## Этот шаг принудительно сбрасывает любые случайные смещения.
func _fix_tree_root_joints() -> void:
	var surface_decor: Node = get_node_or_null("Background/SurfaceDecor")
	if surface_decor == null:
		return

	for tree_node in surface_decor.get_children():
		if not (tree_node is Node2D):
			continue
		# Привязываем саму ноду дерева точно к линии поверхности по Y
		var tp: Vector2 = tree_node.position
		tree_node.position = Vector2(tp.x, SURFACE_Y)

		# Сбрасываем смещения у всех дочерних визуальных узлов (корни + крона)
		for visual in tree_node.get_children():
			if visual is Node2D:
				visual.position = Vector2.ZERO   # стык гарантирован


func initialize_world() -> void:
	if camera != null:
		camera.center_on_position(Vector2(960.0, 540.0))
	GameManager.start_new_run()
	spawn_starter_ants(5)
	world_initialized.emit()


func spawn_starter_ants(count: int) -> void:
	if ants_container == null or ant_scene == null:
		return

	TaskAllocationManager.recalculate_job_targets(count)
	var spawn_center: Vector2 = Vector2(976.0, 528.0)

	for i in range(count):
		var ant: AntController = ant_scene.instantiate() as AntController
		ant.ant_id = GameManager.get_next_ant_id()
		ant.position = spawn_center + Vector2((float(i) - 2.0) * 16.0, 10.0)
		ants_container.add_child(ant)
		ant.assign_job(Enums.JobType.DEFEND)

	GameManager.total_workers_alive = count


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()


func toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
