using System;
using System.Collections.Generic;
using Bulwark.Data;
using Bulwark.Presets;
using PF2e.Actions;
using PF2e.CharacterComponents;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.Import;
using PF2e.Utilities;

namespace Bulwark.Cozy;

/// <summary>
/// The live squad: the four preset PCs built ONCE per save and reused across every encounter, so
/// engine state (HP, conditions, spell-slot usage) simply persists between fights — that IS the
/// attrition model. Full reset only happens on outpost sleep (<see cref="RestFully"/>). Plain C#;
/// GameState owns the single instance and wraps it in command methods, UI never touches it directly.
///
/// Lifecycle:
///  - <see cref="BuildNew"/>: assemble the presets (deterministic) and capture each caster's daily
///    prepared loadout for re-preparation on rest.
///  - <see cref="CompleteEncounter"/>: post-combat cleanup + XP award (see method doc for exactly
///    what is cleared vs kept).
///  - <see cref="ApplyBankedLevelUps"/>: outpost sleep, before the rest — banked XP converts to
///    in-place level-ups replaying each member's combo script (capped at
///    <see cref="MaxAppliedLevel"/>).
///  - <see cref="RestFully"/>: outpost sleep — full HP, slots refilled/re-prepared, rest-clearable
///    conditions removed.
///  - <see cref="CaptureMembers"/> / <see cref="RestoreMembers"/>: delta snapshot for the save file.
///    Presets are deterministic, so only live state (HP, persistent conditions, slot usage, XP) is
///    persisted; restore rebuilds the presets and re-applies the delta.
/// </summary>
public sealed class SquadRoster
{
    // Aliases of the preset ids (PresetCharacters owns the strings) so existing call sites compile.
    public const string PlayerId = PresetCharacters.PlayerId;
    public const string ScoutId = PresetCharacters.ScoutId;
    public const string TharrId = PresetCharacters.TharrId;
    public const string ScholarId = PresetCharacters.ScholarId;

    /// <summary>PF2e standard progression: 1000 XP banks a level (applied by the sleep command
    /// via <see cref="ApplyBankedLevelUps"/>).</summary>
    public const int XpPerLevel = CharacterProgression.XPPerLevel;

    /// <summary>
    /// Level-up application cap: the preset combos script choices only through L5 and the engine
    /// features the presets rely on beyond L5 are not ported yet. XP past the cap stays banked
    /// (<see cref="ApplyBankedLevelUps"/> stops consuming at this level).
    /// </summary>
    public const int MaxAppliedLevel = 5;

    /// <summary>
    /// Role: long-term conditions captured into the save file (see <see cref="CaptureConditions"/>) —
    /// the shared attrition whitelist. Encounter cleanup itself relies on the engine's duration
    /// classification (<c>ConditionTracker.RemoveNonPersistingConditions</c>), not this list.
    /// </summary>
    private static readonly Condition[] PersistAcrossEncounters = AttritionConditions.LongTerm;

    private static readonly string[] MemberOrder = { PlayerId, ScoutId, TharrId, ScholarId };

    private static readonly Dictionary<string, Func<int, PF2eCharacter>> Builders = new()
    {
        [PlayerId] = lvl => PresetCharacters.BuildPlayer(lvl),
        [ScoutId] = lvl => PresetCharacters.BuildScout(lvl),
        [TharrId] = lvl => PresetCharacters.BuildTharr(lvl),
        [ScholarId] = lvl => PresetCharacters.BuildScholar(lvl),
    };

    // Each member's locked combo: the per-level scripted choices ApplyBankedLevelUps replays
    // through LevelUpApplicator (same source the preset builders replay from).
    private static readonly Dictionary<string, VariantComboDefinition> Combos = new()
    {
        [PlayerId] = PresetCombos.FighterSentinel,
        [ScoutId] = PresetCombos.RogueThief,
        [TharrId] = PresetCombos.ClericWarpriest,
        [ScholarId] = PresetCombos.WizardBattleMagic,
    };

    private readonly List<PF2eCharacter> _members = new();
    private readonly Dictionary<string, int> _xp = new();

    // Smithy purchases: member id → the bought weapon's pack slug. The preset weapons are
    // deterministic (rebuilt on load), so only a bought REPLACEMENT needs persisting; fundamental
    // runes are captured from the live weapon instance directly. Empty for an untouched squad.
    private readonly Dictionary<string, string> _purchasedWeaponSlug = new();

