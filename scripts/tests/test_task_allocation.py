#!/usr/bin/env python3
"""
Unit tests for TaskAllocationManager mathematical distribution logic.
Tests sum invariants, rounding drift, extreme inputs (0% and 100%), and largest remainder apportionment.
"""

import math
import random
import unittest

class TestTaskAllocationMath(unittest.TestCase):
    def setUp(self):
        self.jobs = ["FORAGE", "DIG", "NURSE", "DEFEND"]
        self.percentages = {j: 0.25 for j in self.jobs}
        self.locked = {j: False for j in self.jobs}

    def set_task_percentage(self, job, new_val):
        new_val = max(0.0, min(1.0, float(new_val)))
        
        unlocked_others = []
        locked_sum = 0.0
        for j in self.jobs:
            if j == job:
                continue
            if self.locked[j]:
                locked_sum += self.percentages[j]
            else:
                unlocked_others.append(j)

        max_allowed = 1.0 - locked_sum
        new_val = max(0.0, min(max_allowed, new_val))
        self.percentages[job] = new_val

        remaining_needed = max(0.0, 1.0 - new_val - locked_sum)

        if unlocked_others:
            unlocked_sum = sum(self.percentages[j] for j in unlocked_others)
            if unlocked_sum > 0.0001:
                for oj in unlocked_others:
                    self.percentages[oj] = (self.percentages[oj] / unlocked_sum) * remaining_needed
            else:
                split_share = remaining_needed / len(unlocked_others)
                for oj in unlocked_others:
                    self.percentages[oj] = split_share

        final_sum = sum(self.percentages.values())
        if final_sum > 0.00001:
            for j in self.jobs:
                self.percentages[j] /= final_sum

    def recalculate_job_targets(self, total_ants):
        if total_ants <= 0:
            return {j: 0 for j in self.jobs}

        int_parts = {}
        remainders = []
        allocated = 0

        for j in self.jobs:
            exact = float(total_ants) * self.percentages[j]
            int_val = math.floor(exact)
            int_parts[j] = int_val
            allocated += int_val
            remainders.append({"job": j, "rem": exact - float(int_val)})

        remainders.sort(key=lambda x: x["rem"], reverse=True)
        seats_left = total_ants - allocated
        for i in range(seats_left):
            target_j = remainders[i % len(remainders)]["job"]
            int_parts[target_j] += 1

        return int_parts

    def test_sum_invariant_default(self):
        self.assertAlmostEqual(sum(self.percentages.values()), 1.0, places=5)

    def test_extreme_zero_percent(self):
        self.set_task_percentage("FORAGE", 0.0)
        self.assertAlmostEqual(self.percentages["FORAGE"], 0.0, places=5)
        self.assertAlmostEqual(sum(self.percentages.values()), 1.0, places=5)

    def test_extreme_one_hundred_percent(self):
        self.set_task_percentage("DEFEND", 1.0)
        self.assertAlmostEqual(self.percentages["DEFEND"], 1.0, places=5)
        for j in ["FORAGE", "DIG", "NURSE"]:
            self.assertAlmostEqual(self.percentages[j], 0.0, places=5)
        self.assertAlmostEqual(sum(self.percentages.values()), 1.0, places=5)

    def test_random_inputs_thousand_trials(self):
        random.seed(42)
        for _ in range(1000):
            job = random.choice(self.jobs)
            val = random.random()
            self.set_task_percentage(job, val)
            total = sum(self.percentages.values())
            self.assertAlmostEqual(total, 1.0, places=5)

    def test_zero_rounding_drift_for_all_population_sizes(self):
        # Test populations 0 to 50 ants across diverse percentage splits
        splits = [
            {"FORAGE": 0.25, "DIG": 0.25, "NURSE": 0.25, "DEFEND": 0.25},
            {"FORAGE": 0.33, "DIG": 0.33, "NURSE": 0.33, "DEFEND": 0.01},
            {"FORAGE": 0.1, "DIG": 0.2, "NURSE": 0.3, "DEFEND": 0.4},
            {"FORAGE": 0.05, "DIG": 0.05, "NURSE": 0.05, "DEFEND": 0.85},
            {"FORAGE": 0.0, "DIG": 0.0, "NURSE": 0.0, "DEFEND": 1.0},
        ]

        for s in splits:
            self.percentages = s.copy()
            for pop in range(0, 51):
                targets = self.recalculate_job_targets(pop)
                self.assertEqual(sum(targets.values()), pop, f"Failed at population {pop} with split {s}")

    def test_slider_locking(self):
        self.locked["DEFEND"] = True
        self.percentages["DEFEND"] = 0.4
        self.percentages["FORAGE"] = 0.2
        self.percentages["DIG"] = 0.2
        self.percentages["NURSE"] = 0.2

        # Change FORAGE - DEFEND must remain exactly 0.4
        self.set_task_percentage("FORAGE", 0.5)
        self.assertAlmostEqual(self.percentages["DEFEND"], 0.4, places=4)
        self.assertAlmostEqual(self.percentages["FORAGE"], 0.5, places=4)
        self.assertAlmostEqual(sum(self.percentages.values()), 1.0, places=5)

    def test_pinned_ant_apportionment(self):
        # When 2 ants are manually pinned to DIG out of 10 ants total:
        total_ants = 10
        pinned = {"FORAGE": 0, "DIG": 2, "NURSE": 0, "DEFEND": 0}
        total_pinned = sum(pinned.values())
        unpinned = max(0, total_ants - total_pinned)

        unpinned_targets = self.recalculate_job_targets(unpinned)
        final_targets = {j: unpinned_targets[j] + pinned[j] for j in self.jobs}

        self.assertEqual(sum(final_targets.values()), total_ants)
        self.assertGreaterEqual(final_targets["DIG"], 2)

if __name__ == "__main__":
    unittest.main()
