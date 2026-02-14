extends Control
## Xenobiology Database: unified encyclopedia of ALL creatures from both stages.
## Accessible from the main menu via button or X hotkey.
## Procedural _draw() UI with alien science desk / blueprint / scanner aesthetic.
## Hybrid discovery: all creatures visible, details locked until discovered in-game.

signal database_closed

enum StageTab { CELL, PARASITE }
enum SubCategory { ALL, PREY, PREDATOR, HAZARD, BOSS, UTILITY, AMBIENT, ENEMIES }

const HEADER_H: float = 70.0
const TAB_H: float = 45.0
const SUBTAB_H: float = 42.0
const SIDEBAR_W: float = 380.0
const ENTRY_H: float = 90.0
const ENTRY_GAP: float = 5.0
const DETAIL_PAD: float = 30.0
const FOOTER_H: float = 44.0
const ICON_R: float = 22.0

# Fish tank ecosystem
const TANK_BOUNDS: Rect2 = Rect2(-640, -320, 1280, 640)
const TANK_POP_PREDATORS: int = 3
const TANK_POP_PREY: int = 5
const TANK_POP_MISC: int = 3
const TANK_POP_BOSSES: int = 3
const TANK_POP_FOOD: int = 10
const TANK_RESPAWN_DELAY: float = 2.0
const TANK_FOOD_RESPAWN_DELAY: float = 4.0
const TANK_CREATURE_SCALE: float = 1.8  # Scale up so creatures are visible in tank

# Tank creature roster: which creatures to spawn by role
const TANK_PREDATORS: Array = ["enemy_cell", "dart_predator", "siren_cell"]
const TANK_PREY: Array = ["snake_prey"]
const TANK_MISC: Array = ["ink_bomber", "electric_eel", "splitter_cell"]
const TANK_BOSSES: Array = ["oculus_titan", "juggernaut", "basilisk"]

# Font sizes (doubled for readability on large screens)
const FONT_NAME: int = 48
const FONT_CATEGORY: int = 26
const FONT_STAT_LABEL: int = 22
const FONT_STAT_VALUE: int = 32
const FONT_BODY: int = 24
const FONT_SECTION: int = 26
const FONT_VOICE_BTN: int = 22

# Scene paths for cell stage creatures (SubViewport live preview)
const CELL_SCENE_PATHS: Dictionary = {
	"food_particle": "res://scenes/food_particle.tscn",
	"snake_prey": "res://scenes/snake_prey.tscn",
	"enemy_cell": "res://scenes/enemy_cell.tscn",
	"dart_predator": "res://scenes/dart_predator.tscn",
	"siren_cell": "res://scenes/siren_cell.tscn",
	"splitter_cell": "res://scenes/splitter_cell.tscn",
	"electric_eel": "res://scenes/electric_eel.tscn",
	"ink_bomber": "res://scenes/ink_bomber.tscn",
	"leviathan": "res://scenes/leviathan.tscn",
	"parasite_organism": "res://scenes/parasite_organism.tscn",
	"danger_zone": "res://scenes/danger_zone.tscn",
	"repeller": "res://scenes/repeller_organism.tscn",
	"kin_organism": "res://scenes/kin_organism.tscn",
	"oculus_titan": "res://scenes/oculus_titan.tscn",
	"juggernaut": "res://scenes/juggernaut.tscn",
	"basilisk": "res://scenes/basilisk.tscn",
}

const BOSS_CREATURES: Array = ["oculus_titan", "juggernaut", "basilisk",
	"macrophage_queen", "cardiac_colossus", "gut_warden", "alveolar_titan", "marrow_sentinel"]

# Unified creature data — merged from both stages
const ALL_CREATURES: Array = [
	# ==================== CELL STAGE ====================
	{"id": "food_particle", "stage": "CELL", "name": "Biomolecule", "category": "PREY",
	 "hp": 0, "damage": 0, "speed": 0.0,
	 "traits": ["Passive", "Collectible"],
	 "abilities": ["Absorbed by organic vacuum", "Provides nutrients"],
	 "habits": "Drifts passively through the cellular soup. The primary food source for all organisms.",
	 "icon_color": [0.3, 0.7, 1.0],
	 "description": "Free-floating biomolecular clusters — amino acids, lipids, and nucleotides. The building blocks of evolution."},

	{"id": "snake_prey", "stage": "CELL", "name": "Flagellate Prey", "category": "PREY",
	 "hp": 10, "damage": 0, "speed": 3.5,
	 "traits": ["Evasive", "Fast"],
	 "abilities": ["Schooling behavior", "Sprint when threatened", "Drops nutrients on death"],
	 "habits": "Schools together in loose groups. Scatters explosively when a predator approaches.",
	 "icon_color": [0.2, 0.8, 0.4],
	 "description": "Small flagellated organisms that travel in schools. Quick and evasive, but nutritious when caught."},

	{"id": "enemy_cell", "stage": "CELL", "name": "Predator Cell", "category": "PREDATOR",
	 "hp": 25, "damage": 10, "speed": 3.0,
	 "traits": ["Territorial", "Persistent"],
	 "abilities": ["Chase player on detection", "Contact damage", "Drops nutrients on death"],
	 "habits": "Patrols territory and chases anything smaller. Relentless but not particularly fast.",
	 "icon_color": [0.8, 0.3, 0.2],
	 "description": "Standard predatory cell with a voracious appetite. The most common threat in the primordial soup."},

	{"id": "dart_predator", "stage": "CELL", "name": "Dart Predator", "category": "PREDATOR",
	 "hp": 20, "damage": 15, "speed": 6.0,
	 "traits": ["Fast", "Hit-and-run", "Glass cannon"],
	 "abilities": ["High-speed dart attack", "Retreat after strike", "Very fast movement"],
	 "habits": "Lurks at distance, then rockets forward in a lethal dart. Retreats to recharge after each strike.",
	 "icon_color": [1.0, 0.4, 0.2],
	 "description": "Needle-shaped predator built for speed. Its dart attack is devastating but leaves it vulnerable during cooldown."},

	{"id": "siren_cell", "stage": "CELL", "name": "Siren Cell", "category": "PREDATOR",
	 "hp": 30, "damage": 18, "speed": 4.0,
	 "traits": ["Mimic", "Ambush", "Deceptive"],
	 "abilities": ["Disguises as golden food", "Reveals and lunges when close", "Contact damage"],
	 "habits": "Shapeshifts to resemble a valuable food particle. Waits motionless until prey is lured close enough to strike.",
	 "icon_color": [1.0, 0.85, 0.2],
	 "description": "A devious mimic that disguises itself as a golden biomolecule. By the time you notice the deception, it's already lunging."},

	{"id": "splitter_cell", "stage": "CELL", "name": "Splitter Cell", "category": "PREDATOR",
	 "hp": 20, "damage": 8, "speed": 3.5,
	 "traits": ["Resilient", "Self-replicating"],
	 "abilities": ["Splits into 2 on death", "Up to 3 generations", "Each gen smaller and faster"],
	 "habits": "Appears ordinary until killed. Its death triggers binary fission, creating two smaller but faster copies.",
	 "icon_color": [0.6, 0.9, 0.3],
	 "description": "A cell that weaponizes its own death. Each kill spawns two smaller copies, quickly overwhelming careless attackers."},

	{"id": "electric_eel", "stage": "CELL", "name": "Electric Eel", "category": "PREDATOR",
	 "hp": 22, "damage": 12, "speed": 4.5,
	 "traits": ["Electrogenic", "Chain attack"],
	 "abilities": ["Charges bioelectric field", "Chain lightning to 3 targets", "Stuns hit organisms", "Death discharge"],
	 "habits": "Patrols in sinusoidal waves. Charges up crackling electricity before unleashing chain lightning across nearby organisms.",
	 "icon_color": [0.3, 0.7, 1.0],
	 "description": "Serpentine predator with bioelectric organelles. Its chain lightning arcs between multiple targets, making groups especially vulnerable."},

	{"id": "ink_bomber", "stage": "CELL", "name": "Ink Bomber", "category": "PREDATOR",
	 "hp": 18, "damage": 5, "speed": 2.5,
	 "traits": ["Defensive", "Area denial", "Evasive"],
	 "abilities": ["Deploys ink clouds (50% slow)", "Puffs up when alarmed", "Panic ink on hit", "Death ink burst"],
	 "habits": "Drifts serenely until threatened, then puffs up and releases thick ink clouds before fleeing.",
	 "icon_color": [0.15, 0.1, 0.3],
	 "description": "Bulbous organism that expels viscous ink clouds. The ink drastically slows anything caught within it."},

	{"id": "leviathan", "stage": "CELL", "name": "Leviathan", "category": "PREDATOR",
	 "hp": 80, "damage": 20, "speed": 2.0,
	 "traits": ["Massive", "Vacuum attack", "Slow"],
	 "abilities": ["Vacuum pull attack", "Massive contact damage", "Very high HP", "Drops rare loot"],
	 "habits": "The apex predator of the cell stage. Slowly roams, creating devastating vacuum currents that pull everything toward its maw.",
	 "icon_color": [0.5, 0.2, 0.4],
	 "description": "Enormous, terrifying predator. Its vacuum attack sucks in everything nearby. Best avoided until you've evolved significantly."},

	{"id": "parasite_organism", "stage": "CELL", "name": "Parasite", "category": "HAZARD",
	 "hp": 15, "damage": 5, "speed": 5.0,
	 "traits": ["Parasitic", "Adaptive", "Draining"],
	 "abilities": ["Latches onto host", "Drains energy over time", "Adapts to host mutations"],
	 "habits": "Seeks larger organisms to parasitize. Once attached, it drains resources and is difficult to remove.",
	 "icon_color": [0.7, 0.2, 0.5],
	 "description": "Adaptive parasite that latches onto hosts and siphons their energy. Evolves countermeasures against host defenses."},

	{"id": "danger_zone", "stage": "CELL", "name": "Danger Zone", "category": "HAZARD",
	 "hp": 0, "damage": 8, "speed": 0.0,
	 "traits": ["Static", "Area damage", "Periodic"],
	 "abilities": ["Pulsing damage field", "Visual warning glow", "Cannot be destroyed"],
	 "habits": "A fixed hazardous region of concentrated toxins. Pulses with damaging energy at regular intervals.",
	 "icon_color": [0.9, 0.3, 0.1],
	 "description": "Toxic environmental hazard zone. The pulsing red glow warns of periodic bursts of cellular damage."},

	{"id": "repeller", "stage": "CELL", "name": "Anemone", "category": "UTILITY",
	 "hp": 0, "damage": 0, "speed": 0.0,
	 "traits": ["Stationary", "Repulsive field", "Parasite cleanse"],
	 "abilities": ["Repels nearby organisms", "Strips parasites on contact", "Cannot be destroyed"],
	 "habits": "A stationary organism that projects a powerful repulsive field, pushing away anything that approaches.",
	 "icon_color": [0.4, 0.8, 0.7],
	 "description": "Sessile anemone-like organism with a repulsive force field. Useful for shaking off parasites and deflecting enemies."},

	{"id": "kin_organism", "stage": "CELL", "name": "Kin Cell", "category": "UTILITY",
	 "hp": 20, "damage": 5, "speed": 3.0,
	 "traits": ["Allied", "Supportive", "Social"],
	 "abilities": ["Follows player loosely", "Attacks nearby enemies", "Slows Juggernaut boss"],
	 "habits": "Friendly organisms of the same species. Loosely follow the player and harass nearby threats.",
	 "icon_color": [0.3, 0.9, 0.7],
	 "description": "Friendly kin organisms that recognize you as their own. They'll follow you and help attack threats."},

	{"id": "oculus_titan", "stage": "CELL", "name": "Oculus Titan", "category": "BOSS",
	 "hp": 200, "damage": 10, "speed": 1.5,
	 "traits": ["Multi-eyed", "Beam-vulnerable", "Massive"],
	 "abilities": ["Covered in beamable eyes", "Invincible to normal damage", "Thrashes when 50% eyes removed", "Each eye drops nutrients"],
	 "habits": "A colossal all-seeing organism. Its many eyes are its weakness — each can be ripped off with the organic vacuum.",
	 "icon_color": [0.9, 0.3, 0.3],
	 "description": "Towering boss covered in watchful eyes. Immune to direct attacks — use organic vacuum to peel off each eye. Spawns after 3rd evolution."},

	{"id": "juggernaut", "stage": "CELL", "name": "Juggernaut", "category": "BOSS",
	 "hp": 300, "damage": 25, "speed": 4.0,
	 "traits": ["Armored", "Unstoppable", "Charge attack"],
	 "abilities": ["8 armor plates", "Immune to direct damage", "Relentless charge", "Armor stripped by anemones", "Slowed by kin"],
	 "habits": "An armored juggernaut that charges relentlessly. Its armor can only be stripped by kiting it through anemone fields.",
	 "icon_color": [0.6, 0.4, 0.2],
	 "description": "Heavily armored berserker. Lure it through anemones to strip its plates, and call kin allies for help. Spawns after 6th evolution."},

	{"id": "basilisk", "stage": "CELL", "name": "Basilisk", "category": "BOSS",
	 "hp": 150, "damage": 15, "speed": 1.0,
	 "traits": ["Armored front", "Rear vulnerable", "Ranged"],
	 "abilities": ["Front shield deflects damage", "Fires toxic spine bursts", "Vulnerable only from behind", "Slow turner"],
	 "habits": "A calculating sniper with an impenetrable front shield. Circles slowly, firing spine volleys. Attack from behind.",
	 "icon_color": [0.5, 0.2, 0.6],
	 "description": "Slow but deadly ranged boss. Its front is completely armored — circle behind it and strike with jets or spikes. Spawns after 9th evolution."},

	# ==================== PARASITE STAGE ====================
	{"id": "red_blood_cell", "stage": "PARASITE", "name": "Red Blood Cell", "category": "AMBIENT",
	 "hp": 0, "damage": 0, "speed": 1.5,
	 "traits": ["Passive", "Harmless"],
	 "abilities": ["Drift in streams"],
	 "habits": "Disc-shaped cells that drift passively through the bloodstream. Oxygen carriers, completely non-threatening.",
	 "icon_color": [0.8, 0.15, 0.1],
	 "description": "Disc-shaped cells that drift passively through the bloodstream. Harmless oxygen carriers."},

	{"id": "platelet", "stage": "PARASITE", "name": "Platelet", "category": "AMBIENT",
	 "hp": 0, "damage": 0, "speed": 0.5,
	 "traits": ["Passive", "Clustering"],
	 "abilities": ["Float slowly", "Cluster together"],
	 "habits": "Tiny irregular cell fragments that float aimlessly. Involved in clotting, but pose no threat.",
	 "icon_color": [0.9, 0.85, 0.6],
	 "description": "Tiny irregular cell fragments. Involved in clotting, but pose no threat."},

	{"id": "microbiome_bacteria", "stage": "PARASITE", "name": "Microbiome Bacteria", "category": "AMBIENT",
	 "hp": 0, "damage": 0, "speed": 1.0,
	 "traits": ["Passive", "Commensal"],
	 "abilities": ["Wiggle randomly"],
	 "habits": "Rod-shaped commensal bacteria that inhabit the gut. Part of the host's microbiome, non-threatening.",
	 "icon_color": [0.4, 0.7, 0.3],
	 "description": "Rod-shaped commensal bacteria. Part of the gut flora, non-threatening."},

	{"id": "cilia_plankton", "stage": "PARASITE", "name": "Cilia Plankton", "category": "AMBIENT",
	 "hp": 0, "damage": 0, "speed": 0.8,
	 "traits": ["Passive", "Delicate"],
	 "abilities": ["Pulse upward", "Feathery tendrils"],
	 "habits": "Delicate feathery organisms that pulse gently through the alveolar spaces of the lungs.",
	 "icon_color": [0.6, 0.8, 0.85],
	 "description": "Delicate feathery organisms that float through the alveolar spaces."},

	{"id": "prey_bug", "stage": "PARASITE", "name": "Prey Bug", "category": "PREY",
	 "hp": 10, "damage": 0, "speed": 3.0,
	 "traits": ["Evasive", "Nutritious"],
	 "abilities": ["Flee from player", "Drop nutrients on death"],
	 "habits": "Small scurrying organisms that flee on sight. Easy prey once cornered.",
	 "icon_color": [0.2, 0.8, 0.4],
	 "description": "Small scurrying organisms. Easy prey that flee when approached."},

	{"id": "land_nutrient", "stage": "PARASITE", "name": "Nutrient Orb", "category": "PREY",
	 "hp": 0, "damage": 0, "speed": 0.0,
	 "traits": ["Passive", "Healing"],
	 "abilities": ["Collectible", "Heals on pickup"],
	 "habits": "Glowing biomolecule clusters that rest on cave floors. Restore health and energy on contact.",
	 "icon_color": [0.4, 0.7, 0.9],
	 "description": "Glowing biomolecule clusters. Collect to restore health and energy."},

	{"id": "golden_nutrient", "stage": "PARASITE", "name": "Golden Nutrient", "category": "PREY",
	 "hp": 0, "damage": 0, "speed": 2.0,
	 "traits": ["Rare", "Evasive", "High value"],
	 "abilities": ["3x value", "Flees from player"],
	 "habits": "Rare shimmering orbs worth triple the normal value. Tries to escape when approached.",
	 "icon_color": [1.0, 0.85, 0.2],
	 "description": "Rare shimmering orb worth triple. Tries to escape when approached."},

	{"id": "white_blood_cell", "stage": "PARASITE", "name": "White Blood Cell", "category": "ENEMIES",
	 "hp": 40, "damage": 8, "speed": 4.0,
	 "traits": ["Immune defender", "Patrol"],
	 "abilities": ["Patrol", "Chase on detection", "Melee attack"],
	 "habits": "The host's primary immune patrol. Wanders caves and attacks any foreign organism on sight.",
	 "icon_color": [0.9, 0.9, 0.85],
	 "description": "The host's primary immune defender. Patrols caves and attacks foreign organisms on sight."},

	{"id": "antibody_flyer", "stage": "PARASITE", "name": "Antibody Flyer", "category": "ENEMIES",
	 "hp": 25, "damage": 12, "speed": 6.0,
	 "traits": ["Airborne", "Aggressive"],
	 "abilities": ["Airborne", "Dive attacks", "Hard to reach"],
	 "habits": "Y-shaped flying antibodies that circle overhead. Dive-bomb with razor-sharp protein tips.",
	 "icon_color": [0.7, 0.5, 0.9],
	 "description": "Y-shaped flying antibodies. Circle overhead and dive-bomb with sharp protein tips."},

	{"id": "phagocyte", "stage": "PARASITE", "name": "Phagocyte", "category": "ENEMIES",
	 "hp": 60, "damage": 5, "speed": 2.5,
	 "traits": ["Tank", "Engulfing"],
	 "abilities": ["Engulf attack", "Damage over time", "High HP"],
	 "habits": "Massive blob-like cell that slowly pursues prey and attempts to engulf them whole.",
	 "icon_color": [0.5, 0.7, 0.3],
	 "description": "Massive blob-like cell that engulfs prey. Hard to kill, locks you in place during digestion."},

	{"id": "killer_t_cell", "stage": "PARASITE", "name": "Killer T-Cell", "category": "ENEMIES",
	 "hp": 25, "damage": 18, "speed": 8.0,
	 "traits": ["Stealth", "Assassin"],
	 "abilities": ["Stealth", "Fast lunge", "High damage", "Retreat"],
	 "habits": "Semi-transparent assassin. Stalks silently, then lunges from the shadows with devastating force.",
	 "icon_color": [0.6, 0.3, 0.7],
	 "description": "Semi-transparent assassin. Stalks in stealth, then lunges with devastating force."},

	{"id": "mast_cell", "stage": "PARASITE", "name": "Mast Cell", "category": "ENEMIES",
	 "hp": 30, "damage": 10, "speed": 3.0,
	 "traits": ["Ranged", "Tactical"],
	 "abilities": ["Ranged histamine shots", "Keeps distance", "Retreats when close"],
	 "habits": "Round granular cell that fires histamine projectiles from range. Retreats if you get close.",
	 "icon_color": [0.9, 0.5, 0.2],
	 "description": "Round granular cell that fires histamine projectiles from range. Retreats if you close in."},

	{"id": "macrophage_queen", "stage": "PARASITE", "name": "Macrophage Queen", "category": "BOSS",
	 "hp": 200, "damage": 20, "speed": 5.0,
	 "traits": ["Apex immune", "Summoner"],
	 "abilities": ["Ground slam", "Summon minions", "Enrage at 25% HP", "Pseudopod strikes"],
	 "habits": "The apex predator of the immune system. Rules the Brain hub with devastating slams and endless minion waves.",
	 "icon_color": [0.9, 0.2, 0.8],
	 "description": "The apex predator of the immune system. Rules the Brain hub with devastating slams and endless minion waves."},

	{"id": "cardiac_colossus", "stage": "PARASITE", "name": "Cardiac Colossus", "category": "BOSS",
	 "hp": 250, "damage": 15, "speed": 6.0,
	 "traits": ["Rhythmic", "Area denial"],
	 "abilities": ["Rhythmic pulse AoE", "Blood wave knockback", "Summon RBC swarms", "Rage mode"],
	 "habits": "Massive pulsing heart creature. Its rhythmic shockwaves push you back relentlessly.",
	 "icon_color": [0.7, 0.15, 0.12],
	 "description": "Massive pulsing heart creature. Its rhythmic shockwaves push you back relentlessly."},

	{"id": "gut_warden", "stage": "PARASITE", "name": "Gut Warden", "category": "BOSS",
	 "hp": 280, "damage": 12, "speed": 5.5,
	 "traits": ["Corrosive", "Territorial"],
	 "abilities": ["Acid pools", "Tentacle vines", "Acid spray cone", "Rage mode"],
	 "habits": "Tentacle-covered guardian that spews acid and drops corrosive pools. Watch where you step.",
	 "icon_color": [0.45, 0.3, 0.2],
	 "description": "Tentacle-covered guardian that spews acid and drops corrosive pools. Watch where you step."},

	{"id": "alveolar_titan", "stage": "PARASITE", "name": "Alveolar Titan", "category": "BOSS",
	 "hp": 220, "damage": 10, "speed": 7.0,
	 "traits": ["Wind control", "Inflatable"],
	 "abilities": ["Wind gust knockback", "Oxygen bubble traps", "Inflate/deflate", "Rage mode"],
	 "habits": "Spongy inflatable creature. Powerful wind gusts send you flying, bubble traps slow your escape.",
	 "icon_color": [0.75, 0.65, 0.7],
	 "description": "Spongy inflatable creature. Powerful wind gusts send you flying, and bubble traps slow your escape."},

	{"id": "marrow_sentinel", "stage": "PARASITE", "name": "Marrow Sentinel", "category": "BOSS",
	 "hp": 300, "damage": 20, "speed": 5.0,
	 "traits": ["Armored", "Regenerative"],
	 "abilities": ["Bone spike eruption", "Calcium shield", "Summon T-cells", "Rage mode"],
	 "habits": "Armored bone construct. The hardest boss — temporarily invulnerable behind its calcium shield.",
	 "icon_color": [0.85, 0.8, 0.65],
	 "description": "Armored bone construct. The hardest boss — temporarily invulnerable behind its calcium shield."},
]