    // Each prepared caster's daily loadout, captured at build time (LeveledSpells starts full).
    // RestFully re-prepares from this list — PF2e daily preparations.
    private readonly Dictionary<string, List<SpellAction>> _dailyPreparations = new();

    // Roster GROWTH (Phase 3 party-join): additional members inserted BEYOND the fixed four. Keyed
    // by the added member's own character id → the spec needed to rebuild it (PartyPresets key +
    // its builder + combo). Empty for the default squad, so the fixed-four path is byte-identical;
    // growth is purely additive (appended after the four). The key persists in the save so restore
    // rebuilds the grown member via PartyPresets and re-applies its live-state delta.
    private readonly Dictionary<string, GrownMemberSpec> _grown = new();

    /// <summary>Rebuild recipe for one grown (party-joined) member.</summary>
    private sealed class GrownMemberSpec
    {
        public required string PresetKey { get; init; }
        public required Func<int, PF2eCharacter> Builder { get; init; }
        public required VariantComboDefinition Combo { get; init; }
    }

    /// <summary>Raised after any squad-state mutation (encounter completion, rest, restore).</summary>
    public event Action? Changed;

    public IReadOnlyList<PF2eCharacter> Members => _members;

    /// <summary>Party level for XP budgeting (presets are built uniformly at this level).</summary>
    public int Level { get; private set; }

    private string? _playerName;

    private SquadRoster(int level, string? playerName = null)
    {
        Level = Math.Max(1, level);
        _playerName = playerName;
        foreach (var id in MemberOrder)
            AddMember(BuildMember(id, Level));
    }

    /// <summary>Build the four live preset PCs once for a new save.</summary>
    public static SquadRoster BuildNew(int level, string? playerName = null) => new(level, playerName);

    private PF2eCharacter BuildMember(string id, int level)
    {
        if (id == PlayerId)
            return PresetCharacters.BuildPlayer(level, _playerName);
        return Builders[id](level);
    }

    public PF2eCharacter? FindMember(string memberId) => _members.Find(m => m.Id == memberId);

    public int GetXp(string memberId) => _xp.TryGetValue(memberId, out var xp) ? xp : 0;

    /// <summary>
    /// Bank XP directly (quest/story awards and dev tooling). Encounter XP goes through
    /// <see cref="CompleteEncounter"/>.
    /// </summary>
    public void AddXp(string memberId, int amount)
    {
        if (amount <= 0 || FindMember(memberId) == null)
            return;
        _xp[memberId] = GetXp(memberId) + amount;
        Changed?.Invoke();
    }

    // ===================== Roster growth (Phase 3 party-join) =====================

    /// <summary>
    /// Grow the roster POOL by one member, built from a registered (builder, combo) party preset —
    /// the roster-join seam (validated by <see cref="RosterJoin"/> / GameState.JoinRoster). This
    /// enlarges the POOL of available characters, NOT a live combat party: the adventuring party is
    /// always a selection of ≤4 from the pool (TerritorySystem.BuildPartySelectView / Travel), so a
    /// pool of five never puts a fifth body into an encounter. The fixed four are untouched: the new
    /// member is APPENDED after them and shares the identical member lifecycle across the whole pool
    /// (encounter cleanup, rest, fatigue, capture, and — via <see cref="ComboFor"/> — banked
    /// level-ups). Keyed by the built character's own <see cref="ICharacter.Id"/>; a duplicate id is
    /// rejected (idempotent). The <paramref name="presetKey"/> is retained so a save round-trip
    /// rebuilds the member via PartyPresets and re-applies its live-state delta. Returns the new
    /// member, or null when the inputs are invalid or the member is already present. Raises
    /// <see cref="Changed"/> on success.
    /// </summary>
    public PF2eCharacter? InsertMember(string presetKey, Func<int, PF2eCharacter> builder, VariantComboDefinition combo, int level)
    {
        if (string.IsNullOrEmpty(presetKey) || builder == null || combo == null)
            return null;

        var member = builder(Math.Max(1, level));
        if (member == null || FindMember(member.Id) != null)
            return null;

        AddMember(member);
        _grown[member.Id] = new GrownMemberSpec { PresetKey = presetKey, Builder = builder, Combo = combo };
        Changed?.Invoke();
        return member;
    }

