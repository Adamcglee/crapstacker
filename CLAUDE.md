# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

This is a **Godot 4.4.1** project. There is no build step — open the project in the Godot editor and press **F5** to run from the main scene (`scenes/Main.tscn`) or **F6** to run the currently open scene.

Mouse clicks are mapped to touch events in the editor via `input_devices/pointing/emulate_touch_from_mouse=true` in `project.godot`, so the drag/rotate mechanic works with mouse during development.

There are no tests, linters, or external tooling. All code is GDScript 4.

## Architecture

### Game Flow

```
Scene loads → MENU phase
  [Upgrades button + "Load Up!" visible]
  ↓ player presses "Load Up!"
LOADING phase — items spawn one at a time, player stacks them
  [shop hidden during active stacking]
  ↓ all items placed → "Get Moving!" appears
TRAVEL phase — truck drives, progress bar and "On Truck: X%" visible
  ↓ truck arrives
RESULTS phase — earnings tallied, "Play Again" always shown
  ["Next Level" only shown on 100% delivery]
```

"Play Again" reloads the scene at the same level. "Next Level" increments `GameManager.level` then reloads. Both buttons route back to MENU phase on reload.

### Autoloads (persistent across `reload_current_scene`)

| Autoload | Role |
|---|---|
| `GameManager` | Central state machine (`GamePhase` enum: MENU/LOADING/TRAVEL/RESULTS), persistent `money` and `level`, item counts, signals |
| `ItemDatabase` | 10 item definitions (`ItemDef` inner class) with value, mass, size, color |
| `UpgradeManager` | Upgrade levels and effect accessors; persists so purchases carry across reloads |

`GameManager.money` **never resets** — it accumulates across every delivery. `GameManager.level` persists and is read by `Main._ready()` to resume at the correct difficulty. `GameManager.start_level()` now routes to MENU phase (not LOADING) — call `GameManager.begin_loading()` to actually start spawning items.

### Signal Flow

Everything goes through `GameManager` signals — no system calls another directly:
`phase_changed`, `money_changed`, `items_count_changed`, `all_items_loaded`, `item_fell_off`

Money is awarded only at delivery: `Main._on_arrived()` counts PLACED items, calls `GameManager.add_earnings(total)`.

### Item Lifecycle

`HouseholdItem` (RigidBody2D) moves through four states:

| State | Physics | Collision layer |
|---|---|---|
| `STAGED` | Frozen static, gravity off | 0 (ghost) |
| `HELD` | Frozen kinematic, follows finger | 4 |
| `PLACED` | Full RigidBody, gravity on | 2 |
| `FALLEN` | Frozen static, red tint | 0 (ghost) |

Rotation is free during Phase 1 so items can topple realistically. `_begin_travel()` locks rotation on all PLACED items so they stay flat during the drive.

Each item gets a `PhysicsMaterial` (friction=0.8, rough=true, bounce=0) so item-to-item contacts are inelastic and don't fight the solver. Solver iterations are raised to 16 via `PhysicsServer2D.space_set_param` in `_build_world()` to prevent items compressing/squishing into each other under load.

Layer 1 = truck bed surfaces. Layer 2 = placed items. Layer 4 = held items.

### Placement Input (Multitouch)

`HouseholdItem._input()` handles all touch:
- First touch on a STAGED item → HELD; finger offset preserved
- Second touch while HELD → horizontal swipe rotates (`delta_x * 0.018` rad)
- Release first touch → PLACED; full physics

### Spawner Queue

`ItemSpawner.spawn_next()` pops from `_queue`, spawns the current item at `_stage_pos` (STAGED, interactive) and a dimmed preview at `_preview_pos`. After each placement waits 0.7 s then calls `spawn_next()` again.

### Screen Layout (portrait, world coordinates)

Viewport is **720 × 1280** portrait.

