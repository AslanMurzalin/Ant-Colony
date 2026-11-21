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
- `get_task_percentage(job: Enums.JobType) -> float`
  - *Description:* Alias for `get_job_percentage(job)` returning current target percentage for a given job.
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
- `get_pinned_ant_count() -> int`
  - *Description:* Returns the total number of worker ants currently manually pinned to their jobs.
- `unpin_all_ants() -> void`
  - *Description:* Clears manual pinning for all active workers and recalculates quotas for the colony.

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
- `_on_chamber_completed(coords: Vector2i, type: Enums.ChamberType) -> void`
  - *Description:* Signal listener that triggers food capacity recalculation and emits food_changed when a food store chamber is completed.

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
- `_on_chamber_updated(coords: Vector2i, type: Enums.ChamberType) -> void`
  - *Description:* Signal handler that queues a canvas redraw when a specialized chamber is designated or completed.
- `_on_draw_overlay() -> void`
  - *Description:* Draw callback for the dedicated dig overlay node, rendering active dig markers and excavation progress bars without redrawing the terrain.

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
- `_find_nearest_food_storage() -> Vector2`
  - *Description:* Queries GridManager for the closest designated food store chamber, or falls back to the Royal Chamber.
- `_is_entity_targeted_by_another_nurse(target: Node2D) -> bool`
  - *Description:* Checks whether another active nurse ant is already en route to feed the specified entity.
- `_find_unclaimed_hungry_larva() -> LarvaEntity`
  - *Description:* Finds a hungry larva from NurseryManager that is not currently targeted by another nurse ant.
- `_wander_in_chamber() -> void`
  - *Description:* Periodically steps to a small randomized offset in the chamber so idle nurses do not overlap.
- `_apply_soft_separation(delta: float) -> void`
  - *Description:* Gently nudges nearby ants away from each other when within close proximity to prevent sprite stacking.
- `get_action_description() -> String`
  - *Description:* Returns human-readable status description of the ant's current activity for the colony roster UI.
- `set_manually_pinned(pinned: bool) -> void`
  - *Description:* Sets or unsets manual pinning flag and queues visual redraw for pin diamond marker.
- `assign_job_manually(new_job: Enums.JobType) -> void`
  - *Description:* Directly assigns a specific role to the worker and marks it as manually pinned.
- `unpin_job() -> void`
  - *Description:* Removes manual pinning so the worker returns to slider auto-allocation.
- `set_selected(selected: bool) -> void`
  - *Description:* Sets selection highlight state and queues visual redraw for the selection ring.

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
- `_process_lifecycle(delta: float) -> void`
  - *Description:* Updates incubation timers for eggs and growth countdown for fed larvae.
- `get_hungry_larva() -> LarvaEntity`
  - *Description:* Finds and returns the first active larva that requires food feeding.
- `get_random_nursery_position() -> Vector2`
  - *Description:* Returns a world coordinate in an excavated nursery chamber, or defaults to the royal chamber.

#### `EggEntity` (`res://scripts/entities/egg_entity.gd`)
- `egg_id: int`
- `incubation_timer: float`

#### `LarvaEntity` (`res://scripts/entities/larva_entity.gd`)
- `larva_id: int`
- `food_fed: int`
- `food_required: int`
- `growth_timer: float`
- `is_fed: bool`
- **Methods:**
  - `feed() -> bool`
  - `is_hungry() -> bool`
  - `_update_hunger_bubble() -> void`

---

### 3.4 Economy Entities (`FoodSource` / `FoodSpawner`)

#### `FoodSource` (`res://scripts/economy/food_source.gd`)
- `food_units: int`
- `initial_units: int`
- `source_name: String`
- `is_depleted: bool`
- **Signals:**
  - `food_harvested(remaining: int)`
  - `food_depleted()`
- **Methods:**
  - `harvest_unit() -> int`
  - `get_remaining_food() -> int`
  - `_update_display() -> void`

#### `FoodSpawner` (`res://scripts/economy/food_spawner.gd`)
- `active_sources: Array[FoodSource]`
- `spawn_timer: float`
- `spawn_interval: float`
- **Signals:**
  - `food_spawned(source: FoodSource)`
- **Methods:**
  - `spawn_initial_food() -> void`
  - `spawn_food_node(pos: Vector2, amount: int, s_name: String) -> FoodSource`
  - `_spawn_periodic_food() -> void`
  - `get_closest_food(from_pos: Vector2) -> FoodSource`
  - `_on_food_depleted(source: FoodSource) -> void`

