using System;
using Bulwark.Data;
using PF2e.Conditions;

namespace Bulwark.Cozy;

/// <summary>
/// The Phase-5 meal buff system: eating a meal at camp applies a DAY-LONG buff to the whole roster
/// pool, lasting until the next rest/day. Plain C#; GameState owns the single instance and wraps it
/// in the EatMeal command.
///
/// SCOPE (decision — confirm/adjust): the buff applies to every living ROSTER-POOL member (whoever
/// adventures carries it), not the selected party — the party is chosen per expedition and any pooled
/// member may go. SINGLE-ACTIVE: eating a meal replaces whatever meal was active (its buff is cleared
/// first). DURATION: cleared on the next day rollover (any path — sleep, all-nighter, defeat wake),
/// hooked in GameState.AdvanceDay.
///
/// ENGINE PATH (CALL-only — no engine edit): each buff kind maps to an existing engine API on the
/// live PF2eCharacter that combat already reads:
///   TempHp        → Health.GrantTempHP (absorbs damage; visible in Health.TempHP)
///   FortitudeSave → ModifierStack.AddModifier(status ConditionModifier on Fortitude)
///   Speed         → ModifierStack.AddModifier(status ConditionModifier on Speed)
///   AttackRoll    → ModifierStack.AddModifier(status ConditionModifier on AttackRoll — attack umbrella)
///   ArmorClass    → ModifierStack.AddModifier(status ConditionModifier on AC)
/// Both the modifier stack and temp-HP source are tagged with <see cref="BuffSourceName"/> /
/// <see cref="_buffSource"/> so clearing is surgical (never touches combat-granted temp HP or other
/// modifiers). The buff lives on the live instances only — never serialized — so on load GameState
/// restores the ACTIVE MEAL ID and calls <see cref="ReapplyToSquad"/> to recompute it.
///
/// DAY-LONG vs PER-COMBAT (Refinement 1): a meal is a day-long benefit cleared only on the next day
/// rollover (GameState.AdvanceDay → <see cref="ClearActive"/>). Its PERSISTENT components (the status
/// modifiers) are applied once on eat and left on the ModifierStack all day — post-combat cleanup
/// (SquadRoster.CompleteEncounter) never strips modifier sources, so they survive every fight. Its
/// PER-COMBAT component (temp HP) IS wiped by that cleanup (Health.ClearTempHP), so it is re-granted at
/// the START of each encounter via <see cref="RefreshPerCombat"/> (GameState.BeginTerritoryEncounter) —
/// well-fed = a fresh temp-HP cushion every fight, all day.
/// </summary>
public sealed class MealSystem
{
    /// <summary>Source tag on every meal-granted modifier (removal key).</summary>
    public const string BuffSourceName = "Meal Buff";

    // Stable object identity for temp-HP grants, so ClearTempHP(source) only clears meal temp HP.
    private readonly object _buffSource = new();

    private readonly SquadRoster? _squad;
    private string? _activeMealId;

    /// <summary>Raised after the active meal changes (eaten, replaced, or cleared).</summary>
    public event Action? Changed;

    public MealSystem(SquadRoster? squad)
    {
        _squad = squad;
    }

    /// <summary>The currently active meal id, or null when none is active (baseline = no buff).</summary>
    public string? ActiveMealId => _activeMealId;

    // ===================== Command =====================

    /// <summary>
    /// Eat a meal: consume one of its Food item from the party inventory and apply its day-long buff
    /// to the roster. Single-active — any previously active meal's buff is cleared first (the new
    /// meal replaces it). Rejects cleanly (false, nothing consumed) when the squad is unavailable, the
    /// meal id is unknown, or the party doesn't hold the Food item. Emits <see cref="Changed"/>.
    /// </summary>
    public bool EatMeal(string mealId, Inventory inventory)
    {
        if (_squad == null || inventory == null || !Meals.TryGet(mealId, out var meal))
            return false;

        // Consume one meal item (validated present by RemoveItem's own guard — no mutation on miss).
        if (!inventory.RemoveItem(meal.Id, 1))
            return false;

        ClearBuffModifiers();      // drop the previous meal's buff (single-active)
        _activeMealId = mealId;
        ApplyBuff(meal);
        Changed?.Invoke();
        return true;
    }

    // ===================== Day/rest clearing =====================

    /// <summary>
    /// Clear the active meal and its buff — the day-long expiry hook (GameState.AdvanceDay calls this
    /// on every day rollover: sleep, all-nighter, defeat wake). Idempotent: a no-op when no meal is
    /// active. Emits <see cref="Changed"/> only when a meal was actually cleared.
    /// </summary>
    public void ClearActive()
    {
        if (_activeMealId == null)
        {
            // Defensive: still strip any stray buff modifiers (e.g. after a load with no meal).
            ClearBuffModifiers();
            return;
        }
        _activeMealId = null;
        ClearBuffModifiers();
        Changed?.Invoke();
    }

