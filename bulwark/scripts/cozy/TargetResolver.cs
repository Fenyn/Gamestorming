using System;
using System.Linq;
using Bulwark.Data;
using Godot;

namespace Bulwark.Cozy;

/// <summary>
/// Pure decision logic for "which cell does the active tool act on, and can it act there?". No Godot
/// nodes, no scene tree — the <see cref="PlayerController"/> supplies the world queries as delegates
/// so this stays deterministically testable. The predicates here mirror the FarmSystem command
/// validation, so a highlighted (actionable) cell always corresponds to a command that will succeed.
///
/// Targeting rule: prefer the hovered (mouse) cell when it is within one tile of the player and
/// actionable (Stardew-style cursor aim); otherwise the cell one tile in front of the player's
/// facing; if the tool can't act there, fall back to the player's own cell (lets you
/// till/water/harvest the tile you're standing on). If none is actionable the faced cell is
/// returned with <c>CanAct == false</c> so callers can suppress the highlight.
/// </summary>
public static class TargetResolver
{
    public readonly record struct Target(Vector2I Cell, bool CanAct);

    public static Target Resolve(
        ToolKind tool,
        Vector2I playerCell,
        Vector2I facingDir,
        ItemDefinition? selectedSeed,
        Season season,
        Func<Vector2I, bool> isFarmable,
        Func<Vector2I, Plot?> getPlot,
        Func<string, int> itemCount,
        Vector2I? hoveredCell = null)
    {
        if (hoveredCell is Vector2I hovered &&
            Math.Abs(hovered.X - playerCell.X) <= 1 && Math.Abs(hovered.Y - playerCell.Y) <= 1 &&
            CanActOn(tool, hovered, selectedSeed, season, isFarmable, getPlot, itemCount))
            return new Target(hovered, true);

        Vector2I faced = playerCell + facingDir;

        if (CanActOn(tool, faced, selectedSeed, season, isFarmable, getPlot, itemCount))
            return new Target(faced, true);

        if (facingDir != Vector2I.Zero &&
            CanActOn(tool, playerCell, selectedSeed, season, isFarmable, getPlot, itemCount))
            return new Target(playerCell, true);

        return new Target(faced, false);
    }

    /// <summary>True when the tool would produce a successful command on <paramref name="cell"/>.</summary>
    public static bool CanActOn(
        ToolKind tool,
        Vector2I cell,
        ItemDefinition? selectedSeed,
        Season season,
        Func<Vector2I, bool> isFarmable,
        Func<Vector2I, Plot?> getPlot,
        Func<string, int> itemCount)
    {
        Plot? plot = getPlot(cell);

        switch (tool)
        {
            case ToolKind.Hoe:
                // Till bare farmable ground.
                return isFarmable(cell) && (plot == null || plot.Stage == PlotStage.Untilled);

            case ToolKind.WateringCan:
                // Water a planted/maturing crop not yet watered today.
                return plot != null && plot.CropId != null && !plot.WateredToday;

            case ToolKind.Seeds:
                // Plant the selected seed on tilled soil, in season, with a seed in hand.
                if (plot == null || plot.Stage != PlotStage.Tilled)
                    return false;
                if (selectedSeed?.CropId == null || itemCount(selectedSeed.Id) <= 0)
                    return false;
                return Crops.TryGet(selectedSeed.CropId, out var crop) && crop.Seasons.Contains(season);

            case ToolKind.Hand:
                // Harvest a mature crop. (Bedroll interaction is handled by the controller separately.)
                return plot != null && plot.Stage == PlotStage.Mature;

            default:
                return false;
        }
    }
}
