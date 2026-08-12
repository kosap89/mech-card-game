# GAME_DESIGN.md

# Mech Card Game – MVP Game Design

## 1. Purpose

This document describes the current MVP-level game design.

The design is not final.

The purpose of the MVP is to test whether the core gameplay loop is:

- fast
- easy to understand
- tactically interesting
- satisfying
- capable of maintaining strong gameplay flow

**Flow is the highest design priority.**

If a mechanic significantly slows down the game or interrupts the flow, it should be questioned even if it adds tactical depth.

---

# 2. Core Concept

The game is a real-time card game where each player controls and builds a mech during the match.

The player uses cards to:

- attach parts to the mech
- summon helper robots
- activate other gameplay mechanics

The mech and its installed parts continuously perform actions automatically.

Examples include:

- firing weapons
- creating shields
- healing
- summoning helper robots
- activating other effects

The player's main role is to continuously decide:

- what card to play
- when to play it
- where to play it
- what to replace
- what to trash
- what enemy component to target when targeting is available

---

# 3. Match Structure

The game is real-time.

There are no traditional turns in the MVP.

Match duration:

**180 seconds / 3 minutes**

Each player has a mech with its own Health.

Example MVP value:

**Mech Health: 1000**

The exact Health value is subject to balancing.

At the end of the 3-minute match, the winner is:

**the player who has dealt more damage to the opposing mech.**

For the MVP, dealing damage does not provide any additional reward or resource.

---

# 4. Mechs

Before the match, the player selects a mech.

Each mech has:

- its own Health
- exactly 4 generic part slots
- a starting card
- one mech-specific card that is shuffled into the deck

Example mech-specific card:

**Main Cannon**

The mech selection does not currently affect the Scrap Pool or its color/theme composition.

---

# 5. Mech Slots

Each mech has exactly:

**4 slots**

The slots are generic.

There are no predefined:

- offensive slots
- defensive slots
- support slots

A slot's role depends entirely on the part installed into it.

For example:

- a weapon makes the slot offensive
- armor or shielding makes the slot defensive
- a summoning component may make the slot support-oriented

If a slot is empty, a part can be installed into it.

If all four slots are occupied, installing another part requires replacing an existing part.

---

# 6. Parts

Parts are cards that can be installed into mech slots.

Each part may have its own properties such as:

- Health
- damage
- attack interval
- defensive effect
- healing effect
- summoning effect
- other card-specific behavior

Installed parts operate automatically once active.

Each installed part has its own Health.

Enemy attacks and targeted effects can damage or destroy parts independently from the main mech.

---

# 7. Helper Robots / Summons

Some cards or mech parts can summon helper robots.

Possible helper robot roles include:

- attacking
- healing
- harvesting
- other card-specific functions

Helper robots may have their own Health.

Certain enemy cards may be able to target them directly.

---

# 8. Scrap

Scrap is the game's only playable resource.

There is no separate energy or mana resource.

The Scrap meter is the resource meter.

Cards cost Scrap to play.

Example costs:

- Cost 1
- Cost 2
- Cost 3

Higher costs may be added later if required.

---

# 9. Scrap Generation

Scrap is generated continuously during the match.

Thematically, small background robots called **Harvesters** collect scrap metal from the Scrapyard and deliver it to the mech.

Gameplay representation:

**Harvesters collect Scrap → Scrap meter increases → player spends Scrap on cards.**

The exact Scrap generation rate has not yet been decided.

Scrap can currently be gained through:

### Harvest

Scrap is generated automatically over time.

### Trash

An installed part is deliberately removed from the mech.

The player receives Scrap for the removed part.

### Replace

A new part replaces an installed part.

The old installed part is scrapped and provides Scrap.

The new card still costs its normal Scrap cost to play.

---

# 10. Trash

Trash can only be performed on a part that is already installed in a mech slot.

A card cannot currently be discarded directly from the player's hand for Scrap.

When a player uses Trash:

1. the installed part is removed
2. the slot becomes empty
3. the player receives Scrap

Conceptually:

The player scraps an old component already installed on the mech rather than throwing away a new component that has not yet been installed.

Whether a trashed card returns to the shared card pool is currently undecided.

---

# 11. Replace

Replace occurs when the player installs a new part into a slot that already contains another part.

Process:

1. player selects a card from hand
2. player selects an occupied mech slot
3. the old part is removed
4. the old part is scrapped
5. the player receives Scrap from the old part
6. the new card's normal Scrap cost is paid
7. the new part is installed

Replace is therefore different from Trash because the player replaces the old component immediately with a new one.

---

# 12. Destroyed Parts

A part can be destroyed when its Health reaches zero.

If a part is destroyed naturally:

**the player receives no Scrap from it.**

This creates a distinction between:

- intentionally scrapping a damaged part
- allowing the enemy to destroy it

