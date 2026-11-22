extends Node

# Autoload: ResourceManager
# Tracks food quantities, individual chamber stockpile cells, storage limits, and delivery to the colony.

signal food_changed(current_food: int, max_food: int)
signal food_spoiled(amount: int)
signal colony_starving()
signal storage_updated()

const CAPACITY_PER_STORAGE_CELL: int = 5
const BASE_QUEEN_STORAGE_CAPACITY: int = 10

var base_storage_capacity: int = BASE_QUEEN_STORAGE_CAPACITY
var extra_capacity_per_store: int = CAPACITY_PER_STORAGE_CELL

var queen_stored_food: int = 10
var cell_food_storage: Dictionary = {} # Vector2i -> int
var stored_food: int = 10
var food_capacity: int:
	get:
		return get_max_capacity()
var food_burn_timer: float = 0.0


func _ready() -> void:
	_recalculate_stored_food()
	var grid_mgr: Node = get_node_or_null("/root/GridManager")
	if grid_mgr != null:
		if grid_mgr.has_signal("chamber_completed"):
			grid_mgr.connect("chamber_completed", Callable(self, "_on_chamber_completed"))
		if grid_mgr.has_signal("cell_modified"):
			grid_mgr.connect("cell_modified", Callable(self, "_on_cell_modified"))


func _on_chamber_completed(coords: Vector2i, type: Enums.ChamberType) -> void:
	if type == Enums.ChamberType.FOOD_STORE:
		if not cell_food_storage.has(coords):
			cell_food_storage[coords] = 0
	_recalculate_stored_food()


func _on_cell_modified(coords: Vector2i, new_type: Enums.CellType) -> void:
	# Если ячейка с едой перестала быть полостью, переносим её еду в хранилище королевы
	if new_type != Enums.CellType.AIR and cell_food_storage.has(coords):
		var saved_food: int = cell_food_storage[coords]
		cell_food_storage.erase(coords)
		queen_stored_food += saved_food
	_recalculate_stored_food()


## Возвращает список всех клеток кладовых, доступных по туннелям от центра колонии
func get_reachable_storage_cells() -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var grid_mgr = get_node_or_null("/root/GridManager")
	if grid_mgr != null and "chambers" in grid_mgr:
		for coord in grid_mgr.chambers.keys():
			if grid_mgr.chambers[coord] == Enums.ChamberType.FOOD_STORE:
				if grid_mgr.has_method("is_cell_reachable_from_colony"):
					if grid_mgr.is_cell_reachable_from_colony(coord):
						reachable.append(coord)
				else:
					reachable.append(coord)
	return reachable


## Максимальная вместимость = база королевы (10) + доступные кладовые * 5
func get_max_capacity() -> int:
	var reachable_stores: Array[Vector2i] = get_reachable_storage_cells()
	return BASE_QUEEN_STORAGE_CAPACITY + reachable_stores.size() * CAPACITY_PER_STORAGE_CELL


## Проверяет, есть ли хотя бы одно свободное место на складах колонии
func has_available_storage_space() -> bool:
	return stored_food < get_max_capacity()


## Количество еды в конкретной ячейке кладовой
func get_cell_food(coords: Vector2i) -> int:
	return cell_food_storage.get(coords, 0)


## Находит лучшую ячейку кладовой со свободным местом, ближайшую к позиции муравья
func find_best_deposit_cell(from_world_pos: Vector2) -> Vector2i:
	var grid_mgr = get_node_or_null("/root/GridManager")
	if grid_mgr == null:
		return Vector2i(30, 16)

	var reachable_stores: Array[Vector2i] = get_reachable_storage_cells()
	var candidates: Array[Vector2i] = []

	for c in reachable_stores:
		if get_cell_food(c) < CAPACITY_PER_STORAGE_CELL:
			candidates.append(c)

	if candidates.size() > 0:
		var best_c: Vector2i = candidates[0]
		var min_d: float = from_world_pos.distance_squared_to(grid_mgr.grid_to_world(best_c))
		for c in candidates:
			var d: float = from_world_pos.distance_squared_to(grid_mgr.grid_to_world(c))
			if d < min_d:
				min_d = d
				best_c = c
		return best_c

	# Если кладовые заполнены или отсутствуют, проверяем королевскую камеру
	if queen_stored_food < BASE_QUEEN_STORAGE_CAPACITY:
		return Vector2i(30, 16)

	return Vector2i(-1, -1)