    /// <summary>The level-up combo for a member: a grown member's registered combo, else the fixed-four map.</summary>
    private VariantComboDefinition ComboFor(string memberId)
        => _grown.TryGetValue(memberId, out var g) ? g.Combo : Combos[memberId];

    // ===================== Smithy (gold-sink: fundamental runes + weapon shop) =====================

    /// <summary>
    /// The member's live main-hand weapon instance — the exact object combat reads
    /// (EquipmentHolder.GetActiveWeapon → DamageCalculator/AttackResolver). Null when the member is
    /// unknown or wields nothing (unarmed). Rune mutations here flow straight into strike math.
    /// </summary>
    private WeaponInstance? MainWeapon(string memberId) => FindMember(memberId)?.Equipment?.MainHandWeapon;

    /// <summary>
    /// True when <paramref name="kind"/> can still be applied to the member's main-hand weapon
    /// (member exists, holds a weapon, and the rune isn't already maxed). The command layer calls
    /// this BEFORE spending gold so an inapplicable rune costs nothing.
    /// </summary>
    public bool CanApplyRune(string memberId, RuneKind kind)
    {
        var w = MainWeapon(memberId);
        if (w == null)
            return false;
        return kind switch
        {
            RuneKind.Potency => w.PotencyBonus < RunePrices.MaxPotency,
            RuneKind.Striking => w.Striking < StrikingRuneLevel.Striking,
            _ => false,
        };
    }

    /// <summary>
    /// Apply a fundamental rune to the member's LIVE main-hand weapon instance in place — potency
    /// bumps to-hit (+1/step), striking adds a weapon damage die. In-place mutation is the cleanest
    /// path: the instance IS what combat reads, and nothing re-syncs hands mid-play, so no re-equip
    /// is needed. Rejects (no mutation) when <see cref="CanApplyRune"/> is false. Gold is the
    /// command layer's concern; this only mutates the weapon. Raises <see cref="Changed"/>.
    /// </summary>
    public bool ApplyWeaponRune(string memberId, RuneKind kind)
    {
        var w = MainWeapon(memberId);
        if (w == null)
            return false;

        switch (kind)
        {
            case RuneKind.Potency:
                if (w.PotencyBonus >= RunePrices.MaxPotency)
                    return false;
                w.PotencyBonus++;
                break;
            case RuneKind.Striking:
                if (w.Striking >= StrikingRuneLevel.Striking)
                    return false;
                w.Striking = StrikingRuneLevel.Striking;
                break;
            default:
                return false;
        }

        Changed?.Invoke();
        return true;
    }

    /// <summary>
    /// Equip a freshly bought weapon to the member's main hand, built from the engine
    /// <paramref name="weaponDef"/> (a real pack weapon). Uses EquipmentHolder.DrawMainHand, which
    /// creates the instance and occupies both hands for two-handers — preserving the member's other
    /// live state (HP, conditions, spell slots). The new weapon carries no runes (a blank blade);
    /// the bought slug is recorded so the purchase round-trips a save/load. Raises
    /// <see cref="Changed"/>. False when the member is unknown or has no equipment holder.
    /// </summary>
    public bool BuyWeapon(string memberId, WeaponDefinition weaponDef, string weaponSlug)
    {
        var member = FindMember(memberId);
        if (member?.Equipment == null || weaponDef == null)
            return false;

        if (!ReequipMainHand(member, weaponDef))
            return false;

        _purchasedWeaponSlug[memberId] = weaponSlug;
        Changed?.Invoke();
        return true;
    }

    /// <summary>
    /// Swap the member's main-hand weapon to <paramref name="def"/>, freeing whatever the hands hold
    /// first so even a two-hander fits (the preset weapon may already occupy both hands via a
    /// two-hand grip, and a held shield must yield the off hand). Shared by the live buy and the
    /// save-restore replay. Returns EquipmentHolder.DrawMainHand's success.
    /// </summary>
    private static bool ReequipMainHand(PF2eCharacter member, WeaponDefinition def)
    {
        var equip = member.Equipment!;

        // FreeMainHand also releases a two-hand-grip off slot; that clears the common preset case.
        equip.Appendages?.FreeMainHand();

        if (def.Hands == HandRequirement.TwoHands)
        {
            if (equip.HasShieldEquipped && equip.IsShieldInHand)
                equip.StowShield(member);
            equip.Appendages?.FreeOffHand();
        }

        return equip.DrawMainHand(def);
    }