---

### 3.5 `ThreatManager` (`res://scripts/threats/threat_manager.gd`)
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
- `_on_day_started(day_number: int) -> void`
  - *Description:* Daily event handler that triggers schedule_threats_for_day on each day start.
- `_process_threat_schedule(delta: float) -> void`
  - *Description:* Updates timer countdowns for daily scheduled threat waves and issues advance alerts.
- `_process_rain_flooding(delta: float) -> void`
  - *Description:* Deals drowning damage to submerged ants during active rainstorms and drains water upon expiration.
- `is_rain_active() -> bool`
  - *Description:* Returns whether a rainstorm flooding event is currently underway.

---

### 3.6 Enemy Entities (`BeetleController` / `SpiderController`)

#### `BeetleController` (`res://scripts/threats/beetle_controller.gd`)
- `health: float` = 80.0
- `attack_damage: float` = 8.0
- `move_speed: float` = 18.0
- `target_priority: Array[Node2D]`
- **Methods:**
  - `find_highest_priority_target() -> Node2D`: Targets Foragers -> Entrance -> Food Store -> Queen.
  - `attack_target(target: Node2D, delta: float) -> void`
  - `take_damage(amount: float) -> void`
  - `_process_beetle_behavior(delta: float) -> void`
  - `_navigate_to_target(target_world_pos: Vector2) -> void`
  - `_move_along_path(delta: float) -> void`

#### `SpiderController` (`res://scripts/threats/spider_controller.gd`)
- `health: float` = 30.0
- `attack_damage: float` = 12.0
- `move_speed: float` = 60.0
- **Methods:**
  - `patrol_surface(delta: float) -> void`
  - `ambush_forager(ant: AntController) -> void`
  - `flee_surface() -> void`
  - `_process_flee(delta: float) -> void`
  - `take_damage(amount: float) -> void`

---

### 3.7 Weather & Environment (`WeatherController`)

#### `WeatherController` (`res://scripts/weather/weather_controller.gd`)
- `is_raining: bool`
- `rain_timer: float`
- `rain_drops: Array[Vector2]`
- `max_drops: int`
- `sky_darkness: float`
- **Methods:**
  - `_on_rain_storm_started(duration: float) -> void`
  - `_on_rain_storm_ended() -> void`
  - `start_rain(duration: float) -> void`
  - `stop_rain() -> void`

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

### 4.4 `ThreatAlertController` (`res://scripts/ui/threat_alert_controller.gd`)
- **Properties:**
  - `is_alert_active: bool`
  - `alert_type: Enums.ThreatType`
  - `alert_dir: Vector2`
  - `alert_timer: float`
  - `pulse_timer: float`
- **Signals:**
  - `alert_started(type: Enums.ThreatType, dir: Vector2)`
  - `alert_ended()`
- **Methods:**
  - `show_alert(type: Enums.ThreatType, spawn_side: Vector2, duration: float) -> void`
  - `hide_alert() -> void`
  - `_on_threat_warning_issued(type: Enums.ThreatType, spawn_side: Vector2, time_until_spawn: float) -> void`
  - `_on_threat_spawned(threat_node: Node2D) -> void`

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

## 6. Phase 5 — UI, 10-Day Loop & Final Polish

---

### 6.1 `TaskSliderWidget` (`res://scripts/ui/task_slider_widget.gd`)
Bottom-left HUD with 4 sliders for indirect ant job allocation.

#### Signals
- `slider_changed(job: Enums.JobType, new_pct: float)` — emitted after a slider drag is processed.

#### Properties
- `_locked: Dictionary` — per-job lock flags (prevents redistribution into this job).
- `_sliders: Dictionary` — `Enums.JobType → HSlider` node refs.
- `_labels: Dictionary` — `Enums.JobType → Label` node refs.
- `_lock_btns: Dictionary` — `Enums.JobType → Button` node refs.
- `_updating: bool` — guard flag to prevent re-entrant slider updates.

#### Methods
- `_build_ui() -> void`
  - *Description:* Programmatically constructs one HBoxContainer row per job with swatch, label, slider, and lock button.
- `_on_slider_changed(job: Enums.JobType, value: float) -> void`
  - *Description:* Called when user drags a slider; delegates to `TaskAllocationManager.set_task_percentage()`, syncs all sliders, refreshes labels.
- `_on_lock_toggled(job: Enums.JobType, pressed: bool) -> void`
  - *Description:* Marks a slider locked/unlocked; updates button icon.
