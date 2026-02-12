# 3volv3 Feature Plan — 10 Features Per Stage

## CELL STAGE FEATURES

### 1. Dynamic World Events
Random events every 2-3 minutes that break monotony:
- **Feeding Frenzy**: All competitors converge on a nutrient cluster
- **Parasite Swarm**: 10 parasites spawn in a tight cluster
- **Nutrient Bloom**: Double food spawns for 30 seconds in nearby chunks
- **Thermal Eruption**: Damage pulse + bonus spawns from thermal vents
File: `cell_stage_manager.gd` — new timer + event system

### 2. Chain Combo Scoring System
Collecting biomolecules of the same category in succession grants bonuses:
- 2x same = "Chain x2" (+50% fill)
- 3x same = "Chain x3" (+100% fill, visual burst)
- Breaking chain resets. UI shows current chain.
File: `player_cell.gd` `feed()` + new HUD element in `cell_stage_manager.gd`

### 3. Fleeing & Schooling Prey
Prey snakes now school in packs of 3-5 and have improved flee AI:
- Schools form naturally when prey are nearby each other
- When one flees, entire school flees in formation
- Rare "Alpha Prey" (golden) fights back weakly but drops big rewards
File: `prey_snake.gd` — add schooling + alpha variant

### 4. Titan Mini-Bosses
Rare mega-enemy variants with 2x health and unique attacks:
- **Titan Enemy Cell**: Fires 3-burst toxin volleys
- **Titan Leviathan**: Creates dual vacuum zones
- Spawn rate: ~1 per 5 minutes, announced with screen shake
File: `enemy_cell.gd`, `leviathan.gd` — add titan flag + behaviors

### 5. Adaptive Parasite Threat
Parasites that reproduce and drain energy:
- Each attached parasite drains 1 energy/sec
- Left attached 30+ sec → parasite splits into 2
- Visual: parasites grow redder the longer attached
File: `parasite_organism.gd` — reproduction timer + energy drain

### 6. Environmental Danger Zones
Visible hazard regions that add tactical depth:
- **Acid Pools**: Slow-moving green zones that damage on contact
- **Current Streams**: Fast-moving water flows that push the player
- **Static Fields**: Pulsing electrical zones that stun briefly
File: new `cell_hazard_zone.gd`, spawned by `world_chunk_manager.gd`

### 7. Membrane Health Visualization
Player membrane visually degrades as health drops:
- 100%: Smooth, glowing membrane
- 50%: Cracks appear, glow dims
- 25%: Large tears, membrane flickers, breathing pulse
- Healing visibly repairs cracks over 2 seconds
File: `player_cell.gd` `_draw()` — add crack overlay logic

### 8. Biomolecule Magnet Upgrade
After reaching sensory_level 2, nearby biomolecules drift toward the player:
- Gentle pull within 80 units (increases with sensory level)
- Visual: faint particle trail connecting to magnet target
- Stacks with jet stream for rapid collection
File: `biomolecule_particle.gd` — add magnet pull in `_physics_process`

### 9. Kill Streak Announcements
Dramatic floating text for combat milestones:
- "First Blood!" (1st kill)
- "Double Kill!" (2 kills in 5 sec)
- "Rampage!" (5 kills in 15 sec)
- "APEX PREDATOR!" (10 kills total)
- Text fades in with scaling animation
File: `cell_stage_manager.gd` — kill tracking + floating label system

### 10. Depth/Biome Transition Effects
Visual+audio feedback when crossing biome boundaries:
- Screen edge color tint matches new biome
- Brief biome name popup ("Entering: Deep Abyss")
- Audio crossfade between biome ambient tracks
- Particle burst at transition point
File: `cell_stage_manager.gd` — biome change detection + overlay

---

## SNAKE STAGE FEATURES

### 1. Segment Growth System
Worm grows longer as it feeds, adding visual progression:
- Every 5 nutrients collected = +1 body segment
- Max segments: 20 (up from starting ~8)
- Longer worm = more health but slower turning
- Visual: new segments pulse when added
File: `player_worm.gd` — growth tracking in `collect_nutrient()`