# Categories available per stage tab
const CELL_CATEGORIES: Array = ["ALL", "PREY", "PREDATOR", "HAZARD", "BOSS", "UTILITY"]
const PARASITE_CATEGORIES: Array = ["ALL", "AMBIENT", "PREY", "ENEMIES", "BOSS"]

# State
var _active: bool = false
var _time: float = 0.0
var _scroll_offset: float = 0.0
var _max_scroll: float = 0.0
var _selected_idx: int = -1
var _stage_tab: int = 0  # 0 = CELL, 1 = PARASITE
var _sub_category: String = "ALL"
var _hover_entry: int = -1
var _hover_stage_tab: int = -1
var _hover_sub_tab: int = -1
var _hover_close: bool = false
var _hover_reveal: bool = false
var _filtered_entries: Array = []  # indices into ALL_CREATURES
var _glyph_columns: Array = []
var _scan_pulse: float = 0.0
var _hover_voice_type: int = -1
var _voice_btn_rects: Array = []
var _voice_playing_timer: float = 0.0
var _voice_playing_type: int = -1
const VOICE_TYPES: Array = ["idle", "alert", "attack", "hurt", "death"]

# Fish tank ecosystem
var _tank_viewport: SubViewport = null
var _tank_camera: Camera2D = null
var _tank_creatures: Array = []  # All creature nodes in tank
var _tank_food: Array = []  # Food particle nodes
var _tank_initialized: bool = false
var _tank_selected_node: Node2D = null  # Currently followed creature in tank
var _tank_camera_target: Vector2 = Vector2.ZERO
var _tank_highlight_time: float = 0.0  # For pulsing selection highlight
var _scanner_time: float = 0.0

# Discovery VFX
var _last_seen_discoveries: Dictionary = {}
var _discovery_vfx_timers: Dictionary = {}  # creature_id -> time_remaining

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_glyph_columns = UIConstants.create_glyph_columns(8)
	# Initialize last-seen state
	for creature in ALL_CREATURES:
		_last_seen_discoveries[creature.id] = GameManager.is_creature_discovered(creature.id)

func toggle() -> void:
	_active = not _active
	visible = _active
	set_process(_active)
	if _active:
		_check_new_discoveries()
		_rebuild_filtered()
		_selected_idx = -1
		_scroll_offset = 0.0
		# Initialize tank on first open if cell tab
		if _stage_tab == 0 and not _tank_initialized:
			_initialize_tank()
		queue_redraw()
	else:
		database_closed.emit()

func _check_new_discoveries() -> void:
	for creature in ALL_CREATURES:
		var cid: String = creature.id
		var is_now: bool = GameManager.is_creature_discovered(cid)
		var was_before: bool = _last_seen_discoveries.get(cid, false)
		if is_now and not was_before:
			_discovery_vfx_timers[cid] = 3.0
		_last_seen_discoveries[cid] = is_now

func _rebuild_filtered() -> void:
	_filtered_entries.clear()
	var stage_key: String = "CELL" if _stage_tab == 0 else "PARASITE"
	for i in range(ALL_CREATURES.size()):
		var entry: Dictionary = ALL_CREATURES[i]
		if entry.stage != stage_key:
			continue
		if _sub_category != "ALL":
			# Map ENEMIES -> ENEMIES, BOSS -> BOSS (exact match on entry category)
			if entry.category != _sub_category:
				continue
		_filtered_entries.append(i)
	var list_height: float = size.y - HEADER_H - TAB_H - SUBTAB_H - FOOTER_H - 20.0
	_max_scroll = maxf(0.0, _filtered_entries.size() * (ENTRY_H + ENTRY_GAP) - list_height)

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_scanner_time += delta
	_scan_pulse = fmod(_time * 0.8, 1.0)
	if _voice_playing_timer > 0.0:
		_voice_playing_timer -= delta
	for col in _glyph_columns:
		col.offset += col.speed * delta
	# Update tank camera follow, selection highlight, and viewport resolution
	if _tank_initialized and _stage_tab == 0:
		_tank_highlight_time += delta
		_update_tank_camera(delta)
		_resize_tank_viewport()
		# Pulse selected creature modulate
		if _tank_selected_node and is_instance_valid(_tank_selected_node):
			var glow: float = 1.0 + sin(_tank_highlight_time * 3.0) * 0.12
			_tank_selected_node.modulate = Color(glow, glow, minf(glow + 0.08, 1.2), 1.0)
	# Tick discovery VFX
	var expired: Array = []
	for cid in _discovery_vfx_timers:
		_discovery_vfx_timers[cid] -= delta
		if _discovery_vfx_timers[cid] <= 0.0:
			expired.append(cid)
	for cid in expired:
		_discovery_vfx_timers.erase(cid)
	queue_redraw()

