extends Node

# Autoload: GridManager
# Manages the underground 2D discrete cell grid, soil tiles, rock barriers, excavated tunnels, chamber declarations, and water presence.

signal cell_modified(coords: Vector2i, new_type: Enums.CellType)
signal dig_marked(coords: Vector2i)
signal dig_cancelled(coords: Vector2i)
signal dig_progress_updated(coords: Vector2i, progress: float)
signal chamber_designated(coords: Vector2i, type: Enums.ChamberType)
signal chamber_completed(coords: Vector2i, type: Enums.ChamberType)

var grid_width: int = 60
var grid_height: int = 40
var cell_size: Vector2 = Vector2(32.0, 32.0)
var surface_row: int = 8

var cell_data: Dictionary = {} # Vector2i -> Enums.CellType
var dig_queue: Array[Vector2i] = []
var cell_dig_progress: Dictionary = {} # Vector2i -> float (0.0 to 1.0)
var chambers: Dictionary = {} # Vector2i -> Enums.ChamberType
var astar: AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
	initialize_grid(1337)

func initialize_grid(seed_value: int) -> void:
	cell_data.clear()
	dig_queue.clear()
	cell_dig_progress.clear()
	chambers.clear()

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08

	for y in range(grid_height):
		for x in range(grid_width):
			var pos: Vector2i = Vector2i(x, y)
			if y < surface_row:
				cell_data[pos] = Enums.CellType.AIR
			else:
				var noise_val: float = noise.get_noise_2d(float(x), float(y))
				# Rock generation below surface with higher density in deep rows
				var rock_threshold: float = 0.38 - (float(y - surface_row) * 0.003)
				if y > surface_row + 2 and noise_val > rock_threshold:
					cell_data[pos] = Enums.CellType.ROCK
				else:
					cell_data[pos] = Enums.CellType.SOIL

	# Carve initial Royal Chamber (5x3 area centered around row 16, col 28..32)
	var royal_start_x: int = 28
	var royal_start_y: int = 15
	for ry in range(royal_start_y, royal_start_y + 3):
		for rx in range(royal_start_x, royal_start_x + 5):
			var rpos: Vector2i = Vector2i(rx, ry)
			cell_data[rpos] = Enums.CellType.AIR
			chambers[rpos] = Enums.ChamberType.ROYAL

	# Carve vertical entrance shaft from surface down to royal chamber
	var entrance_x: int = 30
	for ey in range(surface_row, royal_start_y + 1):
		var epos: Vector2i = Vector2i(entrance_x, ey)
		cell_data[epos] = Enums.CellType.AIR

	for pos in cell_data.keys():
		cell_modified.emit(pos, cell_data[pos])

	astar.region = Rect2i(0, 0, grid_width, grid_height)
	astar.cell_size = cell_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for pos in cell_data.keys():
		astar.set_point_solid(pos, not is_cell_walkable(pos))

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / cell_size.x)),
		int(floor(world_pos.y / cell_size.y))
	)

func grid_to_world(grid_coords: Vector2i) -> Vector2:
	return Vector2(
		(float(grid_coords.x) + 0.5) * cell_size.x,
		(float(grid_coords.y) + 0.5) * cell_size.y
	)

