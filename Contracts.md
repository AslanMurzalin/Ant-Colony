# Ant Colony — System Contracts & Function Specifications (Contracts.md)

This document contains the functional contracts, public interfaces, method signatures, signals, and invariants for all systems, singletons, and entities in the **Ant Colony** Godot 4.x codebase.

> [!IMPORTANT]
> **Contract Invariant Rule:** Every time a new function, method, signal, or class is introduced or modified in the project, this file **MUST** be updated to reflect that change. AI Agents and human developers must consult `Agents.md` for enforcement procedures.

---

## 1. Global Enumerations & Data Types (`Enums.gd`)

```gdscript
class_name Enums

enum JobType {
    FORAGE = 0,
    DIG = 1,
    NURSE = 2,
    DEFEND = 3,
    IDLE = 4
}

enum AntState {
    IDLE,
    TRAVELING_TO_TARGET,
    WORKING,
    CARRYING_PAYLOAD,
    COMBAT,
    RETREATING,
    DEAD
}

enum CellType {
    AIR = 0,
    SOIL = 1,
    ROCK = 2,
    WATER = 3
}

enum ChamberType {
    NONE = 0,
    ROYAL = 1,
    NURSERY = 2,
    FOOD_STORE = 3
}

enum ThreatType {
    BEETLE,
    SPIDER,
    RAIN
}

enum GameState {
    NOT_STARTED,
    RUNNING,
    PAUSED,
    DAY_SUMMARY,
    VICTORY,
    DEFEAT
}
```

---

## 2. Core Singletons & Managers

### 2.1 `GameManager` (Autoload: `res://scripts/core/game_manager.gd`)
Oversees the run lifecycle, day-night progression, game speed, win/lose evaluation, and deterministic seed management.

#### Properties
- `current_day: int` (1 to 10)
- `day_duration_seconds: float` (default 150.0s = 2.5 min)
- `day_timer: float` (elapsed seconds in current day)
- `game_state: Enums.GameState`
- `simulation_speed: float` (0.0 = paused, 1.0 = normal, 2.0 = fast)
- `run_seed: int` (Seed used for all deterministic RNG streams)
- `total_workers_alive: int` (Current active worker ant count, max 50)
- `ants_born_today: int`
- `ants_lost_today: int`
- `food_gathered_today: int`

#### Signals
- `day_started(day_number: int)`
- `day_time_updated(elapsed_ratio: float)` # 0.0 to 1.0 progress through day
- `day_ended(day_number: int, stats: Dictionary)`
- `game_speed_changed(new_speed: float)`
- `game_over(reason: String)`
- `game_won(rating: String, final_stats: Dictionary)`

#### Methods
- `start_new_run(optional_seed: int = -1) -> void`
  - *Description:* Initializes a new 10-day run. If seed is -1, generates a random 64-bit integer. Sets Day 1, resets colony stats, spawns Queen and initial 5 workers.
- `set_game_speed(multiplier: float) -> void`
  - *Description:* Sets engine time scale (`Engine.time_scale = multiplier`) and updates `simulation_speed`. Valid values: `0.0`, `1.0`, `2.0`.
- `advance_day() -> void`
  - *Description:* Concludes the current day, gathers day summary metrics, pauses real-time simulation, and emits `day_ended`.
- `start_next_day() -> void`
  - *Description:* Unpauses the game, increments `current_day`, resets daily counters, triggers threat schedule for the day, and emits `day_started`.
- `check_win_lose_conditions() -> void`
  - *Description:* Called during `_process`. If Queen health <= 0, triggers `trigger_defeat()`. If `current_day > 10`, triggers `trigger_victory()`.
- `trigger_defeat(reason: String) -> void`
  - *Description:* Transitions `game_state` to `DEFEAT`, sets speed to 0.0, and emits `game_over`.
- `trigger_victory() -> void`
  - *Description:* Transitions `game_state` to `VICTORY`, calculates colony score rating (Fledgling, Healthy, Thriving), and emits `game_won`.
- `calculate_end_rating() -> String`
  - *Description:* Evaluates surviving ants, stored food, and Queen health to return `"Fledgling"`, `"Healthy"`, or `"Thriving"`.