### 2. Tail Whip Attack
Secondary combat ability with crowd control:
- Press [F] to spin-slam tail in 360° arc
- Knockback + stun (1.5 sec) on hit enemies
- 8-second cooldown, costs 15 energy
- Visual: tail glows, sweeping arc trail
File: `player_worm.gd` — new `_tail_whip()` method + input binding

### 3. Venom Bite Upgrade
Bites now apply damage-over-time poison:
- Base: 2 damage/sec for 4 seconds
- Venomed enemies glow green and slow by 30%
- Upgradeable: more damage with evolution_level
- Visual: dripping green particles from bitten enemy
File: `player_worm.gd` bite handling, `white_blood_cell.gd` + `antibody_flyer.gd` — add venom state

### 4. Boss: Macrophage Queen (Brain Biome)
Epic boss encounter in the Brain hub:
- Massive spherical enemy (3x WBC size)
- Phases: Patrol → Alert → Summon Minions → Rage
- Summons 3 mini-WBCs every 20 seconds
- Defeating her opens the "exit" to ocean stage
- Drops unique visual upgrade
File: new `macrophage_queen.gd`, spawned in `snake_stage_manager.gd`

### 5. Danger Proximity Indicator
HUD element showing nearest threat direction:
- Red pulsing arrow at screen edge pointing toward closest enemy
- Intensity increases as enemy gets closer
- Audio: heartbeat speeds up with proximity
- Disappears when no enemies within 100m
File: new section in `vitals_hud.gd` or new `danger_indicator.gd`

### 6. Randomized Biome Placement
Different biome at each spoke tip every playthrough:
- Stomach always stays as center hub
- 5 remaining biomes randomly assigned to 5 spoke tips
- Brain always furthest from start position
- Each run feels different
File: `cave_generator.gd` — shuffle biome assignment array

### 7. Camouflage System
Context-sensitive stealth near walls:
- Hold [C] near a wall to blend in (uses 3 energy/sec)
- Player becomes semi-transparent, enemies ignore
- Breaking camo with a bite = critical hit (3x damage)
- Visual: player texture shifts to match wall color
File: `player_worm.gd` — camo state + wall proximity check

### 8. Fleeing Golden Nutrients
Rare high-value nutrients that run away:
- 5% of nutrient spawns are "golden" (3x value)
- They drift away from player when within 30m
- Catching one triggers celebration particles
- Creates exciting chase sequences
File: `nutrient_orb.gd` — add golden variant with flee AI

### 9. Dynamic Combat Music
Audio intensity scales with combat engagement:
- Calm: Ambient drone only
- Alert: Subtle percussion layer fades in (enemy within 80m)
- Combat: Full tension track (actively being attacked)
- Victory: Brief triumphant sting after killing enemy
- Smooth crossfading between states
File: `cave_audio.gd` — new combat intensity system

### 10. Death Consequence: Segment Loss
Dying has a cost beyond respawn:
- Each death loses 2 body segments (min 4 segments)
- Lost segments remain as collectible orbs at death location
- Creates risk/reward: go back to reclaim lost segments?
- "Souls-like" recovery mechanic
File: `player_worm.gd` — death handler + segment drop, `snake_stage_manager.gd` — respawn logic

---

## TESTING INSTRUCTIONS

### Files Modified/Created

**Cell Stage (all implemented):**
- `scripts/cell_stage/cell_stage_manager.gd` — World events, chain combo, kill streaks, floating text, biome transitions
- `scripts/cell_stage/player_cell.gd` — Membrane health viz, biomolecule magnet, category signal
- `scripts/cell_stage/parasite_organism.gd` — Adaptive parasites (energy drain, reproduction)
- `scripts/cell_stage/snake_prey.gd` — Schooling behavior, alpha prey variant
- `scripts/cell_stage/enemy_cell.gd` — Titan mini-bosses (burst attack, aura)
- `scripts/cell_stage/world_chunk_manager.gd` — Danger zone spawning, titan chance
- `scripts/cell_stage/danger_zone.gd` — NEW: Environmental hazard zones
- `scenes/danger_zone.tscn` — NEW: Hazard zone scene

