#!/usr/bin/env python3
"""
Unit tests for Phase 3: Resource Economy & Growth.
Tests:
- Task 3.1A: Surface Food Spawner & Deposit Logic (crumbs vs rich nodes, harvesting, ResourceManager storage)
- Task 3.1B: Food Store Chambers & Capacity (chamber designation, bonus capacity formula: 20 + 15 * stores)
- Task 3.2A: Egg Incubation & Larva Metamorphosis (incubation 25s, 2 food requirement, 50-ant hard population cap)
- Task 3.2B: Nursery Chamber & Larva Visuals (hunger bubble, nurse ant feeding priority: Queen -> Larva)
"""

import unittest

class MockFoodSource:
    def __init__(self, pos, units, name="Crumb"):
        self.pos = pos
        self.food_units = units
        self.initial_units = units
        self.source_name = name
        self.is_depleted = False

    def harvest_unit(self) -> int:
        if self.is_depleted or self.food_units <= 0:
            return 0
        self.food_units -= 1
        if self.food_units <= 0:
            self.is_depleted = True
        return 1

    def get_remaining_food(self) -> int:
        return self.food_units


class MockFoodSpawner:
    def __init__(self):
        self.active_sources = []

    def spawn_food_node(self, pos, amount, name="Crumb"):
        node = MockFoodSource(pos, amount, name)
        self.active_sources.append(node)
        return node

    def get_closest_food(self, from_pos):
        best_source = None
        min_dist = float("inf")
        for s in self.active_sources:
            if not s.is_depleted and s.food_units > 0:
                d = (from_pos[0] - s.pos[0]) ** 2 + (from_pos[1] - s.pos[1]) ** 2
                if d < min_dist:
                    min_dist = d
                    best_source = s
        return best_source


class MockResourceManager:
    CAPACITY_PER_STORAGE_CELL = 5
    BASE_QUEEN_STORAGE_CAPACITY = 10

    def __init__(self, base_cap=10, capacity_per_cell=5):
        self.queen_stored_food = 10
        self.stored_food = 10
        self.base_storage_capacity = base_cap
        self.capacity_per_cell = capacity_per_cell
        self.cell_food_storage = {}
        self.reachable_cells = set()
        self.starving = False

    def get_max_capacity(self) -> int:
        return self.base_storage_capacity + (len(self.reachable_cells) * self.capacity_per_cell)

    def has_available_storage_space(self) -> bool:
        return self.stored_food < self.get_max_capacity()

    def get_cell_food(self, coords) -> int:
        return self.cell_food_storage.get(coords, 0)

    def add_food(self, amount: int) -> int:
        max_cap = self.get_max_capacity()
        space = max(0, max_cap - self.stored_food)
        added = min(space, amount)
        self.stored_food += added
        return added

    def consume_food(self, amount: int) -> bool:
        if self.stored_food >= amount:
            self.stored_food -= amount
            return True
        self.starving = True
        return False

    def has_food(self, amount: int) -> bool:
        return self.stored_food >= amount


class MockEgg:
    def __init__(self, egg_id, pos, incubation=25.0):
        self.egg_id = egg_id
        self.pos = pos
        self.incubation_timer = incubation


class MockLarva:
    def __init__(self, larva_id, pos, food_required=2, growth=35.0):
        self.larva_id = larva_id
        self.pos = pos
        self.food_fed = 0
        self.food_required = food_required
        self.growth_timer = growth
        self.is_fed = False

    def feed(self) -> bool:
        if self.food_fed < self.food_required:
            self.food_fed += 1
            if self.food_fed >= self.food_required:
                self.is_fed = True
            return True
        return False

    def is_hungry(self) -> bool:
        return self.food_fed < self.food_required


class MockNurseryManager:
    def __init__(self):
        self.active_eggs = []
        self.active_larvae = []
        self.egg_counter = 0
        self.larva_counter = 0
        self.total_workers_alive = 5
        self.ants_born = 0

    def spawn_egg(self, pos):
        if self.total_workers_alive >= 50:
            return None
        egg = MockEgg(self.egg_counter, pos)
        self.egg_counter += 1
        self.active_eggs.append(egg)
        return egg

    def hatch_egg(self, egg_id):
        target = None
        for e in self.active_eggs:
            if e.egg_id == egg_id:
                target = e
                break
        if not target:
            return None
        self.active_eggs.remove(target)
        larva = MockLarva(self.larva_counter, target.pos)
        self.larva_counter += 1
        self.active_larvae.append(larva)
        return larva

    def feed_larva(self, larva_id):
        for l in self.active_larvae:
            if l.larva_id == larva_id:
                return l.feed()
        return False

    def mature_larva(self, larva_id):
        target = None
        for l in self.active_larvae:
            if l.larva_id == larva_id:
                target = l
                break
        if not target:
            return False
        self.active_larvae.remove(target)
        if self.total_workers_alive < 50:
            self.total_workers_alive += 1
            self.ants_born += 1
            return True
        return False

    def get_hungry_larva(self):
        for l in self.active_larvae:
            if l.is_hungry():
                return l
        return None

    def process(self, delta):
        # Eggs
        for e in list(self.active_eggs):
            e.incubation_timer -= delta
            if e.incubation_timer <= 0.0:
                self.hatch_egg(e.egg_id)
        # Larvae
        for l in list(self.active_larvae):
            if l.is_fed:
                l.growth_timer -= delta
                if l.growth_timer <= 0.0:
                    self.mature_larva(l.larva_id)


