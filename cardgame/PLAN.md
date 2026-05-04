# Card Game Prototype — Plan

A 1v1 turn-based TCG prototype built in **Unreal Engine 5.7**. Targets PC (Steam) eventually. This document defines architecture and milestones; gameplay content (specific cards, balance, art) is out of scope for the prototype phase.

## Goals

- Prove the core TCG loop works: deck → hand → mana-gated plays → combat → win condition.
- Establish an architecture that scales to complex effects without rewriting the foundation.
- Ship a 1v1 networked prototype playable on LAN by end of M3.
- Keep the door open for: PvE story mode, hundreds of cards, dedicated-server hosting, mod content.

## Non-Goals (Prototype Phase)

- Polished art, animation, or sound.
- Matchmaking, lobbies, accounts, persistence.
- Anti-cheat hardening beyond the listen-server defaults.
- Card sets beyond the 4–6 needed to exercise each system.

## Visual Assets

Final art is handled by a separate person. The prototype uses **bare-minimum greyboxes only**: primitive shapes for cards (flat quads + text), units (cubes/cylinders), and the board (flat plane with grid). Animations are limited to position lerps, scale tweens, and color flashes — enough to read state changes, no more. No materials beyond default lit + a few solid colors. No imported art assets. UI uses CommonUI defaults and basic text/buttons.

The card definition asset reserves an art reference field for later, but it stays unset; widgets fall back to a solid color keyed off card type.

## Tech Stack Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | UE 5.7 | User's installed version |
| Language split | C++ for systems, Blueprint for content/UI | Standard UE idiom; iteration speed without losing perf or testability |
| Authority model | **Listen-server** P2P, designed for clean migration to dedicated | Native UE alignment, zero hosting cost for prototype, simulation code is identical to the dedicated case |
| GAS | **Partial adoption**: Tags + Attributes + Effects. **Skip** Abilities. | Tags/Attributes/Effects fit a TCG perfectly. Abilities assume latency-sensitive activation with prediction, which fights a turn-based action queue. |
| Input | Enhanced Input | Standard in 5.7 |
| UI | CommonUI on top of UMG | Better primitives, gamepad-ready for free, small upfront cost |
| Card data | `UPrimaryDataAsset` + AssetManager | Data-driven, async-loadable, mod-friendly |
| Replication | UE default replication | Iris is for dedicated-scale, unnecessary for 1v1 |
| Phase FSM | Enum + switch | Simpler than State Tree for 5 phases |

## Authority Model: Listen-Server

One peer hosts a listen-server; the other connects as a client. The host's machine runs the authoritative `UMatchSimulation`. Clients send action requests via `Server_*` RPCs; server validates, mutates state, replicates result via standard UE replication.

**Honest limits**: the host can cheat (memory edit life, peek opponent hand, bias RNG). For prototype this doesn't matter. For shipping competitive play, migration to dedicated is the answer (the simulation code does not change — the server just stops being a player).

**Mitigations available later on listen-server** (not building now, but architecture leaves room): deck commit-reveal hashing at game start, EAC integration, server-side replay logs.

## Migration Path to Dedicated

The simulation lives on `AGameModeBase`, which exists only on the server in both listen and dedicated configurations. Same source code. To migrate:

1. Build with the dedicated-server target (already wired in M1).
2. Switch matchmaking/connection flow to point at a hosted server instead of a peer.
3. Done — gameplay code is untouched.

## Module Layout

Two C++ modules:

- **`CardGame`** — gameplay runtime: simulation, turn manager, cards, effects, GAS attribute sets, player state.
- **`CardGameNet`** — thin transport-selection layer wrapping UE's NetDriver subsystem. Allows `IpNetDriver` → `SteamSocketsNetDriver` → dedicated transport via config without touching gameplay.

## GAS Integration

| GAS subsystem | Used | How |
|---|---|---|
| Gameplay Tags | Yes | Card types, factions, keywords, zones, phases — everywhere |
| Attributes (`UAttributeSet`) | Yes | Unit stats (Power, Toughness, CurrentHealth); player stats (Life, Mana, MaxMana, HandSize, DeckSize) |
| Gameplay Effects | Yes | All stat modifications: damage, buffs, +1/+1 counters, "until end of turn" durations |
| Gameplay Abilities | No | Mismatch with turn-based action queue; we use `UCardEffect` instead |

