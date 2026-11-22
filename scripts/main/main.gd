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

func _ready() -> void:
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
