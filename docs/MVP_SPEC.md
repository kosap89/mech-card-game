# MVP_SPEC.md

# Mech Card Game – Technical MVP Specification

## 1. Objective

Build a minimal playable prototype of the real-time mech card game defined in `GAME_DESIGN.md`.

The prototype should validate gameplay mechanics only.

Graphics should use simple placeholder UI elements.

The MVP should prioritize:

- correct game logic
- easy iteration
- configurable balancing values
- separation between gameplay logic and presentation
- clear code structure

Recommended engine:

**Godot 4.x**

Recommended scripting language:

**GDScript**

---

# 2. Technical Principles

## Gameplay logic must be independent from visuals

Game-state logic must not depend on:

- textures
- animations
- final card graphics
- final UI layout

The UI observes and represents the game state.

---

## Data-driven cards

Card behavior and statistics should use reusable data structures.

Avoid implementing individual cards using large chains such as:

```gdscript
if card_name == "Cannon":
    ...
elif card_name == "Armor":
    ...
elif card_name == "Rocket":
    ...
```

Use card definitions / resources instead.

---

## Configurable balance values

Do not hard-code balance-sensitive values throughout the codebase.

Centralize values such as:

- match duration
- starting Health
- Scrap generation
- card draw interval
- starting hand size

---

# 3. Suggested Project Structure

```text
res://
│
├── scenes/
│   ├── main/
│   ├── match/
│   ├── mech/
│   ├── cards/
│   └── ui/
│
├── scripts/
│   ├── core/
│   ├── match/
│   ├── cards/
│   ├── mech/
│   ├── combat/
│   └── ui/
│
├── data/
│   ├── cards/
│   ├── mechs/
│   └── balance/
│
├── tests/
│
├── GAME_DESIGN.md
└── MVP_SPEC.md
```

Exact folder naming can change if necessary.

Maintain clear separation of responsibilities.

---

# 4. Core Match State

Implement a central match controller.

Suggested responsibility:

```text
MatchController
```

It manages:

- match start
- elapsed time
- remaining time
- player references
- total damage dealt by each player
- match end
- winner calculation

Default match duration:

```text
180 seconds
```

This value must be configurable.

---

# 5. Player State

Each player requires at minimum:

```text
PlayerState
```

Containing:

- mech
- deck
- hand
- Scrap
- total damage dealt
- card draw timer

For the first prototype, both players may exist inside the same local game session.

Online networking is out of scope.

---

# 6. Mech

Suggested logical object:

```text
Mech
```

Required state:

```text
max_health
current_health
slots[4]
```

Exactly four slots must exist in the MVP.

Slots are generic.

A slot contains either:

```text
null
```

or:

```text
MechPart
```

---

# 7. Mech Part

Suggested object:

```text
MechPart
```

Required state:

```text
card_data
max_health
current_health
owner
slot_index
```

Optional depending on the card:

```text
activation_timer
current_target
```

A part must support:

- installation
- taking damage
- destruction
- Trash
- Replace
- automatic effects

---

# 8. Card Data

Create reusable card definitions.

Suggested structure:

```gdscript
class_name CardData
extends Resource
```

Possible fields:

```text
id
display_name
cost
card_type

max_health

damage
activation_interval

targeting_mode

effect_type
effect_value
```

Not every card needs every property.

Do not over-engineer the initial card system.

The data structure should only include properties actually required by the initial test cards.

---

# 9. Minimum Card Categories

The architecture should allow at least:

```text
PART
SUMMON
MECHANIC
```

These names are implementation placeholders and may change later.

The MVP may initially focus mostly on `PART` cards.

---

# 10. Scrap System

Scrap is the only playable resource.

Required state:

```text
current_scrap
```

Scrap increases continuously during active gameplay.

Suggested system:

```text
ScrapSystem
```

or functionality contained within `PlayerState`.

Required operations:

```text
add_scrap(amount)
spend_scrap(amount)
can_afford(amount)
```

Scrap generation must use a configurable rate.

Example temporary configuration:

```text
scrap_per_second
```

Do not treat the temporary value as final balance.

---

# 11. Harvesting

During the match:

```text
current_scrap += harvest_rate * delta
```

or equivalent timer-based logic.

Harvesters are currently primarily a thematic representation.

The MVP does not require animated Harvester entities unless later needed for gameplay.

---

# 12. Starting Hand

At match start:

```text
starting_hand_size = 3
```

Draw three cards from the player's deck.

The value should remain configurable.

---

# 13. Automatic Card Draw

Implement automatic card drawing during the match.

Current placeholder:

```text
draw_interval = 3.0 seconds
```

At each interval:

```text
draw_card()
```

Maximum hand size is currently unresolved.

Until defined, implement a configurable temporary maximum or a simple safe behavior and mark it as a TODO.

---

# 14. Playing a Card

Basic flow:

```text
player selects card
↓
system checks Scrap cost
↓
player selects valid destination/target if required
↓
Scrap is spent
↓
card resolves
↓
game continues immediately
```