    // ===================== Level-up application (sleep command) =====================

    /// <summary>
    /// Consume banked XP into level-ups for every LIVING member: while XP ≥ <see cref="XpPerLevel"/>
    /// and level &lt; <see cref="MaxAppliedLevel"/>, spend 1000 XP and apply ONE level via the
    /// engine's LevelUpApplicator — sequential single-level applications so each level's grants
    /// resolve before the next level's choices are applied (matching the fresh-build replay
    /// order). Per level the member's combo supplies the scripted choices (Free-Archetype feats
    /// etc.); everything unscripted auto-assigns (skill increases, L5 ability boosts). XP above
    /// the cap stays banked. Casters then re-run their level-dependent daily-casting decisions
    /// (<see cref="PresetCharacters.RefreshDailyCasting"/>) and the captured daily preparations
    /// are refreshed, so the caller's follow-up rest re-prepares the NEW loadout and refills to
    /// the NEW maxima. Called by the sleep command BEFORE <see cref="RestFully"/>.
    /// </summary>
    public List<SquadLevelUpView> ApplyBankedLevelUps()
    {
        // Both are idempotent; guarantees the feat/spell ids the replay references resolve even
        // if no preset was built this session (defensive — GameState always builds first).
        PresetCombos.EnsureFeaturesRegistered();

        var applied = new List<SquadLevelUpView>();
        foreach (var m in _members)
        {
            if (m.Health == null || m.Health.IsDead)
                continue;

            int from = m.Stats?.Level ?? Level;
            int level = from;
            var combo = ComboFor(m.Id);

            while (GetXp(m.Id) >= XpPerLevel && level < MaxAppliedLevel)
            {
                _xp[m.Id] = GetXp(m.Id) - XpPerLevel;
                int target = level + 1;
                var scripted = combo.ScriptedChoices.TryGetValue(target, out var choices)
                    ? new List<LevelUpChoices> { choices }
                    : null;
                LevelUpApplicator.ApplyLevelUp(m, fromLevel: level, toLevel: target, scripted);

                // ApplyLevelUp only appends the chosen feats; resolve so this level's grants
                // fire before the next level is processed (preset builders do the same).
                m.Features?.ResolveAndGrantFeatures();
                level = target;
            }

            if (level == from)
                continue;

            // Max HP grows with the new level (and any L5 Con boost); current HP rescales
            // proportionally — the sleep flow's FullHeal rest follows immediately, so no
            // partial-HP math is owed here.
            m.Health.RecalculateMaxHP();

            PresetCharacters.RefreshDailyCasting(m);
            if (m.Spellcasting != null)
                _dailyPreparations[m.Id] = new List<SpellAction>(m.Spellcasting.LeveledSpells);

            applied.Add(new SquadLevelUpView(m.Id, m.Name, from, level));
        }

        if (applied.Count > 0)
        {
            // Party level for XP budgeting follows the members (RestoreMembers precedent).
            Level = _members[0].Stats?.Level ?? Level;
            Changed?.Invoke();
        }
        return applied;
    }

    // ===================== Encounter completion =====================

    /// <summary>
    /// Post-combat cleanup + XP. Runs for every result so the squad never leaves combat mid-dying.
    ///
    /// CLEARS (encounter-scoped): MAP and all per-turn flags (<see cref="CombatState.ResetTurnState"/>
    /// — the engine only resets these on a normal turn end, which a mid-turn victory skips), temp HP,
    /// round cooldowns and per-encounter ability uses, all condition floors (Shatter Defenses), and
    /// every encounter-scoped condition via the engine's <c>RemoveNonPersistingConditions</c> —
    /// Frightened, Prone, Off-Guard, Grabbed, Feinted, spell effects, etc. end with the encounter
    /// (the importer duration-classifies conditions; affliction-style UntilSave instances persist
    /// per RAW).
    ///
    /// KEEPS (attrition): current HP, spell-slot usage / prepared-spell consumption, focus points,
    /// shield HP, daily ability uses, and the whitelist conditions (Wounded, Drained, Doomed,
    /// Fatigued).
    ///
    /// STABILIZES: an ally at 0 HP (dying or knocked out) is healed to 1 HP. The engine handles the
    /// bookkeeping in <see cref="Health.Heal"/>: removing Dying grants/increments Wounded exactly
    /// once (DyingSystem.HandleConditionRemoved) and the zero-HP-sourced Unconscious is removed —
    /// no double-apply here. Dead members stay dead.
    ///
    /// XP: on victory each member banks the encounter's creature XP total (PF2e Table 10-2 via the
    /// engine's <see cref="EncounterXPCalculator"/>, level-vs-party-level differential).
    ///
    /// Returns the encounter XP banked PER MEMBER (0 on defeat/draw) — the additive seam the
    /// day ledger reads; existing callers may ignore it.
    /// </summary>
    public int CompleteEncounter(BattleResult result, IReadOnlyList<ICharacter>? defeatedEnemies)
    {
        foreach (var m in _members)
            CleanUpAfterEncounter(m);

        int encounterXp = 0;
        if (result == BattleResult.Team1Wins && defeatedEnemies != null)
        {
            foreach (var enemy in defeatedEnemies)
                encounterXp += EncounterXPCalculator.GetCreatureXP(GetEnemyLevel(enemy), Level);

            foreach (var m in _members)
                _xp[m.Id] = GetXp(m.Id) + encounterXp;
        }

        Changed?.Invoke();
        return encounterXp;
    }

