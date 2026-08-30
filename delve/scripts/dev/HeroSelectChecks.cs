using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using Delve.Flow;
using Delve.Run;
using Godot;
using PF2e.Core;
using PF2e.Utilities;

namespace Delve.Dev;

/// <summary>
/// The predicates and lookups <see cref="HeroSelectSpike"/> asserts with, kept out of the screen
/// walk so the spike file stays the story of the screen and this stays the list of rules the
/// overview has to obey.
/// </summary>
internal static class HeroSelectChecks
{
    /// <summary>Every roster card under the panel, so the spike reads the state the player sees.</summary>
    internal static List<RosterCard> Cards(Node node)
    {
        var found = new List<RosterCard>();
        Collect(node, found);
        return found;
    }

    private static void Collect(Node node, List<RosterCard> cards)
    {
        foreach (var child in node.GetChildren())
        {
            if (child is RosterCard card) cards.Add(card);
            Collect(child, cards);
        }
    }

    internal static RosterCard? Card(List<RosterCard> cards, string id) => cards.Find(c => c.Id == id);

    /// <summary>The confirmed payload is only right if <see cref="Party.Build"/> accepts it.</summary>
    internal static bool BuildsAParty(string? leader, IReadOnlyList<string>? members)
    {
        if (leader == null || members == null) return false;
        try
        {
            return Party.Build(leader, members, new UnlockState(), Party.DefaultLevel).Members.Count == 1;
        }
        catch (ArgumentException e)
        {
            GD.PushError($"[HeroSelect] the confirmed payload is not a legal party: {e.Message}");
            return false;
        }
    }

    /// <summary>The words on the last chip of a row, or "" when the row built none.</summary>
    internal static string LastChip(Node items)
    {
        int count = items.GetChildCount();
        if (count == 0) return "";
        var last = items.GetChild(count - 1);
        return (last as Label)?.Text ?? last.GetChildOrNull<Label>(0)?.Text ?? "";
    }

    /// <summary>A proficiency rank letter standing on its own in a printed line. The overview
    /// spells ranks out on the hover instead, so none may reach the page.</summary>
    private static readonly Regex RankLetter = new(@"(?:^|[ ·])[TEML](?:$|[ ·])", RegexOptions.Compiled);

    /// <summary>The value under one headline label, or null when the sheet has no such box.</summary>
    internal static string? Headline(HeroSheetData sheet, string label)
    {
        foreach (var headline in sheet.Headlines)
        {
            if (headline.Label == label) return headline.Value;
        }
        return null;
    }

    /// <summary>The three-letter code of the ability the class is built on, or "" when the sheet
    /// flags none. The headline box has to print exactly this and nothing else.</summary>
    internal static string KeyAbilityCode(HeroSheetData sheet)
    {
        foreach (var ability in sheet.Abilities)
        {
            if (ability.IsKey) return ability.Code;
        }
        return "";
    }

    internal static int KeyAbilities(HeroSheetData sheet)
    {
        int keys = 0;
        foreach (var ability in sheet.Abilities)
        {
            if (ability.IsKey) keys++;
        }
        return keys;
    }

    internal static int RowEntries(HeroSheetData sheet, string label)
        => sheet.Row(label)?.Entries.Count ?? 0;

    /// <summary>Every row reads as one line of plain words - no wrapped paragraph, no empty row.</summary>
    internal static bool SingleLine(HeroSheetData sheet)
    {
        foreach (var row in sheet.Rows)
        {
            if (row.Entries.Count == 0 || row.Line.Contains('\n')) return false;
            if (row.Label.Length == 0) return false;
        }
        return true;
    }

    /// <summary>No rank letter anywhere on the page.</summary>
    internal static bool NoRankLetters(HeroSheetData sheet)
    {
        foreach (var row in sheet.Rows)
        {
            if (RankLetter.IsMatch(row.Line)) return false;
        }
        return true;
    }