---

### 2.2 `TaskAllocationManager` (Autoload: `res://scripts/core/task_allocation_manager.gd`)
Controls the indirect slider-based task distribution. Enforces that percentages sum to 100%, calculates target ant quotas, and coordinates worker role transitions.

#### Properties
- `target_percentages: Dictionary` -> `{ Enums.JobType: float }` (Values between 0.0 and 1.0, sum = 1.0)
- `current_job_counts: Dictionary` -> `{ Enums.JobType: int }`
- `target_job_counts: Dictionary` -> `{ Enums.JobType: int }`

#### Signals
- `task_percentages_updated(percentages: Dictionary)`
- `job_assignments_changed(current_counts: Dictionary, target_counts: Dictionary)`

#### Methods
- `set_task_percentage(job: Enums.JobType, new_value: float) -> void`
  - *Description:* Updates one slider's target ratio. Automatically redistributes the remaining `1.0 - new_value` proportionately among the other unlocked jobs so the total remains exactly 1.0 (100%).
- `lock_slider(job: Enums.JobType, is_locked: bool) -> void`
  - *Description:* Locks or unlocks a job slider to prevent its percentage from changing during redistribution.
- `is_slider_locked(job: Enums.JobType) -> bool`
  - *Description:* Returns whether a job slider is currently locked.
- `get_job_percentage(job: Enums.JobType) -> float`
  - *Description:* Returns current target percentage (0.0 to 1.0) for a given job.
- `get_job_target_count(job: Enums.JobType) -> int`
  - *Description:* Returns target headcount quota for a given job.
- `get_job_current_count(job: Enums.JobType) -> int`
  - *Description:* Returns active headcount currently assigned to a given job.
- `recalculate_job_targets(total_ants: int) -> void`
  - *Description:* Computes `target_job_counts[job]` using the Largest Remainder (Hamilton) method. Guarantees the integer sum strictly equals `total_ants` without rounding drift.
- `request_job_for_ant(ant: AntController) -> Enums.JobType`
  - *Description:* Called when an ant completes its active chore and enters an idle state. Checks which job has `current_job_counts[job] < target_job_counts[job]` with highest deficit and returns that `Enums.JobType`.
- `register_ant(job: Enums.JobType) -> void`
  - *Description:* Increments `current_job_counts[job]` when an ant is spawned or assumes a job.
- `unregister_ant(job: Enums.JobType) -> void`
  - *Description:* Decrements `current_job_counts[job]` when an ant dies or vacates its assignment.

---

### 2.3 `ResourceManager` (Autoload: `res://scripts/core/resource_manager.gd`)
Tracks food quantities, storage limits, spoil timers, and delivers food to the colony.

#### Properties
- `stored_food: int` (Current available food units)
- `base_storage_capacity: int` (Default 20 units)
- `extra_capacity_per_store: int` (15 units per Food Store chamber)
- `food_burn_timer: float` (Periodic worker food consumption tick)

#### Signals
- `food_changed(current_food: int, max_food: int)`
- `food_spoiled(amount: int)`
- `colony_starving()`

#### Methods
- `get_max_capacity() -> int`
  - *Description:* Returns `base_storage_capacity + (GridManager.get_chamber_count(Enums.ChamberType.FOOD_STORE) * extra_capacity_per_store)`.
- `add_food(amount: int) -> int`
  - *Description:* Deposits food into storage up to maximum capacity. Returns the amount successfully stored. Emits `food_changed`.
- `consume_food(amount: int) -> bool`
  - *Description:* Deducts food if `stored_food >= amount`. Returns `true` if successful. If insufficient, returns `false` and emits `colony_starving()`.
- `has_food(amount: int) -> bool`
  - *Description:* Returns `stored_food >= amount`.
- `spoil_food(amount: int) -> void`
  - *Description:* Removes `amount` from `stored_food` due to rain flooding or elapsed spoil ticks in non-chamber caches.

---

