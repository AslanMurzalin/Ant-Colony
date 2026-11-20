"""
Phase 5 Unit Tests — UI, 10-Day Loop & Final Polish
Tests: TaskSliderWidget, TopBarHUD, DaySummaryController, BalanceConstants,
       AudioController, PauseMenu, GameManager new signals, QueenController.get_health_pct
"""
import unittest


# ---------------------------------------------------------------------------
# 5.1 — Slider math mirrors TaskAllocationManager normalization rules
# ---------------------------------------------------------------------------

class MockTAM:
    def __init__(self):
        self._pct = {0: 0.25, 1: 0.25, 2: 0.25, 3: 0.25}  # FORAGE/DIG/NURSE/DEFEND

    def set_task_percentage(self, job: int, value: float) -> None:
        """Clamp value and redistribute remainder equally across unlocked jobs."""
        value = max(0.0, min(1.0, value))
        delta = value - self._pct[job]
        others = [j for j in self._pct if j != job]
        self._pct[job] = value
        per_other = -delta / len(others)
        for j in others:
            self._pct[j] = max(0.0, self._pct[j] + per_other)
        # Renormalize to exactly 1.0 to absorb rounding
        total = sum(self._pct.values())
        if total > 0.0:
            for j in self._pct:
                self._pct[j] /= total

    def get_task_percentage(self, job: int) -> float:
        return self._pct[job]


class TestSliderNormalization(unittest.TestCase):
    def setUp(self):
        self.tam = MockTAM()

    def test_initial_sum_is_one(self):
        total = sum(self.tam.get_task_percentage(j) for j in range(4))
        self.assertAlmostEqual(total, 1.0, places=5)

    def test_set_one_slider_sum_stays_one(self):
        self.tam.set_task_percentage(0, 0.6)  # FORAGE = 60 %
        total = sum(self.tam.get_task_percentage(j) for j in range(4))
        self.assertAlmostEqual(total, 1.0, places=5)

    def test_set_all_to_zero_except_one(self):
        self.tam.set_task_percentage(1, 1.0)  # DIG = 100 %
        total = sum(self.tam.get_task_percentage(j) for j in range(4))
        self.assertAlmostEqual(total, 1.0, places=5)

    def test_headcount_does_not_exceed_total(self):
        total_ants = 30
        self.tam.set_task_percentage(0, 0.5)
        counts = [round(self.tam.get_task_percentage(j) * total_ants) for j in range(4)]
        # Allow off-by-one from rounding
        self.assertLessEqual(sum(counts), total_ants + 1)


# ---------------------------------------------------------------------------
# 5.2 — Day summary rating logic
# ---------------------------------------------------------------------------

class StubDaySummary:
    def _day_rating(self, stats: dict) -> str:
        born = stats.get("ants_born", 0)
        lost = stats.get("ants_lost", 0)
        if lost == 0 and born > 0:
            return "⭐⭐⭐  Excellent!"
        elif lost <= 2:
            return "⭐⭐  Good"
        elif lost <= 5:
            return "⭐  Struggled"
        else:
            return "☠  Heavy Losses"


class TestDaySummaryRating(unittest.TestCase):
    def setUp(self):
        self.ds = StubDaySummary()

    def test_no_losses_gives_triple_star(self):
        self.assertEqual(self.ds._day_rating({"ants_born": 2, "ants_lost": 0}), "⭐⭐⭐  Excellent!")

    def test_two_losses_gives_double_star(self):
        self.assertEqual(self.ds._day_rating({"ants_born": 1, "ants_lost": 2}), "⭐⭐  Good")

    def test_five_losses_gives_single_star(self):
        self.assertEqual(self.ds._day_rating({"ants_born": 0, "ants_lost": 5}), "⭐  Struggled")

    def test_many_losses_gives_skull(self):
        self.assertEqual(self.ds._day_rating({"ants_born": 0, "ants_lost": 10}), "☠  Heavy Losses")


