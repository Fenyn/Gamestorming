using System;
using System.Collections.Generic;
using Bulwark.Data;
using Bulwark.Presets;
using PF2e.Actions;
using PF2e.CharacterComponents;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
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
    public const string VeteranId = "the-veteran";
    public const string ScoutId = "the-scout";
    public const string MedicId = "the-medic";
    public const string ScholarId = "the-scholar";

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
    /// Long-term conditions captured into the save file (see <see cref="CaptureConditions"/>).
    /// Encounter cleanup itself now relies on the engine's duration classification
    /// (<c>ConditionTracker.RemoveNonPersistingConditions</c>), not this list.
    /// </summary>
    private static readonly Condition[] PersistAcrossEncounters =
    {
        Condition.Wounded, Condition.Drained, Condition.Doomed, Condition.Fatigued,
    };

    private static readonly string[] MemberOrder = { VeteranId, ScoutId, MedicId, ScholarId };

    private static readonly Dictionary<string, Func<int, PF2eCharacter>> Builders = new()
    {
        [VeteranId] = lvl => PresetCharacters.BuildVeteran(lvl),
        [ScoutId] = lvl => PresetCharacters.BuildScout(lvl),
        [MedicId] = lvl => PresetCharacters.BuildMedic(lvl),
        [ScholarId] = lvl => PresetCharacters.BuildScholar(lvl),
    };

    // Each member's locked combo: the per-level scripted choices ApplyBankedLevelUps replays
    // through LevelUpApplicator (same source the preset builders replay from).
    private static readonly Dictionary<string, VariantComboDefinition> Combos = new()
    {
        [VeteranId] = PresetCombos.FighterSentinel,
        [ScoutId] = PresetCombos.RogueThief,
        [MedicId] = PresetCombos.ClericWarpriest,
        [ScholarId] = PresetCombos.WizardBattleMagic,
    };

    private readonly List<PF2eCharacter> _members = new();
    private readonly Dictionary<string, int> _xp = new();

    // Each prepared caster's daily loadout, captured at build time (LeveledSpells starts full).
    // RestFully re-prepares from this list — PF2e daily preparations.
    private readonly Dictionary<string, List<SpellAction>> _dailyPreparations = new();

    /// <summary>Raised after any squad-state mutation (encounter completion, rest, restore).</summary>
    public event Action? Changed;

    public IReadOnlyList<PF2eCharacter> Members => _members;

    /// <summary>Party level for XP budgeting (presets are built uniformly at this level).</summary>
    public int Level { get; private set; }

    private SquadRoster(int level)
    {
        Level = Math.Max(1, level);
        foreach (var id in MemberOrder)
            AddMember(Builders[id](Level));
    }

    /// <summary>Build the four live preset PCs once for a new save.</summary>
    public static SquadRoster BuildNew(int level) => new(level);

    public PF2eCharacter? FindMember(string memberId) => _members.Find(m => m.Id == memberId);

    public int GetXp(string memberId) => _xp.TryGetValue(memberId, out var xp) ? xp : 0;

    /// <summary>Level-up is banked, not applied — the sleep command owns applying it
    /// (<see cref="ApplyBankedLevelUps"/>, capped at <see cref="MaxAppliedLevel"/>).</summary>
    public bool CanLevelUp(string memberId) => GetXp(memberId) >= XpPerLevel;

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
            var combo = Combos[m.Id];

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
    /// </summary>
    public void CompleteEncounter(BattleResult result, IReadOnlyList<ICharacter>? defeatedEnemies)
    {
        foreach (var m in _members)
            CleanUpAfterEncounter(m);

        if (result == BattleResult.Team1Wins && defeatedEnemies != null)
        {
            int encounterXp = 0;
            foreach (var enemy in defeatedEnemies)
                encounterXp += EncounterXPCalculator.GetCreatureXP(GetEnemyLevel(enemy), Level);

            foreach (var m in _members)
                _xp[m.Id] = GetXp(m.Id) + encounterXp;
        }

        Changed?.Invoke();
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
            };
            result.Add(dto);
        }
        return result;
    }

    /// <summary>
    /// Rebuild the presets (deterministic) and re-apply a snapshot. Round-trip is exact for
    /// everything <see cref="CaptureMembers"/> captures.
    /// </summary>
    public void RestoreMembers(List<SquadMemberDto> snapshot)
    {
        _members.Clear();
        _xp.Clear();
        _dailyPreparations.Clear();

        foreach (var id in MemberOrder)
        {
            var dto = snapshot.Find(d => d.Id == id);
            // Members rebuild at their SAVED level (level-ups persist); saves predating the
            // per-member Level field carry the 0 default and fall back to the roster's build
            // level (GameState's SquadStartLevel). Live state overlays below via ApplyDelta.
            int level = dto != null && dto.Level >= 1 ? dto.Level : Level;
            var member = Builders[id](level);
            AddMember(member);
            if (dto != null)
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

        RestoreSpellRanks(member, dto.SpellRanks, dto.FocusPoints);

        // Divine font usage (additive v2 field; -1 = absent/no font → keep the rebuilt pool).
        var font = member.Spellcasting?.DivineFont;
        if (font != null && dto.FontSlotsRemaining >= 0)
            font.RestoreState(dto.FontSlotsRemaining, font.FontRank);
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