**Snake Stage (all implemented):**
- `scripts/snake_stage/player_worm.gd` — Segment growth, tail whip, venom bite, camouflage, death segment loss, crit multiplier
- `scripts/snake_stage/land_nutrient.gd` — Golden nutrient variant (flee behavior)
- `scripts/snake_stage/snake_stage_manager.gd` — Danger proximity, combat music state, venom ticking, golden nutrient spawning, tail whip VFX, Macrophage Queen spawning
- `scripts/snake_stage/cave_generator.gd` — Randomized biome placement (Brain always last)
- `scripts/snake_stage/vitals_hud.gd` — Danger proximity indicator arrow
- `scripts/snake_stage/macrophage_queen.gd` — NEW: Boss encounter for Brain biome

---

### How to Test Each Feature

#### CELL STAGE

**1. Dynamic World Events**
- Play the cell stage for 2-3 minutes
- Watch for event banners appearing at the top of the screen (e.g., "Nutrient Bloom!", "Parasite Swarm!")
- Events last 30 seconds with a progress bar
- Events spawn extra food, parasites, or eruption particles depending on type

**2. Chain Combo System**
- Eat food particles and watch the top-center of the screen
- Eating the same biomolecule category consecutively shows "Chain x2", "Chain x3", etc.
- At 3+ chain, you get an energy bonus (watch for floating "+Energy" text)
- Eating a different category resets the chain
- Chain has an 8-second timeout

**3. Schooling Prey**
- Observe prey snake behavior — they should form loose groups and move together
- When you chase one prey, nearby prey should also flee (school panic)
- ~5% of prey are golden "Alpha Prey" — larger, golden color, more HP, drops better loot
- Alpha prey has a golden pulsing crown/glow effect

**4. Titan Mini-Bosses**
- ~10% of enemy cells spawn as Titans (larger, with a red pulsing aura and skull dot)
- Titans have 2x health and fire 3-burst toxin volleys when within range
- Titans drop 6-10 nutrients on death (vs 3-6 normal)
- Look for them especially after playing for a while as chunks load

**5. Adaptive Parasites**
- Let a parasite attach to you and watch your energy drain (1.5/sec)
- After ~25 seconds attached, it will reproduce (spawn a new parasite nearby)
- The attached parasite turns progressively redder over time

**6. Environmental Danger Zones**
- Travel to Deep Abyss biome — look for green circular acid pools (40% chance per chunk)
- Travel to Thermal Vent biome — look for electrical static fields (30% chance)
- Acid pools deal 8 DPS, static fields pulse 12 damage every 3 seconds
- Both have visible circular draw effects (green bubbles / electrical sparks)

**7. Membrane Health Visualization**
- Take damage until below 75% health
- Watch for jagged cracks appearing in your membrane outline
- Below 50%: more cracks, dimmer glow
- Below 25%: large tears, pulsing red warning ring

**8. Biomolecule Magnet**
- Requires sensory_level >= 2 (upgrade at workstation or via GameManager)
- Once active, nearby food particles (60-80 unit range) gently drift toward you
- Pull strength increases with sensory_level

**9. Kill Streak Announcements**
- Kill enemy cells in rapid succession
- 1st kill: "First Blood!" (yellow)
- 3rd kill: "Triple Kill!" (orange)
- 5th kill: "RAMPAGE!" (red)
- 10th kill: "UNSTOPPABLE!" (magenta)
- 15th kill: "APEX PREDATOR!" (cyan)
- Text appears center-screen and fades over 2.5 seconds

**10. Biome Transition Effects**
- Swim between different biome zones
- Watch the screen edges — they tint with the new biome's color
- Effect is subtle (alpha 0.12) and appears as a vignette overlay

---

#### SNAKE STAGE

**1. Segment Growth**
- Collect nutrients (glowing orbs) — every 5 nutrients grows a new body segment
- Max segments: 20 (starting from 10)
- Each new segment adds +5 max health
- Watch the worm get visibly longer as you feed