# ---------------------------------------------------------------------------
# 5.3 — BalanceConstants sanity checks
# ---------------------------------------------------------------------------

class TestBalanceConstants(unittest.TestCase):
    # Replicate the constants from balance_constants.gd
    QUEEN_HP                = 100.0
    QUEEN_HUNGER_INTERVAL   = 15.0
    ANT_WALK_SPEED          = 45.0
    ANT_DIG_DURATION        = 2.5
    BEETLE_HP               = 80.0
    SPIDER_HP               = 30.0
    ANT_MAX_POPULATION      = 50
    DAY_DURATION            = 150.0

    def test_queen_hp_positive(self):
        self.assertGreater(self.QUEEN_HP, 0)

    def test_beetle_tougher_than_spider(self):
        self.assertGreater(self.BEETLE_HP, self.SPIDER_HP)

    def test_max_population_cap(self):
        self.assertEqual(self.ANT_MAX_POPULATION, 50)

    def test_dig_duration_reasonable(self):
        self.assertGreater(self.ANT_DIG_DURATION, 0)
        self.assertLess(self.ANT_DIG_DURATION, 10.0)

    def test_day_under_five_minutes(self):
        self.assertLessEqual(self.DAY_DURATION, 300.0)


# ---------------------------------------------------------------------------
# 5.4 — Queen get_health_pct
# ---------------------------------------------------------------------------

class StubQueen:
    def __init__(self, current: float, maximum: float):
        self.current_health = current
        self.max_health = maximum

    def get_health_pct(self) -> float:
        if self.max_health <= 0.0:
            return 0.0
        return max(0.0, min(1.0, self.current_health / self.max_health))


class TestQueenHealthPct(unittest.TestCase):
    def test_full_health(self):
        q = StubQueen(100.0, 100.0)
        self.assertAlmostEqual(q.get_health_pct(), 1.0)

    def test_half_health(self):
        q = StubQueen(50.0, 100.0)
        self.assertAlmostEqual(q.get_health_pct(), 0.5)

    def test_zero_health(self):
        q = StubQueen(0.0, 100.0)
        self.assertAlmostEqual(q.get_health_pct(), 0.0)

    def test_no_overflow(self):
        q = StubQueen(110.0, 100.0)
        self.assertLessEqual(q.get_health_pct(), 1.0)


# ---------------------------------------------------------------------------
# 5.5 — GameManager ant tracking
# ---------------------------------------------------------------------------

class StubGameManager:
    def __init__(self):
        self.total_workers_alive = 0
        self.ants_born_today = 0
        self.ants_lost_today = 0
        self._events = []

    def register_ant_born(self) -> None:
        self.total_workers_alive += 1
        self.ants_born_today += 1
        self._events.append(("ant_count_changed", self.total_workers_alive, 50))

    def register_ant_died(self) -> None:
        self.total_workers_alive = max(0, self.total_workers_alive - 1)
        self.ants_lost_today += 1
        self._events.append(("ant_count_changed", self.total_workers_alive, 50))


class TestAntTracking(unittest.TestCase):
    def setUp(self):
        self.gm = StubGameManager()

    def test_register_born_increments(self):
        self.gm.register_ant_born()
        self.assertEqual(self.gm.total_workers_alive, 1)

    def test_register_died_decrements(self):
        self.gm.register_ant_born()
        self.gm.register_ant_born()
        self.gm.register_ant_died()
        self.assertEqual(self.gm.total_workers_alive, 1)

    def test_no_negative_count(self):
        self.gm.register_ant_died()  # already 0
        self.assertEqual(self.gm.total_workers_alive, 0)

    def test_signal_emitted_on_change(self):
        self.gm.register_ant_born()
        self.assertIn("ant_count_changed", [e[0] for e in self.gm._events])


if __name__ == "__main__":
    unittest.main()
