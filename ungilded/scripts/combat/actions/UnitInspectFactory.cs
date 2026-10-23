using System.Collections.Generic;
using Ungilded.Knowledge;
using PF2e.Core;
using PF2e.Data;
using PF2e.Grid;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

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

    /// <summary>The mark an unrevealed knowledge row shows.</summary>
    internal const string HiddenMark = "???";

    /// <summary>The card's knowledge rows for an enemy: AC, the three saves, weakness and
    /// abilities (its stat-block strikes), each "???" until Recall Knowledge reveals it. Empty for
    /// a party member.</summary>
    internal static IReadOnlyList<JournalFact> KnowledgeRows(ICharacter c)
    {
        if (c.CreatureStats is not { } stats) return System.Array.Empty<JournalFact>();
        string? id = stats.CreatureId;
        JournalFact Row(CreatureKnowledgeField field, string label, bool wide, string? known = null)
        {
            bool isKnown = IsCreatureFieldKnown(id, field);
            string value = isKnown ? known ?? CreatureFacts.Value(field, stats.SourceDefinition, stats.Data) : HiddenMark;
            return new JournalFact($"{label} {value}", isKnown, wide);
        }
        int ac = StatsCalculator.CalculateAC(c);
        var rows = new JournalFact[CardRows.Length];
        for (int i = 0; i < CardRows.Length; i++)
        {
            var (field, label, wide) = CardRows[i];
            rows[i] = Row(field, label, wide, field == CreatureKnowledgeField.AC ? AcPair(c, ac)["AC ".Length..] : null);
        }
        return rows;
    }

    /// <summary>The card's knowledge rows in order, with their labels. Wide rows hold long values
    /// (a weakness list, the strikes) and get a line each on the card.</summary>
    private static readonly (CreatureKnowledgeField Field, string Label, bool Wide)[] CardRows =
    {
        (CreatureKnowledgeField.AC, "AC", false),
        (CreatureKnowledgeField.FortSave, "Fort", false),
        (CreatureKnowledgeField.RefSave, "Ref", false),
        (CreatureKnowledgeField.WillSave, "Will", false),
        (CreatureKnowledgeField.Weaknesses, "Weakness", true),
        (CreatureKnowledgeField.Strikes, "Abilities", true),
    };

    /// <summary>The label of a field's row on the card ("Weakness"), or the field name when the card has no such row.</summary>
    internal static string CardLabel(CreatureKnowledgeField field)
    {
        foreach (var (f, label, _) in CardRows)
            if (f == field) return label;
        return field.ToString();
    }

    /// <summary>"AC 16", or "AC 16 → 15" while conditions or a raised shield move it, so the change
    /// reads as a before→after pair instead of a number that silently differs from last turn.</summary>
    internal static string AcPair(ICharacter c, int ac)
    {
        int modifiers = c.Modifiers?.GetModifierTotal(PF2e.Conditions.StatType.AC) ?? 0;
        return modifiers == 0 ? $"AC {ac}" : $"AC {ac - modifiers} → {ac}";
    }

    /// <param name="shownHp">The HP the board shows, which trails the live HP while a roll plays;
    /// null reads the live HP.</param>
    internal static UnitInspectView BuildInspectView(ICharacter c, int? shownHp = null)
    {
        var conditions = new List<string>(ConditionMarks.Labels(c));
        if (c.Equipment?.IsShieldRaised == true)
            conditions.Add("Shield Raised");

        // Only creatures (enemies with a stat block) are gated; PC sheets have no CreatureStats.
        string? creatureId = c.CreatureStats?.CreatureId;
        bool isCreature = c.CreatureStats != null;
        bool acKnown = !isCreature || IsCreatureFieldKnown(creatureId, CreatureKnowledgeField.AC);
        bool hpKnown = !isCreature || IsCreatureFieldKnown(creatureId, CreatureKnowledgeField.MaxHP);

        int hp = shownHp ?? c.Health?.CurrentHP ?? 0;
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
            Level = isCreature ? c.CreatureStats!.Level : c.Stats?.Level ?? 0,
            ClassName = isCreature ? "" : c.Stats?.CharacterClass?.ClassName ?? "",
            HeroId = isCreature ? "" : c.Id,
            Reaction = ActiveCharacterView.ReactionOf(c),
            Conditions = conditions,
            AcText = acKnown ? AcPair(c, ac) : "AC ?",
            HpText = hpKnown ? $"{hp}/{maxHp}" : "?/?",
            // Hidden creature facts are a rule wherever a journal is wired: the card lists them as ???.
            KnowledgeRows = CreatureKnowledgeLocator.Instance != null
                ? KnowledgeRows(c) : System.Array.Empty<JournalFact>(),
        };
    }
}
