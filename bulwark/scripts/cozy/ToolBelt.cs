using System;
using System.Collections.Generic;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>The tool slots the player cycles through with Tab. Axe and Pick (M3) gate territory
/// resource nodes; they have no farm action at the outpost.</summary>
public enum ToolKind
{
    Hoe,
    WateringCan,
    Seeds,
    Axe,
    Pick,
    Hand,
}

/// <summary>
/// Selection state for the player's tool belt. Pure C# — holds no game rules and mutates nothing in
/// the world; it only tracks which of the four tools is active and, for the Seeds tool, which held
/// seed is selected. The <see cref="PlayerController"/> node reads this to dispatch GameState
/// commands, and the HUD renders <see cref="CurrentDisplayName"/> / <see cref="SelectedSeed"/>.
/// </summary>
public sealed class ToolBelt
{
    private static readonly ToolKind[] Slots =
    {
        ToolKind.Hoe, ToolKind.WateringCan, ToolKind.Seeds, ToolKind.Axe, ToolKind.Pick, ToolKind.Hand,
    };

    private int _slot;
    private int _seedIndex;
    private readonly List<ItemDefinition> _seeds = new();

    /// <summary>Raised whenever the active tool or selected seed changes (drives the HUD refresh).</summary>
    public event Action? Changed;

    public ToolKind Current => Slots[_slot];

    /// <summary>Human-readable name of the active tool.</summary>
    public string CurrentDisplayName => Current switch
    {
        ToolKind.Hoe => "Hoe",
        ToolKind.WateringCan => "Watering Can",
        ToolKind.Seeds => "Seeds",
        ToolKind.Axe => "Axe",
        ToolKind.Pick => "Pick",
        ToolKind.Hand => "Hand",
        _ => Current.ToString(),
    };

    /// <summary>Seed types currently held, in stable order (empty when the player has no seeds).</summary>
    public IReadOnlyList<ItemDefinition> AvailableSeeds => _seeds;

    /// <summary>The seed the Seeds tool would plant, or null when none are held.</summary>
    public ItemDefinition? SelectedSeed => _seeds.Count == 0 ? null : _seeds[_seedIndex];

    /// <summary>Advance to the next tool slot (Tab).</summary>
    public void CycleTool()
    {
        _slot = (_slot + 1) % Slots.Length;
        Changed?.Invoke();
    }

    /// <summary>Advance to the next held seed type (Q). No-op when fewer than two seed types are held.</summary>
    public void CycleSeed()
    {
        if (_seeds.Count == 0)
            return;
        _seedIndex = (_seedIndex + 1) % _seeds.Count;
        Changed?.Invoke();
    }

    /// <summary>
    /// Recompute the held-seed list from the current inventory, preserving the current selection when
    /// that seed type is still held (so picking up / spending seeds doesn't jump the cursor around).
    /// </summary>
    public void RefreshSeeds(IReadOnlyList<ItemDefinition> heldSeeds)
    {
        string? prevId = SelectedSeed?.Id;
        _seeds.Clear();
        _seeds.AddRange(heldSeeds);

        if (_seeds.Count == 0)
        {
            _seedIndex = 0;
        }
        else
        {
            int keep = prevId == null ? -1 : _seeds.FindIndex(s => s.Id == prevId);
            _seedIndex = keep >= 0 ? keep : 0;
        }
        Changed?.Invoke();
    }
}