# ======================== INPUT ========================

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_scroll_offset = maxf(_scroll_offset - 35.0, 0.0)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_scroll_offset = minf(_scroll_offset + 35.0, _max_scroll)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				_handle_click(mb.position)
	elif event is InputEventMouseMotion:
		_handle_hover(event.position)
		accept_event()

func _handle_click(_pos: Vector2) -> void:
	if _hover_close:
		toggle()
		return
	if _hover_reveal:
		# Reveal all creatures
		for creature in ALL_CREATURES:
			GameManager.discover_creature(creature.id)
		_check_new_discoveries()
		_rebuild_filtered()
		return
	if _hover_stage_tab >= 0:
		_stage_tab = _hover_stage_tab
		_sub_category = "ALL"
		_scroll_offset = 0.0
		_selected_idx = -1
		_tank_selected_node = null
		# Lazy-init tank when switching to cell tab
		if _stage_tab == 0 and not _tank_initialized:
			_initialize_tank()
		_rebuild_filtered()
		return
	if _hover_sub_tab >= 0:
		var cats: Array = CELL_CATEGORIES if _stage_tab == 0 else PARASITE_CATEGORIES
		if _hover_sub_tab < cats.size():
			_sub_category = cats[_hover_sub_tab]
			_scroll_offset = 0.0
			_selected_idx = -1
			_rebuild_filtered()
		return
	if _hover_voice_type >= 0 and _selected_idx >= 0 and _selected_idx < ALL_CREATURES.size():
		var voice_entry: Dictionary = ALL_CREATURES[_selected_idx]
		if VoiceGenerator.SPECIES_PRESETS.has(voice_entry.id):
			AudioManager.play_voice_preview(voice_entry.id, VOICE_TYPES[_hover_voice_type])
			_voice_playing_timer = 0.6
			_voice_playing_type = _hover_voice_type
		return
	if _hover_entry >= 0 and _hover_entry < _filtered_entries.size():
		var data_idx: int = _filtered_entries[_hover_entry]
		_selected_idx = data_idx
		# Find matching creature in fish tank
		_select_tank_creature(ALL_CREATURES[data_idx].id)

func _handle_hover(pos: Vector2) -> void:
	_hover_entry = -1
	_hover_stage_tab = -1
	_hover_sub_tab = -1
	_hover_close = false
	_hover_reveal = false
	_hover_voice_type = -1

	# Close button
	var s: Vector2 = size
	var close_rect: Rect2 = Rect2(s.x - 54, 13, 44, 44)
	if close_rect.has_point(pos):
		_hover_close = true
		return

	# Reveal All button
	var reveal_rect: Rect2 = Rect2(s.x - 200, 20, 130, 30)
	if reveal_rect.has_point(pos):
		_hover_reveal = true
		return

	# Stage tabs
	var tab_names: Array = ["CELL STAGE", "PARASITE STAGE"]
	var tab_w: float = 180.0
	var tab_start_x: float = 20.0
	for i in range(2):
		var tab_rect: Rect2 = Rect2(tab_start_x + i * (tab_w + 4), HEADER_H, tab_w, TAB_H)
		if tab_rect.has_point(pos):
			_hover_stage_tab = i
			return

	# Sub-category tabs
	var cats: Array = CELL_CATEGORIES if _stage_tab == 0 else PARASITE_CATEGORIES
	var sub_tab_w: float = (SIDEBAR_W - 16.0) / cats.size()
	var sub_y: float = HEADER_H + TAB_H
	for i in range(cats.size()):
		var sub_rect: Rect2 = Rect2(16 + i * sub_tab_w, sub_y, sub_tab_w - 2, SUBTAB_H)
		if sub_rect.has_point(pos):
			_hover_sub_tab = i
			return

	# Voice buttons in detail panel
	for vi in range(_voice_btn_rects.size()):
		if _voice_btn_rects[vi].has_point(pos):
			_hover_voice_type = vi
			return

	# Entry list
	var list_y_start: float = HEADER_H + TAB_H + SUBTAB_H + 10.0
	if pos.x >= 16 and pos.x <= 16 + SIDEBAR_W:
		var rel_y: float = pos.y - list_y_start + _scroll_offset
		if rel_y >= 0:
			var idx: int = int(rel_y / (ENTRY_H + ENTRY_GAP))
			if idx >= 0 and idx < _filtered_entries.size():
				var entry_top: float = idx * (ENTRY_H + ENTRY_GAP)
				if rel_y - entry_top < ENTRY_H:
					_hover_entry = idx

# ======================== FISH TANK ECOSYSTEM ========================

func _initialize_tank() -> void:
	if _tank_initialized:
		return
	# Create SubViewport for the ecosystem.
	# Note: Tank creatures join SceneTree groups (prey, enemies, etc.) which is fine because
	# the database is only accessible from the main menu where no gameplay is active.
	# The isolated World2D prevents physics contamination.
	_tank_viewport = SubViewport.new()
	_tank_viewport.size = Vector2i(int(TANK_BOUNDS.size.x), int(TANK_BOUNDS.size.y))
	_tank_viewport.transparent_bg = true
	_tank_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_tank_viewport.gui_disable_input = true
	_tank_viewport.world_2d = World2D.new()
	_tank_viewport.physics_object_picking = false
	add_child(_tank_viewport)
	# Camera centered in tank
	_tank_camera = Camera2D.new()
	_tank_camera.position = Vector2.ZERO
	_tank_camera.enabled = true
	_tank_viewport.add_child(_tank_camera)
	# Boundary walls
	_create_tank_walls()
	# Mark initialized before populating so spawn guards pass
	_tank_initialized = true
	# Populate ecosystem
	_populate_tank()

func _create_tank_walls() -> void:
	var half_w: float = TANK_BOUNDS.size.x * 0.5
	var half_h: float = TANK_BOUNDS.size.y * 0.5
	var thickness: float = 20.0
	# Wall definitions: [pos_x, pos_y, size_x, size_y]
	var walls: Array = [
		[0, -(half_h + thickness * 0.5), TANK_BOUNDS.size.x + thickness * 2, thickness],  # Top
		[0, half_h + thickness * 0.5, TANK_BOUNDS.size.x + thickness * 2, thickness],  # Bottom
		[-(half_w + thickness * 0.5), 0, thickness, TANK_BOUNDS.size.y + thickness * 2],  # Left
		[half_w + thickness * 0.5, 0, thickness, TANK_BOUNDS.size.y + thickness * 2],  # Right
	]
	for w in walls:
		var body := StaticBody2D.new()
		body.position = Vector2(w[0], w[1])
		var col_shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w[2], w[3])
		col_shape.shape = rect
		body.add_child(col_shape)
		_tank_viewport.add_child(body)

func _populate_tank() -> void:
	# Spawn predators
	for i in range(TANK_POP_PREDATORS):
		var cid: String = TANK_PREDATORS[i % TANK_PREDATORS.size()]
		_spawn_tank_creature(cid)
	# Spawn prey
	for i in range(TANK_POP_PREY):
		var cid: String = TANK_PREY[i % TANK_PREY.size()]
		_spawn_tank_creature(cid)
	# Spawn misc (ink_bomber, electric_eel, etc.)
	for i in range(TANK_POP_MISC):
		var cid: String = TANK_MISC[i % TANK_MISC.size()]
		_spawn_tank_creature(cid)
	# Spawn bosses
	for i in range(TANK_POP_BOSSES):
		var cid: String = TANK_BOSSES[i % TANK_BOSSES.size()]
		_spawn_tank_creature(cid)
	# Spawn food particles
	for i in range(TANK_POP_FOOD):
		_spawn_tank_food()

func _spawn_tank_creature(creature_id: String) -> void:
	if not _tank_initialized or not _active:
		return  # Guard: don't spawn if tank is closed or inactive
	if not CELL_SCENE_PATHS.has(creature_id):
		return
	var scene: PackedScene = load(CELL_SCENE_PATHS[creature_id])
	if not scene:
		return
	var creature: Node = scene.instantiate()
	# Random position within bounds (inset from walls)
	var hw: float = TANK_BOUNDS.size.x * 0.5 - 40
	var hh: float = TANK_BOUNDS.size.y * 0.5 - 40
	creature.position = Vector2(randf_range(-hw, hw), randf_range(-hh, hh))
	# Scale up so creatures are visible
	creature.scale = Vector2(TANK_CREATURE_SCALE, TANK_CREATURE_SCALE)
	# Tag for identification
	creature.set_meta("tank_creature_id", creature_id)
	# Detect when creature dies (queue_free triggers tree_exiting)
	creature.tree_exiting.connect(_on_tank_creature_exiting.bind(creature_id))
	_tank_creatures.append(creature)
	_tank_viewport.add_child(creature)

func _spawn_tank_food() -> void:
	if not _tank_initialized or not _active:
		return  # Guard: don't spawn if tank is closed or inactive
	var scene: PackedScene = load("res://scenes/food_particle.tscn")
	if not scene:
		return
	var food: Node = scene.instantiate()
	var hw: float = TANK_BOUNDS.size.x * 0.5 - 30
	var hh: float = TANK_BOUNDS.size.y * 0.5 - 30
	food.position = Vector2(randf_range(-hw, hw), randf_range(-hh, hh))
	food.scale = Vector2(TANK_CREATURE_SCALE, TANK_CREATURE_SCALE)
	# Setup with random biomolecule data
	if food.has_method("setup"):
		var bio_data: Dictionary = BiologyLoader.get_random_biomolecule()
		if bio_data.is_empty():
			bio_data = {"color": [0.3, 0.7, 1.0], "category": "default", "rarity": "common"}
		food.setup(bio_data, false)
	food.set_meta("tank_creature_id", "food_particle")
	food.tree_exiting.connect(_on_tank_food_exiting)
	_tank_food.append(food)
	_tank_viewport.add_child(food)

func _on_tank_creature_exiting(creature_id: String) -> void:
	# Clean up refs — tree_exiting fires before free, so check queued_for_deletion
	_tank_creatures = _tank_creatures.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	if _tank_selected_node and (not is_instance_valid(_tank_selected_node) or _tank_selected_node.is_queued_for_deletion()):
		_tank_selected_node = null
	# Respawn after delay (spawn function has its own _active guard)
	if _tank_initialized:
		get_tree().create_timer(TANK_RESPAWN_DELAY).timeout.connect(_spawn_tank_creature.bind(creature_id))

func _on_tank_food_exiting() -> void:
	_tank_food = _tank_food.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion())
	# Spawn function has its own _active guard, safe to always schedule
	if _tank_initialized:
		get_tree().create_timer(TANK_FOOD_RESPAWN_DELAY).timeout.connect(_spawn_tank_food)

func _update_tank_camera(delta: float) -> void:
	if not _tank_camera:
		return
	var target: Vector2 = Vector2.ZERO
	if _tank_selected_node and is_instance_valid(_tank_selected_node):
		target = _tank_selected_node.position
	_tank_camera_target = _tank_camera_target.lerp(target, delta * 3.0)
	# Clamp camera to keep tank in view
	var hw: float = TANK_BOUNDS.size.x * 0.25
	var hh: float = TANK_BOUNDS.size.y * 0.25
	_tank_camera_target.x = clampf(_tank_camera_target.x, -hw, hw)
	_tank_camera_target.y = clampf(_tank_camera_target.y, -hh, hh)
	_tank_camera.position = _tank_camera_target

func _resize_tank_viewport() -> void:
	## Resize the SubViewport to match the actual display rect so it renders at full resolution.
	## Uses uniform zoom to avoid stretching creatures.
	if not _tank_viewport or not _tank_camera:
		return
	var s: Vector2 = size
	var x: float = SIDEBAR_W + 26.0 + DETAIL_PAD
	var panel_w: float = s.x - x - DETAIL_PAD
	var tank_h: float = minf(panel_w * 0.62, (s.y - HEADER_H - TAB_H - FOOTER_H) * 0.55)
	var tank_w: float = panel_w - 8.0
	var target_size: Vector2i = Vector2i(maxi(int(tank_w), 64), maxi(int(tank_h), 64))
	if _tank_viewport.size != target_size:
		_tank_viewport.size = target_size
		# Uniform zoom: fit TANK_BOUNDS without stretching
		var zoom_val: float = minf(tank_w / TANK_BOUNDS.size.x, tank_h / TANK_BOUNDS.size.y)
		_tank_camera.zoom = Vector2(zoom_val, zoom_val)

func _select_tank_creature(creature_id: String) -> void:
	# Clear previous highlight
	if _tank_selected_node and is_instance_valid(_tank_selected_node):
		_tank_selected_node.modulate = Color.WHITE
	_tank_selected_node = null
	_tank_highlight_time = 0.0
	# Find first matching creature in tank
	for c in _tank_creatures:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			if c.get_meta("tank_creature_id", "") == creature_id:
				_tank_selected_node = c
				break

