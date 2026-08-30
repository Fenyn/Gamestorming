using System.Collections.Generic;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Delve.Combat;

/// <summary>
/// Builds the hover-inspect snapshot for whatever stands on a tile, and owns the bestiary-knowledge
/// gate that masks an unstudied creature's exact AC and HP.
/// </summary>
internal static class UnitInspectFactory
{
    /// <summary>
    /// Compact inspection snapshot of the unit occupying <paramref name="tile"/>, or null when the
    /// tile is empty. Read-only, no side effects — feeds the hover-inspect panel (works for any
    /// occupied tile, any mode, any team). Conditions come straight from the character's
    /// ConditionTracker plus a synthesized "Shield Raised" entry (not itself a condition).
    ///
    /// KNOWLEDGE-GATED for creatures: an enemy's name, conditions and HP BAR are always readable
    /// (they are what the board already shows), but the exact AC and HP numbers stay masked until
    /// Recall Knowledge reveals those fields for its species. Allies are never gated. The masking is
    /// resolved here, as text, so the panel renders without knowing the rule.
    /// </summary>
    internal static UnitInspectView? GetUnitInspect(BattleGrid grid, PF2eVec tile)
    {
        var c = grid.GetGroundOccupant(tile);
        return c == null ? null : BuildInspectView(c);
    }

    /// <summary>
    /// Whether a creature's stat-block <paramref name="field"/> is known to the player. Reads the
    /// game's <see cref="ICreatureKnowledgeProvider"/> through the engine locator, which
    /// <c>GameState</c> is the only thing that ever sets. UNGATED (true) when there is no journal
    /// wired (standalone combat scene, headless spike) or the subject has no species id — a
    /// bestiary-less run must not read as "everything unknown".
    /// </summary>
    internal static bool IsCreatureFieldKnown(string? creatureId, CreatureKnowledgeField field)
    {
        var provider = CreatureKnowledgeLocator.Instance;
        if (provider == null || string.IsNullOrEmpty(creatureId))
            return true;
        return provider.IsFieldRevealed(creatureId!, field);
    }

    private static UnitInspectView BuildInspectView(ICharacter c)
    {
        var conditions = new List<string>();
        foreach (var instance in c.Conditions?.GetAllConditions() ?? new List<ConditionInstance>())
        {
            conditions.Add(instance.Definition.HasValue && instance.Value > 0
                ? $"{instance.Definition.DisplayName} {instance.Value}"
                : instance.Definition.DisplayName);
        }
        if (c.Equipment?.IsShieldRaised == true)
            conditions.Add("Shield Raised");

        // Only creatures (enemies with a stat block) are gated; PC sheets have no CreatureStats.
        string? creatureId = c.CreatureStats?.CreatureId;
        bool isCreature = c.CreatureStats != null;
        bool acKnown = !isCreature || IsCreatureFieldKnown(creatureId, CreatureKnowledgeField.AC);
        bool hpKnown = !isCreature || IsCreatureFieldKnown(creatureId, CreatureKnowledgeField.MaxHP);

        int hp = c.Health?.CurrentHP ?? 0;
        int maxHp = c.Health?.MaxHP ?? 0;
        int ac = StatsCalculator.CalculateAC(c);

        return new UnitInspectView
        {
            Name = c.Name,
            TeamId = c.TeamId,
            IsAlly = c.TeamId == 1,
            Hp = hp,
            MaxHp = maxHp,
            Ac = ac,
            Conditions = conditions,
            AcText = acKnown ? $"AC {ac}" : "AC ?",
            HpText = hpKnown ? $"{hp}/{maxHp}" : "?/?",
        };
    }
}