**2. Tail Whip Attack (F key)**
- Press F to perform a 360-degree tail whip
- Costs 15 energy, 8-second cooldown
- Damages (20 DMG) and knocks back all enemies within 5 units
- Orange expanding ring VFX appears at tail position
- Breaks camouflage if active

**3. Venom Bite**
- Right-click to bite enemies as usual
- Now bites automatically apply venom: 2 DPS for 4 seconds
- Venomed enemies get a green emission tint
- Venom ticks every 0.5 seconds (managed by stage manager)

**4. Macrophage Queen Boss (Brain Biome)**
- Navigate to the Brain biome hub (always at the furthest spoke)
- The Queen is a massive translucent sphere (3x WBC size) with a golden crown ring
- She has 300 HP and 4 phases: Patrol -> Alert -> Summon -> Rage
- She summons 3 mini-WBCs every 20 seconds (max 6 alive)
- At 30% health she enters Rage: faster, redder, rapid slams
- Ground slam does 25 DMG with knockback in an 8-unit radius
- Resists stun (halved duration)

**5. Danger Proximity Indicator**
- When enemies (WBCs or Flyers) are within 100 units, a red pulsing arrow appears at the screen edge
- Arrow points toward the nearest threat
- Arrow gets brighter and larger as the threat gets closer
- Disappears when no threats are within range

**6. Randomized Biome Placement**
- Start multiple new games and check the cave minimap
- The 5 spoke biomes (Heart, Intestinal, Lung, Bone Marrow, Liver) should be in different positions each run
- Brain is always at the last spoke (furthest from start)
- Stomach is always the center hub

**7. Camouflage System (C key)**
- Hold C to activate camouflage (drains 3 energy/sec)
- Player becomes semi-transparent (alpha drops to 0.2)
- Noise level drops to near-zero — enemies should have trouble detecting you
- Release C to deactivate (fades back to full visibility)
- Taking damage breaks camo instantly
- Biting while camo'd deals 3x critical damage
- Cannot camo while sprinting

**8. Golden Nutrients**
- ~5% of nutrient spawns are golden (bright gold color, brighter glow)
- Golden nutrients give 30 energy + 10 heal (vs 10/3 normal)
- They flee from you when within 30 units — chase them!
- They spin faster than normal nutrients

**9. Dynamic Combat Music**
- State machine: CALM -> ALERT -> COMBAT -> VICTORY
- ALERT triggers when enemies are within 80 units
- COMBAT triggers when enemies are within 15 units
- VICTORY plays briefly after combat ends (5-second cooldown)
- Audio hooks are in place but require AudioManager methods (set_combat_intensity, play_victory_sting)
- You may hear the state transitions in console output

**10. Death Segment Loss**
- When you die, you lose 2 body segments (minimum 4 segments remain)
- Each lost segment reduces max_health by 5
- You respawn at 50% health/energy
- Lost segment positions are stored (for future recovery orb implementation)

---

### Controls Reference (Snake Stage)
| Key | Action |
|-----|--------|
| WASD | Move |
| Shift | Sprint (drains energy) |
| Space | Creep (stealth mode) |
| RMB | Bite (with venom) |
| LMB | Tractor beam (pull nutrients) |
| E | Stun burst (AoE stun) |
| F | Tail whip (360 knockback) |
| C | Camouflage (hold, drains energy) |
| ESC | Pause menu |

---

## CREATURE EDITOR OVERHAUL

### Changes Summary
Complete redesign of the creature editor screen with unified experience for both initial customization and evolution upgrades.

### Files Modified/Created

- `scripts/autoload/game_manager.gd` — Added new color targets (interior_color, cilia_color, organelle_tint), eye_angle, eye_spacing. Added update_mutation_scale(). Removed mouth_style from default customization.
- `scripts/cell_stage/color_picker_ui.gd` — Full rewrite. Removed mouth selector. 9 eye styles. 6 color targets. Eye spacing/angle controls via mouse wheel.
- `scripts/cell_stage/creature_preview.gd` — Full rewrite. No mouth. Tightened organelles. Forward/back direction indicator. New eye styles. Mutation scaling.
- `scripts/cell_stage/evolution_ui.gd` — Full rewrite. Unified CARD_SELECT + CUSTOMIZE modes. Mutation sizing via mouse wheel. Organic background. Cards at bottom during customize.
- `scripts/cell_stage/player_cell.gd` — Uses cilia_color, interior_color, organelle_tint. 4 new eye styles (lashed, fierce, dot, star). Eye angle/spacing from customization. Mouth drawing removed. Tightened organelles. Mutation scaling applied.

