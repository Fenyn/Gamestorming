using System;
using System.Collections.Generic;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Pure evaluator for a building's active visual stage + overlay key set (design/building_visuals.md).
/// No Node/scene state — <see cref="BuildingLoader"/> feeds it a definition plus the current derived
/// inputs (tier, under-construction flag, calendar, story-flag query) and applies the result via
/// <see cref="BuildingInstance.Apply"/>. Everything here is deterministic and re-derivable from
/// save-restored state (tiers, flags, clock), so nothing about the result is itself persisted.
/// </summary>
public static class BuildingVisualState
{
    /// <summary>
    /// Resolve the active stage index + overlay key set for a building.
    ///
    /// STAGE — the design's 3-level priority is: (1) last matching stage-override rule, (2) under
    /// construction → scaffold, (3) tier mapping. Level 2 is intentionally NOT decided here:
    /// <paramref name="isUnderConstruction"/> is accepted for signature symmetry with the loader's
    /// other inputs but does not affect <c>StageIndex</c> — <see cref="BuildingInstance.Apply"/>
    /// independently swaps to the <c>%Scaffold</c> node when under construction, regardless of the
    /// stage this method resolves. So this method implements levels 1 and 3 only:
    ///  1. LAST matching stage-override rule on <paramref name="def"/> wins (list order).
    ///  3. <see cref="BuildingDefinition.StageIndexForTier"/> — the shipped tier→stage mapping.
    ///
    /// OVERLAYS are additive and independent of the stage decision:
    ///  - The current season's name is ALWAYS an active key (the auto-key) — buildings without a
    ///    matching <c>%Overlays</c> child simply ignore it.
    ///  - A Window rule (Season + FromDay/ToDay, inclusive) is active while the season matches and
    ///    <paramref name="dayOfSeason"/> falls in range.
    ///  - A season-only rule (Season set, no window) is active for the whole matching season — lets
    ///    a rule apply a season key to a DIFFERENT overlay child name than the auto-key.
    ///  - A Flag rule is active once <paramref name="hasFlag"/>(FlagId) is true, unless
    ///    UnlessFlagId is ALSO true (the retire clause).
    ///
    /// A rule that sets both <see cref="BuildingVisualRule.OverlayKey"/> and
    /// <see cref="BuildingVisualRule.StageOverride"/> (or neither) is invalid — skipped, with a
    /// pushed warning, never thrown.
    /// </summary>
    public static (int StageIndex, IReadOnlyCollection<string> OverlayKeys) Evaluate(
        BuildingDefinition def,
        int tier,
        bool isUnderConstruction,
        Season season,
        int dayOfSeason,
        Func<string, bool> hasFlag)
    {
        ArgumentNullException.ThrowIfNull(def);
        hasFlag ??= static _ => false;

        int stageIndex = def.StageIndexForTier(tier);
        var overlayKeys = new HashSet<string>(StringComparer.Ordinal) { season.ToString() };

        foreach (var rule in def.VisualRules)
        {
            bool hasOverlayKey = !string.IsNullOrEmpty(rule.OverlayKey);
            bool hasStageOverride = rule.StageOverride.HasValue;
            if (hasOverlayKey == hasStageOverride)
            {
                GD.PushWarning(
                    $"[BuildingVisualState] {def.Id}: visual rule must set exactly one of OverlayKey/StageOverride — ignored.");
                continue;
            }

            if (!Matches(rule, season, dayOfSeason, hasFlag))
                continue;

            if (hasStageOverride)
                stageIndex = rule.StageOverride!.Value; // list order — LAST match wins (keeps overwriting)
            else
                overlayKeys.Add(rule.OverlayKey!);
        }

        return (stageIndex, overlayKeys);
    }

    private static bool Matches(BuildingVisualRule rule, Season season, int dayOfSeason, Func<string, bool> hasFlag)
    {
        if (rule.FlagId != null)
            return hasFlag(rule.FlagId) && (rule.UnlessFlagId == null || !hasFlag(rule.UnlessFlagId));

        if (rule.Season.HasValue)
        {
            if (rule.Season.Value != season)
                return false;
            return !rule.FromDay.HasValue || !rule.ToDay.HasValue
                || (dayOfSeason >= rule.FromDay.Value && dayOfSeason <= rule.ToDay.Value);
        }

        return false; // no driver set — never matches
    }
}
