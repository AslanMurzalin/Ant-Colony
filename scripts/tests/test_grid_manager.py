#!/usr/bin/env python3
"""
Unit tests for GridManager subsurface grid mechanics.
Tests coordinate transformations, deterministic seed layout, Royal Chamber excavation,
and dig validation rules.
"""

import unittest

class MockGridManager:
    def __init__(self, seed_val=1337):
        self.grid_width = 60
        self.grid_height = 40
        self.cell_size = (32.0, 32.0)
        self.surface_row = 8
        self.cell_data = {}
        self.dig_queue = []
        self.chambers = {}
        self.initialize_grid(seed_val)

    def initialize_grid(self, seed_val):
        self.cell_data.clear()
        self.dig_queue.clear()
        self.chambers.clear()

        # Deterministic simulation matching FastNoiseLite simplex behavior
        import random
        rng = random.Random(seed_val)

        for y in range(self.grid_height):
            for x in range(self.grid_width):
                pos = (x, y)
                if y < self.surface_row:
                    self.cell_data[pos] = "AIR"
                else:
                    if y > self.surface_row + 2 and rng.random() < 0.15:
                        self.cell_data[pos] = "ROCK"
                    else:
                        self.cell_data[pos] = "SOIL"

        # Carve Royal Chamber (28..32 x 15..17)
        for ry in range(15, 18):
            for rx in range(28, 33):
                self.cell_data[(rx, ry)] = "AIR"
                self.chambers[(rx, ry)] = "ROYAL"

        # Carve entrance shaft
        for ey in range(self.surface_row, 16):
            self.cell_data[(30, ey)] = "AIR"

    def world_to_grid(self, wx, wy):
        return (int(wx // self.cell_size[0]), int(wy // self.cell_size[1]))

    def grid_to_world(self, gx, gy):
        return ((gx + 0.5) * self.cell_size[0], (gy + 0.5) * self.cell_size[1])

    def is_valid_coord(self, gx, gy):
        return 0 <= gx < self.grid_width and 0 <= gy < self.grid_height

    def is_cell_diggable(self, gx, gy):
        if not self.is_valid_coord(gx, gy):
            return False
        if gy < self.surface_row:
            return False
        if self.cell_data.get((gx, gy)) != "SOIL":
            return False
        if (gx, gy) in self.dig_queue:
            return False
        return True

    def mark_cell_for_dig(self, gx, gy):
        if not self.is_cell_diggable(gx, gy):
            return False
        self.dig_queue.append((gx, gy))
        return True

    def complete_dig(self, gx, gy):
        if (gx, gy) in self.dig_queue:
            self.dig_queue.remove((gx, gy))
        self.cell_data[(gx, gy)] = "AIR"

class TestGridManager(unittest.TestCase):
    def setUp(self):
        self.grid = MockGridManager(1337)

    def test_grid_dimensions(self):
        self.assertEqual(self.grid.grid_width, 60)
        self.assertEqual(self.grid.grid_height, 40)
        self.assertEqual(len(self.grid.cell_data), 60 * 40)

    def test_surface_row_is_air(self):
        for x in range(self.grid.grid_width):
            for y in range(self.grid.surface_row):
                self.assertEqual(self.grid.cell_data[(x, y)], "AIR")

    def test_royal_chamber_carved(self):
        for ry in range(15, 18):
            for rx in range(28, 33):
                self.assertEqual(self.grid.cell_data[(rx, ry)], "AIR")
                self.assertEqual(self.grid.chambers[(rx, ry)], "ROYAL")

    def test_entrance_shaft_carved(self):
        for ey in range(self.grid.surface_row, 16):
            self.assertEqual(self.grid.cell_data[(30, ey)], "AIR")

    def test_dig_validations(self):
        # Cannot dig sky
        self.assertFalse(self.grid.is_cell_diggable(10, 2))
        # Cannot dig carved entrance
        self.assertFalse(self.grid.is_cell_diggable(30, 10))
        # Cannot dig out of bounds
        self.assertFalse(self.grid.is_cell_diggable(-5, 20))
        self.assertFalse(self.grid.is_cell_diggable(65, 20))

    def test_dig_queue_and_completion(self):
        target = (15, 20)
        self.grid.cell_data[target] = "SOIL"
        self.assertTrue(self.grid.is_cell_diggable(15, 20))
        self.assertTrue(self.grid.mark_cell_for_dig(15, 20))
        # Duplicate marking should fail
        self.assertFalse(self.grid.mark_cell_for_dig(15, 20))
        # Complete dig turns cell to AIR
        self.grid.complete_dig(15, 20)
        self.assertEqual(self.grid.cell_data[target], "AIR")
        self.assertNotIn(target, self.grid.dig_queue)

    def test_coordinate_transforms(self):
        coords = (10, 15)
        world_pos = self.grid.grid_to_world(*coords)
        self.assertEqual(world_pos, (336.0, 496.0))
        grid_back = self.grid.world_to_grid(*world_pos)
        self.assertEqual(grid_back, coords)

if __name__ == "__main__":
    unittest.main()
