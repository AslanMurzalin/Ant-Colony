# Ant Colony — Project Task Breakdown (tasks.md)

**Team Members:** Umarov Ruslan (Dev A), Murzalin Aslan (Dev B)  
**Target Platform:** Godot 4.x (GDScript)  
**Task Philosophy:** Every task is scoped to be completed in **one focused work session** (1.5 to 3 hours). Tasks are assigned across parallel tracks to minimize merge conflicts and blockers.

---

## Task Distribution Strategy

```
┌───────────────────────────────────────────────┬──────────────────────────────────────────────┐
│  Track A: Umarov Ruslan (Simulation & Logic)  │  Track B: Murzalin Aslan (Grid, UI & World)  │
├───────────────────────────────────────────────┼──────────────────────────────────────────────┤
│ • Task Allocation & Slider Normalization      │ • 2D Soil Grid & Tilemap Generator           │
│ • Worker Ant Finite State Machine             │ • Dig Marking & Cell Excavation Visuals      │
│ • Pathfinding & Navigation Coordination       │ • Queen & Chamber Placement (Royal/Nursery)  │
│ • Food Storage, Carry & Spoilage Logic        │ • HUD Top Bar, Sliders & Build Tool UI       │
│ • Nursery, Eggs & Larva Lifecycle             │ • Predator Spawning, Animations & Effects    │
│ • Threat Combat Math & Health Management      │ • Day-Night Clock, Event Schedule & Summary  │
└───────────────────────────────────────────────┴──────────────────────────────────────────────┘
```

---

## Phase 1: Foundations & Core Architecture

### [Session 1.1] Project Setup & Autoload Skeleton
- [x] **Task 1.1A — Core Autoload Singletons (Dev A)**
  - **Goal:** Set up `res://scripts/core/` with `game_manager.gd`, `task_allocation_manager.gd`, `resource_manager.gd`, and `Enums.gd`.
  - **Deliverable:** Autoloads registered in `project.godot`; stub methods matching `Contracts.md`.
  - **Acceptance Criteria:** Project boots with zero console warnings; enums and global signals accessible from any test node.

- [x] **Task 1.1B — Main Scene & Camera Rig (Dev B)**
  - **Goal:** Create `res://scenes/main/main.tscn` and configure 2D fixed cross-section camera with vertical pan limits.
  - **Deliverable:** `Camera2D` with mouse edge/drag scroll bounds or fixed view; placeholder background dividing sky, grass, and soil layers.
  - **Acceptance Criteria:** Runs in 1080p canvas with crisp pixel scaling (`stretch/mode="canvas_items"`).

---

### [Session 1.2] Soil Grid & Task Distribution Math
- [x] **Task 1.2A — Task Slider Mathematical Distribution (Dev A)**
  - **Goal:** Implement 4-slider normalization logic in `task_allocation_manager.gd`.
  - **Deliverable:** `set_task_percentage(job, value)` correctly maintains a sum of `1.0` (100%) by balancing across the remaining 3 jobs. Unit tests verify sum invariant under extreme inputs (0% and 100%).
  - **Acceptance Criteria:** Sliders cannot exceed total 1.0; returns integer ant quotas without rounding drift.

- [x] **Task 1.2B — Discrete Subsurface Grid (Dev B)**
  - **Goal:** Implement `grid_manager.gd` with 2D array representation (`width: 60`, `height: 40`).
  - **Deliverable:** Cell types for `AIR`, `SOIL`, and `ROCK`. Render cells using `TileMapLayer` or custom draw calls.
  - **Acceptance Criteria:** Deterministic rock generation based on `seed`; surface row at Y=8 cleanly demarcates underground from surface.

---

### [Session 1.3] Excavation & Dig Queue
- [ ] **Task 1.3A — Dig Queue System (Dev A)**
  - **Goal:** Manage `dig_queue: Array[Vector2i]` in `GridManager`.
  - **Deliverable:** `mark_cell_for_dig()`, `cancel_dig()`, and `complete_dig()`. Emit signals when cells change from `SOIL` to `AIR`.
  - **Acceptance Criteria:** Non-diggable rocks cannot be queued; duplicate clicks toggle off dig markers.

