class_name GridView
extends Node2D

# Visual renderer for the underground soil grid, rocks, excavated tunnels, and dig markers.

var color_soil: Color = Color(0.87, 0.77, 0.56) # Sandy earth from reference
var color_deep_soil: Color = Color(0.75, 0.67, 0.55) # Deep sandy earth
var color_rock: Color = Color(0.32, 0.30, 0.28)
var color_tunnel: Color = Color(0.32, 0.20, 0.12, 0.95) # Dark hollow dug tunnel
var color_water: Color = Color(0.29, 0.56, 0.85, 0.75)
var color_dig_marker: Color = Color("#f08a24")
var color_royal_chamber: Color = Color("#f2c230")
var color_nursery: Color = Color(0.78, 0.45, 0.72)
var color_food_store: Color = Color(0.88, 0.62, 0.18)

var _dig_overlay: Node2D = null
var _progress_throttle_timer: float = 0.0

func _ready() -> void:
	_dig_overlay = Node2D.new()
	_dig_overlay.name = "DigOverlay"
	_dig_overlay.draw.connect(_on_draw_overlay)
	add_child(_dig_overlay)

	if GridManager != null:
		GridManager.cell_modified.connect(_on_cell_modified)
		GridManager.dig_marked.connect(_on_dig_updated)
		GridManager.dig_cancelled.connect(_on_dig_updated)
		GridManager.dig_progress_updated.connect(_on_dig_progress)
		GridManager.chamber_designated.connect(_on_chamber_updated)
		GridManager.chamber_completed.connect(_on_chamber_updated)

func _process(delta: float) -> void:
	if _progress_throttle_timer > 0.0:
		_progress_throttle_timer -= delta

func _on_cell_modified(_coords: Vector2i, _new_type: Enums.CellType) -> void:
	queue_redraw()
	if _dig_overlay != null:
		_dig_overlay.queue_redraw()

func _on_dig_updated(_coords: Vector2i) -> void:
	if _dig_overlay != null:
		_dig_overlay.queue_redraw()

func _on_dig_progress(_coords: Vector2i, _progress: float) -> void:
	# Throttle overlay redraw to at most 15 FPS so we don't spam draw calls
	if _progress_throttle_timer <= 0.0:
		_progress_throttle_timer = 0.066
		if _dig_overlay != null:
			_dig_overlay.queue_redraw()

func _on_chamber_updated(_coords: Vector2i, _type: Enums.ChamberType) -> void:
	queue_redraw()

func _draw() -> void:
	if GridManager == null:
		return

	var c_size: Vector2 = GridManager.cell_size
	var s_row: int = GridManager.surface_row

	for y in range(s_row, GridManager.grid_height):
		for x in range(GridManager.grid_width):
			var coords: Vector2i = Vector2i(x, y)
			var c_type: Enums.CellType = GridManager.get_cell_type(coords)
			var rect: Rect2 = Rect2(float(x) * c_size.x, float(y) * c_size.y, c_size.x, c_size.y)

			match c_type:
				Enums.CellType.SOIL:
					# Undisturbed smooth earth — no harsh square lines
					pass
				Enums.CellType.ROCK:
					draw_rect(rect, color_rock)
					draw_rect(rect, color_rock.lightened(0.2), false, 1.5)
				Enums.CellType.WATER:
					draw_rect(rect, color_water)
				Enums.CellType.AIR:
					# Dark hollow excavated tunnel
					draw_rect(rect, color_tunnel)
					var chamber: Enums.ChamberType = GridManager.get_chamber_type(coords)
					if chamber == Enums.ChamberType.ROYAL:
						draw_rect(rect, Color(0.85, 0.65, 0.25, 0.40))
						draw_rect(rect, color_royal_chamber, false, 1.0)
					elif chamber == Enums.ChamberType.NURSERY:
						draw_rect(rect, Color(0.78, 0.45, 0.72, 0.40))
						draw_rect(rect, color_nursery, false, 1.0)
					elif chamber == Enums.ChamberType.FOOD_STORE:
						draw_rect(rect, Color(0.88, 0.62, 0.18, 0.40))
						draw_rect(rect, color_food_store, false, 1.0)

func _on_draw_overlay() -> void:
	if GridManager == null or _dig_overlay == null:
		return

	var c_size: Vector2 = GridManager.cell_size

	# Draw Dig Queue Indicators and Progress onto overlay
	for d_coord in GridManager.dig_queue:
		var d_rect: Rect2 = Rect2(float(d_coord.x) * c_size.x, float(d_coord.y) * c_size.y, c_size.x, c_size.y)
		_dig_overlay.draw_rect(d_rect, color_dig_marker, false, 2.0)
		_dig_overlay.draw_line(d_rect.position, d_rect.position + d_rect.size, color_dig_marker, 1.5)
		_dig_overlay.draw_line(Vector2(d_rect.position.x + d_rect.size.x, d_rect.position.y), Vector2(d_rect.position.x, d_rect.position.y + d_rect.size.y), color_dig_marker, 1.5)

		var prog: float = GridManager.get_dig_progress(d_coord)
		if prog > 0.0:
			var bar_rect: Rect2 = Rect2(d_rect.position.x + 2.0, d_rect.position.y + d_rect.size.y - 6.0, (d_rect.size.x - 4.0) * prog, 4.0)
			_dig_overlay.draw_rect(bar_rect, Color(0.2, 0.9, 0.2, 0.9))
