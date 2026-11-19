# Ant Colony — Game Design Document (GD.md)

**Project Name:** Ant Colony  
**Team:** Umarov Ruslan, Murzalin Aslan  
**Genre:** 2D Side-View Colony Management / Light Strategy  
**Platform:** PC (Browser or Desktop), Mouse Only  
**Target Session Length:** 20–30 minutes per run (10 in-game days)  
**Engine:** Godot Engine 4.x  

---

## 1. High Concept & Pillars

### 1.1 High Concept
*Ant Colony* is a readable, compact colony-management game. The player cannot command individual ants directly. Instead, they guide a growing nest through indirect control: four task sliders (**Forage**, **Dig**, **Nurse**, **Defend**) distribute the worker pool. 

The goal is simple and tense: **keep the queen alive for ten days** while the colony expands and the threats above and underground escalate.

> **One-sentence Pitch:** Manage a living ant nest in cross-section, balancing hunger, growth, and danger by deciding where your workers should be, before the beetle arrives.

### 1.2 Core Pillars
1. **Indirect Control:** The player sets overarching priorities via sliders; the ants execute them autonomously. Player mistakes stem from flawed priorities and timing, not clumsy micromanagement.
2. **Readable at a Glance:** Every ant’s current assignment is visible via distinct color bands, icons, and carried cargo. No critical information is hidden behind nested menus.
3. **Meaningful Dilemmas:** Every minute demands trade-offs: more food vs. higher safety, rapid excavation vs. dedicating nurses to growing larvae.
4. **Pleasant to Watch:** The nest feels organic, alive, and charming even during quiet periods.

---

## 2. Story and Setting

### 2.1 Setting
A single slice of garden soil in late summer, presented as a 2D side-view cross-section:
- **Surface & Sky (Top):** Grass, sky, and randomly spawned surface food sources (crumbs, seeds, dead insects, fruit), along with surface predators.
- **Subsurface (Below):** Soil layers, unmineable rock formations, and the expanding ant nest dug by workers.

### 2.2 Narrative
The colony's former nest was destroyed by a lawnmower. A young queen and a modest starter crew of workers settle in a fresh patch of garden soil. They have exactly ten days before the arrival of autumn rains and freezing frost. If the queen survives until the first frost (end of Day 10), the colony will be strong enough to overwinter, securing the line.

The story unfolds through brief daily banners ("Day 3: The beetles have noticed the nest") and a concluding run summary card reflecting the colony's final size, health, and stockpiles.

### 2.3 Tone
Warm, slightly humorous, and gently tense. Nature is depicted without malice or sanitization: it is indifferent and dangerous.

---

## 3. Characters & Entities

| Character / Entity | Role | Key Mechanics & Notes |
| :--- | :--- | :--- |
| **Queen** | Vital Objective / Lose Condition | Resides in the immovable Royal Chamber. Has Health and Food meters. Consumes food to lay eggs; starves and takes damage if food runs dry. Visible breathing and worry animations. |
| **Worker Ant** | Primary Unit | Autonomous worker governed by a finite state machine. Role designated by sliders: Brown (Forager), Orange (Digger), Green (Nurse), Red (Defender). |
| **Egg / Larva** | Colony Growth Stage | Nurtured inside the Nursery chamber. Requires nurse attention and food to develop through egg → larva → adult worker. |
| **Beetle** | Heavy Enemy | Slow, armored ground intruder. Attacks via surface or excavated tunnels. Requires multiple defenders to bring down. Targets food stores and the queen. |
| **Spider** | Fast Enemy | Quick, opportunistic surface predator. Ambushes foragers on the grass. Countered by defenders or timely retreats. |
| **Rain Event** | Environmental Hazard | Floods the deepest tunnels and chambers. Submerged ants take damage; unprotected food caches rot/dissolve. Digging drainage paths or relocating chambers mitigates damage. |

*Note: The player has no physical avatar; the player acts as the colony mind.*

---

## 4. Core Gameplay Loop