### 2.4 `GridManager` (Autoload: `res://scripts/grid/grid_manager.gd`)
Manages the underground 2D discrete cell grid, soil tiles, rock barriers, excavated tunnels, chamber declarations, and water presence.

#### Properties
- `grid_width: int` (Horizontal cell count, e.g., 60 cells)
- `grid_height: int` (Vertical cell count, e.g., 40 cells; surface is at row 8)
- `surface_row: int` (Y-coordinate boundary separating surface grass from underground soil)
- `cell_data: Dictionary` -> `{ Vector2i: CellData }`
- `dig_queue: Array[Vector2i]` (Ordered coordinates marked for excavation)
- `cell_dig_progress: Dictionary` -> `{ Vector2i: float }` (Dig excavation progress 0.0 to 1.0)
- `chambers: Dictionary` -> `{ Vector2i: Enums.ChamberType }`

#### Signals
- `cell_modified(coords: Vector2i, new_type: Enums.CellType)`
- `dig_marked(coords: Vector2i)`
- `dig_cancelled(coords: Vector2i)`
- `dig_progress_updated(coords: Vector2i, progress: float)`
- `chamber_designated(coords: Vector2i, type: Enums.ChamberType)`
- `chamber_completed(coords: Vector2i, type: Enums.ChamberType)`

#### Methods
- `initialize_grid(seed_value: int) -> void`
  - *Description:* Generates the subterranean terrain deterministically. Generates air above `surface_row`, soil below it, and rock clusters based on Perlin/simplex noise. Carves initial Royal Chamber and entrance tunnel.
- `world_to_grid(world_pos: Vector2) -> Vector2i`
  - *Description:* Converts a pixel world position into cell grid coordinates.
- `grid_to_world(grid_coords: Vector2i) -> Vector2`
  - *Description:* Returns the central pixel world position of a specified grid cell.
- `get_cell_type(coords: Vector2i) -> Enums.CellType`
  - *Description:* Returns `Enums.CellType` at `coords`. Returns `ROCK` if out of bounds.
- `is_cell_diggable(coords: Vector2i) -> bool`
  - *Description:* Returns `true` if cell is within bounds, is `Enums.CellType.SOIL`, and is not already queued or excavated.
- `is_cell_marked_for_dig(coords: Vector2i) -> bool`
  - *Description:* Returns `true` if coordinate is present in `dig_queue`.
- `mark_cell_for_dig(coords: Vector2i) -> bool`
  - *Description:* Adds `coords` to `dig_queue` if diggable. Emits `dig_marked`.
- `cancel_dig(coords: Vector2i) -> void`
  - *Description:* Removes `coords` from `dig_queue`. Emits `dig_cancelled`.
- `toggle_dig_mark(coords: Vector2i) -> bool`
  - *Description:* Toggles dig marking on cell: cancels if already queued, marks if diggable. Returns new marked state.
- `clear_all_dig_marks() -> void`
  - *Description:* Cancels all pending dig orders in `dig_queue`.
- `apply_dig_damage(coords: Vector2i, amount: float) -> bool`
  - *Description:* Advances excavation progress on cell. If progress reaches 1.0, calls `complete_dig(coords)` and returns `true`. Emits `dig_progress_updated`.
- `get_dig_progress(coords: Vector2i) -> float`
  - *Description:* Returns current excavation progress (0.0 to 1.0) on a cell.
- `get_next_dig_target(ant_pos: Vector2) -> Vector2i`
  - *Description:* Returns the optimal reachable cell in `dig_queue` closest to `ant_pos`.
- `complete_dig(coords: Vector2i) -> void`
  - *Description:* Changes cell type from `SOIL` to `AIR`, removes from `dig_queue`, updates navigation graph, and emits `cell_modified`.
- `designate_chamber(coords: Vector2i, type: Enums.ChamberType) -> bool`
  - *Description:* Designates an excavated `AIR` cell as a specialized chamber (`NURSERY` or `FOOD_STORE`).
- `get_chamber_count(type: Enums.ChamberType) -> int`
  - *Description:* Returns the total number of active, fully completed chambers of specified type.
- `get_chamber_type(coords: Vector2i) -> Enums.ChamberType`
  - *Description:* Returns the chamber designation type at specified coordinates.