    private static int GetEnemyLevel(ICharacter enemy)
        => enemy.CreatureStats?.Data.CreatureLevel ?? enemy.StatProvider?.Level ?? 1;

    private static void CleanUpAfterEncounter(PF2eCharacter m)
    {
        // Per-turn combat state (MAP, flourish/spellshape flags, strike follow-ups) must never leak
        // into the next fight; a mid-turn victory skips the TurnManager's normal EndTurn reset.
        m.Combat?.ResetTurnState();

        var health = m.Health;
        if (health == null || health.IsDead)
            return;

        health.ClearTempHP();

        // Stabilize a downed ally at 1 HP. Heal() from 0 removes Dying (engine grants Wounded+1 on
        // that removal) and removes the zero-HP Unconscious — exactly the PF2e post-fight state.
        if (health.CurrentHP <= 0)
            health.Heal(1);

        var conds = m.Conditions;
        if (conds != null)
        {
            // Floors (Shatter Defenses) are combat effects and can outlive their condition
            // instance; the engine's cleanup below doesn't touch them, so sweep them all.
            foreach (Condition condition in Enum.GetValues(typeof(Condition)))
                conds.ClearConditionFloor(condition);

            // The importer now duration-classifies conditions (long-term = Permanent,
            // combat conditions = Encounter), so the engine's own encounter cleanup replaces
            // the old hand-rolled whitelist loop. Slightly more RAW than the whitelist:
            // affliction-style UntilSave instances persist instead of being cleared.
            conds.RemoveNonPersistingConditions();
        }

        // Round cooldowns + per-encounter uses reset between fights; daily uses persist until rest.
        m.CooldownTracker?.ClearAll();
    }

    // ===================== Out-of-combat healing (Treat Wounds) =====================

    /// <summary>
    /// Apply a resolved Treat Wounds outcome to a live member. Healing goes through
    /// <see cref="Health.Heal"/> (clamps at max HP; the engine's dying bookkeeping is a no-op here
    /// because nobody is at 0 HP outside combat). Crit-fail damage floors at 1 HP — out of combat
    /// there is no dying pipeline to enter, mirroring the post-fight stabilization floor. Success
    /// removes Wounded per RAW. Raises <see cref="Changed"/> on any mutation.
    /// </summary>
    public bool ApplyTreatWoundsResult(string targetId, int healingOrDamage, bool removeWounded)
    {
        var target = FindMember(targetId);
        var health = target?.Health;
        if (target == null || health == null || health.IsDead)
            return false;

        if (healingOrDamage > 0)
            health.Heal(healingOrDamage);
        else if (healingOrDamage < 0)
            health.SetCurrentHP(Math.Max(1, health.CurrentHP + healingOrDamage));

        if (removeWounded)
        {
            var def = ConditionDatabase.Instance?.GetCondition(Condition.Wounded);
            if (def != null && target.Conditions != null && target.Conditions.HasCondition(Condition.Wounded))
                target.Conditions.RemoveCondition(def);
        }

        Changed?.Invoke();
        return true;
    }

    // ===================== Fatigue (up past midnight) =====================