- [ ] **Task 1.3B — Mouse Interaction & Dig Tool UI (Dev B)**
  - **Goal:** Build cursor raycasting from screen to grid coordinates (`world_to_grid`).
  - **Deliverable:** Hover box showing highlighted tile; click to add dig indicator visual overlay over target soil cell.
  - **Acceptance Criteria:** Visual dig mark appears on clicked soil; clicking air or rock gives an invalid cursor flash.

---

## Phase 2: Worker Ants & Queen

### [Session 2.1] Queen Entity & Food Depot
- [ ] **Task 2.1A — Queen Controller & Hunger Loop (Dev A)**
  - **Goal:** Implement `queen_controller.gd` with health, hunger timer, and starvation damage ticks.
  - **Deliverable:** Queen takes starvation damage if hunger timer expires without food; `feed_queen()` heals and resets hunger.
  - **Acceptance Criteria:** Queen emits `queen_starvation_started` and `queen_damaged`; triggers game over if health drops to 0.

- [ ] **Task 2.1B — Queen Scene & Royal Chamber Setup (Dev B)**
  - **Goal:** Build `queen.tscn` with sprite, idle breathing animation, distress flash, and health bar.
  - **Deliverable:** Fixed placement in the starting Royal Chamber excavated at initialization.
  - **Acceptance Criteria:** Queen displays health bar above sprite; visually changes to distressed state when damaged.

---

### [Session 2.2] Worker Ant Base & Navigation
- [ ] **Task 2.2A — Underground A* Grid Navigation (Dev A)**
  - **Goal:** Build lightweight A* grid pathfinder in `GridManager` traversing only `AIR` cells.
  - **Deliverable:** `get_path_between(start_cell, end_cell) -> Array[Vector2i]` that updates whenever a tile is excavated.
  - **Acceptance Criteria:** Ants successfully find path from surface entrance down to Royal Chamber without crossing solid soil.

- [ ] **Task 2.2B — Ant Visual Entity & Color Bands (Dev B)**
  - **Goal:** Create `ant.tscn` (CharacterBody2D) with 4-frame walk animation and job color badge.
  - **Deliverable:** Color tint dynamically swaps between Brown (Forager), Orange (Digger), Green (Nurse), Red (Defender).
  - **Acceptance Criteria:** Ant moves smoothly along path waypoints; cargo node displays carried breadcrumb or dirt clump.

---

### [Session 2.3] Job State Machine & Delayed Switching
- [ ] **Task 2.3A — Ant FSM & Inertia Logic (Dev A)**
  - **Goal:** Implement `AntController` state transitions (`IDLE`, `TRAVELING`, `WORKING`, `CARRYING`).
  - **Deliverable:** Worker only adopts a new job from `TaskAllocationManager` when reaching `IDLE` state after finishing current task.
  - **Acceptance Criteria:** Changing sliders mid-trip does not cause ants to instantly drop cargo; transition happens upon job completion.

- [ ] **Task 2.3B — Digger Job Execution (Dev B)**
  - **Goal:** Digger ant behavior: pick next cell from `GridManager.dig_queue`, walk to it, play dig animation, and remove tile.
  - **Deliverable:** Digging duration timer (2.5 seconds per soil tile); tile turns into `AIR` upon completion.
  - **Acceptance Criteria:** Digger chips away dirt, finishes block, and queries the next closest dig marker automatically.

---

## Phase 3: Resource Economy & Growth

### [Session 3.1] Foraging & Surface Food Nodes
- [ ] **Task 3.1A — Surface Food Spawner & Deposit Logic (Dev A)**
  - **Goal:** Food node system on the surface. Close nodes (small crumbs) vs. Far nodes (dead insects/fruit).
  - **Deliverable:** Nodes spawn on grass with remaining unit counters; `ResourceManager.add_food()` stores carried food.
  - **Acceptance Criteria:** Foragers seek closest available surface food, pick 1 unit, carry it down to storage, and repeat.

