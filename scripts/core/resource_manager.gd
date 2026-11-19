extends Node

# Autoload: ResourceManager
# Tracks food quantities, storage limits, spoil timers, and delivers food to the colony.

signal food_changed(current_food: int, max_food: int)
signal food_spoiled(amount: int)
signal colony_starving()

var stored_food: int = 10
var base_storage_capacity: int = 20
var extra_capacity_per_store: int = 15
var food_burn_timer: float = 0.0

func _ready() -> void:
	food_changed.emit(stored_food, get_max_capacity())

func get_max_capacity() -> int:
	var bonus_capacity: int = 0
	# Safely check if GridManager singleton exists and has get_chamber_count
	var grid_mgr = get_node_or_null("/root/GridManager")
	if grid_mgr != null and grid_mgr.has_method("get_chamber_count"):
		bonus_capacity = grid_mgr.get_chamber_count(Enums.ChamberType.FOOD_STORE) * extra_capacity_per_store
	return base_storage_capacity + bonus_capacity

func add_food(amount: int) -> int:
	var max_cap: int = get_max_capacity()
	var space_available: int = maxi(0, max_cap - stored_food)
	var added: int = mini(space_available, amount)
	stored_food += added
	food_changed.emit(stored_food, max_cap)
	return added

func consume_food(amount: int) -> bool:
	if stored_food >= amount:
		stored_food -= amount
		food_changed.emit(stored_food, get_max_capacity())
		return true
	else:
		colony_starving.emit()
		return false

func has_food(amount: int) -> bool:
	return stored_food >= amount

func spoil_food(amount: int) -> void:
	var actual_loss: int = mini(stored_food, amount)
	stored_food = maxi(0, stored_food - actual_loss)
	food_spoiled.emit(actual_loss)
	food_changed.emit(stored_food, get_max_capacity())
