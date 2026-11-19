class_name Enums
extends RefCounted

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
