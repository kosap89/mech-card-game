# Mech Card Game

Mech Card Game is an experimental real-time mech-building card game prototype made with Godot 4 and GDScript. Players build and modify a mech during a match using weapon cards while both sides fight automatically.

This is an early MVP focused on validating a fast, readable, flow-first core loop. Visuals, balance values, card names, and several rules remain temporary.

## Current gameplay

Player 1 faces a simple AI opponent. Each mech has four generic weapon slots and a permanent built-in cannon that automatically attacks the opposing main mech. Scrap is generated over time, weapon cards are drawn into the player's hand, and affordable cards can be installed into empty slots.

New weapons require construction time before becoming active. Once active, they fire automatically according to their own activation interval and can take damage or be destroyed. Player 1 assigns a target independently to each installed weapon; valid targets are the enemy main mech or an active enemy weapon. The AI uses the same targeting options against Player 1. Weapons still under construction cannot be targeted, while both built-in cannons always fire at the opposing main mech.

Destroyed active weapons explode and damage their owner's main mech by their own Damage value. Combat destruction returns no Scrap. Trash safely removes a weapon, returns the configured amount of Scrap, and causes no explosion. Replace is no longer part of the current rules: a weapon must first be Trashed or destroyed before another card can use its slot.

A match ends immediately when either main mech reaches zero Health. There is no match countdown and damage totals do not determine the winner.

## MVP weapon set

The active test deck contains ten functional automatic weapons:

- Light Cannon
- Heavy Cannon
- Autocannon
- Siege Cannon
- Twin Cannon
- Pulse Gun
- Rail Cannon
- Rotary Gun
- Plasma Cannon
- Mortar

They currently differ through temporary Scrap cost, damage, Health, firing interval, and construction time values. Their names and balance are not final, and special weapon abilities are not implemented.

## Board and interface

The placeholder interface uses a top-versus-bottom board layout with the AI opponent above the battlefield and the human player below it. It includes:

- Four weapon modules for each mech
- Player 1's hand along the bottom
- Scrap and mech Health displays
- Live weapon activation and construction countdowns
- Current target information for active weapons
- Brief red damage-flash feedback for damaged mechs and weapon modules
- Development/debug controls and match restart

The desktop layout targets 1280×720 and remains usable around 1024×640. It is functional prototype UI, not the final art direction.

## Opponent AI

Player 2 is controlled by a lightweight automated opponent. It draws and builds weapons through the normal hand, Scrap, slot, and construction rules. Each active AI weapon can independently choose the Player 1 main mech or an active Player 1 weapon as its target.

Target selection is intentionally simple. The AI does not yet perform advanced threat evaluation, coordinated focus fire, or smart Trash decisions.

## Balance Settings editor

The in-game development editor provides separate Game Settings and Weapon Settings sections so the prototype can be tuned without editing source files.

Game settings include mech Health, built-in cannon values, Scrap generation and returns, hand/draw timing, and AI pacing. Every active weapon exposes Cost, Damage, Health, Fire Interval, and Build Time.

Applied settings persist between application launches. Three preset save/load slots are available, and Reset to Defaults restores the repository's baseline values in the editor. This is a development tuning tool, not a consumer-facing options menu.

## Implementation

- Godot 4.x and GDScript
- Data-driven `CardData` resources
- Centralized defaults with duplicated runtime balance/card configuration
- Separate player, mech, installed-part, match, AI, and presentation responsibilities
- Lightweight headless smoke tests for gameplay and UI behavior

The architecture remains intentionally modest and prototype-oriented.

## Development status

**Current prototype: core gameplay systems implemented through Phase 18.**

The playable loop currently includes real-time Scrap generation and card draw, construction, automatic combat, per-weapon targeting, weapon Health and destruction, explosion risk, safe Trash actions, AI play and targeting, match resolution, restart, runtime balance editing, presets, and development feedback tools.

The project is now entering a gameplay testing and tuning stage. Current priorities are flow testing, balance iteration, match pacing, construction timing, Scrap economy, and the targeting-versus-Trash risk/reward decision. Further mechanics should be driven by what playtesting shows the core loop actually needs.

## Possible future directions

Depending on playtesting, future work may explore smarter AI targeting and Trash behavior, richer combat feedback, projectiles, explosion animations, sound, damage numbers, distinct weapon abilities, defensive/support modules, shields, repair, armor, helper units or summons, broader deck/mech systems, multiplayer, and final visual design and balance.

These are possible directions rather than committed features.

## Project documentation

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — evolving game-design reference
- [`docs/MVP_SPEC.md`](docs/MVP_SPEC.md) — evolving technical MVP reference and implementation history

These documents contain useful design context but also retain older rules and unresolved ideas that may not match the current prototype.

## Development philosophy

Gameplay feel and flow take priority over feature count. Systems are added incrementally, and temporary values and placeholder visuals are intentional during MVP development. Increasingly, future work is guided by actual playtesting rather than expanding the design spec by assumption.

## Status

**Early prototype / work in progress**
