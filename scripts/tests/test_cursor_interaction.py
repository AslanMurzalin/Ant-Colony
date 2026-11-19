#!/usr/bin/env python3
"""
Unit tests for GridCursor and BuildMenu interaction logic.
Tests raycasting, hover validation, tool selection, click dispatching, and invalid click flashes.
"""

import unittest
from test_grid_manager import MockGridManager

class MockGridCursor:
    def __init__(self, grid_mgr):
        self.grid_mgr = grid_mgr
        self.current_hover_cell = (-1, -1)
        self.is_hover_valid = False
        self.flash_timer = 0.0
        self.invalid_flash_pos = (-1, -1)
        self.current_tool = 0 # 0 = DIG, 1 = CANCEL, 2 = NURSERY, 3 = FOOD_STORE
        self.clicked_history = []
        self.invalid_flashes = []

    def update_hover(self, world_x, world_y):
        coords = self.grid_mgr.world_to_grid(world_x, world_y)
        self.current_hover_cell = coords
        self.is_hover_valid = (
            self.grid_mgr.is_valid_coord(*coords) 
            and coords[1] >= self.grid_mgr.surface_row
        )

    def select_tool(self, tool_id):
        self.current_tool = tool_id

    def handle_click(self, coords, is_right_click=False):
        if not self.grid_mgr.is_valid_coord(*coords):
            return

        self.clicked_history.append((coords, is_right_click))

        if is_right_click or self.current_tool == 1: # CANCEL
            if self.grid_mgr.is_cell_marked_for_dig(*coords):
                self.grid_mgr.cancel_dig(*coords)
            else:
                self.trigger_invalid_flash(coords)
            return

        if self.current_tool == 0: # DIG
            if self.grid_mgr.is_cell_marked_for_dig(*coords):
                self.grid_mgr.cancel_dig(*coords)
            elif self.grid_mgr.is_cell_diggable(*coords):
                self.grid_mgr.mark_cell_for_dig(*coords)
            else:
                self.trigger_invalid_flash(coords)

    def trigger_invalid_flash(self, coords):
        self.invalid_flash_pos = coords
        self.flash_timer = 0.25
        self.invalid_flashes.append(coords)

class TestCursorInteraction(unittest.TestCase):
    def setUp(self):
        self.grid = MockGridManager(1337)
        self.cursor = MockGridCursor(self.grid)

    def test_hover_raycasting(self):
        # Above surface (sky) at (100, 50) -> row 1, should be invalid hover
        self.cursor.update_hover(100.0, 50.0)
        self.assertEqual(self.cursor.current_hover_cell, (3, 1))
        self.assertFalse(self.cursor.is_hover_valid)

        # Below surface (soil) at (320, 320) -> col 10, row 10, should be valid
        self.cursor.update_hover(320.0, 320.0)
        self.assertEqual(self.cursor.current_hover_cell, (10, 10))
        self.assertTrue(self.cursor.is_hover_valid)

    def test_click_marks_and_toggles_soil(self):
        target = (15, 20)
        self.grid.cell_data[target] = "SOIL"
        self.cursor.select_tool(0) # DIG

        # Click 1: mark
        self.cursor.handle_click(target, is_right_click=False)
        self.assertTrue(self.grid.is_cell_marked_for_dig(*target))
        self.assertEqual(len(self.cursor.invalid_flashes), 0)

        # Click 2: toggle off
        self.cursor.handle_click(target, is_right_click=False)
        self.assertFalse(self.grid.is_cell_marked_for_dig(*target))
        self.assertEqual(len(self.cursor.invalid_flashes), 0)

    def test_click_rock_triggers_invalid_flash(self):
        target = (12, 12)
        self.grid.cell_data[target] = "ROCK"
        self.cursor.select_tool(0)

        self.cursor.handle_click(target, is_right_click=False)
        self.assertFalse(self.grid.is_cell_marked_for_dig(*target))
        self.assertIn(target, self.cursor.invalid_flashes)
        self.assertEqual(self.cursor.invalid_flash_pos, target)

    def test_right_click_cancels_mark(self):
        target = (14, 20)
        self.grid.cell_data[target] = "SOIL"
        self.grid.mark_cell_for_dig(*target)
        self.assertTrue(self.grid.is_cell_marked_for_dig(*target))

        # Right-click cancels
        self.cursor.handle_click(target, is_right_click=True)
        self.assertFalse(self.grid.is_cell_marked_for_dig(*target))

    def test_tool_selection(self):
        self.cursor.select_tool(1)
        self.assertEqual(self.cursor.current_tool, 1)
        self.cursor.select_tool(2)
        self.assertEqual(self.cursor.current_tool, 2)

if __name__ == "__main__":
    unittest.main()
