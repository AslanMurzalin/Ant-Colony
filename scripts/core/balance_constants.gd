## Balance constants for Ant Colony — single source of truth for all tunable numbers.
## Edit this file to adjust difficulty without touching game logic scripts.

class_name BalanceConstants
extends RefCounted

# ── Queen ────────────────────────────────────────────────────────────────────
const QUEEN_MAX_HEALTH:          float = 100.0
const QUEEN_HUNGER_INTERVAL:     float = 15.0   ## seconds between hunger ticks
const QUEEN_STARVATION_DAMAGE:   float = 2.0    ## HP/second while starving
const QUEEN_EGG_INTERVAL:        float = 20.0   ## seconds between egg-laying attempts

# ── Worker Ants ──────────────────────────────────────────────────────────────
const ANT_WALK_SPEED:            float = 45.0   ## pixels/second
const ANT_DIG_DURATION:          float = 2.5    ## seconds per soil tile
const ANT_ATTACK_DAMAGE:         float = 6.0    ## damage per hit vs threats
const ANT_ATTACK_COOLDOWN:       float = 0.8    ## seconds between attacks
const ANT_MAX_POPULATION:        int   = 50

# ── Foraging ─────────────────────────────────────────────────────────────────
const FOOD_BURN_RATE_PER_ANT:    float = 0.0008 ## food consumed per ant per second
const FOOD_RESPAWN_INTERVAL:     float = 30.0   ## seconds between food node respawns
const FOOD_NEAR_UNITS:           int   = 6      ## units per close food node
const FOOD_FAR_UNITS:            int   = 14     ## units per far rich deposit

# ── Nursery ───────────────────────────────────────────────────────────────────
const EGG_INCUBATION_SECONDS:    float = 25.0
const LARVA_FOOD_REQUIRED:       int   = 2

# ── Spider ───────────────────────────────────────────────────────────────────
const SPIDER_HP:                 float = 30.0
const SPIDER_SPEED:              float = 60.0
const SPIDER_DETECT_RADIUS:      float = 180.0
const SPIDER_DAMAGE:             float = 12.0   ## one-shot kill vs forager (forager has 10 HP)

# ── Beetle ────────────────────────────────────────────────────────────────────
const BEETLE_HP:                 float = 80.0
const BEETLE_SPEED:              float = 18.0
const BEETLE_DAMAGE:             float = 8.0    ## damage per hit vs targets

# ── Rain Event ────────────────────────────────────────────────────────────────
const RAIN_FLOOD_ROWS:           int   = 3
const RAIN_DURATION_SECONDS:     float = 30.0
const RAIN_DROWN_DAMAGE:         float = 5.0    ## HP/second while submerged

# ── Day Progression ───────────────────────────────────────────────────────────
const DAY_DURATION_SECONDS:      float = 150.0  ## real-time seconds per game day