    /// <summary>
    /// Apply the engine Fatigued condition to every LIVING member that doesn't already carry it —
    /// PF2e's going-without-sleep rule, house-tuned to midnight (GameState latches the threshold
    /// and calls this; the 30:00 dawn rollover repeats it as a backstop). Idempotent. Fatigued is
    /// on the attrition whitelist (<see cref="AttritionConditions.LongTerm"/>) and the importer
    /// duration-classifies it as long-term, so it persists through encounters and the save file
    /// until <see cref="RestFully"/> removes it. Returns true (and raises <see cref="Changed"/>)
    /// only when at least one member newly gained the condition.
    /// </summary>
    public bool ApplyFatigue()
    {
        var def = ConditionDatabase.Instance?.GetCondition(Condition.Fatigued);
        if (def == null)
            return false;

        bool applied = false;
        foreach (var m in _members)
        {
            if (m.Health == null || m.Health.IsDead)
                continue;

            var conds = m.Conditions;
            if (conds == null || conds.HasCondition(Condition.Fatigued))
                continue;

            conds.AddCondition(def, value: 0, duration: 0);
            applied = true;
        }

        if (applied)
            Changed?.Invoke();
        return applied;
    }

    // ===================== Rest (outpost sleep) =====================

    /// <summary>
    /// Full night's rest. The per-character PF2e rest rules are the engine's
    /// (<see cref="RestResolver.ApplyDailyRest"/>): daily preparations (slots refilled, prepared
    /// loadout re-prepared, focus and divine font refilled, daily uses reset), Fatigued removed,
    /// Doomed and Drained tick down 1, and Wounded ends at full HP. Bulwark passes
    /// <c>FullHeal = true</c> (house rule: HP to max instead of RAW Con mod × level — with full
    /// heal, Wounded is always removed). Game-side extras kept here: per-turn combat-state reset
    /// and shields mending to full (MVP deviation: no Repair activity exists yet).
    /// Dead members do not recover by sleeping (the resolver skips them).
    /// </summary>
    public void RestFully()
    {
        foreach (var m in _members)
        {
            m.Combat?.ResetTurnState();

            var options = new RestOptions
            {
                FullHeal = true,
                PreparedLoadout = _dailyPreparations.TryGetValue(m.Id, out var loadout)
                    ? loadout
                    : null,
            };
            var result = RestResolver.ApplyDailyRest(m, options);
            if (!result.Rested)
                continue; // dead

            var shield = m.Equipment?.Shield;
            if (shield?.EquippedShield != null)
                shield.SetCurrentShieldHP(shield.EquippedShield.MaxHP);
        }

        Changed?.Invoke();
    }

    // ===================== Save / restore (delta snapshot) =====================

    /// <summary>
    /// Snapshot the live delta from the deterministic presets: HP, death, persistent conditions,
    /// spell-slot usage (per-rank remaining preparations / slots), focus points, shield HP, XP.
    /// </summary>
    public List<SquadMemberDto> CaptureMembers()
    {
        var result = new List<SquadMemberDto>(_members.Count);
        foreach (var m in _members)
        {
            var weapon = m.Equipment?.MainHandWeapon;
            var dto = new SquadMemberDto
            {
                Id = m.Id,
                Level = m.Stats?.Level ?? Level,
                Xp = GetXp(m.Id),
                CurrentHp = m.Health?.CurrentHP ?? 0,
                IsDead = m.Health?.IsDead ?? false,
                ShieldHp = m.Equipment?.Shield?.EquippedShield != null
                    ? m.Equipment.Shield.CurrentShieldHP
                    : -1,
                FocusPoints = m.Spellcasting?.CurrentFocusPoints ?? 0,
                Conditions = CaptureConditions(m),
                SpellRanks = CaptureSpellRanks(m),
                FontSlotsRemaining = m.Spellcasting?.DivineFont?.CurrentSlots ?? -1,
                // Smithy state: the bought weapon slug (null = preset weapon) plus the live
                // fundamental-rune levels on the main-hand instance. StrikingRuneLevel.None is 1;
                // 0 means "absent" in older saves (restore skips it).
                WeaponSlug = _purchasedWeaponSlug.TryGetValue(m.Id, out var slug) ? slug : null,
                WeaponPotency = weapon?.PotencyBonus ?? 0,
                WeaponStriking = weapon != null ? (int)weapon.Striking : 0,
                // Party-join: a grown member carries its PartyPresets key so restore rebuilds it;
                // null for the fixed four (the default-squad snapshot is byte-identical).
                PresetKey = _grown.TryGetValue(m.Id, out var grown) ? grown.PresetKey : null,
            };
            result.Add(dto);
        }
        return result;
    }