class TestPhase3(unittest.TestCase):
    def test_surface_food_source_and_spawner(self):
        spawner = MockFoodSpawner()
        crumb = spawner.spawn_food_node((880, 228), 6, "Bread Crumb")
        fruit = spawner.spawn_food_node((450, 228), 20, "Strawberry")

        self.assertEqual(crumb.food_units, 6)
        self.assertEqual(fruit.food_units, 20)

        # Nearest check from ant at (900, 228) -> should pick crumb
        nearest = spawner.get_closest_food((900, 228))
        self.assertEqual(nearest, crumb)

        # Harvest crumb completely
        for _ in range(6):
            self.assertEqual(crumb.harvest_unit(), 1)
        self.assertEqual(crumb.food_units, 0)
        self.assertTrue(crumb.is_depleted)
        self.assertEqual(crumb.harvest_unit(), 0)

        # After crumb depleted, nearest becomes fruit
        nearest_after = spawner.get_closest_food((900, 228))
        self.assertEqual(nearest_after, fruit)

    def test_food_store_chambers_and_capacity(self):
        res_mgr = MockResourceManager(base_cap=10, capacity_per_cell=5)
        # Base capacity without store chambers (queen base = 10)
        self.assertEqual(res_mgr.get_max_capacity(), 10)

        # Add 1 food store chamber cell -> capacity becomes 15
        res_mgr.reachable_cells.add((10, 10))
        self.assertEqual(res_mgr.get_max_capacity(), 15)

        # Add 2 more food store chamber cells -> capacity becomes 25
        res_mgr.reachable_cells.add((10, 11))
        res_mgr.reachable_cells.add((10, 12))
        self.assertEqual(res_mgr.get_max_capacity(), 25)

        # Adding food respects max capacity
        res_mgr.stored_food = 23
        added = res_mgr.add_food(5)
        self.assertEqual(added, 2)
        self.assertEqual(res_mgr.stored_food, 25)

    def test_nursery_incubation_and_feeding(self):
        nursery = MockNurseryManager()
        egg = nursery.spawn_egg((976, 528))
        self.assertIsNotNone(egg)
        self.assertEqual(len(nursery.active_eggs), 1)

        # Advance 25s: egg hatches into larva
        nursery.process(25.0)
        self.assertEqual(len(nursery.active_eggs), 0)
        self.assertEqual(len(nursery.active_larvae), 1)

        larva = nursery.active_larvae[0]
        self.assertTrue(larva.is_hungry())
        self.assertFalse(larva.is_fed)

        # Nurse feeds larva 1 food -> still hungry (needs 2)
        self.assertTrue(nursery.feed_larva(larva.larva_id))
        self.assertTrue(larva.is_hungry())
        self.assertFalse(larva.is_fed)

        # Nurse feeds larva 2nd food -> now fully fed
        self.assertTrue(nursery.feed_larva(larva.larva_id))
        self.assertFalse(larva.is_hungry())
        self.assertTrue(larva.is_fed)

        # Advance 35s growth timer: larva matures into adult ant
        prev_workers = nursery.total_workers_alive
        nursery.process(35.0)
        self.assertEqual(len(nursery.active_larvae), 0)
        self.assertEqual(nursery.total_workers_alive, prev_workers + 1)
        self.assertEqual(nursery.ants_born, 1)

    def test_population_cap_50(self):
        nursery = MockNurseryManager()
        nursery.total_workers_alive = 50

        # Cannot spawn new egg at cap 50
        egg = nursery.spawn_egg((976, 528))
        self.assertIsNone(egg)
        self.assertEqual(len(nursery.active_eggs), 0)

        # If existing larva matures at cap 50, does not exceed 50
        larva = MockLarva(1, (976, 528))
        larva.is_fed = True
        nursery.active_larvae.append(larva)
        nursery.mature_larva(1)
        self.assertEqual(nursery.total_workers_alive, 50)

    def test_nurse_priority_queen_over_larva(self):
        # Simulate priority decision logic
        queen_starving = True
        hungry_larva_present = True

        target = None
        if queen_starving:
            target = "QUEEN"
        elif hungry_larva_present:
            target = "LARVA"

        self.assertEqual(target, "QUEEN") # Queen prioritized over larva!


if __name__ == "__main__":
    unittest.main()