func _draw_scanner_overlay(rect: Rect2, col: Color) -> void:
	# Sweeping horizontal scan line with glow
	var scan_y: float = rect.position.y + fmod(_scanner_time * 40.0, rect.size.y)
	draw_line(Vector2(rect.position.x, scan_y), Vector2(rect.end.x, scan_y), Color(col.r, col.g, col.b, 0.25), 1.5)
	for i in range(1, 5):
		var fade_a: float = 0.25 * (1.0 - float(i) / 5.0)
		draw_line(Vector2(rect.position.x, scan_y - i * 2), Vector2(rect.end.x, scan_y - i * 2), Color(col.r, col.g, col.b, fade_a * 0.3), 1.0)
	# Corner brackets
	var arm: float = 22.0
	var bw: float = 2.0
	var bc: Color = Color(col.r, col.g, col.b, 0.6)
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x + arm, rect.position.y), bc, bw)
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.position.y + arm), bc, bw)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - arm, rect.position.y), bc, bw)
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + arm), bc, bw)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + arm, rect.end.y), bc, bw)
	draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - arm), bc, bw)
	draw_line(Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x - arm, rect.end.y), bc, bw)
	draw_line(Vector2(rect.end.x, rect.end.y), Vector2(rect.end.x, rect.end.y - arm), bc, bw)
	# Blinking REC dot + label
	var mono: Font = UIConstants.get_mono_font()
	draw_string(mono, Vector2(rect.position.x + 8, rect.position.y + 22), "LIVE ECOSYSTEM", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col.r, col.g, col.b, 0.5))
	if fmod(_scanner_time, 1.2) < 0.8:
		draw_circle(Vector2(rect.end.x - 18, rect.position.y + 14), 4.0, Color(0.9, 0.2, 0.15, 0.7))
		draw_string(mono, Vector2(rect.end.x - 56, rect.position.y + 20), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.2, 0.15, 0.5))
	# Timestamp
	var ts_str: String = "%02d:%02d:%02d" % [int(_scanner_time / 3600) % 24, int(_scanner_time / 60) % 60, int(_scanner_time) % 60]
	draw_string(mono, Vector2(rect.end.x - 100, rect.end.y - 8), ts_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.r, col.g, col.b, 0.4))
	# Entity count bottom-left
	var pop_str: String = "POP: %d" % (_tank_creatures.size() + _tank_food.size())
	draw_string(mono, Vector2(rect.position.x + 8, rect.end.y - 8), pop_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col.r, col.g, col.b, 0.4))

# ======================== DRAWING ========================

func _draw() -> void:
	if not _active:
		return
	var s: Vector2 = size

	# Background
	draw_rect(Rect2(0, 0, s.x, s.y), Color(0.06, 0.08, 0.14, 1.0))

	# Blueprint grid
	UIConstants.draw_blueprint_grid(self, s, 0.35)

	# Glyph columns
	UIConstants.draw_glyph_columns(self, s, _glyph_columns, 0.25)

	# Scan line
	var scan_y: float = fmod(_time * 50.0, s.y)
	UIConstants.draw_scan_line(self, s, scan_y, _time, 0.4)

	# Vignette
	UIConstants.draw_vignette(self, s, 0.9)

	# Header
	_draw_header(s)

	# Stage tabs
	_draw_stage_tabs(s)

	# Sub-category tabs
	_draw_sub_tabs(s)

	# Sidebar
	_draw_sidebar(s)

	# Separator
	var sep_x: float = SIDEBAR_W + 26
	draw_line(Vector2(sep_x, HEADER_H + 5), Vector2(sep_x, s.y - FOOTER_H), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.40), 1.0)
	var glow_y: float = fmod(_time * 35.0, s.y - HEADER_H - FOOTER_H) + HEADER_H
	draw_line(Vector2(sep_x, glow_y - 25), Vector2(sep_x, glow_y + 25), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.55), 2.0)

	# Detail panel
	_draw_detail_panel(sep_x + DETAIL_PAD, s)

	# Corner frame
	UIConstants.draw_corner_frame(self, Rect2(4, 4, s.x - 8, s.y - 8), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.3))

	# Footer
	_draw_footer(s)

