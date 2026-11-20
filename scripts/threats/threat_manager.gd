class_name ThreatManager
extends Node

# Autoload: ThreatManager
# Coordinates threat wave generation, warning alert timers, and environmental disasters based on the run seed and current day.

signal threat_warning_issued(threat_type: Enums.ThreatType, spawn_side: Vector2, time_until_spawn: float)
signal threat_spawned(threat_node: Node2D)
signal threat_defeated(threat_node: Node2D)
signal rain_storm_started(duration: float)
signal rain_storm_ended()

var daily_threat_schedule: Dictionary = {} # int -> Array[Dictionary]
var active_threats: Array[Node2D] = []
var warning_lead_time: float = 8.0
var rain_active: bool = false
var rain_timer: float = 0.0

var beetle_scene: PackedScene = preload("res://scenes/threats/beetle.tscn")
var spider_scene: PackedScene = preload("res://scenes/threats/spider.tscn")

func _ready() -> void:
	if GameManager != null:
		GameManager.day_started.connect(_on_day_started)

func _on_day_started(day_number: int) -> void:
	schedule_threats_for_day(day_number, GameManager.run_seed)

func _process(delta: float) -> void:
	if GameManager.game_state == Enums.GameState.RUNNING:
		_process_threat_schedule(delta)
		_process_rain_flooding(delta)

func _process_threat_schedule(delta: float) -> void:
	var current_day: int = GameManager.current_day
	if not daily_threat_schedule.has(current_day):
		return
	
	var events: Array = daily_threat_schedule[current_day]
	for ev in events:
		if not ev["executed"]:
			ev["time"] -= delta
			
			# Trigger 8s advance warning
			if ev["time"] <= warning_lead_time and not ev["warned"]:
				ev["warned"] = true
				threat_warning_issued.emit(ev["type"], ev["pos"], ev["time"])
			
			# Trigger execution
			if ev["time"] <= 0.0:
				ev["executed"] = true
				if ev["type"] == Enums.ThreatType.RAIN:
					trigger_rain_event(ev["duration"])
				else:
					spawn_threat(ev["type"], ev["pos"])

func _process_rain_flooding(delta: float) -> void:
	if rain_active:
		rain_timer -= delta
		
		# Apply drowning damage to ants submerged in water
		var main_node: Node = get_tree().current_scene
		var ants_node: Node2D = main_node.get_node_or_null("Ants") as Node2D if main_node != null else null
		if ants_node != null and GridManager != null:
			for ant_child in ants_node.get_children():
				if ant_child is AntController:
					var a: AntController = ant_child as AntController
					var grid_pos: Vector2i = GridManager.world_to_grid(a.global_position)
					if GridManager.get_cell_type(grid_pos) == Enums.CellType.WATER:
						a.take_damage(4.0 * delta)
		
		if rain_timer <= 0.0:
			rain_active = false
			if GridManager != null:
				GridManager.drain_cells()
			rain_storm_ended.emit()

func schedule_threats_for_day(day: int, seed_value: int) -> void:
	daily_threat_schedule[day] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + day * 137
	
	# Day 1: Peaceful foraging
	if day == 1:
		return
	
	# Day 2: 1 Spider surface ambusher
	elif day == 2:
		var spawn_x: float = -50.0 if rng.randf() < 0.5 else 2000.0
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.SPIDER,
			"pos": Vector2(spawn_x, 228.0),
			"time": 50.0,
			"warned": false,
			"executed": false
		})
	
	# Day 3-4: First armored Beetle intruder
	elif day == 3 or day == 4:
		var spawn_x: float = -60.0 if rng.randf() < 0.5 else 2020.0
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE,
			"pos": Vector2(spawn_x, 228.0),
			"time": 45.0,
			"warned": false,
			"executed": false
		})
		if day == 4:
			var spider_x: float = 2000.0 if spawn_x < 500.0 else -50.0
			daily_threat_schedule[day].append({
				"type": Enums.ThreatType.SPIDER,
				"pos": Vector2(spider_x, 228.0),
				"time": 95.0,
				"warned": false,
				"executed": false
			})
	
	# Day 5-6: Rainstorm flooding + Predators
	elif day == 5 or day == 6:
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.RAIN,
			"pos": Vector2(960.0, 0.0),
			"time": 35.0,
			"duration": 30.0,
			"warned": false,
			"executed": false
		})
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE if day == 6 else Enums.ThreatType.SPIDER,
			"pos": Vector2(-60.0, 228.0),
			"time": 85.0,
			"warned": false,
			"executed": false
		})
	
	# Day 7-8: Twin Beetles assault
	elif day == 7 or day == 8:
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE,
			"pos": Vector2(-60.0, 228.0),
			"time": 35.0,
			"warned": false,
			"executed": false
		})
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE,
			"pos": Vector2(2020.0, 228.0),
			"time": 80.0,
			"warned": false,
			"executed": false
		})
		if day == 8:
			daily_threat_schedule[day].append({
				"type": Enums.ThreatType.RAIN,
				"pos": Vector2(960.0, 0.0),
				"time": 105.0,
				"duration": 25.0,
				"warned": false,
				"executed": false
			})
	
	# Day 9-10: Combined onslaught (Rain + Beetles + Spiders)
	else:
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.RAIN,
			"pos": Vector2(960.0, 0.0),
			"time": 25.0,
			"duration": 30.0,
			"warned": false,
			"executed": false
		})
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE,
			"pos": Vector2(-60.0, 228.0),
			"time": 40.0,
			"warned": false,
			"executed": false
		})
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.BEETLE,
			"pos": Vector2(2020.0, 228.0),
			"time": 75.0,
			"warned": false,
			"executed": false
		})
		daily_threat_schedule[day].append({
			"type": Enums.ThreatType.SPIDER,
			"pos": Vector2(-50.0, 228.0),
			"time": 110.0,
			"warned": false,
			"executed": false
		})

func spawn_threat(type: Enums.ThreatType, entry_point: Vector2) -> Node2D:
	var enemy_node: Node2D = null
	if type == Enums.ThreatType.BEETLE:
		if beetle_scene != null:
			enemy_node = beetle_scene.instantiate() as Node2D
	elif type == Enums.ThreatType.SPIDER:
		if spider_scene != null:
			enemy_node = spider_scene.instantiate() as Node2D
	
	if enemy_node != null:
		enemy_node.position = entry_point
		var main_node: Node = get_tree().current_scene
		if main_node != null:
			main_node.add_child(enemy_node)
		else:
			add_child(enemy_node)
		
		active_threats.append(enemy_node)
		threat_spawned.emit(enemy_node)
	
	return enemy_node

func trigger_rain_event(duration: float) -> void:
	rain_active = true
	rain_timer = duration
	rain_storm_started.emit(duration)
	
	if GridManager != null:
		# Floods bottom-most 3 rows
		var start_row: int = GridManager.grid_height - 3
		var end_row: int = GridManager.grid_height - 1
		GridManager.flood_cells(start_row, end_row)
		
		# Check if any food stores are submerged and spoil their food
		var stores_flooded: int = 0
		for coord in GridManager.chambers.keys():
			if coord.y >= start_row and GridManager.chambers[coord] == Enums.ChamberType.FOOD_STORE:
				stores_flooded += 1
		
		if stores_flooded > 0 and ResourceManager != null:
			ResourceManager.spoil_food(stores_flooded * 10)

func unregister_threat(threat_node: Node2D) -> void:
	if active_threats.has(threat_node):
		active_threats.erase(threat_node)
		threat_defeated.emit(threat_node)

func is_rain_active() -> bool:
	return rain_active
