using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Data;

namespace Bulwark.Cozy;

/// <summary>
/// The Phase-5 crafting loop: raw resources → refined artisan goods → meals, driven entirely by the
/// declarative <see cref="Recipes"/> registry. Plain C# and unit-testable — it validates every craft
/// against the party <see cref="Inventory"/> and the station-unlock gate (a delegate into
/// GameState.IsCategoryUnlocked / OutpostEffects) before touching state.
///
/// A craft: validate the recipe exists, the count is positive, the required station category is
/// unlocked (null = baseline, always craftable), the inputs are all present, AND the output fits the
/// party's Bulk carry cap. Then it consumes the inputs, adds the output, and charges the craft time
/// through <see cref="DayClock.SpendTime"/> (the exploration-activity seam). Every rejection is clean:
/// NOTHING is consumed unless the whole craft succeeds. Emits <see cref="Crafted"/> with the recipe id.
/// </summary>
public sealed class CraftingSystem
{
    private readonly Inventory _inventory;
    private readonly DayClock _clock;
    private readonly Func<string, bool> _isCategoryUnlocked;

    /// <summary>Raised after a successful craft, with the recipe id (GameState re-exposes it).</summary>
    public event Action<string>? Crafted;

    /// <summary>
    /// <paramref name="isCategoryUnlocked"/> answers the station gate (GameState.IsCategoryUnlocked in
    /// production; a synthetic set in the spike) — baseline recipes never call it.
    /// </summary>
    public CraftingSystem(Inventory inventory, DayClock clock, Func<string, bool> isCategoryUnlocked)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
        _isCategoryUnlocked = isCategoryUnlocked ?? throw new ArgumentNullException(nameof(isCategoryUnlocked));
    }

    // ===================== Queries =====================

    /// <summary>True when this recipe's station gate is satisfied (baseline = always).</summary>
    public bool IsUnlocked(RecipeDefinition recipe)
        => recipe.RequiredCategory == null || _isCategoryUnlocked(recipe.RequiredCategory);

    /// <summary>
    /// Whether <paramref name="count"/> crafts of a recipe can run right now: recipe defined, count
    /// positive, station unlocked, inputs present for the full count, and the produced output fits the
    /// carry cap. Wildcard inputs resolve to the first held item in the matching category. Pure.
    /// </summary>
    public bool CanCraft(string recipeId, int count = 1)
    {
        if (count <= 0 || !Recipes.TryGet(recipeId, out var recipe))
            return false;
        if (!IsUnlocked(recipe))
            return false;
        foreach (var input in recipe.Inputs)
        {
            string? resolved = ResolveInput(input);
            if (resolved == null || !_inventory.Has(resolved, input.Quantity * count))
                return false;
        }
        return _inventory.WouldFit(recipe.OutputItemId, recipe.OutputQuantity * count);
    }

    // ===================== Command =====================

    /// <summary>
    /// Craft <paramref name="count"/> batches of a recipe. Validates via <see cref="CanCraft"/> — a
    /// rejected craft (unknown recipe, non-positive count, locked station, missing inputs, or output
    /// overflow) consumes NOTHING and returns false. On success: consume the inputs (wildcard inputs
    /// resolve to the first held item in their category), add the output, spend the craft-minutes on
    /// the clock, and emit <see cref="Crafted"/>. Returns true.
    /// </summary>
    public bool Craft(string recipeId, int count = 1)
    {
        if (!CanCraft(recipeId, count))
            return false;

        var recipe = Recipes.Get(recipeId);

        foreach (var input in recipe.Inputs)
        {
            string resolved = ResolveInput(input)!;
            _inventory.RemoveItem(resolved, input.Quantity * count);
        }

        _inventory.AddItem(recipe.OutputItemId, recipe.OutputQuantity * count);

        _clock.SpendTime(recipe.CraftMinutes * count);

        Crafted?.Invoke(recipeId);
        return true;
    }

    /// <summary>
    /// For a specific input, returns the item id directly. For a wildcard input, scans the inventory
    /// for the first held item whose category matches, returning null if none is found.
    /// </summary>
    private string? ResolveInput(RecipeInput input)
    {
        if (!input.IsWildcard)
            return input.ItemId;

        var category = input.CategoryWildcard!.Value;
        foreach (var (itemId, qty) in _inventory.Stacks)
        {
            if (qty > 0 && Items.TryGet(itemId, out var def) && def.Category == category)
                return itemId;
        }
        return null;
    }

    // ===================== View-model =====================

    /// <summary>Build the crafting-bench view-model: every recipe with its current craftability
    /// (unlocked / have-vs-need inputs / fits carry).</summary>
    public CraftingView BuildView()
    {
        var view = new CraftingView();
        foreach (var recipe in Recipes.All)
        {
            bool unlocked = IsUnlocked(recipe);
            bool hasInputs = true;
            var inputs = new List<RecipeInputView>(recipe.Inputs.Count);
            foreach (var input in recipe.Inputs)
            {
                string? resolved = ResolveInput(input);
                string displayId = resolved ?? (input.IsWildcard ? $"Any {input.CategoryWildcard}" : input.ItemId!);
                int have = resolved != null ? _inventory.Count(resolved) : 0;
                if (have < input.Quantity)
                    hasInputs = false;
                inputs.Add(new RecipeInputView
                {
                    ItemId = displayId,
                    DisplayName = input.IsWildcard ? $"Any {input.CategoryWildcard}" : NameOf(input.ItemId!),
                    Need = input.Quantity,
                    Have = have,
                });
            }

            view.Recipes.Add(new CraftableRecipeView
            {
                RecipeId = recipe.Id,
                DisplayName = recipe.DisplayName,
                Inputs = inputs,
                OutputItemId = recipe.OutputItemId,
                OutputDisplayName = NameOf(recipe.OutputItemId),
                OutputQuantity = recipe.OutputQuantity,
                CraftMinutes = recipe.CraftMinutes,
                RequiredCategory = recipe.RequiredCategory,
                Unlocked = unlocked,
                HasInputs = hasInputs,
                Fits = _inventory.WouldFit(recipe.OutputItemId, recipe.OutputQuantity),
            });
        }
        return view;
    }

    private static string NameOf(string itemId)
        => Items.TryGet(itemId, out var def) ? def.DisplayName : itemId;
}