- `_on_quotas_updated() -> void`
  - *Description:* Listener for `TaskAllocationManager.quotas_updated` — re-syncs sliders without triggering TAM again.
- `_sync_sliders_from_tam() -> void`
  - *Description:* Reads percentages from TAM and writes them to slider `.value` without triggering `_on_slider_changed`.
- `_refresh_labels() -> void`
  - *Description:* Updates each label to `"JobName (N)"` headcount format based on current TAM percentages × `GameManager.total_workers_alive`.
- `set_slider_value(job: Enums.JobType, pct: float) -> void`
  - *Description:* Programmatic setter (clamped 0.0–1.0) for tutorial or preset buttons.

---

### 6.2 `TopBarHUD` (`res://scripts/ui/top_bar_hud.gd`)
Top HUD strip — Day, day progress bar, Food, Ants alive, Queen HP, speed buttons.

#### Signals
- `roster_toggled()` — emitted when the Ant Roster button is pressed.

#### Constants
- `SPEED_PAUSE: float = 0.0`
- `SPEED_1X: float = 1.0`
- `SPEED_2X: float = 2.0`

#### Methods
- `_on_roster_pressed() -> void`
  - *Description:* Emits `roster_toggled()` when the Ant Roster button is clicked.
- `_set_speed(speed: float) -> void`
  - *Description:* Calls `GameManager.set_game_speed(speed)` and refreshes button modulate states.
- `_toggle_pause() -> void`
  - *Description:* Toggles between `SPEED_PAUSE` and `SPEED_1X`; bound to `Space` key.
- `_update_speed_buttons(speed: float) -> void`
  - *Description:* Highlights the active speed button, grays out others.
- `_on_day_started(day: int) -> void`
  - *Description:* Updates `_day_label` text and resets `_day_bar` to 0.
- `_on_day_progress(pct: float) -> void`
  - *Description:* Sets `_day_bar.value = pct * 100` and refreshes Queen HP.
- `_on_food_changed(current: int, capacity: int) -> void`
  - *Description:* Updates food label to `"Food: X / Y"`.
- `_on_ant_count_changed(alive: int, _max: int) -> void`
  - *Description:* Updates ants label to `"Ants: X / 50"`.
- `_update_ants_label(alive: int = -1) -> void`
  - *Description:* Updates the ants count label and displays the count of manually pinned workers if greater than zero.
- `_refresh_all() -> void`
  - *Description:* Full refresh of all HUD elements; called in `_ready()`.
- `_refresh_queen_hp() -> void`
  - *Description:* Queries first node in group `"queen"` for `get_health_pct()` and sets `_queen_hp_bar.value`.

---

### 6.3 `DaySummaryController` (`res://scripts/ui/day_summary_controller.gd`)
Between-day modal showing stats; also hosts Victory and Defeat panels.

#### Signals
- `continue_pressed()` — emitted when the continue button is pressed on the day summary.

#### Methods
- `_on_day_ended(day: int, stats: Dictionary) -> void`
  - *Description:* Populates the modal with ants born/lost, food gathered, day rating badge; shows the panel (skips if game is in VICTORY/DEFEAT state).
- `_on_continue_pressed() -> void`
  - *Description:* Hides panel, emits `continue_pressed`, calls `GameManager.start_next_day()`.
- `_day_rating(stats: Dictionary) -> String`
  - *Description:* Returns `"⭐⭐⭐  Excellent!"`, `"⭐⭐  Good"`, `"⭐  Struggled"`, or `"☠  Heavy Losses"` based on `ants_lost` count.
- `show_victory(rating: String, final_stats: Dictionary) -> void`
  - *Description:* Repurposes panel for Victory state: shows rating and total ants alive; swaps continue button to restart.
- `show_defeat(reason: String) -> void`
  - *Description:* Repurposes panel for Defeat state: shows collapse reason; swaps continue button to restart.
- `_on_restart_pressed() -> void`
  - *Description:* Hides panel and calls `GameManager.start_new_run()`.

---

### 6.4 `BalanceConstants` (`res://scripts/core/balance_constants.gd`)
Single source of truth for all tunable gameplay numbers (no logic, constants only).

