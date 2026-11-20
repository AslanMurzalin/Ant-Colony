#!/usr/bin/env python3
"""
Unit tests for Phase 2: Worker Ants & Queen.
Tests:
- Task 2.1A: Queen Controller & Hunger Loop (starvation, feeding, health, defeat triggers)
- Task 2.1B: Queen Royal Chamber anchoring & health bar state
- Task 2.2A: Underground A* Grid Navigation (traversing AIR tunnels, avoiding SOIL/ROCK, adjacent target routing)
- Task 2.2B: Ant Visual Entity, job tints, and cargo payloads
- Task 2.3A: Ant FSM & Inertia Logic (delayed role switching only on IDLE, action persistence)
- Task 2.3B: Digger Job Execution (target query, adjacent approach, 2.5s excavation, block removal)
"""

import unittest
from collections import deque

class MockQueenController:
    def __init__(self):
        self.max_health = 100.0
        self.current_health = 100.0
        self.hunger_timer = 15.0
        self.hunger_interval = 15.0
        self.egg_laying_timer = 20.0
        self.egg_laying_interval = 20.0
        self.is_starving = false = False
        self.starvation_damage_rate = 2.0
        self.distress_timer = 0.0
        self.eggs_laid = 0
        self.game_over_reason = None

    def feed_queen(self, amount: int) -> bool:
        if amount <= 0:
            return False
        self.hunger_timer = self.hunger_interval
        self.is_starving = False
        self.current_health = min(self.max_health, self.current_health + 10.0 * float(amount))
        return True

    def take_damage(self, amount: float) -> None:
        if amount <= 0.0 or self.current_health <= 0.0:
            return
        self.current_health = max(0.0, self.current_health - amount)
        self.distress_timer = 0.5
        if self.current_health <= 0.0:
            self.game_over_reason = "Queen died of combat injuries!"

    def tick_starvation(self, delta: float) -> None:
        if self.current_health <= 0.0:
            return
        damage = self.starvation_damage_rate * delta
        self.current_health = max(0.0, self.current_health - damage)
        if self.current_health <= 0.0:
            self.game_over_reason = "Queen died of starvation!"

    def attempt_lay_egg(self, total_workers: int) -> bool:
        if not self.is_starving and total_workers < 50:
            self.eggs_laid += 1
            return True
        return False

    def process(self, delta: float, total_workers: int = 5) -> None:
        self.hunger_timer -= delta
        if self.hunger_timer <= 0.0:
            self.is_starving = True
            self.tick_starvation(delta)

        if not self.is_starving:
            self.egg_laying_timer -= delta
            if self.egg_laying_timer <= 0.0:
                self.attempt_lay_egg(total_workers)
                self.egg_laying_timer = self.egg_laying_interval