---

# 13. Possible Destruction Damage Mechanic

Current concept under consideration:

If an installed part is allowed to reach zero Health and is destroyed, it may cause additional damage to the mech carrying it.

Example:

A damaged missile launcher explodes when destroyed and damages its own mech.

This would create pressure to Trash or Replace heavily damaged components before they are destroyed.

This mechanic is **not yet confirmed for the MVP**.

---

# 14. Card Draw

Starting hand:

**3 cards**

During the match, new cards enter the player's hand automatically.

Current example:

**1 new card every 3 seconds**

The exact draw interval is subject to testing and balancing.

Maximum hand size has not yet been decided.

---

# 15. Card Pool / Scrap Pool

Players use a shared Scrap Pool.

The pool can contain cards belonging to different themes.

For MVP design purposes, these themes may be represented using colors.

Example only:

- Yellow = large bombs / heavy explosive attacks
- Red = small aggressive or troublesome helper units

These colors and themes are placeholders.

The final:

- colors
- number of themes
- theme identities
- pool structure

have not yet been decided.

The selected mech does not determine the Scrap Pool theme.

---

# 16. Automatic Combat

The game should minimize unnecessary player input.

Once installed or summoned, parts and helpers should perform their normal functions automatically when possible.

Examples:

- a cannon fires automatically
- a healer heals automatically
- a summoner creates helpers automatically

The exact targeting rules depend on the card.

---

# 17. Targeting

Some cards act automatically.

Some cards allow the player to select a specific enemy target.

Targetable objects may include:

- enemy mech
- enemy installed parts
- enemy helper robots
- other future targetable objects

Targeted cards create tactical opportunities.

Example:

The opponent has a powerful healing component.

The player uses a targeted attack to destroy that component before continuing to damage the main mech.

The exact distinction between automatic and manually targeted cards is not yet finalized.

---

# 18. Part Upgrades

Current concept:

Playing another copy of the same installed part may upgrade that part.

The upgraded version could become a stronger **golden** version, inspired by the general upgrade concept used in auto-battler games.

The exact rules are not yet decided.

Open questions include:

- how many copies are required
- whether the card must already be installed
- what statistics increase
- whether abilities change
- whether Health is restored
- whether upgrading costs additional Scrap

This feature should not block the first playable prototype.

---

# 19. Intended Gameplay Feel

The game should feel:

- fast
- responsive
- active
- satisfying
- visually readable
- continuously moving

The player should frequently be able to make small decisions.

Typical loop:

**Scrap becomes available → player plays a card → something happens immediately → board state changes → next decision arrives quickly.**

The game should avoid long periods where the player cannot interact.

---

# 20. Design Priorities

The current design priorities are:

## 1. Flow

The game should continuously move forward.

## 2. Tactical Decision-Making

The player should have meaningful choices without requiring long pauses.

## 3. Satisfaction

Playing, replacing and destroying parts should feel impactful.

## 4. Fast Reward Cycle

Actions should produce clear and immediate feedback.

---

# 21. MVP Scope

The MVP only needs enough content to test the core game.

The MVP does not require:

- final graphics
- animations
- final sound design
- online multiplayer
- matchmaking
- accounts
- progression systems
- monetization
- large card collections
- final balance
- final card themes

Placeholder visuals are acceptable.

---

# 22. MVP Success Question

The primary MVP question is:

**Is it fun to build and modify a mech in real time while Scrap continuously generates and both mechs automatically fight each other?**

Secondary questions:

- Does the Scrap generation rate create good pacing?
- Is four slots enough?
- Does replacing parts create meaningful decisions?
- Is Trash useful without becoming tedious?
- Is targeted destruction interesting?
- Does automatic combat preserve enough player agency?
- Is three minutes an appropriate match duration?
- Are players making decisions often enough?
- Does the game maintain flow for the entire match?

---

# 23. Unresolved Design Decisions

The following are intentionally unresolved:

- exact Scrap generation rate
- maximum Scrap
- Scrap value gained from Trash
- Scrap value gained from Replace
- exact card draw interval
- maximum hand size
- final mech Health
- exact card costs
- exact targeting rules
- final card themes
- final color system
- Scrap Pool composition
- upgrade / golden-part rules
- destroyed-part explosion mechanic
- whether trashed cards return to the pool
- helper robot rules
- exact win-condition behavior if a mech reaches zero Health before 3:00

Do not invent permanent solutions for these during implementation.

Use configurable placeholder values where necessary.

---

# 24. AI / Codex Implementation Rule

When implementing this design:

**Do not invent new game mechanics to resolve unspecified behavior.**

If implementation requires a decision that is not defined here:

1. use the simplest temporary implementation possible when necessary
2. make the value configurable
3. add a clear TODO
4. document the unresolved decision

Do not silently turn temporary implementation choices into game-design rules.