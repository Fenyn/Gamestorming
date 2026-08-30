using System.Collections.Generic;
using System.Text;
using PF2e.Actions;
using PF2e.Import;

namespace Delve.Flow;

/// <summary>
/// The one shorthand grammar every spell line on the sheet uses, so the same fact always looks the
/// same: <c>2A · 15-ft cone · basic Ref · 2d6 fire · sustained</c>. Token order is fixed - cost,
/// range or area, defence, effect dice, duration - and a fact the spell does not have is skipped,
/// never padded. Tokens: <c>nA</c> action cost, <c>R</c> reaction, <c>ft</c> feet,
/// Fort/Ref/Will for saves ("basic" when the save is a basic save), <c>spell atk</c> for attack
/// rolls, dice + damage type for effects, <c>heal</c> for healing.
///
/// Godot-free; the spike reads the same tokens the card prints.
/// </summary>
public static class SpellShorthand
{
    /// <summary>"2A · 30 ft · Ref save" for one spell, from pack data with the preset's own
    /// action as the fallback. Empty when nothing is known.</summary>
    public static string Tokens(ImportedSpell? imported, SpellAction? spell = null)
    {
        var tokens = new List<string>();

        int cost = imported?.ActionCost > 0 ? imported.ActionCost : spell?.ActionCostCount ?? 0;
        if (cost is >= 1 and <= 3) tokens.Add($"{cost}A");

        string place = Place(imported);
        if (place.Length > 0) tokens.Add(place);

        string defense = Defense(imported?.Defense);
        if (defense.Length > 0) tokens.Add(defense);

        string effect = Effect(imported?.DamageEntries);
        if (effect.Length > 0) tokens.Add(effect);

        if (imported?.Duration is { } duration)
        {
            if (duration.Sustained) tokens.Add("sustained");
            // "varies"/"unlimited" tell the reader nothing at a glance; the prose covers them.
            else if (duration.Text is { Length: > 0 and <= 12 } text
                     && text != "varies" && text != "unlimited")
            {
                tokens.Add(text);
            }
        }

        return string.Join(" · ", tokens);
    }

    /// <summary>The area when there is one ("15-ft cone"), else the range ("30 ft", "touch").</summary>
    private static string Place(ImportedSpell? imported)
    {
        if (imported == null) return "";
        if (imported.Area is { Value: > 0 } area && area.Type is { Length: > 0 })
            return $"{area.Value}-ft {area.Type}";

        string range = imported.Range ?? "";
        return range.Replace(" feet", " ft").Replace(" foot", "-ft");
    }

    private static string Defense(SpellDefenseInfo? defense)
    {
        if (defense == null) return "";
        if (defense.IsSpellAttack) return "spell atk";
        if (defense.SaveType is not { Length: > 0 } save) return "";

        string name = save.ToLowerInvariant() switch
        {
            "fortitude" => "Fort",
            "reflex" => "Ref",
            "will" => "Will",
            _ => save,
        };
        return defense.IsBasicSave ? $"basic {name}" : $"{name} save";
    }

    /// <summary>"2d6 fire", or "heal 1d8" when the dice put hit points back.</summary>
    private static string Effect(IReadOnlyList<SpellDamageInfo>? entries)
    {
        if (entries == null || entries.Count == 0) return "";

        var sb = new StringBuilder();
        foreach (var entry in entries)
        {
            if (entry.Formula is not { Length: > 0 }) continue;
            if (sb.Length > 0) sb.Append(" + ");
            bool heals = entry.Kinds.Contains("healing");
            sb.Append(heals ? $"heal {entry.Formula}"
                : $"{entry.Formula} {entry.DamageType.ToString().ToLowerInvariant()}");
        }
        return sb.ToString();
    }
}
