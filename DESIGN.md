# Rogue Swipe — Game Design Document (GDD)

**Project Name:** Rogue Swipe (formerly *Rock, Pirate, Swipe*)  
**Engine:** Godot Engine 4.3+ (Compatibility Renderer — WebGL2 / OpenGL3)  
**Target Platforms:** 
1. Web (HTML5 playable demo / itch.io)
2. Mobile (iOS & Android commercial release)
3. Desktop (Steam / itch.io)
**Genre:** Turn-based Tactical Roguelike / Swiper  
**Visual Style:** Cute 2D Pirate (Chibi ships, expressive bobbing crew, vibrant cartoon sea aesthetic)

---

## 1. Executive Summary & Core Concept

**Rogue Swipe** is a fast-paced, tactical 2D pirate game built on an asymmetric Rock-Paper-Scissors combat engine. Players control a cute pirate ship engaged in tense ship-to-ship duels on the high seas, inputting maneuvers via directional swipes.

The game is designed to be instantly playable in modern web browsers while scaling cleanly to mobile touchscreens and desktop.

---

## 2. Core Combat System

Combat is simultaneous turn-based. Each turn, both the player and enemy ship commit an action, which resolves simultaneously with animated feedback.

### 2.1 Health & Victory Condition
* **Single Health Bar:** Each ship has a single HP meter (Hull Integrity / Ship Health).
* **Victory:** Reduce enemy ship HP to 0 (sinks the enemy ship).
* **Defeat:** Player ship HP reaches 0.

### 2.2 Asymmetric Combat Triangle
Actions are not mathematically symmetrical; each move has a distinct tactical profile:

| Action | Input Gesture | Tactical Profile | vs. Cannon | vs. Sail | vs. Board |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Port Cannon** | ⬅️ Swipe Left | Reliable Ranged | Full damage to both (15 HP) | Half damage dealt (8 HP); none taken | Deals full damage (15 HP); takes massive damage (25 HP) + Sabotaged (+1 CD) |
| **Starboard Cannon** | ➡️ Swipe Right | Reliable Ranged | Full damage to both (15 HP) | Half damage dealt (8 HP); none taken | Deals full damage (15 HP); takes massive damage (25 HP) + Sabotaged (+1 CD) |
| **Sail (Maneuver)** | ⬆️ Swipe Up | Low Risk / Evasive | Takes half damage (8 HP); deals none | No damage dealt or taken | Full damage dealt (15 HP); none taken |
| **Board (Grapple)** | ⬇️ Swipe Down | High Risk / High Reward | Deals massive damage (25 HP) + Sabotages (+1 CD); takes full damage (15 HP) | Takes full damage (15 HP); deals none | Moderate damage to both (10 HP) |

* **Cannon (Reliable):** Consistent damage dealer. Clashes evenly with broadsides and deals glancing half-damage against sails. When grappled, cannons fire point-blank for full damage, but suffer massive boarding damage and have their guns spiked (+1 turn added to reload cooldowns).
* **Sail (Low Risk):** Defensive outmaneuvering. Mitigates cannon fire to 50%, completely avoids and punishes boarding via ramming/kiting, and results in a safe neutral stalemate against enemy sails.
* **Board (High Risk, High Reward):** Devastating high-impact strike against cannons. Takes point-blank cannon fire in the approach, but inflicts much higher critical damage upon storming the enemy deck AND sabotages the opponent's cannons (+1 reload cooldown). Heavily countered by evasive sails.

### 2.3 Cannon Cooldown Rule
* **Port Cannon (Left)** and **Starboard Cannon (Right)** each have an independent **3-turn cooldown**.
* *Example Sequence:*
  * Turn 1: Fire Port Cannon (Left) ➔ Port Cannon on cooldown.
  * Turn 2: Fire Starboard Cannon (Right) ➔ Starboard Cannon on cooldown.
  * Turn 3: Both cannons are reloading! You **must** either **Sail** (Up) or **Board** (Down).
* This rule prevents cannon-spamming and forces natural tactical rotation.

---

## 3. Input & Control Scheme

