import unittest


class MockResourceManager:
    def __init__(self, food: int):
        self.stored_food = food

    def consume_food(self, amount: int) -> bool:
        if self.stored_food >= amount:
            self.stored_food -= amount
            return True
        return False


class MockGameManager:
    def __init__(self, count: int):
        self.total_workers_alive = count

    def register_ant_born(self) -> None:
        self.total_workers_alive += 1


class TestHatchAntLogic(unittest.TestCase):
    ANT_COST = 10
    MAX_ANTS = 50

    def can_hatch(self, rm: MockResourceManager, gm: MockGameManager) -> bool:
        return rm.stored_food >= self.ANT_COST and gm.total_workers_alive < self.MAX_ANTS

    def test_can_hatch_with_sufficient_food(self):
        rm = MockResourceManager(15)
        gm = MockGameManager(5)
        self.assertTrue(self.can_hatch(rm, gm))

    def test_cannot_hatch_with_insufficient_food(self):
        rm = MockResourceManager(9)
        gm = MockGameManager(5)
        self.assertFalse(self.can_hatch(rm, gm))

    def test_cannot_hatch_when_population_at_max(self):
        rm = MockResourceManager(50)
        gm = MockGameManager(50)
        self.assertFalse(self.can_hatch(rm, gm))

    def test_hatch_consumes_exact_food_and_increments_ant(self):
        rm = MockResourceManager(25)
        gm = MockGameManager(10)
        self.assertTrue(self.can_hatch(rm, gm))
        
        success = rm.consume_food(self.ANT_COST)
        self.assertTrue(success)
        self.assertEqual(rm.stored_food, 15)
        
        gm.register_ant_born()
        self.assertEqual(gm.total_workers_alive, 11)


if __name__ == "__main__":
    unittest.main()
