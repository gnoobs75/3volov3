# RTS Colony Stage Feature Pass - Full Genre Coverage

## Overview
Comprehensive feature pass on the RTS Colony Wars stage to bring it to genre-standard quality across three pillars: UI/UX polish, unit depth, and strategic depth. Visual style evolves the existing organic/bioluminescent aesthetic into a SC2-Zerg-meets-alien-biology command interface.

## Section 1: UI/UX Overhaul - Bioluminescent Command Interface

### Visual Language
- **Membrane borders**: Wobbly sine-wave edges on panels (animated, ~2px amplitude)
- **Bioluminescent highlights**: Cyan/green glow on interactive elements, red glow on threats
- **Organic fill**: Resource bars use gradient fills that look like fluid levels in biological tubes
- **Pulse feedback**: Actions cause brief brightness pulse on the triggering UI element

### Top Bar (evolved)
- Resource panel with animated membrane borders, pulsing when income changes
- **Threat Alert System**: Red pulsing membrane-vein icon when enemies approach base. Click snaps camera to threat. Stacked alerts with distance.
- Supply bar visualized as filling biological vessel

### Bottom-Left: Selection Panel (new `rts_selection_panel.gd`)
- **Single unit**: Portrait area (colored organism shape), HP bar (organic gradient), stats (ATK/ARM/SPD), current order icon, veterancy stars
- **Multi-unit**: Wire-frame grid of selected unit icons (4x4 grid), click to subselect, shift-click to deselect
- **Building**: Production queue as organic pods, build progress as growing membrane, rally point indicator

### Bottom-Center: Control Groups Bar
- Visual strip showing groups 1-9 with unit count badges
- Color-coded by composition (workers=green, mixed=blue, military=red)
- Pulsing border on groups under attack
- Click to select, double-click to center camera

### Bottom-Right: Command Card (evolved)
- Context-sensitive 3x4 grid (like SC2)
- Workers: Move, Stop, Hold, Attack, Patrol, Build, Gather, Repair
- Military: Move, Stop, Hold, Attack, Patrol, Formation, Ability
- Buildings: Set Rally, Cancel Queue, Upgrade, production buttons
- Hotkey letter on each button, tooltip on hover with cost/description
- Bioluminescent glow on hover, pulse when available

### Minimap (evolved)
- Camera viewport rectangle overlay
- Terrain coloring (resources=yellow, obstacles=dark)
- Alt+click ping system (expanding organic ring)
- Attack pings fade after 5s (bug fix)

## Section 2: Tech Tree & Upgrades

### Structure
Evolution Chamber is the research hub. New `rts_tech_tree.gd` tracks unlocked upgrades per faction.

### 3 Tiers (require Evolution Chamber level)
- **Tier 1** (base Evo Chamber): Basic stat upgrades
- **Tier 2** (1 upgrade + 200B/50G to evolve building): Advanced upgrades
- **Tier 3** (3 upgrades + 400B/100G to evolve building): Elite upgrades

### Research Upgrades (at Evolution Chamber, one at a time)

| Tier | Name | Cost (B/G) | Time | Effect |
|------|------|-----------|------|--------|
| 1 | Hardened Membranes | 100/25 | 20s | All units +2 armor |
| 1 | Metabolic Boost | 100/25 | 20s | All units +15% speed |
| 1 | Sharpened Cilia | 100/25 | 20s | All units +3 damage |
| 2 | Regenerative Tissue | 200/50 | 30s | All units regen 1 HP/s out of combat |
| 2 | Extended Pseudopods | 200/50 | 30s | Melee +20 range, ranged +50 range |
| 2 | Rapid Mitosis | 200/50 | 30s | Unit production 25% faster |
| 3 | Berserker Enzymes | 350/100 | 45s | Units below 30% HP deal 2x damage |
| 3 | Hive Mind | 350/100 | 45s | Units within 80u get +2 armor (stack to +6) |
| 3 | Apex Predator | 350/100 | 45s | Veterancy XP gain doubled |

### Building Upgrades (at the building itself)
- Spawning Pool -> Hatchery (T2, +10 supply, +1 queue slot, 250B/50G)
- Membrane Tower -> Spine Tower (T2, +50% dmg, +50 range, 150B/30G)
- Nutrient Processor -> Refinery (T2, +50% gather rate nearby, 200B/40G)

### AI Tech Usage
AI director gets upgrade logic per phase: OPENING skips, EXPANSION gets T1, AGGRESSION gets T2, ENDGAME rushes T3. Difficulty scales priority.

## Section 3: Unit Abilities & Veterancy

### Active Abilities (hotkey: V, one per military unit)

| Unit | Ability | Cooldown | Effect |
|------|---------|----------|--------|
| Warrior | Charge | 12s | Dash 150u, 2.5x first-hit damage, 0.5s stun |
| Defender | Fortify | 20s | Root 5s, +8 armor, taunt 120u radius |
| Scout | Emit Spores | 15s | Reveal fog 400u for 8s |
| Spitter | Acid Volley | 18s | 3 projectiles in spread, 75% damage each |
| Worker | Burst Gather | 30s | 3x gather speed for 5s |