func _draw_header(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()

	# Header background
	draw_rect(Rect2(0, 0, s.x, HEADER_H), Color(0.08, 0.10, 0.18, 0.94))
	draw_line(Vector2(0, HEADER_H - 1), Vector2(s.x, HEADER_H - 1), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.4), 1.0)

	# Moving accent on header bottom
	var header_scan: float = fmod(_time * 90.0, s.x + 200.0) - 100.0
	draw_line(Vector2(header_scan, HEADER_H - 1), Vector2(header_scan + 160.0, HEADER_H - 1), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.5), 2.5)

	# Title
	var gl: String = UIConstants.random_glyphs(2, _time, 0.0)
	var gr: String = UIConstants.random_glyphs(2, _time, 5.0)
	var title: String = gl + " XENOBIOLOGY DATABASE " + gr
	draw_string(font, Vector2(24, 44), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_HEADER, UIConstants.TEXT_TITLE)

	# Scanner status
	var status_text: String = "SCANNING..." if _scan_pulse < 0.5 else "READY"
	var status_col: Color = UIConstants.ACCENT if _scan_pulse < 0.5 else UIConstants.STAT_GREEN
	draw_circle(Vector2(s.x - 310, 36), 4.0, status_col * (0.6 + 0.4 * sin(_time * 4.0)))
	draw_string(mono, Vector2(s.x - 300, 40), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_TINY, status_col * 0.8)

	# Discovery count
	var total: int = ALL_CREATURES.size()
	var found: int = 0
	for entry in ALL_CREATURES:
		if GameManager.is_creature_discovered(entry.id):
			found += 1
	var count_text: String = "%d/%d CATALOGED" % [found, total]
	draw_string(mono, Vector2(s.x - 430, 40), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, UIConstants.TEXT_NORMAL)

	# Close button
	var close_col: Color = Color(0.9, 0.3, 0.3, 0.9) if _hover_close else Color(0.4, 0.25, 0.25, 0.7)
	draw_rect(Rect2(s.x - 54, 13, 44, 44), close_col * 0.2)
	draw_rect(Rect2(s.x - 54, 13, 44, 44), close_col, false, 1.5)
	draw_string(font, Vector2(s.x - 40, 43), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, close_col)

	# Reveal All button
	var reveal_col: Color = Color(1.0, 0.85, 0.2, 0.9) if _hover_reveal else Color(0.5, 0.45, 0.2, 0.5)
	var reveal_rect: Rect2 = Rect2(s.x - 200, 20, 130, 30)
	draw_rect(reveal_rect, reveal_col * 0.15)
	draw_rect(reveal_rect, reveal_col * 0.5, false, 1.0)
	draw_string(mono, Vector2(s.x - 192, 40), "REVEAL ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, UIConstants.FONT_CAPTION, reveal_col)

func _draw_stage_tabs(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var tab_names: Array = ["CELL STAGE", "PARASITE STAGE"]
	var tab_w: float = 180.0
	var tab_start_x: float = 20.0

	for i in range(2):
		var rect: Rect2 = Rect2(tab_start_x + i * (tab_w + 4), HEADER_H, tab_w, TAB_H)
		var is_active: bool = i == _stage_tab
		var is_hovered: bool = _hover_stage_tab == i

		var bg: Color = Color(0.12, 0.22, 0.34) if is_active else Color(0.06, 0.10, 0.16)
		if is_hovered and not is_active:
			bg = bg.lightened(0.1)
		draw_rect(rect, bg)

		if is_active:
			draw_line(Vector2(rect.position.x, rect.end.y - 2), Vector2(rect.end.x, rect.end.y - 2), UIConstants.ACCENT, 2.5)

		draw_rect(rect, Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.25), false, 1.0)

		var text_col: Color = UIConstants.TEXT_BRIGHT if is_active else UIConstants.TEXT_NORMAL
		var ts: Vector2 = font.get_string_size(tab_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(font, Vector2(rect.position.x + (tab_w - ts.x) * 0.5, rect.position.y + 32), tab_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, text_col)

func _draw_sub_tabs(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var cats: Array = CELL_CATEGORIES if _stage_tab == 0 else PARASITE_CATEGORIES
	var sub_tab_w: float = (SIDEBAR_W - 16.0) / cats.size()
	var sub_y: float = HEADER_H + TAB_H

	for i in range(cats.size()):
		var cat_name: String = cats[i]
		var rect: Rect2 = Rect2(16 + i * sub_tab_w, sub_y, sub_tab_w - 2, SUBTAB_H)
		var is_active: bool = cat_name == _sub_category
		var is_hovered: bool = _hover_sub_tab == i

		var bg: Color = Color(0.10, 0.18, 0.28) if is_active else Color(0.06, 0.10, 0.16)
		if is_hovered and not is_active:
			bg = bg.lightened(0.08)
		draw_rect(rect, bg)

		if is_active:
			draw_line(Vector2(rect.position.x, rect.end.y - 1), Vector2(rect.end.x, rect.end.y - 1), UIConstants.ACCENT * 0.7, 1.5)

		var text_col: Color = UIConstants.TEXT_BRIGHT if is_active else UIConstants.TEXT_NORMAL
		draw_string(font, Vector2(rect.position.x + 5, rect.position.y + 24), cat_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, text_col)

func _draw_sidebar(s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var list_y: float = HEADER_H + TAB_H + SUBTAB_H + 10.0

	for fi in range(_filtered_entries.size()):
		var data_idx: int = _filtered_entries[fi]
		var entry: Dictionary = ALL_CREATURES[data_idx]
		var ey: float = list_y + fi * (ENTRY_H + ENTRY_GAP) - _scroll_offset

		if ey + ENTRY_H < list_y or ey > s.y - FOOTER_H:
			continue

		var cid: String = entry.id
		var discovered: bool = GameManager.is_creature_discovered(cid)
		var is_selected: bool = data_idx == _selected_idx
		var is_hovered: bool = fi == _hover_entry

		# Entry background
		var bg_col: Color = Color(0.07, 0.12, 0.20)
		if is_selected:
			bg_col = Color(0.10, 0.18, 0.28)
		elif is_hovered:
			bg_col = Color(0.09, 0.15, 0.24)
		draw_rect(Rect2(16, ey, SIDEBAR_W, ENTRY_H), bg_col)

		# Selection bar
		if is_selected:
			draw_rect(Rect2(16, ey, 3, ENTRY_H), UIConstants.ACCENT)

		# Border
		var border_col: Color = UIConstants.ACCENT_DIM if is_selected else Color(0.18, 0.28, 0.38)
		draw_rect(Rect2(16, ey, SIDEBAR_W, ENTRY_H), Color(border_col.r, border_col.g, border_col.b, 0.5), false, 1.0)

		# Icon
		var ic: Array = entry.icon_color
		var icon_col: Color = Color(ic[0], ic[1], ic[2]) if discovered else Color(0.28, 0.28, 0.32)
		var icon_center: Vector2 = Vector2(48, ey + ENTRY_H * 0.5)
		_draw_blueprint_icon(icon_center, ICON_R * 0.8, icon_col, entry, discovered)

		# Discovery VFX
		if cid in _discovery_vfx_timers:
			_draw_discovery_vfx(icon_center, ICON_R, _discovery_vfx_timers[cid])

		# Name
		var name_text: String = entry.name if discovered else "??? UNKNOWN ???"
		var name_col: Color = Color(0.80, 0.95, 1.0) if discovered else Color(0.45, 0.48, 0.55)
		draw_string(font, Vector2(76, ey + 30), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, name_col)

		# Category + threat dots
		var cat_col: Color = _category_color(entry.category)
		if discovered:
			draw_string(mono, Vector2(76, ey + 54), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, cat_col * 0.85)
			var threat: int = _get_threat_level(entry)
			for t in range(5):
				var dot_col: Color = UIConstants.STAT_RED if t < threat else Color(0.22, 0.22, 0.25)
				draw_circle(Vector2(168 + t * 14, ey + 50), 4.0, dot_col)
		else:
			draw_string(mono, Vector2(76, ey + 54), "UNSCANNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.50, 0.50, 0.58))

		# HP bar
		if discovered and entry.hp > 0:
			var bar_x: float = 230.0
			var bar_w: float = 120.0
			var bar_h: float = 6.0
			var bar_y: float = ey + ENTRY_H * 0.5 - bar_h * 0.5
			draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.18))
			var hp_ratio: float = clampf(float(entry.hp) / 300.0, 0.0, 1.0)
			var hp_col: Color = UIConstants.STAT_GREEN.lerp(UIConstants.STAT_RED, 1.0 - hp_ratio)
			draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), hp_col)
			draw_string(mono, Vector2(bar_x + bar_w + 6, bar_y + 8), str(entry.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIConstants.TEXT_DIM)

func _draw_cell_tank_panel(x: float, s: Vector2, panel_w: float, font: Font, mono: Font) -> void:
	## Draws the fish tank ecosystem view for cell stage creatures.
	var tank_h: float = minf(panel_w * 0.62, (s.y - HEADER_H - TAB_H - FOOTER_H) * 0.55)
	var tank_rect: Rect2 = Rect2(x + 4, HEADER_H + TAB_H + 8, panel_w - 8, tank_h)

	# Dark background behind tank
	draw_rect(tank_rect, Color(0.02, 0.04, 0.07, 0.95))

	# Draw tank viewport texture
	if _tank_viewport and _tank_initialized:
		var tex: ViewportTexture = _tank_viewport.get_texture()
		if tex:
			draw_texture_rect(tex, tank_rect, false)

	# Scanner overlay color (matches selected creature or default accent)
	var overlay_col: Color = UIConstants.ACCENT
	if _selected_idx >= 0 and _selected_idx < ALL_CREATURES.size():
		var oc: Array = ALL_CREATURES[_selected_idx].icon_color
		overlay_col = Color(oc[0], oc[1], oc[2])
	_draw_scanner_overlay(tank_rect, overlay_col)
	UIConstants.draw_corner_frame(self, Rect2(tank_rect.position.x - 2, tank_rect.position.y - 2, tank_rect.size.x + 4, tank_rect.size.y + 4), Color(overlay_col.r, overlay_col.g, overlay_col.b, 0.35))

	# --- No selection: show hint and return ---
	if _selected_idx < 0 or _selected_idx >= ALL_CREATURES.size():
		_voice_btn_rects.clear()
		var cx: float = tank_rect.position.x + tank_rect.size.x * 0.5
		var cy: float = tank_rect.position.y + tank_rect.size.y * 0.5
		draw_string(font, Vector2(cx - 160, cy), "SELECT AN ORGANISM", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.75))
		draw_string(mono, Vector2(cx - 185, cy + 32), "Click sidebar to track in ecosystem", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.6))
		_draw_helix(Vector2(cx, tank_rect.end.y + 80), 75.0)
		return

	var entry: Dictionary = ALL_CREATURES[_selected_idx]
	var discovered: bool = GameManager.is_creature_discovered(entry.id)
	var ic: Array = entry.icon_color
	var icon_col: Color = Color(ic[0], ic[1], ic[2])

	# --- Undiscovered: locked overlay on tank ---
	if not discovered:
		_voice_btn_rects.clear()
		var cx: float = tank_rect.position.x + tank_rect.size.x * 0.5
		var cy: float = tank_rect.position.y + tank_rect.size.y * 0.5
		draw_rect(tank_rect, Color(0, 0, 0, 0.55))
		_draw_blueprint_icon(Vector2(cx, cy - 20), 60.0, Color(0.12, 0.12, 0.12), entry, false)
		draw_string(font, Vector2(cx - 200, cy + 55), "ORGANISM NOT YET SCANNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.65, 0.55, 0.55, 0.85))
		draw_string(mono, Vector2(cx - 240, cy + 90), "Encounter this organism in-game to unlock data.", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, Color(0.55, 0.50, 0.50, 0.72))
		return

	# --- Selection tracking indicator ---
	if _tank_selected_node and is_instance_valid(_tank_selected_node):
		var cp: Vector2 = _tank_selected_node.position
		var cam_p: Vector2 = _tank_camera.position if _tank_camera else Vector2.ZERO
		# Visible world area = viewport_size / camera_zoom
		var cam_zoom: float = _tank_camera.zoom.x if _tank_camera else 1.0
		var visible_w: float = tank_rect.size.x / maxf(cam_zoom, 0.01)
		var visible_h: float = tank_rect.size.y / maxf(cam_zoom, 0.01)
		var norm_x: float = (cp.x - cam_p.x) / visible_w + 0.5
		var norm_y: float = (cp.y - cam_p.y) / visible_h + 0.5
		var screen_pos: Vector2 = Vector2(
			tank_rect.position.x + norm_x * tank_rect.size.x,
			tank_rect.position.y + norm_y * tank_rect.size.y
		)
		# Only draw indicator if within tank bounds
		if tank_rect.has_point(screen_pos):
			# Pulsing selection ring
			var ring_r: float = 18.0 + sin(_tank_highlight_time * 3.0) * 3.0
			var ring_a: float = 0.5 + sin(_tank_highlight_time * 2.5) * 0.15
			draw_arc(screen_pos, ring_r, 0, TAU, 24, Color(icon_col.r, icon_col.g, icon_col.b, ring_a), 2.0)
			# Corner brackets around selection
			var br: float = ring_r + 6
			var arm_l: float = 8.0
			var bc2: Color = Color(icon_col.r, icon_col.g, icon_col.b, ring_a * 0.7)
			draw_line(screen_pos + Vector2(-br, -br), screen_pos + Vector2(-br + arm_l, -br), bc2, 1.5)
			draw_line(screen_pos + Vector2(-br, -br), screen_pos + Vector2(-br, -br + arm_l), bc2, 1.5)
			draw_line(screen_pos + Vector2(br, -br), screen_pos + Vector2(br - arm_l, -br), bc2, 1.5)
			draw_line(screen_pos + Vector2(br, -br), screen_pos + Vector2(br, -br + arm_l), bc2, 1.5)
			draw_line(screen_pos + Vector2(-br, br), screen_pos + Vector2(-br + arm_l, br), bc2, 1.5)
			draw_line(screen_pos + Vector2(-br, br), screen_pos + Vector2(-br, br - arm_l), bc2, 1.5)
			draw_line(screen_pos + Vector2(br, br), screen_pos + Vector2(br - arm_l, br), bc2, 1.5)
			draw_line(screen_pos + Vector2(br, br), screen_pos + Vector2(br, br - arm_l), bc2, 1.5)

	# --- Stats HUD overlay at bottom of tank ---
	var hud_h: float = 130.0
	var hud_y: float = tank_rect.end.y - hud_h
	# Gradient fade from transparent to dark
	for i in range(16):
		var gy: float = hud_y - 16 + i
		var ga: float = float(i) / 16.0 * 0.75
		draw_line(Vector2(tank_rect.position.x, gy), Vector2(tank_rect.end.x, gy), Color(0.02, 0.04, 0.07, ga), 1.0)
	draw_rect(Rect2(tank_rect.position.x, hud_y, tank_rect.size.x, hud_h), Color(0.02, 0.04, 0.07, 0.78))

	var hx: float = tank_rect.position.x + 16
	var hy: float = hud_y + 8

	# Creature name (large)
	draw_string(font, Vector2(hx, hy + FONT_NAME - 6), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NAME, UIConstants.TEXT_BRIGHT)
	# Category
	var cat_col: Color = _category_color(entry.category)
	draw_string(font, Vector2(hx, hy + FONT_NAME + FONT_CATEGORY - 4), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CATEGORY, cat_col)

	# Stats on right side of HUD
	var stat_rx: float = tank_rect.end.x - 380
	var stat_ry: float = hud_y + 12
	# HP
	draw_string(mono, Vector2(stat_rx, stat_ry + 18), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIConstants.TEXT_DIM)
	var hp_str: String = str(entry.hp) if entry.hp > 0 else "N/A"
	var hp_col: Color = UIConstants.STAT_GREEN if entry.hp > 0 else UIConstants.TEXT_DIM
	draw_string(font, Vector2(stat_rx + 36, stat_ry + 18), hp_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, hp_col)
	# DAMAGE
	draw_string(mono, Vector2(stat_rx + 130, stat_ry + 18), "DMG", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIConstants.TEXT_DIM)
	var dmg_col: Color = UIConstants.STAT_RED if entry.damage > 0 else UIConstants.TEXT_DIM
	draw_string(font, Vector2(stat_rx + 184, stat_ry + 18), str(entry.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, dmg_col)
	# SPEED
	draw_string(mono, Vector2(stat_rx, stat_ry + 52), "SPD", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(stat_rx + 48, stat_ry + 52), "%.1f" % entry.speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.4, 0.7, 0.9))
	# THREAT
	draw_string(mono, Vector2(stat_rx + 130, stat_ry + 52), "THREAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIConstants.TEXT_DIM)
	var threat: int = _get_threat_level(entry)
	for t in range(5):
		var dot_col: Color = UIConstants.STAT_RED if t < threat else Color(0.22, 0.22, 0.25)
		draw_circle(Vector2(stat_rx + 224 + t * 18, stat_ry + 47), 5.0, dot_col)

	# Trait tags at bottom of HUD
	if entry.has("traits") and entry.traits.size() > 0:
		var trait_x: float = hx
		var trait_y: float = hud_y + hud_h - 32
		for trait_name in entry.traits:
			var tw: float = font.get_string_size(trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16
			if trait_x + tw > tank_rect.end.x - 10:
				break  # Don't overflow HUD
			draw_rect(Rect2(trait_x, trait_y, tw, 26), Color(icon_col.r, icon_col.g, icon_col.b, 0.12))
			draw_rect(Rect2(trait_x, trait_y, tw, 26), Color(icon_col.r, icon_col.g, icon_col.b, 0.3), false, 1.0)
			draw_string(font, Vector2(trait_x + 8, trait_y + 19), trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(icon_col.r, icon_col.g, icon_col.b, 0.85))
			trait_x += tw + 5

	# ====== Below tank: Text sections ======
	_draw_info_sections(x, tank_rect.end.y + 8, panel_w, entry, icon_col)

func _draw_detail_panel(x: float, s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var panel_w: float = s.x - x - DETAIL_PAD

	# Cell stage: Fish Tank Ecosystem
	if _stage_tab == 0:
		_draw_cell_tank_panel(x, s, panel_w, font, mono)
		return

	# Parasite stage: Classic blueprint layout
	if _selected_idx < 0 or _selected_idx >= ALL_CREATURES.size():
		_voice_btn_rects.clear()
		_draw_idle_scanner(x, panel_w, s)
		return

	var entry: Dictionary = ALL_CREATURES[_selected_idx]
	var discovered: bool = GameManager.is_creature_discovered(entry.id)
	var ic: Array = entry.icon_color
	var icon_col: Color = Color(ic[0], ic[1], ic[2])

	if not discovered:
		_voice_btn_rects.clear()
		# Show locked silhouette — enlarged
		var bp_center: Vector2 = Vector2(x + panel_w * 0.5, HEADER_H + TAB_H + 140)
		_draw_blueprint_icon(bp_center, 80.0, Color(0.12, 0.12, 0.12), entry, false)
		_draw_scanner_reticle(bp_center, 100.0, Color(0.32, 0.32, 0.35), 0.45)
		# Scanner overlay on the silhouette area
		var lock_rect: Rect2 = Rect2(bp_center.x - 110, bp_center.y - 110, 220, 220)
		_draw_scanner_overlay(lock_rect, Color(0.32, 0.32, 0.35))
		draw_string(font, Vector2(x + 30, HEADER_H + TAB_H + 270), "ORGANISM NOT YET SCANNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.65, 0.55, 0.55, 0.85))
		draw_string(mono, Vector2(x + 30, HEADER_H + TAB_H + 310), "Encounter this organism in-game to unlock data.", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, Color(0.55, 0.50, 0.50, 0.72))
		return

	# ============= TWO-COLUMN LAYOUT =============
	var y_start: float = HEADER_H + TAB_H + 12.0
	var preview_w: float = panel_w * 0.50
	var stats_x: float = x + preview_w + 15
	var stats_w: float = panel_w - preview_w - 15

	# --- LEFT COLUMN: Preview ---
	var preview_rect: Rect2 = Rect2(x + 8, y_start, preview_w - 16, preview_w - 16)
	# Dark background
	draw_rect(preview_rect, Color(0.04, 0.06, 0.10, 0.8))

	# Enlarged procedural blueprint for parasite creatures
	var bp_center: Vector2 = Vector2(preview_rect.position.x + preview_rect.size.x * 0.5, preview_rect.position.y + preview_rect.size.y * 0.5)
	var bp_r: float = minf(preview_rect.size.x, preview_rect.size.y) * 0.38
	_draw_blueprint_icon(bp_center, bp_r, icon_col, entry, true)
	_draw_scanner_reticle(bp_center, bp_r + 15, icon_col, 0.2)

	# Scanner overlay on top of preview
	_draw_scanner_overlay(preview_rect, icon_col)
	# Corner frame around preview
	UIConstants.draw_corner_frame(self, Rect2(preview_rect.position.x - 2, preview_rect.position.y - 2, preview_rect.size.x + 4, preview_rect.size.y + 4), Color(icon_col.r, icon_col.g, icon_col.b, 0.4))

	# Stage badge below preview
	var stage_label: String = "CELL STAGE" if entry.stage == "CELL" else "PARASITE STAGE"
	draw_string(mono, Vector2(preview_rect.position.x + 4, preview_rect.end.y + 22), stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIConstants.ACCENT_DIM * 0.95)
	# Alien annotation
	var alien_note: String = UIConstants.random_glyphs(6, _time * 0.3, float(entry.id.hash() % 100))
	draw_string(mono, Vector2(preview_rect.end.x - 90, preview_rect.end.y + 22), alien_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.45, 0.65, 0.75, 0.55))

	# --- RIGHT COLUMN: Name + Stats ---
	var ry: float = y_start + 4

	# Creature name
	draw_string(font, Vector2(stats_x, ry + FONT_NAME - 4), entry.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NAME, UIConstants.TEXT_BRIGHT)
	ry += FONT_NAME + 4
	# Category
	var cat_col: Color = _category_color(entry.category)
	draw_string(font, Vector2(stats_x, ry + FONT_CATEGORY - 2), entry.category, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CATEGORY, cat_col)
	ry += FONT_CATEGORY + 10

	# Separator
	draw_line(Vector2(stats_x, ry), Vector2(stats_x + stats_w - 10, ry), Color(0.22, 0.35, 0.48, 0.7), 1.0)
	ry += 10

	# Stats in 2x2 grid
	var stat_col2_x: float = stats_x + stats_w * 0.5
	# HEALTH
	draw_string(mono, Vector2(stats_x, ry + FONT_STAT_LABEL), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_LABEL, UIConstants.TEXT_DIM)
	if entry.hp > 0:
		draw_string(font, Vector2(stats_x, ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 2), str(entry.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_VALUE, UIConstants.STAT_GREEN)
		var hp_bar_w: float = stats_w * 0.38
		var hp_bar_y: float = ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 10
		draw_rect(Rect2(stats_x, hp_bar_y, hp_bar_w, 6), Color(0.15, 0.15, 0.18))
		var hp_r: float = clampf(float(entry.hp) / 300.0, 0.0, 1.0)
		draw_rect(Rect2(stats_x, hp_bar_y, hp_bar_w * hp_r, 6), UIConstants.STAT_GREEN * 0.8)
	else:
		draw_string(font, Vector2(stats_x, ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 2), "N/A", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_VALUE, UIConstants.TEXT_DIM)
	# DAMAGE
	draw_string(mono, Vector2(stat_col2_x, ry + FONT_STAT_LABEL), "DAMAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_LABEL, UIConstants.TEXT_DIM)
	var dmg_col: Color = UIConstants.STAT_RED if entry.damage > 0 else UIConstants.TEXT_DIM
	draw_string(font, Vector2(stat_col2_x, ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 2), str(entry.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_VALUE, dmg_col)
	ry += FONT_STAT_LABEL + FONT_STAT_VALUE + 18

	# SPEED
	draw_string(mono, Vector2(stats_x, ry + FONT_STAT_LABEL), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_LABEL, UIConstants.TEXT_DIM)
	draw_string(font, Vector2(stats_x, ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 2), "%.1f" % entry.speed, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_VALUE, Color(0.4, 0.7, 0.9))
	var spd_bar_w: float = stats_w * 0.38
	var spd_bar_y: float = ry + FONT_STAT_LABEL + FONT_STAT_VALUE + 10
	draw_rect(Rect2(stats_x, spd_bar_y, spd_bar_w, 6), Color(0.15, 0.15, 0.18))
	var spd_r: float = clampf(entry.speed / 8.0, 0.0, 1.0)
	draw_rect(Rect2(stats_x, spd_bar_y, spd_bar_w * spd_r, 6), Color(0.4, 0.7, 0.9, 0.7))
	# THREAT
	draw_string(mono, Vector2(stat_col2_x, ry + FONT_STAT_LABEL), "THREAT", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STAT_LABEL, UIConstants.TEXT_DIM)
	var threat: int = _get_threat_level(entry)
	for t in range(5):
		var dot_col: Color = UIConstants.STAT_RED if t < threat else Color(0.22, 0.22, 0.25)
		draw_circle(Vector2(stat_col2_x + t * 20 + 5, ry + FONT_STAT_LABEL + FONT_STAT_VALUE - 2), 6.0, dot_col)
	ry += FONT_STAT_LABEL + FONT_STAT_VALUE + 18

	# Separator
	draw_line(Vector2(stats_x, ry), Vector2(stats_x + stats_w - 10, ry), Color(0.22, 0.35, 0.48, 0.7), 1.0)
	ry += 10

	# Trait markers in right column
	if entry.has("traits") and entry.traits.size() > 0:
		var trait_x: float = stats_x
		for trait_name in entry.traits:
			var tw: float = font.get_string_size(trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY).x + 16
			if trait_x + tw > stats_x + stats_w - 5:
				trait_x = stats_x
				ry += 38
			draw_rect(Rect2(trait_x, ry, tw, 32), Color(icon_col.r, icon_col.g, icon_col.b, 0.1))
			draw_rect(Rect2(trait_x, ry, tw, 32), Color(icon_col.r, icon_col.g, icon_col.b, 0.3), false, 1.0)
			draw_string(font, Vector2(trait_x + 8, ry + 24), trait_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, Color(icon_col.r, icon_col.g, icon_col.b, 0.85))
			trait_x += tw + 5
		ry += 40

	# ============= BOTTOM HALF (full width) =============
	var stats_end_y: float = ry
	var preview_end_y: float = preview_rect.end.y + 28
	_draw_info_sections(x, maxf(stats_end_y, preview_end_y), panel_w, entry, icon_col)

func _draw_info_sections(x: float, start_y: float, panel_w: float, entry: Dictionary, icon_col: Color) -> void:
	## Shared drawing for audio signature, abilities, behavioral analysis, and field notes.
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var y: float = start_y

	# Audio Signature
	if VoiceGenerator.SPECIES_PRESETS.has(entry.id):
		draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.22, 0.35, 0.48, 0.7), 1.0)
		y += 14
		draw_string(mono, Vector2(x + 10, y + FONT_SECTION), "// AUDIO SIGNATURE", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SECTION, UIConstants.ACCENT_DIM)
		y += FONT_SECTION + 14
		_voice_btn_rects.clear()
		var vbtn_x: float = x + 20
		for vi in range(VOICE_TYPES.size()):
			var vlabel: String = VOICE_TYPES[vi].to_upper()
			var vtw: float = font.get_string_size(vlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VOICE_BTN).x + 32
			var vbtn_rect: Rect2 = Rect2(vbtn_x, y, vtw, 36)
			_voice_btn_rects.append(vbtn_rect)
			var v_hover: bool = _hover_voice_type == vi
			var v_playing: bool = _voice_playing_type == vi and _voice_playing_timer > 0.0
			var vbg: Color = Color(icon_col.r, icon_col.g, icon_col.b, 0.15 if v_hover else 0.05)
			if v_playing:
				vbg = Color(icon_col.r, icon_col.g, icon_col.b, 0.12)
			draw_rect(vbtn_rect, vbg)
			draw_rect(vbtn_rect, Color(icon_col.r, icon_col.g, icon_col.b, 0.4 if v_hover else 0.2), false, 1.0)
			var spk_cx: float = vbtn_x + 12
			var spk_cy: float = y + 18
			var spk_col: Color = icon_col if (v_hover or v_playing) else UIConstants.TEXT_DIM
			draw_colored_polygon(PackedVector2Array([
				Vector2(spk_cx - 3, spk_cy - 3), Vector2(spk_cx + 3, spk_cy - 5),
				Vector2(spk_cx + 3, spk_cy + 5), Vector2(spk_cx - 3, spk_cy + 3)
			]), spk_col * 0.7)
			if v_playing:
				var wave_a: float = _voice_playing_timer / 0.6
				draw_arc(Vector2(spk_cx + 5, spk_cy), 5.0, -PI * 0.4, PI * 0.4, 5, Color(icon_col.r, icon_col.g, icon_col.b, wave_a * 0.6), 1.5)
			var vlabel_col: Color = icon_col if v_playing else (UIConstants.TEXT_BRIGHT if v_hover else UIConstants.TEXT_DIM)
			draw_string(font, Vector2(vbtn_x + 22, y + 26), vlabel, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_VOICE_BTN, vlabel_col)
			vbtn_x += vtw + 5
		y += 46
	else:
		_voice_btn_rects.clear()

	# Abilities
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.22, 0.35, 0.48, 0.7), 1.0)
	y += 14
	draw_string(mono, Vector2(x + 10, y + FONT_SECTION), "// ABILITIES", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SECTION, UIConstants.ACCENT_DIM)
	y += FONT_SECTION + 14
	for ability in entry.abilities:
		draw_rect(Rect2(x + 22, y + 8, 7, 7), icon_col * 0.7)
		draw_string(font, Vector2(x + 38, y + FONT_BODY), ability, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, UIConstants.TEXT_NORMAL)
		y += 34
	y += 8

	# Behavioral Analysis
	if entry.has("habits") and entry.habits.length() > 0:
		draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.22, 0.35, 0.48, 0.7), 1.0)
		y += 14
		draw_string(mono, Vector2(x + 10, y + FONT_SECTION), "// BEHAVIORAL ANALYSIS", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SECTION, UIConstants.ACCENT_DIM)
		y += FONT_SECTION + 14
		var habits_lines: Array = _wrap_text(entry.habits, int(panel_w / 15.0))
		for line in habits_lines:
			draw_string(font, Vector2(x + 20, y + FONT_BODY), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, UIConstants.TEXT_NORMAL)
			y += 32
		y += 8

	# Field Notes
	draw_line(Vector2(x + 5, y), Vector2(x + panel_w - 5, y), Color(0.22, 0.35, 0.48, 0.7), 1.0)
	y += 14
	draw_string(mono, Vector2(x + 10, y + FONT_SECTION), "// FIELD NOTES", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SECTION, UIConstants.ACCENT_DIM)
	y += FONT_SECTION + 14
	var desc_lines: Array = _wrap_text(entry.description, int(panel_w / 15.0))
	for line in desc_lines:
		draw_string(font, Vector2(x + 20, y + FONT_BODY), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_BODY, UIConstants.TEXT_NORMAL)
		y += 32

func _draw_footer(s: Vector2) -> void:
	var mono: Font = UIConstants.get_mono_font()
	draw_rect(Rect2(0, s.y - FOOTER_H, s.x, FOOTER_H), Color(0.06, 0.08, 0.14, 0.8))
	draw_line(Vector2(0, s.y - FOOTER_H), Vector2(s.x, s.y - FOOTER_H), Color(UIConstants.ACCENT_DIM.r, UIConstants.ACCENT_DIM.g, UIConstants.ACCENT_DIM.b, 0.2), 1.0)
	draw_string(mono, Vector2(16, s.y - 14), "[X] Close    [Scroll] Navigate    [Click] Select", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIConstants.TEXT_DIM * 0.85)

	# Alien readout on right
	var alien_str: String = UIConstants.random_glyphs(10, _time, 3.0)
	draw_string(mono, Vector2(s.x - 200, s.y - 14), alien_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.40, 0.65, 0.75, 0.50))