    /// <summary>The strike chips print the bonus the rules engine attacks with.</summary>
    internal static bool StrikeShowsBonus(PF2eCharacter built, HeroSheetData sheet)
    {
        var row = sheet.Row(HeroSheetBuilder.StrikesRow);
        if (row == null) return false;

        var weapon = built.Equipment?.MainHandWeapon
            ?? built.Equipment?.UnarmedAttack
            ?? WeaponAttackCalculator.DefaultUnarmedInstance;
        if (weapon == null) return false;

        int expected = WeaponAttackCalculator.CalculateAttackBonus(built, weapon);
        return row.Line.Contains(HeroSheetBuilder.Signed(expected), StringComparison.Ordinal);
    }

    /// <summary>Every strike's hover repeats the number its chip prints.</summary>
    internal static bool StrikeTipCarriesBonus(HeroSheetData sheet)
    {
        var row = sheet.Row(HeroSheetBuilder.StrikesRow);
        if (row == null || row.Entries.Count == 0) return false;

        foreach (var entry in row.Entries)
        {
            int split = entry.Label.LastIndexOf(' ');
            string bonus = split < 0 ? entry.Label : entry.Label[(split + 1)..];
            if (entry.Tip == null) return false;
            bool carried = (entry.Tip.Footer ?? "").Contains(bonus, StringComparison.Ordinal);
            foreach (var row2 in entry.Tip.Meta ?? System.Array.Empty<SheetMetaRow>())
                carried |= row2.Text.Contains(bonus, StringComparison.Ordinal);
            if (!carried) return false;
        }
        return true;
    }

    internal static bool FeatureExplained(HeroSheetData sheet)
    {
        var row = sheet.Row(HeroSheetBuilder.FeaturesRow);
        if (row == null) return false;

        foreach (var entry in row.Entries)
        {
            if (entry.Tip is { Body.Length: > 20 }) return true;
        }
        return false;
    }

    /// <summary>A chip on that row whose label starts with these words.</summary>
    internal static bool HasChip(HeroSheetData sheet, string rowLabel, string prefix)
        => Chip(sheet, rowLabel, prefix) != null;

    internal static SheetEntry? Chip(HeroSheetData sheet, string rowLabel, string prefix)
    {
        var row = sheet.Row(rowLabel);
        if (row == null) return null;

        foreach (var entry in row.Entries)
        {
            if (entry.Label.StartsWith(prefix, StringComparison.Ordinal)) return entry;
        }
        return null;
    }

    /// <summary>The spell chip whose hover names that spell.</summary>
    /// <summary>The meta-row text for one spell on a group card, or null.</summary>
    internal static string? SpellRowText(SheetTip tip, string spellName)
    {
        foreach (var row in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
        {
            if (row.Label.Contains(spellName, StringComparison.Ordinal)) return row.Text;
        }
        return null;
    }

    internal static SheetTip? SpellTip(HeroSheetData sheet, string spellName)
    {
        var row = sheet.Row(HeroSheetBuilder.SpellsRow);
        if (row == null) return null;

        foreach (var entry in row.Entries)
        {
            if (entry.Tip is not { } tip) continue;
            foreach (var row2 in tip.Meta ?? System.Array.Empty<SheetMetaRow>())
            {
                if (row2.Label.Contains(spellName, StringComparison.Ordinal))
                    return tip;
            }
        }
        return null;
    }

    /// <summary>Elements the sheet prints with nothing to say about them.</summary>
    internal static int Untipped(HeroSheetData sheet)
    {
        int missing = 0;
        foreach (var headline in sheet.Headlines)
        {
            if (headline.Tip == null) missing++;
        }
        foreach (var ability in sheet.Abilities)
        {
            if (ability.Tip == null) missing++;
        }
        foreach (var entry in sheet.Entries())
        {
            if (entry.Tip == null) missing++;
        }
        return missing;
    }

    /// <summary>Tips that would hover with nothing readable in them.</summary>
    internal static int Blank(HeroSheetData sheet)
    {
        int blank = 0;
        foreach (var tip in sheet.Tips())
        {
            bool hasContent = tip.Body.Length > 0
                || tip.Footer is { Length: > 0 }
                || tip.Meta is { Count: > 0 };
            if (tip.Title.Length == 0 || !hasContent) blank++;
        }
        return blank;
    }

    internal static int TipCount(HeroSheetData sheet)
    {
        int count = 0;
        foreach (var _ in sheet.Tips()) count++;
        return count;
    }
}
