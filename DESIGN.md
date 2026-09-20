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

### 2.2 The 3-Pillars Combat Triangle
Actions are balanced around a distinct tactical loop: Power Move, Turtle Punish, Risky Turnaround, and Hard Shutdown:

| Action | Input Gesture | Tactical Profile | vs. Cannon | vs. Sail | vs. Board |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Port Cannon** | ⬅️ Swipe Left | Primary Firepower (3t CD) | Full damage to both (15 HP) | Punishes turtles: deals 8 chip damage; takes 0 | Point-blank exchange: deals 15 HP, but takes 25 HP + Sabotaged (+1 CD) |
| **Starboard Cannon** | ➡️ Swipe Right | Primary Firepower (3t CD) | Full damage to both (15 HP) | Punishes turtles: deals 8 chip damage; takes 0 | Point-blank exchange: deals 15 HP, but takes 25 HP + Sabotaged (+1 CD) |
| **Sail (Maneuver)** | ⬆️ Swipe Up | Evasive & Board Shutdown | Takes 8 chip damage; deals 0 | Neutral stalemate (0 HP) | **Total Shutdown:** cleanly evades grapple and rams for 15 HP; takes 0 HP (free of ammo cost)! |
| **Board (Grapple)** | ⬇️ Swipe Down | High-Risk Turnaround Dive | **Turnaround:** deals 25 HP + Sabotages opponent guns (+1 CD); takes 15 HP | **Hard Countered:** completely shut down by Sail (takes 15 HP, deals 0) | Cutlass clash: 10 HP damage to both ships |

* **Cannon (The Power Move):** 15 HP workhorse. Great damage, but restricted by a 3-turn reload cycle on each broadside. Punishes players who try to play too safe (deals 8 chip damage to sails).
* **Sail (The Hard-Read Shutdown):** The anti-grapple shield. When the opponent goes for a desperate or spammy Board, Sail completely shuts it down for 15 damage without consuming ammo.
* **Board (The High-Risk Turnaround):** The comeback mechanic. When you are low on HP or behind on cooldowns, playing safe will let the enemy chip you down with cannons. Swiping Board is your high-stakes gamble: if the winning player carelessly shoots Cannon, Board deals 25 critical damage and sabotages their guns. But if the winning player reads your desperation and Sails, you are completely shut down!

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