func _draw_idle_scanner(x: float, panel_w: float, s: Vector2) -> void:
	var font: Font = UIConstants.get_display_font()
	var mono: Font = UIConstants.get_mono_font()
	var cx: float = x + panel_w * 0.5
	var cy: float = s.y * 0.38

	# Scanner reticle
	var r: float = 65.0 + sin(_time * 2.0) * 5.0
	draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.30), 1.5)
	draw_arc(Vector2(cx, cy), r * 0.6, 0, TAU, 24, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.18), 1.0)

	# Crosshairs
	var ch_len: float = r * 1.3
	draw_line(Vector2(cx - ch_len, cy), Vector2(cx - r * 0.3, cy), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.0)
	draw_line(Vector2(cx + r * 0.3, cy), Vector2(cx + ch_len, cy), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.0)
	draw_line(Vector2(cx, cy - ch_len), Vector2(cx, cy - r * 0.3), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.0)
	draw_line(Vector2(cx, cy + r * 0.3), Vector2(cx, cy + ch_len), Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.25), 1.0)

	# Rotating sweep
	var sweep_angle: float = fmod(_time * 1.5, TAU)
	var sweep_end: Vector2 = Vector2(cx + cos(sweep_angle) * r, cy + sin(sweep_angle) * r)
	draw_line(Vector2(cx, cy), sweep_end, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.40), 1.5)
	draw_circle(sweep_end, 3.0, Color(UIConstants.ACCENT.r, UIConstants.ACCENT.g, UIConstants.ACCENT.b, 0.55))

	draw_string(font, Vector2(cx - 160, cy + r + 30), "SELECT AN ORGANISM", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UIConstants.TEXT_NORMAL.r, UIConstants.TEXT_NORMAL.g, UIConstants.TEXT_NORMAL.b, 0.85))
	draw_string(mono, Vector2(cx - 155, cy + r + 58), "to view xenobiology readout", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIConstants.TEXT_DIM.r, UIConstants.TEXT_DIM.g, UIConstants.TEXT_DIM.b, 0.65))

	# DNA helix decoration
	_draw_helix(Vector2(cx, cy + r + 100), 75.0)

# ======================== BLUEPRINT ICONS ========================

func _draw_blueprint_icon(center: Vector2, radius: float, col: Color, entry: Dictionary, discovered: bool) -> void:
	if not discovered:
		# Gray silhouette — still use creature-specific shape
		_draw_creature_shape(center, radius, Color(0.22, 0.22, 0.25), entry.id, entry.category, 0.5)
		draw_arc(center, radius, 0, TAU, 16, Color(0.32, 0.32, 0.35, 0.45), 1.0)
		var font: Font = UIConstants.get_display_font()
		draw_string(font, Vector2(center.x - 6, center.y + 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.35, 0.35, 0.40))
		return

	_draw_creature_shape(center, radius, col, entry.id, entry.category, 0.8)