```
  ┌────────────────────────────────────────────────────────┐
  │ 1. Observe: Check HUD (Food, Ants, Queen HP, Warning)  │
  └───────────────────────────┬────────────────────────────┘
                              │
  ┌───────────────────────────▼────────────────────────────┐
  │ 2. Decide: Adjust 4 task sliders & place excavation    │
  └───────────────────────────┬────────────────────────────┘
                              │
  ┌───────────────────────────▼────────────────────────────┐
  │ 3. Execute: Ants complete current actions & switch     │
  └───────────────────────────┬────────────────────────────┘
                              │
  ┌───────────────────────────▼────────────────────────────┐
  │ 4. Event: Predator arrival, rain storm, or rich food   │
  └───────────────────────────┬────────────────────────────┘
                              │
  ┌───────────────────────────▼────────────────────────────┐
  │ 5. Resolve: Combat, damage, losses, and day cycle wrap │
  └───────────────────────────┬────────────────────────────┘
                              │
  ┌───────────────────────────▼────────────────────────────┐
  │ 6. Day End: Summary screen; difficulty scales up       │
  └────────────────────────────────────────────────────────┘
```

- **Run Length:** Exactly 10 in-game days.
- **Day Duration:** ~2 to 3 real-world minutes per day (~20–30 minutes full session).
- **Intermission:** Daily report showing ants born, food gathered, losses, and day rating.

---

## 5. Detailed Mechanics

### 5.1 Task Allocation (Slider System)
The total pool of available worker ants is split across four distinct assignments:
- **Forage (Brown):** Move to surface food nodes, collect portions, and transport them to the nearest Food Store or Royal Chamber.
- **Dig (Orange):** Navigate to designated digging cells in the soil grid, chip away soil, and excavate tunnels or specialized chambers.
- **Nurse (Green):** Retrieve stored food, deliver nutrition to the Queen and nursery larvae, and tend to incubating eggs.
- **Defend (Red):** Patrol the nest entrance and tunnel choke points, engaging beetles and spiders in combat.

> **Hysteresis / Inertia Rule:** Task sliders always sum to 100%. When a slider is adjusted, ants **do not switch immediately**; each ant finishes its active chore before re-routing. This intentional inertia prevents instantaneous cheese and rewards forward planning.

### 5.2 Colony Growth & Population
- **Queen Feeding:** Queen consumes 1 food unit periodically. When sustained, an egg-laying countdown triggers.
- **Nursery Cycle:** Eggs hatch into Larvae. Larvae require Nurse deliveries of food. Once their growth meter fills, they emerge as full adult Workers.
- **Population Cap:** Capped at 50 ants for crisp tactical readability and stable 60 FPS performance.
- **Starvation:** If food hits zero and the Queen starves, her health decreases over time. If Queen HP reaches 0, the game triggers Game Over.

### 5.3 Excavation & Chambers
- **Soil Grid:** A 2D discrete cell grid. Cells are either Diggable Soil, Air/Tunnel, or Unbreakable Rock.
- **Player Dig Marking:** Click on soil cells to mark them for excavation.
- **Chamber Types:**
  1. **Royal Chamber:** Built-in default at run start. Houses the Queen.
  2. **Nursery Chamber:** Accelerates egg incubation and larva maturation.
  3. **Food Store Chamber:** Increases food storage capacity and delays food spoilage.
- **Topography Risk:**
  - *Deep chambers:* Safe from surface spiders, but vulnerable to rain flooding.
  - *Shallow chambers:* Vulnerable to surface breaches, but immune to water accumulation.

### 5.4 Threats & Invasions
- **Beetle:** Approaches from surface boundaries or tunnel breaches; high health pool, heavy damage against ants and queen.
- **Spider:** Fast surface ambusher that snatches foraging ants.
- **Rainstorm:** Bottom-most tunnels and chambers fill with water for a temporary duration. Ants caught without air drown; food stores submerged are destroyed.
- **Warning Indicators:** Screen-edge alert icons appear 5–10 seconds before an enemy attack or storm strikes.
- **Targeting Priority for Enemies:**
  1. Foraging Ants on the surface
  2. Nest Entrance
  3. Food Storage
  4. Queen

