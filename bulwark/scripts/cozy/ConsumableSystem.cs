using System.Collections.Generic;
using System.Threading.Tasks;
using Bulwark.Data;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Equipment;
using EngineConsumable = PF2e.Equipment.ConsumableDefinition;
using EngineEffect = PF2e.Equipment.ConsumableEffectDefinition;

namespace Bulwark.Cozy;

/// <summary>
/// The per-fight / instant CONSUMABLE layer: drinking a healing potion, quaffing a combat elixir, or
/// applying an antidote — used IN COMBAT as an action (cost + manipulate-tagged) or out of combat. Plain
/// C#; GameState owns the single instance and wraps it in the <c>UseItem</c> command + the combat action path.
///
/// TRANSLATION: bulwark <see cref="Bulwark.Data.ConsumableDefinition"/> data (a list of bulwark-local
/// <see cref="ConsumableEffect"/>s) is mapped here into the engine's data-driven
/// <see cref="PF2e.Equipment.ConsumableDefinition"/>, then applied through the CALL-only
/// <see cref="ConsumableEffectResolver"/> / <see cref="PF2e.Actions.UseConsumableAction"/>. No engine type
/// escapes into UI — the system exposes bulwark data + view text.
///
/// SCOPE vs MEALS: meals (<see cref="MealSystem"/>) are DAY-LONG whole-roster buffs. Consumables are
/// PER-FIGHT/instant, single-target (the drinker), consumed from that member's carry. A combat elixir's
/// buff is COMBAT-SCOPED: it expires on its round duration (<see cref="AdvanceCombatRound"/>) or is cleared
/// at the encounter boundary (<see cref="ClearCombatEffects"/>) — it does NOT persist like a meal, so
/// nothing new is saved (the items themselves are already persisted inventory).
///
/// POISONS DEFERRED: the framework (durations, item-bonus effects, a Fortitude-resistance kind) is present
/// so poisons slot in later as pure data + one resolver kind; no poison content ships.
/// </summary>
public sealed class ConsumableSystem
{
    private readonly SquadRoster? _squad;

    // Live combat-scoped effect handles (elixir/antidote buffs) awaiting round-expiry or encounter-clear.
    private readonly List<AppliedConsumableEffect> _activeEffects = new();

    public ConsumableSystem(SquadRoster? squad)
    {
        _squad = squad;
    }

    /// <summary>Count of lasting consumable buffs currently live (for tests / diagnostics).</summary>
    public int ActiveEffectCount => _activeEffects.Count;

    // ===================== Translation (bulwark data → engine data) =====================

    /// <summary>Build the engine consumable definition for an item id, or null if it is not a defined
    /// consumable. The single point that turns bulwark <see cref="ConsumableEffect"/>s into engine effects.</summary>
    public static EngineConsumable? EngineDefinition(string itemId)
    {
        if (!Consumables.TryGet(itemId, out var def))
            return null;

        var effects = new List<EngineEffect>(def.Effects.Count);
        foreach (var e in def.Effects)
        {
            switch (e.Type)
            {
                case ConsumableEffectType.Heal:
                    effects.Add(EngineEffect.Heal(e.Magnitude));
                    break;
                case ConsumableEffectType.TempHp:
                    effects.Add(EngineEffect.TempHp(e.Magnitude, e.DurationRounds));
                    break;
                case ConsumableEffectType.FortitudeSave:
                    effects.Add(EngineEffect.Stat(StatType.Fortitude, e.Magnitude, ModifierType.Item, e.DurationRounds));
                    break;
                case ConsumableEffectType.ArmorClass:
                    effects.Add(EngineEffect.Stat(StatType.AC, e.Magnitude, ModifierType.Item, e.DurationRounds));
                    break;
                case ConsumableEffectType.AttackRoll:
                    effects.Add(EngineEffect.Stat(StatType.AttackRoll, e.Magnitude, ModifierType.Item, e.DurationRounds));
                    break;
            }
        }
        return new EngineConsumable(def.Id, def.DisplayName, effects, def.ActionCost, isManipulate: true);
    }

    // ===================== Out-of-combat use =====================

    /// <summary>
    /// Use a consumable OUT OF COMBAT (no action cost): consume one from the party Bulk inventory and apply
    /// its effect to <paramref name="recipient"/>. Rejects cleanly (false, NOTHING consumed) when the id is
    /// not a consumable, the recipient is null, or the party doesn't hold the item. A lasting buff (elixir /
    /// antidote) is tracked so it clears at the next encounter boundary (combat-scoped, never persisted).
    /// </summary>
    public bool UseOutOfCombat(string itemId, PF2eCharacter? recipient, Inventory inventory)
    {
        var def = EngineDefinition(itemId);
        if (def == null || recipient == null || inventory == null)
            return false;

        if (!inventory.RemoveItem(itemId, 1)) // validated present by RemoveItem's own guard — no mutation on miss
            return false;

        var handle = ConsumableEffectResolver.Apply(recipient, def).Effect;
        if (handle != null)
            _activeEffects.Add(handle);
        return true;
    }

    // ===================== In-combat use (an action) =====================

    /// <summary>
    /// Use a consumable IN COMBAT as <paramref name="member"/>'s action: run the engine
    /// <see cref="PF2e.Actions.UseConsumableAction"/> (spends the action(s), manipulate-tagged so it can
    /// trigger a Reactive Strike) and CONSUME the item from THAT member's carry. Rejects cleanly (false,
    /// nothing consumed, no action spent) when the id is not a consumable or the member is not carrying it.
    /// A resulting combat buff is registered for round-expiry.
    /// </summary>
    public async Task<bool> UseInCombat(PF2eCharacter? member, string itemId, Inventory inventory, ICharacter? target = null)
    {
        var def = EngineDefinition(itemId);
        if (def == null || member == null || inventory == null)
            return false;

        // Must be carrying it — reject BEFORE any cost/effect so nothing changes when absent.
        if (inventory.MemberCount(member.Id, itemId) < 1)
            return false;

        var action = new PF2e.Actions.UseConsumableAction(def)
        {
            OnConsumed = () => inventory.RemoveFromMember(member.Id, itemId, 1),
        };

        await action.ExecuteAsync(member, target);

        if (action.LastApplied != null)
            _activeEffects.Add(action.LastApplied);
        return true;
    }

    // ===================== Combat-scoped lifetime =====================

    /// <summary>Advance one combat round: tick every live consumable buff, dropping those that expire. Wire
    /// to the encounter's round tick (TurnManager.OnRoundEnd) so short combat elixirs expire mid-fight.</summary>
    public void AdvanceCombatRound()
    {
        for (int i = _activeEffects.Count - 1; i >= 0; i--)
        {
            var effect = _activeEffects[i];
            if (!effect.IsActive || effect.TickRound())
                _activeEffects.RemoveAt(i);
        }
    }

    /// <summary>Clear ALL live consumable buffs — the encounter-boundary cleanup (combat-scoped effects do
    /// not persist across fights or into the save). Idempotent.</summary>
    public void ClearCombatEffects()
    {
        foreach (var effect in _activeEffects)
            effect.Expire();
        _activeEffects.Clear();
    }
}
