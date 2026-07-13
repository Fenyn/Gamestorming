using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>One input line of a craftable-recipe view: item, how many the craft needs, how many the
/// party holds. Engine-agnostic view-model (UI never touches the data registries directly).</summary>
public sealed class RecipeInputView
{
    public string ItemId { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public int Need { get; init; }
    public int Have { get; init; }
    public bool Enough => Have >= Need;
}

/// <summary>
/// View-model for one recipe on the crafting bench: its inputs (have/need), output, cost, gate state,
/// and whether a single craft is possible right now. The future crafting UI renders this; nothing
/// here references the engine or the data registries.
/// </summary>
public sealed class CraftableRecipeView
{
    public string RecipeId { get; init; } = "";
    public string DisplayName { get; init; } = "";
    public List<RecipeInputView> Inputs { get; init; } = new();
    public string OutputItemId { get; init; } = "";
    public string OutputDisplayName { get; init; } = "";
    public int OutputQuantity { get; init; }
    public int CraftMinutes { get; init; }

    /// <summary>Null for a baseline recipe; otherwise the CategoryUnlock id gating it.</summary>
    public string? RequiredCategory { get; init; }

    /// <summary>True when no station is required or the required category is unlocked.</summary>
    public bool Unlocked { get; init; }

    /// <summary>True when every input is present in sufficient quantity.</summary>
    public bool HasInputs { get; init; }

    /// <summary>True when the output would fit within the party's carry cap.</summary>
    public bool Fits { get; init; }

    /// <summary>True when a single craft can be performed right now (unlocked + inputs + fits).</summary>
    public bool CanCraft => Unlocked && HasInputs && Fits;
}

/// <summary>The crafting-bench view-model: every defined recipe with its current craftability.</summary>
public sealed class CraftingView
{
    public List<CraftableRecipeView> Recipes { get; init; } = new();
}