## Складывает еду в конкретную ячейку кладовой (или в королевское хранилище)
func deposit_food(target_cell: Vector2i, amount: int = 1) -> int:
	if amount <= 0:
		return 0

	var grid_mgr = get_node_or_null("/root/GridManager")
	var is_granary: bool = false
	if grid_mgr != null and grid_mgr.has_method("get_chamber_type"):
		is_granary = (grid_mgr.get_chamber_type(target_cell) == Enums.ChamberType.FOOD_STORE)

	var deposited: int = 0
	if is_granary:
		var current: int = cell_food_storage.get(target_cell, 0)
		var space: int = maxi(0, CAPACITY_PER_STORAGE_CELL - current)
		deposited = mini(space, amount)
		cell_food_storage[target_cell] = current + deposited
	else:
		var space_q: int = maxi(0, BASE_QUEEN_STORAGE_CAPACITY - queen_stored_food)
		deposited = mini(space_q, amount)
		queen_stored_food += deposited

	_recalculate_stored_food()
	return deposited


## Находит ближайшую клетку с ненулевым запасом еды для няньки/кормления
func find_nearest_food_source_cell(from_world_pos: Vector2) -> Vector2i:
	var grid_mgr = get_node_or_null("/root/GridManager")
	if grid_mgr == null:
		return Vector2i(30, 16)

	var sources: Array[Vector2i] = []
	for c in cell_food_storage.keys():
		if cell_food_storage[c] > 0:
			sources.append(c)

	if sources.size() > 0:
		var best_c: Vector2i = sources[0]
		var min_d: float = from_world_pos.distance_squared_to(grid_mgr.grid_to_world(best_c))
		for c in sources:
			var d: float = from_world_pos.distance_squared_to(grid_mgr.grid_to_world(c))
			if d < min_d:
				min_d = d
				best_c = c
		return best_c

	# Если в кладовых пусто, берем у королевы
	if queen_stored_food > 0:
		return Vector2i(30, 16)

	return Vector2i(-1, -1)


## Списывает еду из конкретной клетки
func consume_food_from_cell(cell: Vector2i, amount: int = 1) -> bool:
	if amount <= 0:
		return false

	var grid_mgr = get_node_or_null("/root/GridManager")
	var is_granary: bool = false
	if grid_mgr != null and grid_mgr.has_method("get_chamber_type"):
		is_granary = (grid_mgr.get_chamber_type(cell) == Enums.ChamberType.FOOD_STORE)

	if is_granary and cell_food_storage.has(cell) and cell_food_storage[cell] >= amount:
		cell_food_storage[cell] -= amount
		_recalculate_stored_food()
		return true
	elif queen_stored_food >= amount:
		queen_stored_food -= amount
		_recalculate_stored_food()
		return true

	return false


## Списание еды колонии (например, 10 еды для Hatch Ant)
func consume_food(amount: int) -> bool:
	if stored_food < amount:
		colony_starving.emit()
		return false

	var remaining: int = amount
	# Сначала списываем из кладовых
	for c in cell_food_storage.keys():
		var in_c: int = cell_food_storage[c]
		if in_c > 0:
			var take: int = mini(remaining, in_c)
			cell_food_storage[c] -= take
			remaining -= take
			if remaining <= 0:
				break

	# Остаток списываем из королевского хранилища
	if remaining > 0:
		queen_stored_food = maxi(0, queen_stored_food - remaining)
		remaining = 0

	_recalculate_stored_food()
	return true


## Универсальное добавление еды
func add_food(amount: int) -> int:
	var max_cap: int = get_max_capacity()
	var space: int = maxi(0, max_cap - stored_food)
	var to_add: int = mini(space, amount)
	if to_add <= 0:
		return 0

	var remaining: int = to_add
	# Распределяем по свободным кладовым
	var reachable: Array[Vector2i] = get_reachable_storage_cells()
	for c in reachable:
		var current: int = cell_food_storage.get(c, 0)
		var c_space: int = maxi(0, CAPACITY_PER_STORAGE_CELL - current)
		if c_space > 0:
			var take: int = mini(remaining, c_space)
			cell_food_storage[c] = current + take
			remaining -= take
			if remaining <= 0:
				break

	# Остаток отправляем королеве
	if remaining > 0:
		var q_space: int = maxi(0, BASE_QUEEN_STORAGE_CAPACITY - queen_stored_food)
		var take_q: int = mini(remaining, q_space)
		queen_stored_food += take_q
		remaining -= take_q

	_recalculate_stored_food()
	return to_add


func has_food(amount: int) -> bool:
	return stored_food >= amount


func spoil_food(amount: int) -> void:
	var actual_loss: int = mini(stored_food, amount)
	if actual_loss > 0:
		consume_food(actual_loss)
		food_spoiled.emit(actual_loss)


func reset_food() -> void:
	queen_stored_food = 10
	cell_food_storage.clear()
	_recalculate_stored_food()


## Пересчитывает общее число еды строго как сумму королевской еды и кладовых
func _recalculate_stored_food() -> void:
	var total: int = queen_stored_food
	for count in cell_food_storage.values():
		total += count
	stored_food = total
	food_changed.emit(stored_food, get_max_capacity())
	storage_updated.emit()