`UCardEffect` is the orchestration layer (knows about cards, zones, targeting, the action queue). When an effect changes a stat, it builds and applies a `UGameplayEffect` to the target's `UAbilitySystemComponent`. **GAS does the math; our system does the orchestration.**

## Class Inventory

### Match orchestration (server-only)
- `ACardGameMode : AGameModeBase` — match lifecycle, simulation owner.
- `ACardGameState : AGameStateBase` — replicated public state pointers and metadata.
- `UMatchSimulation : UWorldSubsystem` — server-side simulation core. Owns turn manager, action resolver, effect stack, RNG.
- `UTurnPhaseManager` — enum FSM: `Untap → Draw → Main → Combat → End`. Hooks: `OnPhaseEnter/Exit`.
- `UActionResolver` — validates and processes actions FIFO.
- `UEffectStack` — ordered queue of pending effects. Trivial now; pays off when triggered abilities arrive.

### Players
- `ACardGamePlayerController` — input + UI-side action submission.
- `APlayerStateCG : APlayerState` — UAbilitySystemComponent, UPlayerAttributeSet, replicated public counters.
- `UPlayerAttributeSet : UAttributeSet` — Life, Mana, MaxMana, HandSize, DeckSize.
- `UPrivateZone` — owner-only replicated hand & deck (`COND_OwnerOnly`).

### Cards & effects
- `UCardDefinition : UPrimaryDataAsset` — id, cost, type, art ref (unset for prototype), `FGameplayTagContainer`, `TArray<UCardEffect*>`, `TArray<TSubclassOf<UGameplayEffect>>` for static effects.
- `FCardInstance` (USTRUCT) — runtime: definition ptr, instanceId, owner, mutable status flags.
- `AUnitOnBoard : AActor` — actor spawned when a unit card is played. UAbilitySystemComponent, UUnitAttributeSet, replicated tags. Visual: primitive mesh + text render component.
- `UUnitAttributeSet : UAttributeSet` — Power, Toughness, CurrentHealth.
- `UCardEffect` (UObject base) — `virtual void Resolve(FEffectContext&)`.
  - `UEffect_DealDamage` — applies instant GE
  - `UEffect_DrawCards` — calls into simulation
  - `UEffect_SummonUnit` — spawns AUnitOnBoard
  - `UEffect_BuffUntilEndOfTurn` — applies duration GE

### Networking
- `INetTransport` (interface) — abstract transport.
- `UIpNetTransport` — UE NetDriver wrapper for prototype LAN.
- `USteamSocketsTransport` — stub, implemented when wiring Steam.
- `FNetAction` (USTRUCT) — `Type`, `PrimaryArg`, `SecondaryArg`, `TargetInstanceId`. Sent via `Server_*` RPC.

### UI (CommonUI, greybox only)
- `WBP_Hand`, `WBP_Board`, `WBP_Card`, `WBP_PhaseIndicator`, `WBP_PlayerHud`, `WBP_TargetSelector`. Pure presentation; observe state via delegates. Solid colors + text, no art.

## Wire Protocol (Listen-Server)

Client → Server (reliable RPCs on `ACardGamePlayerController`):
- `Server_PlayCard(int32 HandIndex, FGuid TargetInstanceId)`
- `Server_DeclareAttacker(FGuid AttackerId, FGuid TargetId)`
- `Server_AdvancePhase()`
- `Server_Concede()`

Server → all clients: standard UE replication of `ACardGameState`, `APlayerStateCG`, `AUnitOnBoard`. Owner-only replication of `UPrivateZone` for hand contents.

## Folder Layout

