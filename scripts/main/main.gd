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
const SoilBg = preload("res://scripts/nature/soil_background.gd")

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


## Шаг 1: Убирает серый фон, ставит тёплую многослойную почву позади всего.
func _fix_earth_background() -> void:
	var bg: Node = get_node_or_null("Background")
	if bg == null:
		return

	var old_soil: Node = bg.get_node_or_null("EarthSoil")
	if old_soil != null and old_soil is SoilBg:
		return

	if old_soil != null:
		old_soil.queue_free()

	var soil_node: TextureRect = SoilBg.new() as TextureRect
	soil_node.name = "EarthSoil"
	soil_node.offset_left   = -400.0
	soil_node.offset_top    = SURFACE_Y
	soil_node.offset_right  = 2400.0
	soil_node.offset_bottom = 1400.0
	soil_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	soil_node.z_index = -10
	bg.add_child(soil_node)
	bg.move_child(soil_node, 0)


## Шаг 2: Обеспечивает полную видимость GridView и прозрачность остаточных TileMap.
func _fix_grid_opacity() -> void:
	var grid_view: Node = get_node_or_null("GridView")
	if grid_view != null and grid_view is CanvasItem:
		(grid_view as CanvasItem).modulate = Color.WHITE

	# На случай если в сцене остался старый TileMap или TileMapLayer
	var tilemap: Node = get_node_or_null("TileMap")
	if tilemap == null:
		tilemap = find_child("TileMap", true, false)
	if tilemap == null:
		tilemap = find_child("TileMapLayer", true, false)
	if tilemap != null and tilemap is CanvasItem:
		(tilemap as CanvasItem).modulate = Color(1.0, 1.0, 1.0, 0.05)


## Шаг 3: Выравнивает стволы и корни деревьев — стык точно на SURFACE_Y.
## Полоса травы (GrassStrip) сохраняет привязку основания к SURFACE_Y (SURFACE_Y - 36.0).
func _fix_tree_root_joints() -> void:
	var surface_decor: Node = get_node_or_null("Background/SurfaceDecor")
	if surface_decor == null:
		return

	for child in surface_decor.get_children():
		if not (child is Node2D):
			continue
		if child is Sprite2D or child.name == "GrassStrip":
			# Трава должна оставаться на своей позиции (SURFACE_Y - 36.0), чтобы основание сидело на линии земли
			(child as Node2D).position.y = SURFACE_Y - 36.0
			continue

		# Дерево (ствол + корни) привязываем точно к линии поверхности по Y
		var tp: Vector2 = child.position
		child.position = Vector2(tp.x, SURFACE_Y)

		# Сбрасываем смещения у всех дочерних визуальных узлов (корни + крона)
		for visual in child.get_children():
			if visual is Node2D:
				visual.position = Vector2.ZERO   # стык гарантирован


func initialize_world() -> void:
	if camera != null:
		camera.center_on_position(Vector2(960.0, 540.0))
	GameManager.start_new_run()
	if ResourceManager != null:
		ResourceManager.reset_food()
	spawn_starter_ants(5)
	world_initialized.emit()


func spawn_starter_ants(count: int) -> void:
	if ants_container == null or ant_scene == null:
		return

	var spawn_center: Vector2 = Vector2(976.0, 528.0)
	var initial_roles: Array[Enums.JobType] = [
		Enums.JobType.FORAGE,
		Enums.JobType.FORAGE,
		Enums.JobType.DIG,
		Enums.JobType.NURSE,
		Enums.JobType.DEFEND
	]

	for i in range(count):
		var ant: AntController = ant_scene.instantiate() as AntController
		if ant == null:
			continue
		ant.ant_id = GameManager.get_next_ant_id()
		ant.position = spawn_center + Vector2((float(i) - 2.0) * 20.0, 10.0)
		ant.z_index = 4
		ants_container.add_child(ant)
		var role: Enums.JobType = initial_roles[i % initial_roles.size()]
		ant.assign_job(role)

	GameManager.total_workers_alive = count
	GameManager.ant_count_changed.emit(count, 50)
	TaskAllocationManager.recalculate_job_targets(count)


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