### How to Test the Creature Editor

**Initial Customization (after tutorial)**
- Start a new game and complete the tutorial showcase
- The creature editor should open automatically
- Title reads "CUSTOMIZE YOUR ORGANISM"
- Background is an organic dark gradient with subtle vein-like lines (not plain black)

**Color Targets (6 total)**
- Click the color target buttons in the right panel
- Membrane: affects the outline/border color of the creature
- Iris: affects eye color
- Glow: affects the outer glow halo
- Interior: affects the body fill color (was derived from membrane before)
- Cilia: affects the tiny hair-like appendages around the membrane
- Organelles: tints the internal organelle dots
- Each target shows a color swatch dot on its button

**Eye Styles (9 total)**
- Click eye style buttons in the right panel (arranged 5x2 grid)
- Round: simple circle eyes with big pupil
- Anime: classic anime eyes with iris, pupil, highlights
- Compound: faceted insect-like eyes
- Googly: oversized wobbly eyes
- Slit: reptilian slit pupils
- Lashed: feminine with eyelashes on top
- Fierce: angular aggressive with heavy brow ridge
- Dot: minimalist solid dot eyes
- Star: star-shaped iris decorations

**Eye Placement Controls**
- Below the eye style buttons, find "EYE SPACING" with a slider track
- Scroll mouse wheel over the spacing area to adjust distance between eyes (3.0 to 9.0)
- Below that, "EYE ROTATION" with an angle indicator
- Scroll mouse wheel over the angle area to rotate eye pair position on the creature

**Forward/Back Indicator**
- The creature preview shows a "FRONT" arrow pointing right and "BACK" label on the left
- This helps orient where mutations and eyes will appear

**Mutation Placement & Sizing**
- When evolution triggers (fill a vial), cards appear at the center for selection
- After picking a card, the editor opens with the creature centered and the card strip at the bottom
- Drag mutations from the "OWNED MUTATIONS" sidebar (bottom-left) to snap points on the creature
- Hover over a snap point that has a mutation placed on it — you'll see "Scale: 100%" and "[scroll to resize]"
- Use mouse wheel while hovering a placed mutation's snap point to resize it (40% to 250%)
- The mutation visual on the creature updates in real-time

**Save/Done Button**
- Click "DONE" (initial customize) or "SAVE" (evolution editor) to close and return to gameplay
- All changes persist in GameManager.creature_customization

**Mouth Removal**
- There is no mouth selector — mouths have been entirely removed
- The creature's expression is conveyed entirely through the eyes
- The expressive mood system (happy, scared, angry, etc.) still works through eye changes

### Known Limitations
- Existing save data with `mouth_style` in creature_customization will be ignored gracefully
- LIVER biome (index 5) has no boss encounter (by design — 5 bosses for 5 non-stomach biomes excluding LIVER)

### Resolved (Previously Listed as Limitations)
- ~~AudioManager combat music~~ — `set_combat_intensity()`, `play_victory_sting()`, `play_boss_intro_sting()` all implemented
- ~~Golden nutrient celebration particles~~ — GPUParticles3D burst on golden collection
- ~~Recovery orbs~~ — 4 glowing orbs spawn at death location, restore 15% HP/energy each, 60s lifetime
- ~~Macrophage Queen visual upgrade~~ — Drops "Psionic Crown" tier-3 antenna mutation (+15 HP, +10 energy)
- ~~Biome transition popup~~ — Two-line "Entering: [Biome Name]" popup with colored pill background
- ~~Dead `_draw_mouth()` code~~ — Removed from player_cell.gd along with all `_mouth_open` references