func is_valid_coord(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.x < grid_width and coords.y >= 0 and coords.y < grid_height

func get_cell_type(coords: Vector2i) -> Enums.CellType:
	if not is_valid_coord(coords):
		return Enums.CellType.ROCK
	return cell_data.get(coords, Enums.CellType.ROCK)

func is_cell_diggable(coords: Vector2i) -> bool:
	if not is_valid_coord(coords):
		return false
	if coords.y < surface_row:
		return false
	if cell_data.get(coords, Enums.CellType.AIR) != Enums.CellType.SOIL:
		return false
	if dig_queue.has(coords):
		return false
	return true

func is_cell_marked_for_dig(coords: Vector2i) -> bool:
	return dig_queue.has(coords)

func is_cell_walkable(coords: Vector2i) -> bool:
	if not is_valid_coord(coords):
		return false
	var ctype: Enums.CellType = cell_data.get(coords, Enums.CellType.ROCK)
	return ctype == Enums.CellType.AIR or ctype == Enums.CellType.WATER

func mark_cell_for_dig(coords: Vector2i) -> bool:
	if not is_cell_diggable(coords):
		return false
	dig_queue.append(coords)
	cell_dig_progress[coords] = 0.0
	dig_marked.emit(coords)
	return true

func cancel_dig(coords: Vector2i) -> void:
	if dig_queue.has(coords):
		dig_queue.erase(coords)
		cell_dig_progress.erase(coords)
		dig_cancelled.emit(coords)

func toggle_dig_mark(coords: Vector2i) -> bool:
	if is_cell_marked_for_dig(coords):
		cancel_dig(coords)
		return false
	else:
		return mark_cell_for_dig(coords)

func clear_all_dig_marks() -> void:
	var queued_copy: Array[Vector2i] = dig_queue.duplicate()
	for coord in queued_copy:
		cancel_dig(coord)

func apply_dig_damage(coords: Vector2i, amount: float) -> bool:
	if not is_valid_coord(coords) or cell_data.get(coords) != Enums.CellType.SOIL:
		return false
	
	var current_prog: float = cell_dig_progress.get(coords, 0.0) + amount
	current_prog = clampf(current_prog, 0.0, 1.0)
	cell_dig_progress[coords] = current_prog
	dig_progress_updated.emit(coords, current_prog)

	if current_prog >= 1.0:
		complete_dig(coords)
		return true
	return false

func get_dig_progress(coords: Vector2i) -> float:
	return cell_dig_progress.get(coords, 0.0)

func get_next_dig_target(ant_pos: Vector2) -> Vector2i:
	if dig_queue.is_empty():
		return Vector2i(-1, -1)
	
	var best_coord: Vector2i = dig_queue[0]
	var best_dist: float = ant_pos.distance_squared_to(grid_to_world(best_coord))

	for coord in dig_queue:
		var dist: float = ant_pos.distance_squared_to(grid_to_world(coord))
		if dist < best_dist:
			best_dist = dist
			best_coord = coord

	return best_coord

func complete_dig(coords: Vector2i) -> void:
	if not is_valid_coord(coords):
		return
	cell_data[coords] = Enums.CellType.AIR
	if dig_queue.has(coords):
		dig_queue.erase(coords)
	cell_dig_progress.erase(coords)
	update_cell_navigation(coords)
	cell_modified.emit(coords, Enums.CellType.AIR)

func designate_chamber(coords: Vector2i, type: Enums.ChamberType) -> bool:
	if not is_valid_coord(coords):
		return false
	if cell_data.get(coords, Enums.CellType.SOIL) != Enums.CellType.AIR:
		return false
	chambers[coords] = type
	chamber_designated.emit(coords, type)
	chamber_completed.emit(coords, type)
	return true

func get_chamber_type(coords: Vector2i) -> Enums.ChamberType:
	return chambers.get(coords, Enums.ChamberType.NONE)

func get_chamber_count(type: Enums.ChamberType) -> int:
	var count: int = 0
	for c in chambers.values():
		if c == type:
			count += 1
	return count

func flood_cells(row_start: int, row_end: int) -> void:
	for y in range(maxi(surface_row, row_start), mini(grid_height, row_end + 1)):
		for x in range(grid_width):
			var pos: Vector2i = Vector2i(x, y)
			if cell_data.get(pos, Enums.CellType.ROCK) == Enums.CellType.AIR:
				cell_data[pos] = Enums.CellType.WATER
				update_cell_navigation(pos)
				cell_modified.emit(pos, Enums.CellType.WATER)

func drain_cells() -> void:
	for pos in cell_data.keys():
		if cell_data[pos] == Enums.CellType.WATER:
			cell_data[pos] = Enums.CellType.AIR
			update_cell_navigation(pos)
			cell_modified.emit(pos, Enums.CellType.AIR)

func update_cell_navigation(coords: Vector2i) -> void:
	if is_valid_coord(coords) and astar != null:
		astar.set_point_solid(coords, not is_cell_walkable(coords))

func get_path_between(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	if not is_valid_coord(start_cell) or not is_valid_coord(end_cell):
		return []

	if astar.is_point_solid(start_cell):
		return []

	var target_cell: Vector2i = end_cell
	if astar.is_point_solid(target_cell):
		var best_neighbor: Vector2i = Vector2i(-1, -1)
		var min_dist: float = 999999.0
		var neighbors: Array[Vector2i] = [
			Vector2i(end_cell.x + 1, end_cell.y),
			Vector2i(end_cell.x - 1, end_cell.y),
			Vector2i(end_cell.x, end_cell.y + 1),
			Vector2i(end_cell.x, end_cell.y - 1)
		]
		for n in neighbors:
			if is_valid_coord(n) and not astar.is_point_solid(n):
				var d: float = Vector2(start_cell).distance_squared_to(Vector2(n))
				if d < min_dist:
					min_dist = d
					best_neighbor = n
		if best_neighbor == Vector2i(-1, -1):
			return []
		target_cell = best_neighbor

	return astar.get_id_path(start_cell, target_cell)

func get_world_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2]:
	var id_path: Array[Vector2i] = get_path_between(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	for c in id_path:
		world_path.append(grid_to_world(c))
	return world_path