* **Mobile / Web Touch / Mouse:**
  * ⬆️ **Swipe Up:** Sail / Maneuver
  * ⬅️ **Swipe Left:** Fire Port Broadside
  * ➡️ **Swipe Right:** Fire Starboard Broadside
  * ⬇️ **Swipe Down:** Grapple & Board
* **Keyboard / Mouse Fallback (Web & Desktop Accessibility):**
  * `W` or `Up Arrow`: Sail
  * `A` or `Left Arrow`: Port Cannon
  * `D` or `Right Arrow`: Starboard Cannon
  * `S` or `Down Arrow`: Board
  * Clickable on-screen action buttons (active during prototype & as accessibility toggle).

---

## 4. Phased Development Roadmap for Autonomous Agents & Devs

To ensure rapid, testable progress and avoid getting bogged down in assets early, development follows strict milestones:

### Phase 1: Mechanics & Logic Prototype (Greybox / Clickable)
* **Goal:** Validate combat balance, asymmetric RPS feel, and cannon cooldowns.
* **Requirements:**
  * Zero art assets (Godot `ColorRect`, `Label`, and simple `Button` nodes).
  * 4 clickable buttons (Sail, Port Cannon, Starboard Cannon, Board).
  * Ship HP counters and visual cooldown indicators (Turn countdown timers on cannons).
  * Basic AI with telegraphed or probabilistic movesets.
  * Combat log showing turn-by-turn math and damage resolution.

### Phase 2: Swipe Gesture Engine & Controls
* **Goal:** Convert button inputs into natural, responsive touch/mouse gestures.
* **Requirements:**
  * Directional swipe detection script with customizable deadzones and sensitivity.
  * Visual swipe trail / feedback arrow.
  * Keyboard & button fallback remains functional for testing.

### Phase 3: Art Style & Concept Exploration ("Cute 2D Pirate")
* **Goal:** Establish visual identity and create modular 2D assets.
* **Visual Direction:**
  * Cute, vibrant chibi pirate ships (oversized cannons, expressive hulls).
  * Bobbing water animation / 2D parallax ocean background.
  * Visual state indicators on the ship:
    * Smoking/cooling cannons during cooldown.
    * Billowing/furling sails during maneuvers.
    * Tiny cute crew members jumping with cutlasses during boarding.
    * Visible cracks/creaks as HP drops.

### Phase 4: Combat Juice & Game Feel
* **Goal:** Make every swipe and impact feel punchy and rewarding.
* **Requirements:**
  * 2D particle systems: cannon smoke, water splashes, wood splinters.
  * Screen shake and floating combat text (+CRIT!, -15 HP, DODGED!).
  * Audio: cannon thuds, comical pirate voice quips ("Avast!", "Fire!"), sea shanty music.

### Phase 5: The "Rogue" System (Sea Chart, Items, & Progression)
* **Goal:** Build the replayable roguelike campaign loop.
* **Requirements:**
  * Node-based Sea Chart (choose route between islands, ports, storm zones, and boss battles).
  * Relic / Item system (e.g., *Captain's Spyglass* reveals enemy intent, *Rum Rations* boosts boarding damage, *Reinforced Hull* raises max HP).
  * Random events & repair stops at island ports.
  * Boss encounters (Ghost Galleon, Kraken, Royal Navy Flagship).

### Phase 6: Multiplatform Packaging & Polishing
* **Goal:** Production-ready exports.
* **Requirements:**
  * Web (HTML5) export optimization for itch.io / web portals.
  * Android (Google Play) & iOS (App Store) touch & aspect ratio handling (safe area notches, portrait/landscape auto-scaling).

---

## 5. Technical Stack & Godot Configuration

* **Engine:** Godot 4.3+
* **Renderer:** `Compatibility` (essential for universal WebGL2 web export and low-end mobile support).
* **Architecture:**
  * `BattleManager.gd`: Orchestrates turn phases (Player Input -> AI Choice -> Resolution -> Animation -> Next Turn).
  * `ShipData.gd` (`Resource`): Holds stats (Max HP, Current HP, Cannon Cooldowns, Damage Values) for player and enemy variants.
  * `SwipeDetector.gd`: Standalone reusable node capturing swipe vectors and dispatching typed signals.
  * `CombatResolver.gd`: Pure logic script calculating RPS outcomes and applying damage multipliers.