    // ===================== Save / restore =====================

    /// <summary>The active meal id to persist (null = none).</summary>
    public string? Capture() => _activeMealId;

    /// <summary>
    /// Restore the active meal id from a save and re-apply its buff to the (freshly rebuilt) roster.
    /// Version-tolerant: null / unknown id clears to "no meal active". Silent (no <see cref="Changed"/>
    /// — a restore is not a gameplay change). GameState calls this after RestoreMembers so the buff
    /// lands on the live instances combat will read.
    /// </summary>
    public void Restore(string? mealId)
    {
        ClearBuffModifiers();
        _activeMealId = mealId != null && Meals.IsDefined(mealId) ? mealId : null;
        ReapplyToSquad();
    }

    /// <summary>Re-apply the active meal's buff to the current roster (idempotent — clears first).
    /// Used on load and any time the roster's live instances were rebuilt.</summary>
    public void ReapplyToSquad()
    {
        ClearBuffModifiers();
        if (_activeMealId != null && Meals.TryGet(_activeMealId, out var meal))
            ApplyBuff(meal);
    }

    // ===================== Per-combat refresh (encounter-start seam) =====================

    /// <summary>
    /// Re-grant the active meal's PER-COMBAT components (temp HP) to every living roster member — the
    /// encounter-START seam (GameState.BeginTerritoryEncounter calls this before combat reads the live
    /// instances). Post-combat cleanup wiped the temp HP after the previous fight, so a well-fed squad
    /// gets a fresh cushion each fight, all day. No-op when no meal is active or the active meal is a
    /// PERSISTENT-only buff (stat/attack/AC — those were applied on eat and never cleared by combat).
    /// Surgical: clears only the meal's own temp-HP source first, so combat-granted temp HP and the
    /// persistent modifiers are untouched.
    /// </summary>
    public void RefreshPerCombat()
    {
        if (_squad == null || _activeMealId == null || !Meals.TryGet(_activeMealId, out var meal))
            return;
        if (!meal.IsPerCombatRefreshed)
            return;

        foreach (var m in _squad.Members)
        {
            if (m.Health == null || m.Health.IsDead)
                continue;
            m.Health.ClearTempHP(_buffSource);           // drop last fight's stale meal temp HP (source-tagged)
            ApplyBuffKind(m, meal.Buff, meal.Magnitude); // fresh grant for this fight
        }
    }

    // ===================== Engine buff application (CALL-only) =====================

    private void ApplyBuff(MealDefinition meal)
    {
        if (_squad == null)
            return;

        foreach (var m in _squad.Members)
        {
            if (m.Health == null || m.Health.IsDead)
                continue;
            ApplyBuffKind(m, meal.Buff, meal.Magnitude);
        }
    }

    /// <summary>Apply one buff kind's engine effect to a single living member (CALL-only). Shared by
    /// the whole-meal apply (persistent + per-combat, on eat/load) and the per-combat refresh.</summary>
    private void ApplyBuffKind(PF2e.Core.PF2eCharacter m, MealBuffKind kind, int magnitude)
    {
        switch (kind)
        {
            case MealBuffKind.TempHp:
                // durationRounds -1 = no combat expiry; the day-rollover clear is our expiry.
                m.Health!.GrantTempHP(magnitude, _buffSource, durationRounds: -1);
                break;
            case MealBuffKind.FortitudeSave:
                AddStatusModifier(m, StatType.Fortitude, magnitude);
                break;
            case MealBuffKind.Speed:
                AddStatusModifier(m, StatType.Speed, magnitude);
                break;
            case MealBuffKind.AttackRoll:
                AddStatusModifier(m, StatType.AttackRoll, magnitude);
                break;
            case MealBuffKind.ArmorClass:
                AddStatusModifier(m, StatType.AC, magnitude);
                break;
        }
    }

    private void ClearBuffModifiers()
    {
        if (_squad == null)
            return;

        foreach (var m in _squad.Members)
        {
            m.Modifiers?.RemoveModifiersBySource(BuffSourceName);
            m.Health?.ClearTempHP(_buffSource);
        }
    }

    private static void AddStatusModifier(PF2e.Core.PF2eCharacter member, StatType stat, int value)
    {
        if (member.Modifiers == null)
            return;
        member.Modifiers.AddModifier(new ConditionModifier
        {
            TargetStat = stat,
            Type = ModifierType.Status,
            Value = value,
            Source = BuffSourceName,
            SourceInstanceId = Guid.NewGuid(),
        });
    }
}