There should be no turn-ending logic.

The game remains active continuously.

---

# 15. Installing a Part

If the player selects an empty mech slot:

```text
install_part(card, slot)
```

Requirements:

1. card must be affordable
2. slot must be valid
3. Scrap is spent
4. card leaves the hand
5. part instance is created
6. part enters the selected slot
7. automatic behavior starts if applicable

---

# 16. Replace

If a player attempts to install a part into an occupied slot:

```text
replace_part(new_card, slot)
```

Process:

1. verify new card can be afforded
2. retrieve existing part
3. calculate Scrap returned by replacing the existing part
4. remove existing part
5. add returned Scrap
6. spend the new card cost
7. install new part

The exact Scrap return value is unresolved.

Use configurable placeholder logic.

---

# 17. Trash

Implement:

```text
trash_part(slot)
```

Requirements:

1. slot must contain an installed part
2. remove the part
3. return configurable Scrap value
4. leave the slot empty

Cards in hand cannot currently be trashed.

---

# 18. Part Destruction

When:

```text
current_health <= 0
```

the part is destroyed.

Process:

```text
destroy_part()
```

Requirements:

- remove part from slot
- grant no Scrap
- stop timers/effects associated with the part

Potential self-damage from destruction is unresolved and should not be treated as mandatory MVP behavior unless explicitly enabled.

---

# 19. Automatic Part Activation

Parts may perform actions automatically.

Suggested pattern:

```text
activation_interval
```

Example:

```text
Cannon:
damage = X
activation_interval = Y
```

When its timer fires:

```text
find_target()
activate_effect()
reset_timer()
```

Exact values come from card data.

---

# 20. Targeting Modes

Architecture should support multiple targeting modes.

Initial examples:

```text
ENEMY_MECH
RANDOM_ENEMY_PART
MANUAL_ENEMY_PART
ALLY_PART
SELF
```

Only implement modes actually required by initial test cards.

Do not create a large generalized targeting framework prematurely.

---

# 21. Manual Targeting

For cards requiring manual targeting:

```text
select card
↓
enter targeting state
↓
highlight valid targets
↓
player selects target
↓
resolve card
```

Valid targets may include:

- enemy mech
- enemy mech parts
- enemy helpers

The UI should clearly indicate when the game is waiting for a target selection.

The real-time simulation should otherwise continue unless later design decisions specify otherwise.

---

# 22. Damage System

Create one consistent method for dealing damage.

Suggested:

```gdscript
apply_damage(amount, source)
```

Both mechs and destructible parts should support damage.

Track damage dealt to the opposing main mech separately because it determines the match winner.

Example:

```text
player.total_mech_damage_dealt
```

Damage dealt to parts does not currently count toward the MVP victory calculation.

---

# 23. Match End

When the match timer reaches zero:

```text
match_active = false
```

Stop:

- automatic attacks
- Scrap generation
- card draws
- card interactions

Compare:

```text
player_1.total_mech_damage_dealt
player_2.total_mech_damage_dealt
```

Highest value wins.

Support a draw result if both values are equal.

---

# 24. Mech Reaching Zero Health

Behavior is not yet defined.

Do not invent a permanent rule.

For the first implementation, this must be isolated behind a clearly configurable or replaceable rule.

Add:

```text
TODO: Define what happens if mech health reaches zero before timer expires.
```

---

# 25. Shared Scrap Pool / Deck Generation

Full Scrap Pool logic is not required for the earliest playable build.

Initial MVP may use predefined test decks.

However, architecture should avoid making decks permanently hard-coded.

Later implementation may generate decks using shared Scrap Pool rules and card themes.

---

# 26. Color / Theme Data

Card definitions may optionally contain:

```text
theme_id
color_id
```

These should currently be treated as metadata.

Example placeholders:

```text
yellow = heavy explosives
red = aggressive helper units
```

Do not create gameplay effects based on these themes unless explicitly specified later.

---

# 27. Same-Part Upgrade

This system is optional for the first playable prototype.

Do not allow it to block implementation of the core loop.

If implemented later, use a separate upgrade function such as:

```text
try_upgrade_part()
```

Exact rules remain undefined.

---

# 28. Initial Test Cards

Create approximately 8–12 placeholder cards.

Their purpose is to test systems rather than define final game content.

Suggested functionality coverage:

```text
1. Basic automatic weapon
2. Slow high-damage weapon
3. Fast low-damage weapon
4. Defensive part
5. Healing part
6. Summoning part
7. Basic helper robot
8. Manually targeted attack
9. Scrap-related part
10. Highly destructible / high-risk part
```

Names and numerical values may be placeholders.

These are test implementations, not final card designs.

---

# 29. Placeholder UI

The prototype UI should clearly show:

```text
MATCH TIMER

ENEMY MECH HEALTH

ENEMY SLOT 1
ENEMY SLOT 2
ENEMY SLOT 3
ENEMY SLOT 4

ENEMY HELPERS if required

PLAYER SCRAP

PLAYER SLOT 1
PLAYER SLOT 2
PLAYER SLOT 3
PLAYER SLOT 4

PLAYER MECH HEALTH

PLAYER HAND
```

