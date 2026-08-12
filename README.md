# Mech Card Game

Mech Card Game is an experimental real-time card game prototype where players build and modify mechs during a short match. The project is currently focused on validating its core gameplay systems and flow rather than graphics or production-ready features.

## Core concept

The intended gameplay includes:

- Real-time card gameplay
- Building a mech during the match
- Four generic mech part slots
- Automatically operating mech components
- Scrap as the primary resource
- Installing, replacing, and scrapping mech parts
- Targeted attacks against enemy components
- Short, predictable matches
- Flow-first game design

Many of these mechanics are planned and are not implemented yet.

## Current prototype status

The current Phase 1–3 prototype includes:

- A Godot project that launches successfully
- A local match state
- Two mech states, each with four generic slots
- A match timer that counts down from three minutes
- Mech health and damage-tracking architecture
- Winner and draw calculation
- Match restart logic
- Temporary debug damage controls
- Independently generated Scrap for both players
- Scrap affordability, spending, and debug-testing controls

Cards, automatic combat, AI, and other later gameplay systems are not implemented.

## Planned MVP systems

- Cards and hand
- Automatic card draw
- Installing mech parts
- Automatic combat
- Trash
- Replace
- Targeting
- Destructible mech parts
- Basic helper robots

## Tech

- Godot 4.x
- GDScript

## Project documentation

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) – current game-design source of truth
- [`docs/MVP_SPEC.md`](docs/MVP_SPEC.md) – technical MVP specification and implementation plan

## Development philosophy

Flow is the highest-level game-design priority. The project is intentionally being built incrementally, and placeholder graphics and temporary balance values are expected during MVP development. Undefined game-design decisions should not be silently invented during implementation.

## Status

**Early prototype / work in progress**