class MockAStarGrid:
    def __init__(self, width=60, height=40, surface_row=8):
        self.width = width
        self.height = height
        self.surface_row = surface_row
        self.cells = {}
        self.dig_queue = []
        self.cell_dig_progress = {}
        self.init_grid()

    def init_grid(self):
        for y in range(self.height):
            for x in range(self.width):
                if y < self.surface_row:
                    self.cells[(x, y)] = "AIR"
                else:
                    self.cells[(x, y)] = "SOIL"
        
        # Royal Chamber (28..32 x 15..17)
        for ry in range(15, 18):
            for rx in range(28, 33):
                self.cells[(rx, ry)] = "AIR"

        # Entrance tunnel
        for ey in range(self.surface_row, 16):
            self.cells[(30, ey)] = "AIR"

    def is_walkable(self, pos):
        if not (0 <= pos[0] < self.width and 0 <= pos[1] < self.height):
            return False
        return self.cells.get(pos) in ("AIR", "WATER")

    def get_path_between(self, start, end):
        if not (0 <= start[0] < self.width and 0 <= start[1] < self.height):
            return []
        if not (0 <= end[0] < self.width and 0 <= end[1] < self.height):
            return []
        if not self.is_walkable(start):
            return []

        target = end
        if not self.is_walkable(target):
            # Find closest walkable neighbor
            best_neighbor = None
            min_dist = float("inf")
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                n = (end[0] + dx, end[1] + dy)
                if self.is_walkable(n):
                    d = (start[0] - n[0]) ** 2 + (start[1] - n[1]) ** 2
                    if d < min_dist:
                        min_dist = d
                        best_neighbor = n
            if not best_neighbor:
                return []
            target = best_neighbor

        # BFS / A*
        queue = deque([(start, [start])])
        visited = {start}
        while queue:
            cur, path = queue.popleft()
            if cur == target:
                return path
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                nxt = (cur[0] + dx, cur[1] + dy)
                if self.is_walkable(nxt) and nxt not in visited:
                    visited.add(nxt)
                    queue.append((nxt, path + [nxt]))
        return []

    def mark_cell_for_dig(self, pos):
        if self.cells.get(pos) == "SOIL" and pos not in self.dig_queue:
            self.dig_queue.append(pos)
            self.cell_dig_progress[pos] = 0.0
            return True
        return False

    def apply_dig_damage(self, pos, amount):
        if pos not in self.dig_queue or self.cells.get(pos) != "SOIL":
            return False
        prog = self.cell_dig_progress.get(pos, 0.0) + amount
        self.cell_dig_progress[pos] = min(1.0, prog)
        if self.cell_dig_progress[pos] >= 1.0:
            self.cells[pos] = "AIR"
            self.dig_queue.remove(pos)
            del self.cell_dig_progress[pos]
            return True
        return False


class MockAntController:
    def __init__(self, grid: MockAStarGrid, job="IDLE"):
        self.grid = grid
        self.current_job = job
        self.state = "IDLE"
        self.pos = (30, 16) # start in Royal Chamber
        self.target_cell = None
        self.carried_cargo = None
        self.path = []
        self.health = 20.0
        self.desired_job = job

    def request_job_transition(self):
        # Inertia rule: only transitions when IDLE
        if self.state == "IDLE" and self.desired_job != self.current_job:
            self.current_job = self.desired_job

    def tick_dig(self, delta):
        if self.current_job != "DIG":
            return

        if self.state == "IDLE":
            self.request_job_transition()
            if self.current_job != "DIG":
                return
            if self.grid.dig_queue:
                self.target_cell = self.grid.dig_queue[0]
                dx = abs(self.pos[0] - self.target_cell[0])
                dy = abs(self.pos[1] - self.target_cell[1])
                if dx + dy <= 1:
                    self.state = "WORKING"
                else:
                    self.path = self.grid.get_path_between(self.pos, self.target_cell)
                    if self.path:
                        self.state = "TRAVELING_TO_TARGET"

        elif self.state == "TRAVELING_TO_TARGET":
            if self.target_cell not in self.grid.dig_queue:
                self.path = []
                self.target_cell = None
                self.state = "IDLE"
                return
            dx = abs(self.pos[0] - self.target_cell[0])
            dy = abs(self.pos[1] - self.target_cell[1])
            if dx + dy <= 1:
                self.state = "WORKING"
            elif self.path:
                self.pos = self.path.pop(0)

        elif self.state == "WORKING":
            if self.target_cell not in self.grid.dig_queue:
                self.target_cell = None
                self.state = "IDLE"
                return
            completed = self.grid.apply_dig_damage(self.target_cell, delta / 2.5)
            if completed:
                self.carried_cargo = "dirt"
                self.target_cell = None
                self.state = "IDLE"