- `is_valid_coord(coords: Vector2i) -> bool`
  - *Description:* Checks whether coordinate vector falls within `grid_width` and `grid_height` boundaries.
- `is_cell_walkable(coords: Vector2i) -> bool`
  - *Description:* Returns whether a cell is traversable for ant navigation (AIR or WATER).
- `flood_cells(row_start: int, row_end: int) -> void`
  - *Description:* Fills specified excavated cells in deep rows with `Enums.CellType.WATER`.
- `drain_cells() -> void`
  - *Description:* Clears all water cells back to `Enums.CellType.AIR`.
- `update_cell_navigation(coords: Vector2i) -> void`
  - *Description:* Updates the AStarGrid2D solid/traversable state for the specified cell coordinates.
- `get_path_between(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]`
  - *Description:* Computes lightweight A* path between two grid cells, traversing only walkable excavated cells. If destination is solid soil, paths to adjacent reachable cell.
- `get_world_path(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2]`
  - *Description:* Converts grid coordinate path from `get_path_between` into an ordered array of central pixel world positions.

---

### 2.5 `GridView` (`res://scripts/grid/grid_view.gd`)
Visual 2D renderer for subterranean cells, rocks, excavated tunnels, royal chambers, and active dig target markers.

#### Properties
- `color_soil: Color` = `#8a5a32`
- `color_deep_soil: Color` = `#5a3820`
- `color_rock: Color` = `#2d241e`
- `color_water: Color` = `Color(0.29, 0.56, 0.85, 0.75)`
- `color_dig_marker: Color` = `#f08a24`
- `color_royal_chamber: Color` = `#f2c230`

#### Methods
- `_on_cell_modified(coords: Vector2i, new_type: Enums.CellType) -> void`
  - *Description:* Signal handler that queues a canvas redraw when any cell type is updated.
- `_on_dig_updated(coords: Vector2i) -> void`
  - *Description:* Signal handler that queues a canvas redraw when a dig order is marked or cancelled.
- `_on_dig_progress(coords: Vector2i, progress: float) -> void`
  - *Description:* Signal handler that queues a canvas redraw when a cell excavation progress updates.

---

### 2.6 `GridCursor` (`res://scripts/grid/grid_cursor.gd`)
Mouse interaction and raycasting controller for grid cells, tile highlighting, and invalid-click feedback.

#### Properties
- `current_hover_cell: Vector2i`
- `is_hover_valid: bool`
- `flash_timer: float`
- `invalid_flash_pos: Vector2i`
- `current_tool: int` (0 = DIG, 1 = CANCEL, 2 = NURSERY, 3 = FOOD_STORE)
- `color_valid_hover: Color` = `Color(1.0, 1.0, 1.0, 0.45)`
- `color_dig_hover: Color` = `#f08a24`
- `color_invalid_flash: Color` = `Color(0.9, 0.15, 0.15, 0.8)`

#### Signals
- `cell_clicked(coords: Vector2i, button_index: int)`
- `hover_cell_changed(coords: Vector2i, is_valid: bool)`
- `invalid_click_occurred(coords: Vector2i)`

#### Methods
- `select_tool(tool_id: int) -> void`
  - *Description:* Switches the active cursor tool (Dig, Cancel, Nursery, Food Store).
- `get_hover_cell() -> Vector2i`
  - *Description:* Returns the grid coordinates currently under the mouse cursor.
- `handle_click(coords: Vector2i, is_right_click: bool = false) -> void`
  - *Description:* Processes mouse button clicks on grid cells; executes active tool or triggers invalid flash.
- `trigger_invalid_flash(coords: Vector2i) -> void`
  - *Description:* Triggers red flashing feedback indicating the clicked tile cannot be dug or selected.

---

## 3. Entity Controllers & State Machines

### 3.1 `QueenController` (`res://scripts/entities/queen_controller.gd`)
Anchored in the Royal Chamber. Serves as the primary win/lose condition and lays eggs.