func _draw_creature_shape(center: Vector2, radius: float, col: Color, creature_id: String, category: String, alpha: float) -> void:
	var draw_col: Color = Color(col.r, col.g, col.b, alpha)
	var fill_col: Color = Color(col.r, col.g, col.b, alpha * 0.3)

	match creature_id:
		# ---- CELL STAGE ----
		"food_particle":
			# Hexagonal molecule with bonds
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU * i / 6.0
				pts.append(center + Vector2(cos(a), sin(a)) * radius * 0.8)
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 1.5)
			# Inner bonds
			draw_circle(center, radius * 0.25, fill_col)
			for i in range(6):
				var a: float = TAU * i / 6.0
				draw_line(center, center + Vector2(cos(a), sin(a)) * radius * 0.5, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.0)

		"snake_prey":
			# Flagellated oval with tail
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var a: float = TAU * i / 16.0
				var rx: float = radius * 0.6
				var ry: float = radius * 0.9
				pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 1.5)
			# Flagella tail (wavy)
			for i in range(8):
				var t: float = float(i) / 7.0
				var fy: float = center.y + radius + t * radius * 0.8
				var fx: float = center.x + sin(t * TAU * 1.5 + _time * 3.0) * radius * 0.2
				if i > 0:
					var prev_t: float = float(i - 1) / 7.0
					var pfy: float = center.y + radius + prev_t * radius * 0.8
					var pfx: float = center.x + sin(prev_t * TAU * 1.5 + _time * 3.0) * radius * 0.2
					draw_line(Vector2(pfx, pfy), Vector2(fx, fy), Color(draw_col.r, draw_col.g, draw_col.b, alpha * (1.0 - t * 0.5)), 1.5)

		"enemy_cell":
			# Spiky membrane blob
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(12):
				var a: float = TAU * i / 12.0
				var r: float = radius * (0.85 + 0.2 * sin(float(i) * 2.3 + 1.0))
				pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 1.5)
			# Nucleus
			draw_arc(center + Vector2(radius * 0.1, -radius * 0.1), radius * 0.3, 0, TAU, 12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.0)

		"dart_predator":
			# Elongated needle
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -radius * 1.3),
				center + Vector2(radius * 0.3, -radius * 0.3),
				center + Vector2(radius * 0.2, radius * 0.5),
				center + Vector2(radius * 0.4, radius),
				center + Vector2(-radius * 0.4, radius),
				center + Vector2(-radius * 0.2, radius * 0.5),
				center + Vector2(-radius * 0.3, -radius * 0.3),
			])
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 1.5)
			# Speed lines
			for i in range(3):
				var ly: float = center.y + radius * 0.3 + i * radius * 0.25
				draw_line(Vector2(center.x + radius * 0.6, ly), Vector2(center.x + radius * 1.1, ly), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.0)

		"siren_cell":
			# Shapeshifter — half circle, half golden form
			draw_arc(center, radius * 0.9, 0, PI, 16, draw_col, 1.5)
			draw_arc(center, radius * 0.9, PI, TAU, 16, Color(1.0, 0.85, 0.2, alpha * 0.5), 1.5)
			# Center question mark
			draw_circle(center, radius * 0.35, fill_col)
			# Lure glow
			draw_circle(center + Vector2(0, -radius * 0.5), radius * 0.15, Color(1.0, 0.85, 0.2, alpha * 0.4))

		"splitter_cell":
			# Binary fission diagram — one splitting into two
			draw_arc(center + Vector2(-radius * 0.45, 0), radius * 0.5, 0, TAU, 12, draw_col, 1.5)
			draw_arc(center + Vector2(radius * 0.45, 0), radius * 0.5, 0, TAU, 12, draw_col, 1.5)
			draw_circle(center + Vector2(-radius * 0.45, 0), radius * 0.5, fill_col)
			draw_circle(center + Vector2(radius * 0.45, 0), radius * 0.5, fill_col)
			# Division line
			draw_line(center + Vector2(0, -radius * 0.7), center + Vector2(0, radius * 0.7), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.5)
			# Arrow pointing down from middle
			draw_line(center + Vector2(0, radius * 0.3), center + Vector2(0, radius * 0.8), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.0)

		"electric_eel":
			# Sinusoidal body with lightning bolts
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var t: float = float(i) / 15.0
				var ex: float = center.x - radius + t * radius * 2.0
				var ey: float = center.y + sin(t * TAU * 1.5) * radius * 0.4
				pts.append(Vector2(ex, ey))
			draw_polyline(pts, draw_col, 2.0)
			# Lightning bolt
			var bolt_start: Vector2 = center + Vector2(radius * 0.3, -radius * 0.5)
			draw_line(bolt_start, bolt_start + Vector2(-5, 10), Color(0.4, 0.8, 1.0, alpha * 0.6), 2.0)
			draw_line(bolt_start + Vector2(-5, 10), bolt_start + Vector2(5, 15), Color(0.4, 0.8, 1.0, alpha * 0.6), 2.0)
			draw_line(bolt_start + Vector2(5, 15), bolt_start + Vector2(-3, 25), Color(0.4, 0.8, 1.0, alpha * 0.6), 2.0)

		"ink_bomber":
			# Bulbous body + ink clouds
			draw_circle(center, radius * 0.65, fill_col)
			draw_arc(center, radius * 0.65, 0, TAU, 16, draw_col, 1.5)
			# Puffed state outline
			draw_arc(center, radius * 0.9, 0, TAU, 16, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2), 1.0)
			# Ink clouds
			draw_circle(center + Vector2(radius * 0.8, radius * 0.3), radius * 0.25, Color(0.15, 0.1, 0.3, alpha * 0.4))
			draw_circle(center + Vector2(radius * 0.6, radius * 0.6), radius * 0.2, Color(0.15, 0.1, 0.3, alpha * 0.3))

		"leviathan":
			# Massive maw with vacuum lines
			# Body - large arc
			draw_arc(center, radius, PI * 0.3, TAU - PI * 0.3, 20, draw_col, 2.0)
			# Open maw
			var maw_top: Vector2 = center + Vector2(cos(PI * 0.3) * radius, sin(PI * 0.3) * radius)
			var maw_bot: Vector2 = center + Vector2(cos(-PI * 0.3) * radius, sin(-PI * 0.3) * radius)
			var maw_point: Vector2 = center + Vector2(radius * 1.2, 0)
			draw_line(maw_top, maw_point, draw_col, 2.0)
			draw_line(maw_bot, maw_point, draw_col, 2.0)
			# Teeth
			for i in range(4):
				var t: float = float(i + 1) / 5.0
				var tooth_y: float = lerp(maw_top.y, maw_bot.y, t)
				var tooth_x: float = lerp(maw_top.x, maw_bot.x, t)
				draw_line(Vector2(tooth_x, tooth_y), Vector2(tooth_x + radius * 0.15, lerp(maw_top.y, maw_bot.y, 0.5)), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.0)
			# Vacuum suction lines
			for i in range(3):
				var vy: float = center.y - radius * 0.3 + i * radius * 0.3
				draw_line(Vector2(center.x + radius * 1.5, vy), Vector2(center.x + radius * 2.0, vy), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2), 1.0)

		"parasite_organism":
			# Clinging tendrils on a host outline
			# Host circle (dashed)
			for i in range(8):
				var a1: float = TAU * i / 8.0
				var a2: float = a1 + TAU / 16.0
				draw_arc(center, radius, a1, a2, 4, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2), 1.0)
			# Parasite body
			var p_center: Vector2 = center + Vector2(radius * 0.6, -radius * 0.3)
			draw_circle(p_center, radius * 0.3, fill_col)
			draw_arc(p_center, radius * 0.3, 0, TAU, 10, draw_col, 1.5)
			# Tendrils reaching to host
			for i in range(3):
				var a: float = PI + float(i) * PI * 0.3 - PI * 0.3
				var end: Vector2 = p_center + Vector2(cos(a), sin(a)) * radius * 0.5
				draw_line(p_center, end, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6), 1.0)

		"danger_zone":
			# Radiation/toxicity symbol
			var pts: PackedVector2Array = PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius * 0.87, radius * 0.5),
				center + Vector2(-radius * 0.87, radius * 0.5),
			])
			pts.append(pts[0])
			draw_colored_polygon(pts, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.15))
			draw_polyline(pts, draw_col, 2.0)
			# Inner circle
			draw_circle(center, radius * 0.25, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))
			# Pulse rings
			var pulse_r: float = radius * (0.5 + fmod(_time * 0.5, 0.5))
			draw_arc(center, pulse_r, 0, TAU, 16, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.15 * (1.0 - fmod(_time * 0.5, 0.5) * 2.0)), 1.0)

		"repeller":
			# Radial anemone tentacles with force field
			# Central disc
			draw_circle(center, radius * 0.3, fill_col)
			draw_arc(center, radius * 0.3, 0, TAU, 12, draw_col, 1.5)
			# Tentacles
			for i in range(10):
				var a: float = TAU * i / 10.0
				var end: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.9
				draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.35, end, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6), 1.0)
				draw_circle(end, 2.0, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4))
			# Force field ring
			draw_arc(center, radius, 0, TAU, 20, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2), 1.5)

		"kin_organism":
			# Friendly marker — heart/shield shape with smile
			draw_circle(center, radius * 0.7, fill_col)
			draw_arc(center, radius * 0.7, 0, TAU, 16, draw_col, 1.5)
			# Friendly indicator (small star)
			var star_pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU * i / 8.0 - PI * 0.5
				var r: float = radius * (0.2 if i % 2 == 0 else 0.12)
				star_pts.append(center + Vector2(0, -radius * 0.2) + Vector2(cos(a) * r, sin(a) * r))
			star_pts.append(star_pts[0])
			draw_colored_polygon(star_pts, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))
			# Alliance circles (orbiting)
			draw_arc(center, radius, 0, TAU, 16, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.15), 1.0)

		"oculus_titan":
			# Multi-eye pattern
			draw_arc(center, radius, 0, TAU, 20, draw_col, 2.0)
			draw_circle(center, radius, fill_col)
			# Eyes scattered
			var eye_positions: Array = [
				Vector2(0, 0), Vector2(-0.4, -0.3), Vector2(0.4, -0.3),
				Vector2(-0.3, 0.3), Vector2(0.3, 0.3), Vector2(0, -0.5),
				Vector2(-0.5, 0), Vector2(0.5, 0),
			]
			for ep in eye_positions:
				var epos: Vector2 = center + Vector2(ep.x * radius * 0.8, ep.y * radius * 0.8)
				draw_circle(epos, radius * 0.1, Color(1.0, 0.3, 0.2, alpha * 0.7))
				draw_circle(epos, radius * 0.05, Color(0.0, 0.0, 0.0, alpha * 0.8))

		"juggernaut":
			# Armored plates
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU * i / 8.0 - PI * 0.5
				pts.append(center + Vector2(cos(a) * radius, sin(a) * radius))
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 2.0)
			# Armor plate lines
			for i in range(4):
				var a: float = TAU * i / 4.0
				draw_line(center, center + Vector2(cos(a), sin(a)) * radius, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.0)
			# Central core
			draw_circle(center, radius * 0.25, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))

		"basilisk":
			# Shield front + vulnerable rear
			# Front shield (thick arc)
			draw_arc(center, radius, -PI * 0.5, PI * 0.5, 16, draw_col, 3.0)
			# Rear body (thin, dashed)
			for i in range(4):
				var a1: float = PI * 0.5 + float(i) * PI * 0.25
				var a2: float = a1 + PI * 0.15
				draw_arc(center, radius * 0.8, a1, a2, 6, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.0)
			# Spine projectiles
			for i in range(3):
				var sx: float = center.x + radius * 0.5
				var sy: float = center.y - radius * 0.4 + i * radius * 0.4
				draw_line(Vector2(sx, sy), Vector2(sx + radius * 0.5, sy), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.0)
				draw_circle(Vector2(sx + radius * 0.5, sy), 1.5, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))

		# ---- PARASITE STAGE ----
		"red_blood_cell":
			# Biconcave disc (side view)
			draw_arc(center, radius * 0.85, 0, TAU, 20, draw_col, 1.5)
			draw_circle(center, radius * 0.85, fill_col)
			# Concavity dips
			draw_arc(center, radius * 0.4, 0, TAU, 12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2), 1.0)

		"platelet":
			# Irregular fragment cluster
			var offsets: Array = [Vector2(-0.3, -0.2), Vector2(0.2, -0.3), Vector2(0.3, 0.15), Vector2(-0.1, 0.35), Vector2(-0.35, 0.1)]
			for off in offsets:
				var frag_center: Vector2 = center + Vector2(off.x * radius, off.y * radius)
				var frag_r: float = radius * randf_range(0.2, 0.35)
				# Use seeded sizes for consistency
				frag_r = radius * (0.22 + abs(off.x) * 0.3)
				draw_circle(frag_center, frag_r, fill_col)
				draw_arc(frag_center, frag_r, 0, TAU, 8, draw_col, 1.0)

		"microbiome_bacteria":
			# Rod shape (capsule)
			var half_len: float = radius * 0.7
			draw_line(center + Vector2(0, -half_len), center + Vector2(0, half_len), draw_col, radius * 0.5)
			draw_circle(center + Vector2(0, -half_len), radius * 0.25, fill_col)
			draw_circle(center + Vector2(0, half_len), radius * 0.25, fill_col)
			draw_arc(center + Vector2(0, -half_len), radius * 0.25, 0, TAU, 8, draw_col, 1.0)
			draw_arc(center + Vector2(0, half_len), radius * 0.25, 0, TAU, 8, draw_col, 1.0)
			# Flagella
			for i in range(3):
				var fy: float = center.y + half_len + radius * 0.15 * (i + 1)
				var fx: float = center.x + sin(float(i) * 1.5 + _time * 2.0) * radius * 0.15
				draw_circle(Vector2(fx, fy), 1.0, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3))

		"cilia_plankton":
			# Feathery tendrils from central body
			draw_circle(center, radius * 0.3, fill_col)
			draw_arc(center, radius * 0.3, 0, TAU, 12, draw_col, 1.0)
			# Cilia feathers
			for i in range(12):
				var a: float = TAU * i / 12.0
				var base: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.35
				var tip: Vector2 = center + Vector2(cos(a), sin(a)) * radius * (0.85 + sin(_time * 2.0 + float(i)) * 0.1)
				draw_line(base, tip, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.0)

		"prey_bug":
			# Small bug with legs
			var body_pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU * i / 8.0
				var rx: float = radius * 0.5
				var ry: float = radius * 0.7
				body_pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
			body_pts.append(body_pts[0])
			draw_colored_polygon(body_pts, fill_col)
			draw_polyline(body_pts, draw_col, 1.5)
			# Legs
			for i in range(3):
				var ly: float = center.y - radius * 0.3 + i * radius * 0.3
				draw_line(Vector2(center.x - radius * 0.5, ly), Vector2(center.x - radius * 0.9, ly - radius * 0.15), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.0)
				draw_line(Vector2(center.x + radius * 0.5, ly), Vector2(center.x + radius * 0.9, ly - radius * 0.15), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.0)

		"land_nutrient":
			# Glowing sphere with inner sparkle
			draw_circle(center, radius * 0.65, fill_col)
			draw_arc(center, radius * 0.65, 0, TAU, 16, draw_col, 1.5)
			# Inner sparkle
			draw_circle(center + Vector2(-radius * 0.15, -radius * 0.15), radius * 0.15, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))
			# Outer glow ring
			draw_arc(center, radius * 0.9, 0, TAU, 16, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.15), 1.5)

		"golden_nutrient":
			# Golden shimmer orb
			draw_circle(center, radius * 0.6, Color(1.0, 0.85, 0.2, alpha * 0.3))
			draw_arc(center, radius * 0.6, 0, TAU, 16, Color(1.0, 0.85, 0.2, alpha * 0.8), 1.5)
			# Shimmer rays
			for i in range(6):
				var a: float = TAU * i / 6.0 + _time * 0.5
				var inner: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.65
				var outer: Vector2 = center + Vector2(cos(a), sin(a)) * radius
				draw_line(inner, outer, Color(1.0, 0.9, 0.3, alpha * 0.3), 1.0)

		"white_blood_cell":
			# Irregular blob with pseudopods
			var pts: PackedVector2Array = PackedVector2Array()
			var offsets_wbc: Array = [1.0, 0.85, 1.1, 0.75, 0.95, 1.15, 0.8, 1.05, 0.9, 1.0, 0.88, 1.08]
			for i in range(12):
				var a: float = TAU * i / 12.0
				var r: float = radius * offsets_wbc[i]
				pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 1.5)
			# Multi-lobed nucleus
			draw_arc(center + Vector2(-radius * 0.15, 0), radius * 0.2, 0, TAU, 8, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.0)
			draw_arc(center + Vector2(radius * 0.15, 0), radius * 0.2, 0, TAU, 8, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.0)

		"antibody_flyer":
			# Y-shaped antibody
			var stem_bot: Vector2 = center + Vector2(0, radius * 0.8)
			var stem_mid: Vector2 = center + Vector2(0, -radius * 0.1)
			draw_line(stem_bot, stem_mid, draw_col, 2.5)
			# Y branches
			var branch_l: Vector2 = center + Vector2(-radius * 0.7, -radius * 0.8)
			var branch_r: Vector2 = center + Vector2(radius * 0.7, -radius * 0.8)
			draw_line(stem_mid, branch_l, draw_col, 2.0)
			draw_line(stem_mid, branch_r, draw_col, 2.0)
			# Binding sites (tips)
			draw_circle(branch_l, radius * 0.12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6))
			draw_circle(branch_r, radius * 0.12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6))
			draw_circle(stem_bot, radius * 0.1, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4))

		"phagocyte":
			# Massive engulfing membrane
			draw_circle(center, radius * 0.9, fill_col)
			draw_arc(center, radius * 0.9, 0, TAU, 20, draw_col, 2.0)
			# Engulfing pseudopod (open mouth shape)
			draw_arc(center + Vector2(radius * 0.5, 0), radius * 0.5, PI * 0.6, TAU - PI * 0.6, 10, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 1.5)
			# Internal vesicles
			draw_circle(center + Vector2(-radius * 0.2, -radius * 0.15), radius * 0.12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3))
			draw_circle(center + Vector2(-radius * 0.1, radius * 0.25), radius * 0.1, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.25))

		"killer_t_cell":
			# Stealth silhouette — semi-transparent outline
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				var a: float = TAU * i / 8.0
				var r: float = radius * (0.8 + 0.15 * float(i % 2))
				pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			pts.append(pts[0])
			# Dashed outline effect
			for i in range(pts.size() - 1):
				if i % 2 == 0:
					draw_line(pts[i], pts[i + 1], Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6), 1.5)
			# Ghostly fill
			draw_colored_polygon(pts, Color(fill_col.r, fill_col.g, fill_col.b, fill_col.a * 0.4))
			# Lunge arrow
			draw_line(center + Vector2(0, -radius * 0.3), center + Vector2(0, -radius * 1.1), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.5)

		"mast_cell":
			# Round body with granules and projectile
			draw_circle(center, radius * 0.7, fill_col)
			draw_arc(center, radius * 0.7, 0, TAU, 16, draw_col, 1.5)
			# Interior granules
			for i in range(6):
				var gx: float = center.x + cos(float(i) * 1.2) * radius * 0.35
				var gy: float = center.y + sin(float(i) * 1.7) * radius * 0.35
				draw_circle(Vector2(gx, gy), radius * 0.08, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4))
			# Projectile
			var proj_start: Vector2 = center + Vector2(radius * 0.7, 0)
			draw_line(proj_start, proj_start + Vector2(radius * 0.5, 0), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5), 2.0)
			draw_circle(proj_start + Vector2(radius * 0.5, 0), 2.5, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6))

		"macrophage_queen":
			# Crown + massive body + pseudopod arms
			var crown_pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var a: float = TAU * i / 10.0 - PI * 0.5
				var r: float = radius * (1.1 if i % 2 == 0 else 0.6)
				crown_pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			crown_pts.append(crown_pts[0])
			draw_colored_polygon(crown_pts, Color(fill_col.r, fill_col.g, fill_col.b, fill_col.a * 0.6))
			draw_polyline(crown_pts, draw_col, 2.5)
			# Pseudopod arms
			for i in range(4):
				var a: float = TAU * i / 4.0 + PI * 0.25
				var end: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 1.5
				draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.8, end, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 2.0)
				draw_circle(end, 3.0, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.5))

		"cardiac_colossus":
			# Pulsing heart shape
			var heart_scale: float = 1.0 + sin(_time * 3.0) * 0.05
			var hr: float = radius * heart_scale
			# Simplified heart using arcs
			draw_arc(center + Vector2(-hr * 0.35, -hr * 0.15), hr * 0.45, PI, TAU + PI * 0.1, 12, draw_col, 2.0)
			draw_arc(center + Vector2(hr * 0.35, -hr * 0.15), hr * 0.45, -PI * 0.1, PI, 12, draw_col, 2.0)
			# Bottom point
			draw_line(center + Vector2(-hr * 0.8, hr * 0.05), center + Vector2(0, hr * 0.9), draw_col, 2.0)
			draw_line(center + Vector2(hr * 0.8, hr * 0.05), center + Vector2(0, hr * 0.9), draw_col, 2.0)
			# Pulse rings
			var pulse_r: float = hr * (0.5 + fmod(_time * 0.8, 0.5))
			draw_arc(center, pulse_r, 0, TAU, 16, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.1 * (1.0 - fmod(_time * 0.8, 0.5) * 2.0)), 1.0)

		"gut_warden":
			# Tentacle vines central body
			draw_circle(center, radius * 0.5, fill_col)
			draw_arc(center, radius * 0.5, 0, TAU, 16, draw_col, 1.5)
			# Tentacle vines
			for i in range(6):
				var a: float = TAU * i / 6.0
				var mid: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.7
				var tip: Vector2 = center + Vector2(cos(a + 0.3), sin(a + 0.3)) * radius * 1.1
				draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.5, mid, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.6), 1.5)
				draw_line(mid, tip, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.4), 1.0)
			# Acid drip
			draw_circle(center + Vector2(0, radius * 1.0), radius * 0.08, Color(0.5, 0.8, 0.1, alpha * 0.5))

		"alveolar_titan":
			# Spongy inflatable body
			var inflate: float = 1.0 + sin(_time * 2.0) * 0.08
			var ar: float = radius * inflate
			draw_circle(center, ar * 0.85, fill_col)
			draw_arc(center, ar * 0.85, 0, TAU, 20, draw_col, 1.5)
			# Sponge pores
			for i in range(8):
				var px: float = center.x + cos(float(i) * 0.9 + 0.5) * ar * 0.5
				var py: float = center.y + sin(float(i) * 1.3 + 0.3) * ar * 0.5
				draw_circle(Vector2(px, py), ar * 0.08, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.2))
			# Wind gust lines
			for i in range(3):
				var wy: float = center.y - ar * 0.3 + i * ar * 0.3
				draw_line(Vector2(center.x + ar, wy), Vector2(center.x + ar * 1.6, wy + 3), Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.0)

		"marrow_sentinel":
			# Bone armor construct
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var a: float = TAU * i / 6.0 - PI * 0.5
				var r: float = radius * (1.0 + 0.1 * float(i % 2))
				pts.append(center + Vector2(cos(a) * r, sin(a) * r))
			pts.append(pts[0])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(pts, draw_col, 2.5)
			# Bone spike protrusions
			for i in range(3):
				var a: float = TAU * i / 3.0 - PI * 0.5
				var spike_base: Vector2 = center + Vector2(cos(a), sin(a)) * radius
				var spike_tip: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 1.4
				draw_line(spike_base, spike_tip, draw_col, 2.0)
			# Calcium shield shimmer
			draw_arc(center, radius * 0.5, 0, TAU, 12, Color(draw_col.r, draw_col.g, draw_col.b, alpha * 0.3), 1.5)

		_:
			# Generic fallback
			draw_circle(center, radius * 0.7, fill_col)
			draw_arc(center, radius * 0.7, 0, TAU, 16, draw_col, 1.5)