#### Constants
- `QUEEN_MAX_HEALTH: float = 100.0`
- `QUEEN_HUNGER_INTERVAL: float = 15.0`
- `QUEEN_STARVATION_DAMAGE: float = 2.0`
- `QUEEN_EGG_INTERVAL: float = 20.0`
- `ANT_WALK_SPEED: float = 45.0`
- `ANT_DIG_DURATION: float = 2.5`
- `ANT_ATTACK_DAMAGE: float = 6.0`
- `ANT_ATTACK_COOLDOWN: float = 0.8`
- `ANT_MAX_POPULATION: int = 50`
- `FOOD_BURN_RATE_PER_ANT: float = 0.0008`
- `FOOD_RESPAWN_INTERVAL: float = 30.0`
- `FOOD_NEAR_UNITS: int = 6`
- `FOOD_FAR_UNITS: int = 14`
- `EGG_INCUBATION_SECONDS: float = 25.0`
- `LARVA_FOOD_REQUIRED: int = 2`
- `SPIDER_HP: float = 30.0`
- `SPIDER_SPEED: float = 60.0`
- `SPIDER_DETECT_RADIUS: float = 180.0`
- `SPIDER_DAMAGE: float = 12.0`
- `BEETLE_HP: float = 80.0`
- `BEETLE_SPEED: float = 18.0`
- `BEETLE_DAMAGE: float = 8.0`
- `RAIN_FLOOD_ROWS: int = 3`
- `RAIN_DURATION_SECONDS: float = 30.0`
- `RAIN_DROWN_DAMAGE: float = 5.0`
- `DAY_DURATION_SECONDS: float = 150.0`

---

### 6.5 `AudioController` (`res://scripts/ui/audio_controller.gd`)
Manages SFX and Music audio buses, screen shake, and volume settings.

#### Properties
- `_camera: Camera2D` — reference to camera node for screen shake.
- `_shake_intensity: float` — current shake pixel magnitude.
- `_shake_duration: float` — remaining shake seconds.
- `sfx_volume_db: float` — current SFX bus volume in dB.
- `music_volume_db: float` — current Music bus volume in dB.

#### Methods
- `play_dig_sfx() -> void`
  - *Description:* Plays the dig chomp one-shot audio player.
- `play_step_sfx() -> void`
  - *Description:* Plays the ant footstep tick at reduced volume; only if not already playing.
- `trigger_screen_shake(intensity: float, duration: float) -> void`
  - *Description:* Sets shake intensity/duration; `_tick_screen_shake` applies random camera offset each frame until duration elapses.
- `set_sfx_volume(linear: float) -> void`
  - *Description:* Converts 0.0–1.0 linear value to dB and applies to `"SFX"` audio bus.
- `set_music_volume(linear: float) -> void`
  - *Description:* Converts 0.0–1.0 linear value to dB and applies to `"Music"` audio bus.
- `_connect_signals() -> void`
  - *Description:* Connects to `ThreatManager.threat_warning_issued`, `rain_started`, `rain_stopped`, and `GameManager.game_won`.
- `_on_threat_warning(_direction: int) -> void`
  - *Description:* Plays alert siren SFX.
- `_on_rain_started() -> void`
  - *Description:* Plays rain ambient SFX.
- `_on_rain_stopped() -> void`
  - *Description:* Stops rain SFX player if currently playing.
- `_play_sfx(player: AudioStreamPlayer) -> void`
  - *Description:* Generic helper — sets volume_db and calls `.play()` if stream is not null.
- `_tick_screen_shake(delta: float) -> void`
  - *Description:* Called every frame; applies random offset to `_camera` while `_shake_duration > 0`.
- `_setup_audio_buses() -> void`
  - *Description:* Ensures `"SFX"` and `"Music"` buses exist in `AudioServer`; sets initial volumes.

---

### 6.6 `PauseMenu` (`res://scripts/ui/pause_menu.gd`)
Escape-key pause overlay with SFX/Music volume sliders and quit button.

#### Methods
- `_toggle() -> void`
  - *Description:* Shows pause menu (pauses game) or hides it (resumes at 1×).
- `_on_resume_pressed() -> void`
  - *Description:* Hides the panel and calls `GameManager.set_game_speed(1.0)`.
- `_on_sfx_changed(value: float) -> void`
  - *Description:* Calls `AudioController.set_sfx_volume(value / 100.0)`.
- `_on_music_changed(value: float) -> void`
  - *Description:* Calls `AudioController.set_music_volume(value / 100.0)`.

---

### 6.7 `AntRosterController` (`res://scripts/ui/ant_roster_controller.gd`)
Side drawer menu displaying live activity, role, health, and status for every ant in the colony. Toggled via Tab key or TopBarHUD button.

#### Methods
- `open_roster() -> void`
  - *Description:* Makes the roster panel visible and initiates an immediate refresh of ant cards.