#### Properties
- `max_health: float` = 100.0
- `current_health: float` = 100.0
- `hunger_timer: float`
- `hunger_interval: float` = 15.0s
- `egg_laying_timer: float`
- `egg_laying_interval: float` = 20.0s
- `is_starving: bool` = false

#### Signals
- `queen_health_changed(current: float, maximum: float)`
- `queen_laid_egg()`
- `queen_damaged(damage_amount: float)`
- `queen_starvation_started()`
- `queen_starvation_ended()`

#### Methods
- `feed_queen(amount: int) -> bool`
  - *Description:* Called by Nurse ants. Consumes food to reset `hunger_timer`, clears `is_starving`, and heals the queen for a small amount.
- `take_damage(amount: float) -> void`
  - *Description:* Deducts health, emits `queen_damaged`, plays pain animation/white flash. If `current_health <= 0`, calls `GameManager.trigger_defeat("Queen died of combat injuries!")`.
- `tick_starvation(delta: float) -> void`
  - *Description:* If `hunger_timer <= 0`, deals periodic health damage directly. If health hits 0, calls `GameManager.trigger_defeat("Queen died of starvation!")`.
- `attempt_lay_egg() -> void`
  - *Description:* If not starving and colony size < 50, triggers `NurseryManager.spawn_egg()` and emits `queen_laid_egg()`.
- `_process_queen_logic(delta: float) -> void`
  - *Description:* Processes hunger decay, starvation damage ticks, and egg incubation countdown during active simulation.
- `_update_visuals(delta: float) -> void`
  - *Description:* Updates idle breathing oscillation, distress damage flashing, and starvation blinking tints.

---

### 3.2 `AntController` (`res://scripts/entities/ant_controller.gd`)
Base controller for worker ants. Manages locomotion, pathfinding, visual role badges, cargo transport, and finite state machine execution.

#### Properties
- `current_job: Enums.JobType`
- `state: Enums.AntState`
- `health: float` = 20.0
- `move_speed: float` = 45.0
- `carried_cargo: Variant` (null, food unit object, or dirt clump)
- `current_target_pos: Vector2`
- `target_cell: Vector2i`
- `combat_target: Node2D`

#### Signals
- `ant_died(ant: AntController)`
- `ant_state_changed(old_state: Enums.AntState, new_state: Enums.AntState)`
- `job_switched(old_job: Enums.JobType, new_job: Enums.JobType)`

#### Methods
- `assign_job(new_job: Enums.JobType) -> void`
  - *Description:* Sets `current_job`, swaps ant visual badge/tint (Brown, Orange, Green, Red), updates role counts in `TaskAllocationManager`.
- `request_job_transition() -> void`
  - *Description:* Called only when the ant is idle or finishes its current payload delivery. Asks `TaskAllocationManager` for any overdue job assignment changes.
- `navigate_to(target_world_pos: Vector2) -> void`
  - *Description:* Queries `GridNavigation` for an A* path through excavated tunnels and sets waypoints.
- `execute_job_behavior(delta: float) -> void`
  - *Description:* Dispatches to specific handlers: `_tick_forage()`, `_tick_dig()`, `_tick_nurse()`, `_tick_defend()`.
- `_tick_forage() -> void`
  - *Description:* Navigates to surface food source node, harvests 1 unit, carries cargo back to nearest food store or royal chamber, deposits it, and resets.
- `_tick_dig() -> void`
  - *Description:* Navigates to cell in `GridManager.dig_queue`, performs digging damage ticks over 2–4 seconds, clears cell to `AIR` when health reaches 0.
- `_tick_nurse() -> void`
  - *Description:* Fetches 1 food from storage, navigates to Royal Chamber or Nursery, feeds Queen or growing larva.
- `_tick_defend() -> void`
  - *Description:* Patrols nest entrance or chamber chokepoint. If threat enters detection radius, enters `COMBAT` and attacks until threat is slain or ant dies.
- `take_damage(amount: float) -> void`
  - *Description:* Reduces health. If health <= 0, drops cargo, unregisters from `TaskAllocationManager`, emits `ant_died`, and plays death animation before freeing.