### 5.5 Food Economy & Spoilage
- Food nodes appear on the surface at varying distances.
- **Near Nodes:** Lower yield, completely safe from long spider ambushes.
- **Far Nodes:** Rich food deposits (e.g., fruit, dead insect), but long transit times leave foragers exposed to predators.
- Food is consumed by:
  1. Queen (lays eggs)
  2. Larvae (metamorphose into workers)
  3. General worker upkeep (slow base burn rate)

---

## 6. Game Rules & Win/Lose Conditions

1. **Victory:** Queen remains alive at the conclusion of Day 10.
2. **Defeat:** Queen health drops to 0 at any time.
3. **Allocation Sum:** The four task sliders always add up to 100%.
4. **Action Persistence:** Ants finish their current step before adopting a newly assigned job.
5. **Terrain Restrictions:** Only dirt/soil tiles can be excavated; bedrock/rock tiles are indestructible.
6. **Hard Cap:** Maximum of 50 simultaneous living worker ants.
7. **Deterministic Seeds:** Daily events, surface food drops, and enemy waves are seed-driven to allow reproducible runs and competitive comparisons.
8. **End Rating Categories:**
   - *Survived (Fledgling):* Queen alive, <15 ants, <10 food.
   - *Healthy Colony:* Queen alive, 15–35 ants, healthy food reserves.
   - *Thriving Colony:* Queen alive, 36–50 ants, full food stores, minimal casualties.

---

## 7. Difficulty & Day-by-Day Progression

| Day Range | Event & Difficulty Profile |
| :--- | :--- |
| **Day 1–2** | **Tutorial & Foundations:** Plentiful close food, no heavy enemies, occasional solitary weak spider. Introduces sliders and basic food retrieval. |
| **Day 3–4** | **First Armor Threat:** First beetle assault. Close surface food depletes; foragers must travel farther out. Digging chamber needs grow. |
| **Day 5–6** | **Environmental Pressure:** Rain event floods deep layers. Spider frequency doubles. Player must manage drainage and food safety. |
| **Day 7–8** | **Pincer Attacks:** Beetles attack in pairs. Surface food is sparse and far from the entrance. Nurse and defender priorities compete heavily. |
| **Day 9–10** | **Final Frost Onset:** Relentless predator waves, temperature drops, combined beetle-spider raids. All resources must be marshaled to defend the Queen until the 10th day expires. |

---

## 8. Visual Style & Art Direction

- **Perspective:** 2D side-view cross-section with fixed camera and vertical panning bounds.
- **Aesthetic:** Crisp pixel/vector aesthetic with warm earth tones (soil, roots, stone), vibrant green surface grass, and high-contrast ant accents.
- **Ant Visual Feedback:**
  - *Forager:* Brown band, carried crumb sprite.
  - *Digger:* Orange band, small pick/jaw dirt dust.
  - *Nurse:* Green band, tending particle / droplet icon.
  - *Defender:* Red band, aggressive mandible posture.
- **Combat & States:** White flash on hit, floating status indicators, Queen distress animations.

---

## 9. User Interface (UI) Layout

- **Top Bar HUD:**
  - Day Counter (`Day X / 10`)
  - Day Clock / Sun-Moon progress bar
  - Stored Food counter (`Food: X / Cap`)
  - Total Worker count (`Ants: X / 50`)
  - Queen Health bar (`Queen HP: [========]`)
- **Bottom-Left Control Deck:**
  - 4 Sliders: Forage %, Dig %, Nurse %, Defend % with numerical lock indicators and active headcounts.
- **Bottom-Right Architecture Deck:**
  - Tool selectors: Dig / Cancel Dig / Build Nursery / Build Food Store.
- **Overlay & HUD Prompts:**
  - Threat warning arrows indicating direction and type of inbound threat.
  - Simulation Speed Controls: Pause (Space), 1x Speed, 2x Speed.
  - End-of-Day Summary dialog overlay.