### Veterancy (XP from kills + assists within 150u)
- **Star 1** (3 kills): +10% HP, +10% damage
- **Star 2** (8 kills): +20% HP, +20% damage, +5% speed
- **Star 3** (15 kills): +30% HP, +30% damage, +10% speed, -25% ability cooldown

Visual: Gold stars above unit, glow intensifies with rank.

## Section 4: Strategic Depth

### Map Events (every 90-180s, random)

| Event | Duration | Effect |
|-------|----------|--------|
| Nutrient Bloom | 30s | Rich resource cluster spawns, all factions alerted |
| Toxic Tide | 20s | Expanding wave from edge, 5 DPS to caught units, 5s warning |
| Evolutionary Surge | 15s | All units +30% attack speed globally |
| Petri Quake | 10s | All buildings take 50 damage |
| Migration | 25s | NPC herd moves across map, blocks paths, killable for resources |

Announcements: center-screen text flash + organic border animation + minimap ping at location.

### Enhanced NPCs
- **Neutral camps**: 3-5 NPCs guard bonus resource nodes
- **Titan corpses**: Workers can harvest for gene fragment bonus
- **Roaming predators**: Large patrolling NPCs, attack any faction, worth high XP

### Formations (F key cycles, 3+ military selected)
- **Spread** (default): Natural spacing
- **Line**: Perpendicular to movement, ranged behind melee
- **Box**: Defensive square, defenders on edges, ranged center
- **Wedge**: V-shape, fastest at tip

Visualized as faint connecting lines while moving.

## Section 5: Additional UI Features

### Build Placement Validation
- Ghost turns red on overlap with buildings/resources/edge
- Tower range circle during placement
- Shift = free placement (default snaps to grid)

### Production Tab (F1)
- Fullscreen overlay of all buildings + queues
- Click building to center camera
- Queue/cancel from panel
- Shows production capacity vs utilization

### Threat Alerts (`rts_threat_detector.gd`)
- Scans for enemies within 500u of player buildings every 1.5s
- Red membrane-vein pulse on HUD edge toward threat
- Click to snap camera
- Audio: low rumble on new detection
- Stack up to 3, auto-dismiss after 10s

### Shift-Queue Commands
- Hold Shift to queue commands (move->attack->move waypoints)
- Queued waypoints shown as faint lines + numbered dots
- Workers: Shift+click multiple buildings to queue construction

### Attack Priority
- Attack-move priority: threats attacking them > lowest HP > nearest
- Ranged auto-kite within min-range (spitters already do this)

## Section 6: Audio & Feedback

### New Synth Audio
- Upgrade complete: rising crystalline chime
- Tech tier unlocked: deep harmonic + bright overtone
- Threat alert: low organic rumble with rising urgency
- Per-ability sounds: charge=whoosh, fortify=thud, spores=airy, acid=sizzle, burst gather=squelch
- Veterancy star: ascending triple-note
- Map event warning: distant rumble 5s before + per-event sound
- Formation change: organic click
- Queued command: soft acknowledgment ping

### Visual Feedback
- Damage numbers: floating values on hit (0.6s fade-up)
- Ability cooldown: radial sweep on command card button
- Upgrade progress: animated DNA helix on Evo Chamber
- Unit state icons: shield=fortified, sword=charging, eye=scouting, wrench=building

## Files Affected

### New Scripts
- `rts_tech_tree.gd` - Tech tree state + upgrade definitions
- `rts_threat_detector.gd` - Enemy proximity scanning + alerts
- `rts_selection_panel.gd` - Selection grid + control group bar + building info
- `rts_map_events.gd` - Map event spawning + announcements
- `rts_formation.gd` - Formation calculation + visualization
- `rts_damage_numbers.gd` - Floating damage number pool
- `rts_production_tab.gd` - F1 production overview

### Heavy Modifications
- `rts_hud.gd` - Evolved top bar, command card, organic styling
- `rts_unit.gd` - Abilities, veterancy, formations, shift-queue, attack priority
- `rts_building.gd` - Upgrades, evolved production UI hooks
- `ai_director.gd` - Tech tree decisions, ability usage
- `rts_input_handler.gd` - Shift-queue, formation hotkey, ability hotkey, F1
- `command_system.gd` - Queued commands, formation commands
- `rts_minimap.gd` - Viewport rect, ping system, ping fade fix
- `unit_stats.gd` - Ability definitions, upgrade modifiers
- `building_stats.gd` - Upgrade definitions, tier requirements
- `petri_dish_map.gd` - Neutral camps, roaming predators, event zones
- `rts_stage_manager.gd` - Wire up new subsystems
- `synth_sounds.gd` - ~10 new generators
- `audio_manager.gd` - New buffer/play functions
- `selection_manager.gd` - Sub-selection from grid clicks
- `rts_tutorial_overlay.gd` - New steps for abilities/upgrades if needed