- [ ] **Task 3.1B — Food Store Chambers & Capacity (Dev B)**
  - **Goal:** Chamber designation tool for `FOOD_STORE`.
  - **Deliverable:** Excavating and marking a 3x2 room as `FOOD_STORE` increases colony food capacity in `ResourceManager`.
  - **Acceptance Criteria:** Food HUD reflects `stored / max_capacity`; ants deposit food into nearest available store chamber.

---

### [Session 3.2] Nursing, Eggs & Population Growth
- [ ] **Task 3.2A — Egg Incubation & Larva Metamorphosis (Dev A)**
  - **Goal:** Implement `nursery_manager.gd` tracking egg incubation (25s) and larva feeding (needs 2 food).
  - **Deliverable:** Fed larvae emerge as new adult `AntController` workers; respects the 50-ant hard population cap.
  - **Acceptance Criteria:** No new eggs hatch if population reaches 50; Nurse ants prioritize feeding Queen first, then larvae.

- [ ] **Task 3.2B — Nursery Chamber & Larva Visuals (Dev B)**
  - **Goal:** Build `Nursery` chamber type and visual representation of eggs/larvae on chamber floor.
  - **Deliverable:** Eggs appear in nest; larvae show a small hunger bubble when requiring food from a Nurse ant.
  - **Acceptance Criteria:** Nurse ant walks to Food Store, picks food, carries it to larva, and hunger bubble disappears.

---

## Phase 4: Threats & Combat

### [Session 4.1] Spider Threat (Surface Ambusher)
- [ ] **Task 4.1A — Spider AI & Forager Ambush (Dev A)**
  - **Goal:** Implement `spider_controller.gd`. Spawns on surface edge, patrols grass, and attacks nearest foraging ant.
  - **Deliverable:** Fast movement speed; chases foragers within detection radius; kills ant if caught before ant reaches tunnel entrance.
  - **Acceptance Criteria:** Spider retreats off-screen after killing 1 ant or after taking damage from Defender ants.

- [ ] **Task 4.1B — Threat Warning Alert System (Dev B)**
  - **Goal:** Screen-edge warning arrows in UI (`threat_alert_controller.gd`).
  - **Deliverable:** Pulsing icon appears 8 seconds prior to spider/beetle arrival indicating inbound direction.
  - **Acceptance Criteria:** Alert points accurately toward the boundary where the enemy will enter the screen.

---

### [Session 4.2] Beetle Threat (Heavy Subsurface Intruder)
- [ ] **Task 4.2A — Beetle Controller & Target Priority (Dev A)**
  - **Goal:** Implement `beetle_controller.gd`. High HP (80), slow movement, attacks entrance -> food -> queen.
  - **Deliverable:** Tunnels into nest; attacks defenders, food chambers, and queen; takes damage from surrounding defender ants.
  - **Acceptance Criteria:** Requires 3+ defender ants to defeat without casualties; deals heavy damage to undefended Queen.

- [ ] **Task 4.2B — Defender Ant Patrol & Combat Animations (Dev B)**
  - **Goal:** Defender ant behavior and combat visuals.
  - **Deliverable:** Defenders gather at entrance or follow enemy; attack animations and damage numbers/white hit-flashes.
  - **Acceptance Criteria:** Setting Defend slider to 50% immediately routes idle ants to entrance choke point; engages beetle on sight.

---

### [Session 4.3] Rainstorm Environmental Event
- [ ] **Task 4.3A — Rainstorm Flooding Logic (Dev A)**
  - **Goal:** Rain hazard system. Submerges the bottom-most 3 rows of excavated tunnels in water for 30 seconds.
  - **Deliverable:** Ants submerged take drowning damage; food stored in flooded cells is lost (`ResourceManager.spoil_food`).
  - **Acceptance Criteria:** Water recedes after storm duration ends; drainage tunnels direct water away if dug by player.