- `set_ant_state(new_state: Enums.AntState) -> void`
  - *Description:* Transitions worker state machine to a new state and emits `ant_state_changed`.
- `move_along_path(delta: float) -> bool`
  - *Description:* Advances ant along navigation waypoints using velocity and `move_and_slide`. Returns `true` when path end is reached.
- `_animate_walk(delta: float) -> void`
  - *Description:* Updates sprite bobbing and flips sprite horizontally based on locomotion direction.
- `update_job_visuals() -> void`
  - *Description:* Updates color badge tint according to active job (Brown, Orange, Green, Red).
- `update_cargo_visuals() -> void`
  - *Description:* Displays or hides carried payload indicator (dirt clump or breadcrumb).

---

### 3.3 `NurseryManager` (`res://scripts/entities/nursery_manager.gd`)
Tracks eggs and larvae inside the nursery, managing incubation and maturation timers.

#### Properties
- `active_eggs: Array[EggEntity]`
- `active_larvae: Array[LarvaEntity]`
- `egg_incubation_time: float` = 25.0s
- `larva_growth_time: float` = 35.0s
- `larva_food_required: int` = 2

#### Signals
- `egg_spawned(egg_id: int)`
- `egg_hatched(larva_id: int)`
- `larva_matured(ant_instance: AntController)`

#### Methods
- `spawn_egg(chamber_pos: Vector2) -> void`
  - *Description:* Spawns a new egg node at the Royal Chamber or Nursery position and starts incubation timer.
- `feed_larva(larva_id: int) -> bool`
  - *Description:* Called by Nurse ants. Increments nourishment counter for specified larva.
- `hatch_egg(egg_id: int) -> void`
  - *Description:* Replaces egg instance with a larva instance.
- `mature_larva(larva_id: int) -> void`
  - *Description:* Consumes larva and instantiates a new adult `AntController` (Worker) into the colony if total population < 50.

---

### 3.4 `ThreatManager` (`res://scripts/threats/threat_manager.gd`)
Coordinates threat wave generation, warning alert timers, and environmental disasters based on the run seed and current day.

#### Properties
- `daily_threat_schedule: Dictionary` -> `{ int: Array[ThreatScheduleItem] }`
- `active_threats: Array[Node2D]`
- `warning_lead_time: float` = 8.0s

#### Signals
- `threat_warning_issued(threat_type: Enums.ThreatType, spawn_side: Vector2, time_until_spawn: float)`
- `threat_spawned(threat_node: Node2D)`
- `threat_defeated(threat_node: Node2D)`
- `rain_storm_started(duration: float)`
- `rain_storm_ended()`

#### Methods
- `schedule_threats_for_day(day: int, seed_value: int) -> void`
  - *Description:* Computes arrival times, types, and entrance positions for all threats on `day`. Day 1–2: zero/weak spiders; Day 3–4: first beetle; Day 5–6: rain + spiders; Day 7–8: twin beetles; Day 9–10: combined assaults.
- `spawn_threat(type: Enums.ThreatType, entry_point: Vector2) -> Node2D`
  - *Description:* Instantiates enemy scene (`Beetle` or `Spider`) and adds it to the active threat list.
- `trigger_rain_event(duration: float) -> void`
  - *Description:* Signals impending rain, initiates water accumulation in lower tunnels via `GridManager.flood_cells()`, and starts drainage timer.
- `unregister_threat(threat_node: Node2D) -> void`
  - *Description:* Removes defeated enemy from `active_threats` and emits `threat_defeated`.

---

### 3.5 Enemy Entities (`BeetleController` / `SpiderController`)

#### `BeetleController` (`res://scripts/threats/beetle_controller.gd`)
- `health: float` = 80.0
- `attack_damage: float` = 8.0
- `move_speed: float` = 18.0
- `target_priority: Array[Node2D]`
- **Methods:**
  - `find_highest_priority_target() -> Node2D`: Targets Foragers -> Entrance -> Food Store -> Queen.
  - `attack_target(target: Node2D, delta: float) -> void`
  - `take_damage(amount: float) -> void`