- `close_roster() -> void`
  - *Description:* Hides the ant roster panel.
- `toggle_roster() -> void`
  - *Description:* Toggles visibility of the ant roster panel.
- `refresh_roster() -> void`
  - *Description:* Queries all active ants in group 'workers', aggregates role counts, and constructs detailed status cards.
- `_create_ant_card(ant: AntController, ant_index: int) -> PanelContainer`
  - *Description:* Instantiates a formatted card containing role badge, health, current action text, and camera focus button.
- `_focus_on_ant(ant: AntController) -> void`
  - *Description:* Centers the active cross-section camera on the specified ant's world position.
- `_assign_role_to_ant(ant: AntController, role: Enums.JobType) -> void`
  - *Description:* Directly assigns a job to an individual worker ant, flags it as manually pinned, and recalculates quotas.
- `_unpin_ant(ant: AntController) -> void`
  - *Description:* Unpins a worker ant so it returns to automatic quota allocation.

---

### 6.8 `SelectionController` (`res://scripts/grid/selection_controller.gd`)
Controls Shift+RMB box selection of worker ants in the world, renders selection rectangle overlay, and manages the role assignment popup.

#### Signals
- `ants_selected(selected: Array[AntController])`
- `selection_cleared()`

#### Methods
- `_finish_selection() -> void`
  - *Description:* Evaluates the world-space selection rectangle or click point, populates selected workers, highlights them, and displays `SelectionPopup`.
- `_on_role_chosen(job: Enums.JobType) -> void`
  - *Description:* Receives role selection from popup, assigns role and manual pin to all selected ants, and clears selection.
- `_on_unpin_chosen() -> void`
  - *Description:* Unpins all selected ants, returns them to automatic quota allocation, and clears selection.
- `clear_selection() -> void`
  - *Description:* Unselects all currently highlighted ants, hides the popup, and emits `selection_cleared()`.
- `get_selected_ants() -> Array[AntController]`
  - *Description:* Returns the current list of selected worker ants.

---

### 6.9 `SelectionPopup` (`res://scripts/ui/selection_popup.gd`)
Floating context menu that appears after selecting ants with Shift+RMB, allowing rapid direct role assignment or unpinning.

#### Signals
- `role_chosen(job: Enums.JobType)`
- `unpin_chosen()`
- `popup_closed()`

#### Methods
- `open_at(screen_pos: Vector2, ant_count: int) -> void`
  - *Description:* Positions and displays the popup at the clamped screen coordinate showing the count of selected ants.
- `close_popup() -> void`
  - *Description:* Hides the popup and emits `popup_closed()`.
- `_on_role_pressed(job: Enums.JobType) -> void`
  - *Description:* Emits `role_chosen` with the selected `Enums.JobType` and hides the popup.
- `_on_unpin_pressed() -> void`
  - *Description:* Emits `unpin_chosen` and hides the popup.
- `_on_close_pressed() -> void`
  - *Description:* Closes the popup without making changes.

---

### 6.8 Additions to `GameManager` (Phase 5)

#### New Signals
- `day_progress_ticked(elapsed_ratio: float)` — alias of `day_time_updated`; consumed by `TopBarHUD`.
- `ant_count_changed(alive: int, maximum: int)` — emitted by `register_ant_born()` and `register_ant_died()`.

#### New Methods
- `register_ant_born() -> void`
  - *Description:* Increments `total_workers_alive` and `ants_born_today`; emits `ant_count_changed`.
- `register_ant_died() -> void`
  - *Description:* Decrements `total_workers_alive` (floor 0) and increments `ants_lost_today`; emits `ant_count_changed`.

---

### 6.8 Additions to `QueenController` (Phase 5)

#### New Methods
- `get_health_pct() -> float`
  - *Description:* Returns `current_health / max_health` clamped to `[0.0, 1.0]`; used by `TopBarHUD._refresh_queen_hp()`.

---

## 7. Contract Checklist for New Code

Whenever any new script or function is created in this project, the author MUST ensure:
1. The function signature, parameters, and return types are documented in this file (`Contracts.md`).
2. Signals emitted and invariants are documented.
3. Class belongs to a designated layer (Autoload, Entity, Grid, Threat, UI).
4. No direct hard coupling bypasses manager singletons.
2. Signals emitted and invariants are documented.
3. Class belongs to a designated layer (Autoload, Entity, Grid, Threat, UI).
4. No direct hard coupling bypasses manager singletons.