- [ ] **Task 4.3B — Weather Effects & Water Shaders (Dev B)**
  - **Goal:** Surface rain particle system, sky darkening tween, and semi-transparent blue water fill in flooded cells.
  - **Deliverable:** Audio/visual warning before storm; rain sounds, water level rise and drain animation.
  - **Acceptance Criteria:** Clean visual distinction between safe dry tunnels and hazardous flooded tunnels.

---

## Phase 5: UI, 10-Day Loop & Final Polish

### [Session 5.1] HUD & Indirect Slider Controls
- [ ] **Task 5.1A — Task Slider UI Widget (Dev A)**
  - **Goal:** 4 interactive sliders in bottom-left corner with headcount indicators (`Forage (12)`, `Dig (5)`, `Nurse (3)`, `Defend (10)`).
  - **Deliverable:** Connected to `TaskAllocationManager`; dragging one slider updates the others smoothly.
  - **Acceptance Criteria:** Sliders can be dragged or locked; live headcount updates as ants change jobs.

- [ ] **Task 5.1B — Top Bar HUD & Speed Controls (Dev B)**
  - **Goal:** Top HUD showing Day (1–10), Day progress bar, Food count (`X/Cap`), Ants alive (`X/50`), and Queen HP.
  - **Deliverable:** Pause, 1x, and 2x simulation speed toggle buttons (`Space` toggles pause).
  - **Acceptance Criteria:** Pausing allows moving sliders and marking dig orders; speed 2x accelerates time scale without physics glitches.

---

### [Session 5.2] 10-Day Progression & Run Generator
- [ ] **Task 5.2A — Deterministic Seed Schedule (Dev A)**
  - **Goal:** Implement 10-day escalation curve in `ThreatManager` driven by random seed.
  - **Deliverable:** Day 1–2 easy; Day 3–4 first beetle; Day 5–6 rain; Day 7–8 twin beetles; Day 9–10 frost & swarm.
  - **Acceptance Criteria:** Running with identical seed produces identical enemy spawn timings and food positions.

- [ ] **Task 5.2B — Day Summary & Victory/Defeat Screens (Dev B)**
  - **Goal:** Build end-of-day summary dialog and final victory/defeat modal cards.
  - **Deliverable:** Displays ants born, ants lost, food gathered; calculates final rank ("Fledgling", "Healthy", "Thriving Colony").
  - **Acceptance Criteria:** Reaching end of Day 10 with Queen alive triggers Victory screen with restart button.

---

### [Session 5.3] Balance Pass, Sound & Integration Polish
- [ ] **Task 5.3A — Economy & Combat Balancing (Dev A)**
  - **Goal:** Fine-tune numbers: Queen hunger frequency, dig speeds, ant walk speed, beetle HP, and food respawn rates.
  - **Deliverable:** Run feels challenging but fair; requires strategic slider balancing between foraging and defense.
  - **Acceptance Criteria:** Full 10-day playthrough completed under 25 minutes without deadlock or unwinnable states.

- [ ] **Task 5.3B — Audio, SFX & Visual Juice (Dev B)**
  - **Goal:** Add ambient underground rumble, ant footstep ticks, dig chomp SFX, alert sirens, and victory fanfare.
  - **Deliverable:** Audio buses for SFX and Music; screen shake when beetles strike walls.
  - **Acceptance Criteria:** Game feels tactile, charming, and polished; volume sliders in pause menu.

---

## Invariant Check & Instant Contract Synchronization
Humans are made of flesh and may forget, but AI Agents and automated checks never do!
Whenever completing any task in this checklist that introduces or modifies a function:
1. Verify Godot 4 static typing is used throughout.
2. Open **[Contracts.md](file:///c:/Users/aslan/Documents/ant-colony/Contracts.md)** and document all new methods, signals, and properties.
3. Review **[Agents.md](file:///c:/Users/aslan/Documents/ant-colony/Agents.md)** to ensure architectural compliance.
4. Run the automated contract verification script:
   ```powershell
   python scripts/tools/check_contracts.py
   ```
   Ensure it reports zero missing functions, signals, or classes before concluding the turn.