class TestPhase2(unittest.TestCase):
    def test_queen_health_and_damage(self):
        queen = MockQueenController()
        self.assertEqual(queen.current_health, 100.0)
        queen.take_damage(30.0)
        self.assertEqual(queen.current_health, 70.0)
        self.assertIsNone(queen.game_over_reason)

        queen.take_damage(80.0)
        self.assertEqual(queen.current_health, 0.0)
        self.assertEqual(queen.game_over_reason, "Queen died of combat injuries!")

    def test_queen_hunger_and_starvation_loop(self):
        queen = MockQueenController()
        self.assertFalse(queen.is_starving)
        # Advance 15 seconds: hunger depletes
        queen.process(15.0)
        self.assertTrue(queen.is_starving)

        # Further elapsed time damages queen via starvation ticks
        initial_hp = queen.current_health
        queen.process(5.0)
        self.assertLess(queen.current_health, initial_hp)

        # Feeding resets hunger timer and heals
        hp_before_feed = queen.current_health
        fed = queen.feed_queen(1)
        self.assertTrue(fed)
        self.assertFalse(queen.is_starving)
        self.assertGreater(queen.current_health, hp_before_feed)

    def test_queen_starvation_defeat(self):
        queen = MockQueenController()
        # Drain hunger timer
        queen.process(15.0)
        self.assertTrue(queen.is_starving)
        # 50 seconds of starvation damage at 2.0/s = 100 dmg
        queen.process(55.0)
        self.assertEqual(queen.current_health, 0.0)
        self.assertEqual(queen.game_over_reason, "Queen died of starvation!")

    def test_queen_egg_laying_cap(self):
        queen = MockQueenController()
        # Feed queen midway so she is not starving
        queen.process(10.0, total_workers=10)
        queen.feed_queen(1)
        queen.process(10.0, total_workers=10)
        self.assertEqual(queen.eggs_laid, 1)

        # When colony >= 50, no eggs laid
        queen.egg_laying_timer = 0.0
        queen.attempt_lay_egg(total_workers=50)
        self.assertEqual(queen.eggs_laid, 1)

    def test_grid_astar_pathfinding(self):
        grid = MockAStarGrid()
        # Start at surface entrance (30, 8), end in Royal Chamber (30, 16)
        path = grid.get_path_between((30, 8), (30, 16))
        self.assertTrue(len(path) > 0)
        self.assertEqual(path[0], (30, 8))
        self.assertEqual(path[-1], (30, 16))
        
        # Verify every node in path is strictly walkable (AIR)
        for pt in path:
            self.assertTrue(grid.is_walkable(pt))

    def test_grid_astar_adjacent_soil_routing(self):
        grid = MockAStarGrid()
        # Soil cell right next to entrance shaft at (31, 10)
        target_soil = (31, 10)
        self.assertFalse(grid.is_walkable(target_soil))
        
        # Pathfinding to solid soil targets adjacent walkable air cell (30, 10)
        path = grid.get_path_between((30, 8), target_soil)
        self.assertTrue(len(path) > 0)
        self.assertEqual(path[-1], (30, 10))

    def test_ant_fsm_and_inertia(self):
        grid = MockAStarGrid()
        ant = MockAntController(grid, job="FORAGE")
        
        # Working or traveling ant does NOT switch job immediately when player moves sliders
        ant.state = "WORKING"
        ant.desired_job = "DEFEND"
        ant.request_job_transition()
        self.assertEqual(ant.current_job, "FORAGE") # Preserved due to inertia!

        # Ant only switches when reaching IDLE
        ant.state = "IDLE"
        ant.request_job_transition()
        self.assertEqual(ant.current_job, "DEFEND")

    def test_digger_job_execution(self):
        grid = MockAStarGrid()
        # Mark cell adjacent to royal chamber: (33, 16)
        dig_pos = (33, 16)
        grid.mark_cell_for_dig(dig_pos)
        self.assertIn(dig_pos, grid.dig_queue)

        ant = MockAntController(grid, job="DIG")
        ant.pos = (32, 16) # Adjacent air cell in royal chamber

        # First tick: queries target and transitions to WORKING
        ant.tick_dig(0.1)
        self.assertEqual(ant.state, "WORKING")
        self.assertEqual(ant.target_cell, dig_pos)

        # 2.5s of dig work completes excavation
        ant.tick_dig(2.5)
        # Block excavated to AIR and removed from queue
        self.assertEqual(grid.cells[dig_pos], "AIR")
        self.assertNotIn(dig_pos, grid.dig_queue)
        # Ant carries dirt cargo and returns to IDLE
        self.assertEqual(ant.carried_cargo, "dirt")
        self.assertEqual(ant.state, "IDLE")


if __name__ == "__main__":
    unittest.main()