| Element | World Y |
|---|---|
| HUD bar | screen-space (CanvasLayer) |
| Staging slots (items to place) | `VP_H × 0.18 ≈ 230` |
| Truck bed floor | `TRUCK_Y = 920` |
| Physics ground / fall zone | `TRUCK_Y + 66 ≈ 986` |

Items appear at the top and fall down onto the truck at the bottom. The truck has `scale.x = -1` so the cab faces right for Phase 2 travel.

### Truck Construction

`Truck.gd` builds itself in `_ready()` using instance `var` dimensions (not constants) so upgrade values can be injected before the node enters the tree:

```gdscript
truck = TruckScript.new()
truck.bed_width    = 308.0 + UpgradeManager.bed_width_bonus()
truck.bed_depth    = 8.0   + UpgradeManager.rail_height_bonus()
truck.bed_friction = UpgradeManager.floor_friction()
add_child(truck)   # _ready() fires here with upgraded values
```

The truck is rebuilt immediately when an upgrade is purchased (`_rebuild_truck()` in Main). The truck origin = top surface of the bed floor.

### Phase 2 Travel

`Main._physics_process()` drives travel:
- Truck ramps from 0 → `TRAVEL_MAX_SPEED × level_speed_scale()` at `TRAVEL_ACCEL` px/s²
- A spring force (`CARRY_SPRING = 3.0`) pulls each PLACED item's `linear_velocity.x` toward truck speed
- Bump amplitude = base × `level_bump_scale()` × `UpgradeManager.bump_multiplier()`
- Camera lerp runs in `_process`; truck movement in `_physics_process`

### Difficulty Scaling

`GameManager` exposes two level-based multipliers:
- `level_speed_scale()` = `1.0 + (level-1) * 0.10` (+10% max speed per level)
- `level_bump_scale()` = `1.0 + (level-1) * 0.15` (+15% bump amplitude per level)
- Item count = `5 + (level-1) * 2`

### Upgrade System

`UpgradeManager` (autoload) holds levels that survive scene reloads. The shop (`UpgradeMenu.gd`) is only accessible in MENU phase (before loading) and RESULTS phase. Purchasing an upgrade immediately rebuilds the truck via `UpgradeManager.upgraded` signal → `Main._on_upgrade_purchased()`.

| Upgrade | Effect per level | Max | Costs (×4 exponential) |
|---|---|---|---|
| Bed Extension | +60 px `bed_width` | 3 | $300 / $1,200 / $4,800 |
| Raised Rails | +16 px `bed_depth` | 3 | $200 / $800 / $3,200 |
| Suspension | −25% bump amplitude | 3 | $350 / $1,400 / $5,600 |
| Grip Tape | +4.0 floor friction | 2 | $250 / $1,000 |

### HUD Elements

All on a `CanvasLayer` node named "HUD":
- Top bar: Earnings, Items count, Level/Phase label
- "Upgrades" button: bottom-right corner, visible in MENU and RESULTS only
- "Load Up!" / "Get Moving!" / "Next Level" / "Play Again": centered, shown per phase
- "On Truck: X%" label: shown during TRAVEL, color-coded green→yellow→red
- Delivery progress bar + "Destination" label: bottom of screen, shown during TRAVEL only

## Key Files

- `scripts/Main.gd` — world/HUD construction, phase wiring, Phase 2 travel loop, fall detection, truck rebuild
- `scripts/GameManager.gd` — state machine, persistent money/level, signals (autoload)
- `scripts/ItemDatabase.gd` — 10 item definitions (autoload)
- `scripts/UpgradeManager.gd` — upgrade state, costs, effect accessors (autoload)
- `scripts/HouseholdItem.gd` — physics item, multitouch drag+rotate, four-state machine
- `scripts/Truck.gd` — procedural truck, runtime-configurable dimensions, bed physics
- `scripts/ItemSpawner.gd` — item queue, current/preview spawning
- `scripts/UpgradeMenu.gd` — upgrade shop overlay UI