```
cardgame/
  CardGame.uproject
  Config/
    DefaultEngine.ini
    DefaultGame.ini
    DefaultInput.ini
    DefaultGameplayTags.ini
  Source/
    CardGame.Target.cs
    CardGameEditor.Target.cs
    CardGameServer.Target.cs       (dedicated migration)
    CardGame/
      CardGame.Build.cs
      CardGameModule.cpp
      Public/
        Match/        (Simulation, TurnPhaseManager, ActionResolver, EffectStack, GameMode, GameState)
        Cards/        (CardDefinition, CardInstance, CardEffect + subclasses, UnitOnBoard)
        Player/       (PlayerStateCG, PlayerController, PrivateZone, AttributeSets)
        Core/         (Logging, Hashing helpers for replay logs)
      Private/        (mirrors Public)
    CardGameNet/
      CardGameNet.Build.cs
      Public/         (INetTransport, FNetAction)
      Private/        (UIpNetTransport)
  Content/
    Cards/            (UCardDefinition assets)
    Effects/          (UGameplayEffect blueprints)
    UI/               (WBP_*)
    Blueprints/       (BP_GameMode, BP_PlayerController — thin wrappers)
    Maps/             (MainMenu, Match)
  README.md
  CLAUDE.md           (architecture summary, commands, conventions)
  PLAN.md             (this document)
  .gitignore          (UE5-specific)
```

## Milestones

### M1 — Bootstrap
- `.uproject` with required plugins enabled (`GameplayAbilities`, `EnhancedInput`, `CommonUI`)
- Two C++ modules (`CardGame`, `CardGameNet`) compile clean
- Three build targets: Editor, Game, Server
- UE5-appropriate `.gitignore`
- README, CLAUDE.md (architecture summary)
- Empty `MainMenu` and `Match` levels with thin BP wrappers
- Hash utility for future replay logging

**Deliverable**: project opens in 5.7, builds, runs, displays empty levels.

### M2 — Local Match
- `UCardDefinition` data asset class + 4 sample cards: 1-cost vanilla unit, 3-cost vanilla unit, 2-cost damage spell, 2-cost draw spell
- `UPlayerAttributeSet`, `UUnitAttributeSet` with Life/Mana/Power/Toughness/CurrentHealth
- `UMatchSimulation` running deck → hand → play → combat loop
- `UTurnPhaseManager` cycling phases
- `UCardEffect` base + 3 concrete subclasses (`DealDamage`, `DrawCards`, `SummonUnit`)
- Hot-seat playable (single machine, two PlayerControllers) end-to-end with a winner
- Greybox debug UI: zones, phase, mana, life, hand contents — text and solid-color rectangles

**Deliverable**: complete match playable locally. Rules engine validated.

### M3 — Networking
- `ACardGameMode` listen-server flow: host opens, client joins via direct IP
- All client actions routed through `Server_*` RPCs
- Public state replicates via UE default replication
- `UPrivateZone` owner-only replication for hand contents
- Concede + ungraceful disconnect handling
- Two PCs on LAN play a full match end-to-end

**Deliverable**: 1v1 networked match completable on LAN.

### M4 — Prototype Polish
- CommonUI card widgets (still greybox), drag-to-play, click-to-target
- Turn/phase indicator, life/mana HUD
- 4–6 additional cards exercising buff/debuff GE flow
- "Buff until end of turn" via duration GE proves the effect system breadth
- Basic main menu: Host / Join (IP entry) / Quit
- Simple position-lerp animations for card play and unit attack — readability only, no polish

**Deliverable**: prototype suitable for friends-and-family playtesting on LAN.

## Out of Scope (Future Work)

- Steam Sockets transport (after M4, before public testing)
- Dedicated server build pipeline (when migrating off listen-server)
- Deck commit-reveal anti-cheat (when first cheating reports happen)
- Matchmaking, lobbies, friends list (post-prototype)
- Persistent collection, deckbuilder UI (post-prototype)
- PvE story scaffolding (post-prototype, but card system is designed to support it)
- EAC integration (pre-launch)
- Card editor utility widgets (when content volume justifies it)
- Replay system (post-prototype, hash utility from M1 is the seed)
- Final art, VFX, sound, polished animation (handled by separate person)

## Repository Note

This prototype lives in `Gamestorming/cardgame/` as a temporary home. The existing Gamestorming CI (`.github/workflows/build-all.yml`) is Godot-only and won't build this project; the `cardgame/` folder is intentionally excluded from that pipeline. It will be moved to its own repo once the client provides one.