    /// <summary>
    /// Rebuild the presets (deterministic) and re-apply a snapshot. Round-trip is exact for
    /// everything <see cref="CaptureMembers"/> captures.
    /// </summary>
    public void RestoreMembers(List<SquadMemberDto> snapshot, string? playerName = null)
    {
        _members.Clear();
        _xp.Clear();
        _dailyPreparations.Clear();
        _purchasedWeaponSlug.Clear();
        _grown.Clear();
        _playerName = playerName;

        foreach (var id in MemberOrder)
        {
            var dto = snapshot.Find(d => d.Id == id);
            // Members rebuild at their SAVED level (level-ups persist); saves predating the
            // per-member Level field carry the 0 default and fall back to the roster's build
            // level (GameState's SquadStartLevel). Live state overlays below via ApplyDelta.
            int level = dto != null && dto.Level >= 1 ? dto.Level : Level;
            var member = BuildMember(id, level);
            AddMember(member);
            if (dto != null)
                ApplyDelta(member, dto);
        }

        // Grown (party-joined) members: rebuild each from its PartyPresets key, appended after the
        // four. Skipped cleanly when the preset isn't registered (no content shipped) — the default
        // squad simply stays at four. A grown member's PresetKey identifies it; the fixed four never
        // carry one, so the MemberOrder guard is belt-and-suspenders.
        foreach (var dto in snapshot)
        {
            if (dto == null || string.IsNullOrEmpty(dto.PresetKey) || Array.IndexOf(MemberOrder, dto.Id) >= 0)
                continue;
            if (!PartyPresets.TryGet(dto.PresetKey!, out var spec))
                continue;
            int level = dto.Level >= 1 ? dto.Level : Level;
            var member = spec.Builder(level);
            if (member == null || FindMember(member.Id) != null)
                continue;
            AddMember(member);
            _grown[member.Id] = new GrownMemberSpec { PresetKey = dto.PresetKey!, Builder = spec.Builder, Combo = spec.Combo };
            ApplyDelta(member, dto);
        }

        Level = _members[0].Stats?.Level ?? Level;
        Changed?.Invoke();
    }

    private void AddMember(PF2eCharacter member)
    {
        _members.Add(member);
        _xp[member.Id] = 0;

        if (member.Spellcasting != null)
            _dailyPreparations[member.Id] = new List<SpellAction>(member.Spellcasting.LeveledSpells);

        // Keep MaxHP in sync when Drained is applied/removed on the live instance.
        member.Health?.SubscribeToConditionEvents();
    }

    private void ApplyDelta(PF2eCharacter member, SquadMemberDto dto)
    {
        _xp[member.Id] = dto.Xp;

        var db = ConditionDatabase.Instance;
        var conds = member.Conditions;
        if (db != null && conds != null && dto.Conditions != null)
        {
            foreach (var c in dto.Conditions)
            {
                if (!Enum.TryParse<Condition>(c.Condition, out var condition))
                    continue;
                var def = db.GetCondition(condition);
                if (def != null)
                    conds.AddCondition(def, value: c.Value, duration: 0);
            }
        }

        var health = member.Health;
        if (health != null)
        {
            health.RecalculateMaxHP(); // account for restored Drained
            if (dto.IsDead)
                health.ForceDeadState();
            else
                // Clamp to [1, MaxHP]: the save is always written post-cleanup, so 0 HP without
                // IsDead would be malformed — never re-trigger the dying pipeline from a load.
                health.SetCurrentHP(Math.Clamp(dto.CurrentHp, 1, health.MaxHP));
        }

        if (dto.ShieldHp >= 0)
            member.Equipment?.Shield?.SetCurrentShieldHP(dto.ShieldHp);

        RestoreWeapon(member, dto);

        RestoreSpellRanks(member, dto.SpellRanks, dto.FocusPoints);

        // Divine font usage (additive v2 field; -1 = absent/no font → keep the rebuilt pool).
        var font = member.Spellcasting?.DivineFont;
        if (font != null && dto.FontSlotsRemaining >= 0)
            font.RestoreState(dto.FontSlotsRemaining, font.FontRank);
    }