# ======================== VFX ========================

func _draw_discovery_vfx(center: Vector2, radius: float, time_remaining: float) -> void:
	var t: float = 3.0 - time_remaining
	var alpha: float = clampf(1.0 - t / 3.0, 0.0, 1.0)

	# Expanding golden pulse ring
	var pulse_r: float = radius + t * 12.0
	draw_arc(center, pulse_r, 0, TAU, 24, Color(1.0, 0.85, 0.2, alpha * 0.5), 2.5)

	# Sparkles rotating around the entry
	for i in range(8):
		var a: float = TAU * i / 8.0 + t * 0.8
		var sparkle_r: float = radius + 8.0 + sin(t * 5.0 + float(i)) * 3.0
		var sparkle_pos: Vector2 = center + Vector2(cos(a), sin(a)) * sparkle_r
		var sparkle_size: float = 2.5 + sin(t * 8.0 + float(i) * 1.3) * 1.5
		draw_circle(sparkle_pos, maxf(sparkle_size, 0.5), Color(1.0, 0.9, 0.3, alpha * 0.7))

	# Inner glow
	draw_circle(center, radius, Color(1.0, 0.85, 0.2, alpha * 0.12))

func _draw_scanner_reticle(center: Vector2, radius: float, col: Color, alpha: float) -> void:
	# Corner ticks
	var tick_len: float = 10.0
	for i in range(4):
		var a: float = TAU * i / 4.0 + PI * 0.25
		var p1: Vector2 = center + Vector2(cos(a), sin(a)) * radius
		var p2: Vector2 = center + Vector2(cos(a), sin(a)) * (radius + tick_len)
		draw_line(p1, p2, Color(col.r, col.g, col.b, alpha), 1.5)
	# Crosshair
	var ch: float = radius * 0.25
	draw_line(center + Vector2(-ch, 0), center + Vector2(ch, 0), Color(col.r, col.g, col.b, alpha * 0.5), 1.0)
	draw_line(center + Vector2(0, -ch), center + Vector2(0, ch), Color(col.r, col.g, col.b, alpha * 0.5), 1.0)

func _draw_helix(center: Vector2, height: float) -> void:
	var steps: int = 28
	for i in range(steps):
		var t: float = float(i) / steps
		var y: float = center.y - height * 0.5 + t * height
		var x1: float = center.x + sin(t * TAU * 2.0 + _time) * 18.0
		var x2: float = center.x - sin(t * TAU * 2.0 + _time) * 18.0
		var a: float = 0.25 + sin(t * PI) * 0.2
		draw_circle(Vector2(x1, y), 1.5, Color(0.40, 0.85, 0.60, a))
		draw_circle(Vector2(x2, y), 1.5, Color(0.60, 0.85, 0.40, a))
		if i % 4 == 0:
			draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.50, 0.75, 0.50, a * 0.6), 1.0)

# ======================== HELPERS ========================

func _category_color(cat: String) -> Color:
	match cat:
		"PREY": return Color(0.3, 0.8, 0.4)
		"PREDATOR": return Color(0.8, 0.35, 0.25)
		"HAZARD": return Color(0.9, 0.6, 0.15)
		"BOSS": return Color(0.8, 0.3, 0.8)
		"UTILITY": return Color(0.3, 0.8, 0.7)
		"AMBIENT": return Color(0.4, 0.7, 0.8)
		"ENEMIES": return Color(0.8, 0.4, 0.3)
	return Color(0.5, 0.5, 0.5)

func _get_threat_level(entry: Dictionary) -> int:
	var score: float = 0.0
	score += entry.damage * 0.15
	score += entry.speed * 0.2
	if entry.category == "BOSS":
		score += 2.0
	elif entry.category == "HAZARD":
		score += 1.0
	elif entry.category in ["PREDATOR", "ENEMIES"]:
		score += 0.5
	return clampi(int(score), 0, 5)

func _wrap_text(text: String, max_chars: int) -> Array:
	var words: PackedStringArray = text.split(" ")
	var lines: Array = []
	var current_line: String = ""
	for word in words:
		if current_line.length() + word.length() + 1 > max_chars:
			lines.append(current_line)
			current_line = word
		else:
			if current_line.length() > 0:
				current_line += " "
			current_line += word
	if current_line.length() > 0:
		lines.append(current_line)
	return lines
