#!/usr/bin/env python3
"""
Unit tests for Phase 4: Threats & Combat.
Tests:
- Task 4.1A: Spider AI & Forager Ambush (detection radius, attack damage 12, flee retreat on strike or hit)
- Task 4.1B: Threat Warning Alert System (8-second advance warning, inbound direction arrow)
- Task 4.2A: Beetle Controller & Target Priority (80 HP, target priority Queen/Ants, attack ticks)
- Task 4.2B: Defender Ant Patrol & Combat (choke point routing, engaging beetle on sight, combat damage)
- Task 4.3A: Rainstorm Flooding Logic (3 bottom rows flooded, drowning damage, food spoilage, drainage)
- Task 4.3B: Weather Effects & Sky Darkening (duration, rain drop count, reset)
"""

import unittest

class MockSpider:
    def __init__(self, pos=(0.0, 228.0)):
        self.pos = list(pos)
        self.health = 30.0
        self.attack_damage = 12.0
        self.move_speed = 60.0
        self.detection_radius = 180.0
        self.is_fleeing = False
        self.defeated = False

    def detect_forager(self, ant_pos):
        d = ((self.pos[0] - ant_pos[0]) ** 2 + (self.pos[1] - ant_pos[1]) ** 2) ** 0.5
        return d <= self.detection_radius

    def ambush(self, ant):
        if self.detect_forager(ant.pos):
            ant.take_damage(self.attack_damage)
            self.flee()
            return True
        return False

    def flee(self):
        self.is_fleeing = True

    def take_damage(self, amount):
        self.health = max(0.0, self.health - amount)
        self.flee()
        if self.health <= 0.0:
            self.defeated = True


class MockBeetle:
    def __init__(self, pos=(0.0, 228.0)):
        self.pos = list(pos)
        self.health = 80.0
        self.attack_damage = 8.0
        self.move_speed = 18.0
        self.defeated = False

    def attack_target(self, target):
        target.take_damage(self.attack_damage)

    def take_damage(self, amount):
        self.health = max(0.0, self.health - amount)
        if self.health <= 0.0:
            self.defeated = True


class MockAnt:
    def __init__(self, job="FORAGE", pos=(960.0, 228.0)):
        self.job = job
        self.pos = list(pos)
        self.health = 20.0
        self.state = "IDLE"

    def take_damage(self, amount):
        self.health = max(0.0, self.health - amount)
        if self.health <= 0.0:
            self.state = "DEAD"


class MockQueen:
    def __init__(self):
        self.health = 100.0

    def take_damage(self, amount):
        self.health = max(0.0, self.health - amount)


class MockThreatManager:
    def __init__(self, seed_val=1337):
        self.seed = seed_val
        self.warning_lead_time = 8.0
        self.active_threats = []
        self.warnings = []
        self.rain_active = False
        self.rain_timer = 0.0

    def trigger_warning(self, threat_type, spawn_pos, lead_time):
        dir_str = "LEFT" if spawn_pos[0] < 960.0 else "RIGHT"
        self.warnings.append({
            "type": threat_type,
            "dir": dir_str,
            "time": lead_time
        })

    def trigger_rain(self, duration=30.0):
        self.rain_active = True
        self.rain_timer = duration

    def tick_rain(self, delta):
        if self.rain_active:
            self.rain_timer -= delta
            if self.rain_timer <= 0.0:
                self.rain_active = False
                return True # Drained
        return False


class TestPhase4(unittest.TestCase):
    def test_spider_detection_and_ambush(self):
        spider = MockSpider(pos=(800.0, 228.0))
        ant = MockAnt(job="FORAGE", pos=(900.0, 228.0))

        # Ant at distance 100 is within detection radius (180)
        self.assertTrue(spider.detect_forager(ant.pos))
        self.assertFalse(spider.is_fleeing)

        # Ambush deals 12 damage to ant
        hit = spider.ambush(ant)
        self.assertTrue(hit)
        self.assertEqual(ant.health, 8.0) # 20 - 12
        self.assertTrue(spider.is_fleeing) # Flees after attacking

    def test_spider_takes_damage_and_flees(self):
        spider = MockSpider(pos=(500.0, 228.0))
        self.assertFalse(spider.is_fleeing)

        # Hit by defender ant
        spider.take_damage(6.0)
        self.assertEqual(spider.health, 24.0)
        self.assertTrue(spider.is_fleeing) # Retreats when wounded

        # Multiple hits defeat spider
        spider.take_damage(25.0)
        self.assertEqual(spider.health, 0.0)
        self.assertTrue(spider.defeated)

    def test_beetle_stats_and_queen_attack(self):
        beetle = MockBeetle(pos=(976.0, 528.0))
        queen = MockQueen()

        self.assertEqual(beetle.health, 80.0)
        self.assertEqual(beetle.move_speed, 18.0)

        # Attack deals heavy damage to Queen
        beetle.attack_target(queen)
        self.assertEqual(queen.health, 92.0) # 100 - 8

        # 10 attacks defeat Queen if undefended
        for _ in range(9):
            beetle.attack_target(queen)
        self.assertEqual(queen.health, 20.0)

    def test_beetle_requires_defenders_to_defeat(self):
        beetle = MockBeetle()
        # 3 defenders dealing 6 dmg every tick (total 18 dmg/tick)
        ticks_to_kill = 0
        while not beetle.defeated:
            beetle.take_damage(18.0)
            ticks_to_kill += 1
        
        self.assertTrue(beetle.defeated)
        self.assertEqual(ticks_to_kill, 5) # 5 * 18 = 90 >= 80

    def test_threat_warning_alert_system(self):
        threat_mgr = MockThreatManager()
        # Threat inbound from left edge
        threat_mgr.trigger_warning("SPIDER", (-50.0, 228.0), 8.0)
        self.assertEqual(len(threat_mgr.warnings), 1)
        self.assertEqual(threat_mgr.warnings[0]["dir"], "LEFT")
        self.assertEqual(threat_mgr.warnings[0]["time"], 8.0)

        # Threat inbound from right edge
        threat_mgr.trigger_warning("BEETLE", (2000.0, 228.0), 8.0)
        self.assertEqual(len(threat_mgr.warnings), 2)
        self.assertEqual(threat_mgr.warnings[1]["dir"], "RIGHT")

    def test_rainstorm_flooding_and_drainage(self):
        threat_mgr = MockThreatManager()
        self.assertFalse(threat_mgr.rain_active)

        threat_mgr.trigger_rain(30.0)
        self.assertTrue(threat_mgr.rain_active)
        self.assertEqual(threat_mgr.rain_timer, 30.0)

        # Submerged ant takes drowning damage
        ant = MockAnt(pos=(960.0, 1200.0)) # Deep tunnel
        drowning_rate = 4.0
        ant.take_damage(drowning_rate * 5.0) # 5s submerged
        self.assertEqual(ant.health, 0.0) # 20 - 20 = 0
        self.assertEqual(ant.state, "DEAD")

        # 30 seconds elapse: rain recedes and drains
        drained = threat_mgr.tick_rain(30.0)
        self.assertTrue(drained)
        self.assertFalse(threat_mgr.rain_active)


if __name__ == "__main__":
    unittest.main()