#### `SpiderController` (`res://scripts/threats/spider_controller.gd`)
- `health: float` = 30.0
- `attack_damage: float` = 12.0
- `move_speed: float` = 60.0
- **Methods:**
  - `patrol_surface(delta: float) -> void`
  - `ambush_forager(ant: AntController) -> void`
  - `flee_surface() -> void`

---

## 4. User Interface & HUD Controllers

### 4.1 `HUDController` (`res://scripts/ui/hud_controller.gd`)
- **Signals:** `slider_adjusted(job: Enums.JobType, value: float)`, `speed_button_pressed(speed: float)`
- **Methods:**
  - `update_top_bar(day: int, time_pct: float, food: int, max_food: int, ants: int, queen_hp: float) -> void`
  - `update_task_slider_counts(counts: Dictionary) -> void`
  - `show_warning_indicator(threat_type: Enums.ThreatType, screen_edge_pos: Vector2) -> void`

### 4.2 `BuildMenuController` (`res://scripts/ui/build_menu_controller.gd`)
- **Properties:** `current_tool: int` (DIG, NURSERY, FOOD_STORE)
- **Signals:** `tool_selected(tool_id: int)`
- **Methods:**
  - `select_tool(tool_id: int) -> void`
  - `handle_grid_click(cell_coords: Vector2i) -> void`
  - `_update_button_highlights() -> void`

### 4.3 `DaySummaryController` (`res://scripts/ui/day_summary_controller.gd`)
- **Methods:**
  - `show_summary(day: int, stats: Dictionary) -> void`
  - `on_continue_pressed() -> void`

---

## 5. World & Camera Controllers

### 5.1 `CameraController` (`res://scripts/core/camera_controller.gd`)
Controls the 2D cross-section camera with pan limits, dragging, and zoom controls.

#### Properties
- `pan_speed: float` = 500.0
- `drag_sensitivity: float` = 1.0
- `zoom_speed: float` = 0.1
- `min_zoom: float` = 0.5
- `max_zoom: float` = 2.0
- `limit_top_val: int` = -300
- `limit_bottom_val: int` = 1600
- `limit_left_val: int` = -200
- `limit_right_val: int` = 2120
- `is_dragging: bool` = false
- `drag_start_mouse_pos: Vector2`
- `drag_start_camera_pos: Vector2`

#### Signals
- `camera_moved(new_position: Vector2)`
- `camera_zoomed(new_zoom: Vector2)`

#### Methods
- `set_bounds(left: int, top: int, right: int, bottom: int) -> void`
  - *Description:* Sets vertical and horizontal scrolling limits for the camera viewport.
- `move_camera(offset: Vector2) -> void`
  - *Description:* Moves camera by relative offset vector and clamps to bounds. Emits `camera_moved`.
- `adjust_zoom(zoom_delta: float) -> void`
  - *Description:* Changes camera zoom level clamped between `min_zoom` and `max_zoom`. Emits `camera_zoomed`.
- `reset_camera() -> void`
  - *Description:* Resets camera position to default center (960, 540) and zoom to 1.0.
- `center_on_position(world_pos: Vector2) -> void`
  - *Description:* Moves camera directly to center on given coordinates, clamped to view limits.
- `_clamp_position() -> void`
  - *Description:* Helper to constrain current camera position within configured world limits.

---

### 5.2 `MainController` (`res://scripts/main/main.gd`)
Root orchestrator in `res://scenes/main/main.tscn`.

#### Properties
- `camera: CameraController`

#### Signals
- `world_initialized()`

#### Methods
- `initialize_world() -> void`
  - *Description:* Initializes camera center position and emits `world_initialized()`.
- `spawn_starter_ants(count: int) -> void`
  - *Description:* Spawns starter worker ants in the royal chamber and apportions initial tasks via `TaskAllocationManager`.

---

## 6. Contract Checklist for New Code

Whenever any new script or function is created in this project, the author MUST ensure:
1. The function signature, parameters, and return types are documented in this file (`Contracts.md`).
2. Signals emitted and invariants are documented.
3. Class belongs to a designated layer (Autoload, Entity, Grid, Threat, UI).
4. No direct hard coupling bypasses manager singletons.