Each card should show at minimum:

```text
name
cost
```

Installed parts should show:

```text
name
current health
max health
```

No custom artwork is required.

Use:

- panels
- labels
- buttons
- progress bars
- simple placeholder icons if useful

---

# 30. Debug Information

During development, include an optional debug panel.

Useful values:

```text
match time
Scrap generation rate
current Scrap
cards drawn
damage dealt
part activation timers
current targets
```

Debug information should be removable or hideable.

---

# 31. Basic Bot

A sophisticated opponent AI is out of scope.

For single-player testing, implement a minimal bot if necessary.

Example temporary behavior:

```text
if affordable cards exist:
    choose one
    choose a valid slot/target
    play it
```

Random valid choices are acceptable for the initial prototype.

AI strategy should not block testing the core mechanics.

---

# 32. Testing Requirements

Core systems should be testable independently where practical.

Important cases:

### Scrap

- Scrap increases over time.
- Playing a card decreases Scrap.
- Cannot play unaffordable cards.

### Slots

- Mech always has four slots.
- Empty slot accepts a part.
- Occupied slot triggers Replace behavior.

### Trash

- Installed part can be removed.
- Scrap is granted.
- Slot becomes empty.

### Replace

- Existing part is removed.
- Scrap refund occurs.
- New part is installed.

### Damage

- Mech Health decreases correctly.
- Part Health decreases correctly.
- Part is removed at zero Health.

### Match

- Timer reaches zero.
- Damage totals are compared.
- Winner is determined correctly.

### Draw

- Starting hand contains three cards.
- Automatic card draw occurs at configured intervals.

---

# 33. Recommended Implementation Order

## Phase 1 – Project foundation

Implement:

- project structure
- main scene
- match state
- simple placeholder UI

---

## Phase 2 – Match timer and Health

Implement:

- 180-second timer
- two mechs
- Health
- damage tracking
- end-of-match winner calculation

---

## Phase 3 – Scrap

Implement:

- Scrap resource
- automatic Scrap generation
- Scrap UI
- spending

---

## Phase 4 – Cards and Hand

Implement:

- CardData
- deck
- starting hand
- automatic draw
- simple hand UI

---

## Phase 5 – Mech slots

Implement:

- four slots
- part installation
- part Health

---

## Phase 6 – Automatic combat

Implement:

- activation timers
- basic weapon
- damage to opposing mech

At this point the first minimal match should already be playable.

---

## Phase 7 – Trash and Replace

Implement:

- Trash
- Replace
- Scrap refund

---

## Phase 8 – Targeting

Implement:

- targeted enemy part attacks
- target selection UI
- destructible enemy components

---

## Phase 9 – Supporting mechanics

Implement:

- defensive component
- healer
- summons
- helper robot Health

---

## Phase 10 – Gameplay testing

Do not add major features.

Adjust:

- Scrap generation
- card costs
- draw rate
- Health
- damage
- activation intervals
- match pacing

The goal is to determine whether the core loop is fun.

---

# 34. Definition of First Playable MVP

The first playable version is complete when:

- [ ] A match starts.
- [ ] Match timer counts down from 3:00.
- [ ] Both players have mechs.
- [ ] Both mechs have four slots.
- [ ] Players begin with three cards.
- [ ] Cards continue entering the hand.
- [ ] Scrap continuously regenerates.
- [ ] Cards cost Scrap.
- [ ] Parts can be installed.
- [ ] Installed parts operate automatically.
- [ ] Mechs can take damage.
- [ ] Parts can take damage.
- [ ] Parts can be destroyed.
- [ ] Parts can be trashed.
- [ ] Parts can be replaced.
- [ ] At least one card can manually target an enemy component.
- [ ] Damage dealt to each mech is tracked.
- [ ] Match ends after 180 seconds.
- [ ] Player with more mech damage dealt wins.
- [ ] Match can be restarted.

---

# 35. Out of Scope

Do not implement unless separately requested:

- accounts
- login
- cloud saving
- matchmaking
- online multiplayer
- ranking
- progression
- battle pass
- monetization
- card packs
- final graphics
- final animations
- final VFX
- final audio
- detailed tutorial
- final balancing
- large card library
- mobile store integration

---

# 36. Codex Instructions

When Codex works on this repository:

1. Read `GAME_DESIGN.md`.
2. Read `MVP_SPEC.md`.
3. Preserve the defined game rules.
4. Do not invent new mechanics.
5. Keep unresolved design questions unresolved.
6. Prefer configurable placeholder values over assumptions.
7. Add TODO comments when a design decision is required.
8. Keep gameplay logic separate from visual presentation.
9. Implement one system at a time.
10. Avoid unnecessary abstraction before the core loop works.

When uncertain whether something is a programming decision or a game-design decision:

**do not silently make the game-design decision.**

Document the question instead.