    /// <summary>
    /// Re-apply persisted smithy state after the preset rebuilt with its default weapon: re-equip a
    /// bought weapon (from its pack slug), then stamp the fundamental-rune levels onto the resulting
    /// main-hand instance. Older saves carry null slug / 0 rune levels and leave the preset weapon
    /// untouched. StrikingRuneLevel.None == 1, so a stored value ≥ 2 is a real striking rune.
    /// </summary>
    private void RestoreWeapon(PF2eCharacter member, SquadMemberDto dto)
    {
        if (!string.IsNullOrEmpty(dto.WeaponSlug) && member.Equipment != null)
        {
            var def = GameDataLoader.FindEquipment(dto.WeaponSlug)?.ToWeaponDefinition();
            if (def != null && ReequipMainHand(member, def))
                _purchasedWeaponSlug[member.Id] = dto.WeaponSlug!;
        }

        var weapon = member.Equipment?.MainHandWeapon;
        if (weapon == null)
            return;
        if (dto.WeaponPotency > 0)
            weapon.PotencyBonus = dto.WeaponPotency;
        if (dto.WeaponStriking >= (int)StrikingRuneLevel.Striking)
            weapon.Striking = (StrikingRuneLevel)dto.WeaponStriking;
    }

    private List<SquadConditionDto> CaptureConditions(PF2eCharacter member)
    {
        var result = new List<SquadConditionDto>();
        var conds = member.Conditions;
        if (conds == null)
            return result;

        // Only the persistence whitelist is captured: saves are written post-cleanup, so anything
        // else on the tracker is encounter noise that must not be resurrected by a load.
        foreach (var condition in PersistAcrossEncounters)
        {
            if (!conds.HasCondition(condition))
                continue;
            result.Add(new SquadConditionDto
            {
                Condition = condition.ToString(),
                Value = conds.GetConditionValue(condition),
            });
        }
        return result;
    }

    private static List<SpellRankDto>? CaptureSpellRanks(PF2eCharacter member)
    {
        var spellcasting = member.Spellcasting;
        if (spellcasting == null)
            return null;

        var ranks = new List<SpellRankDto>();
        for (int rank = 1; rank <= 10; rank++)
        {
            int max = spellcasting.GetMaxSlots(rank);
            if (max <= 0)
                continue;

            var dto = new SpellRankDto { Rank = rank };
            if (spellcasting.IsPreparedCaster)
            {
                // Prepared: remaining = uncast preparations at this rank, by stable spell id.
                // Focus spells (Force Bolt) are feature-granted, not slot preparations — the
                // deterministic rebuild re-grants them, so they are excluded from the snapshot
                // (RestoreSlotState preserves granted focus entries on restore).
                var ids = new List<string>();
                foreach (var spell in spellcasting.LeveledSpells)
                {
                    if (spell?.Spell == null || spell.Spell.SpellLevel != rank)
                        continue;
                    if (spell.Spell.IsFocusSpell)
                        continue;
                    ids.Add(string.IsNullOrEmpty(spell.SpellId) ? spell.ActionName : spell.SpellId);
                }
                dto.Remaining = ids.Count;
                dto.PreparedSpellIds = ids;
            }
            else
            {
                // Spontaneous: remaining = slot counter.
                dto.Remaining = spellcasting.GetCurrentSlots(rank);
            }
            ranks.Add(dto);
        }
        return ranks;
    }

    private static void RestoreSpellRanks(PF2eCharacter member, List<SpellRankDto>? ranks, int focusPoints)
    {
        var spellcasting = member.Spellcasting;
        if (spellcasting == null || ranks == null)
            return;

        // Bridge into the engine's own save-restoration API (handles both prepared and spontaneous
        // models and clears consumed-preparation tracking).
        var slots = new SpellLevelSnapshot[10];
        foreach (var dto in ranks)
        {
            if (dto.Rank < 1 || dto.Rank > 10)
                continue;
            slots[dto.Rank - 1] = new SpellLevelSnapshot
            {
                Remaining = dto.Remaining,
                Max = spellcasting.GetMaxSlots(dto.Rank),
                SpellIds = dto.PreparedSpellIds?.ToArray(),
                SpellNames = dto.PreparedSpellIds?.ToArray(),
            };
        }
        spellcasting.RestoreSlotState(slots, focusPoints);
    }
}
