using System;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive crafting-bench screen: lists every recipe with its inputs (have/need per input), unlocked
/// state, output, and a Craft button that respects carry-fit. Renders the <see cref="CraftingView"/>
/// pushed via <see cref="Render"/> and raises <see cref="CraftRequested"/> the host forwards to
/// GameState.Craft — no game rules, no engine types, per CLAUDE.md. Recipes carry their own display
/// names in the view-model, so no data lookups happen here.
/// Toggled by the "toggle_crafting_panel" input action (K); Esc closes.
/// </summary>
public partial class CraftingPanel : TogglePanel
{
    /// <summary>Intent: craft <c>count</c> of a recipe (recipeId, count).</summary>
    public event Action<string, int>? CraftRequested;

    private VBoxContainer _body = null!;

    public CraftingPanel() => ToggleAction = "toggle_crafting_panel";

    public override void _Ready()
    {
        _body = GetNode<VBoxContainer>("%Body");
        Visible = false;
    }

    /// <summary>Render a fresh crafting view — rebuilds every recipe row.</summary>
    public void Render(CraftingView view)
    {
        foreach (Node child in _body.GetChildren())
            child.QueueFree();

        if (view.Recipes.Count == 0)
        {
            _body.AddChild(new Label { Text = "No recipes known yet.", ThemeTypeVariation = "HintLabel" });
            return;
        }

        foreach (var r in view.Recipes)
            _body.AddChild(BuildRecipeRow(r));
    }

    private Control BuildRecipeRow(CraftableRecipeView r)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        // Header: recipe name + output + time.
        var header = new HBoxContainer();
        header.AddThemeConstantOverride("separation", 12);
        header.AddChild(new Label { Text = r.DisplayName, ThemeTypeVariation = "TitleLabel" });
        header.AddChild(new Label
        {
            Text = $"→ {r.OutputDisplayName} x{r.OutputQuantity}  ({r.CraftMinutes} min)",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
            HorizontalAlignment = HorizontalAlignment.Right,
        });
        col.AddChild(header);

        // Inputs: one have/need line per input, green when satisfied, red when short.
        foreach (var input in r.Inputs)
        {
            var line = new Label { Text = $"{input.DisplayName}   {input.Have}/{input.Need}" };
            line.AddThemeColorOverride("font_color", input.Enough ? UiPalette.HpGreen : UiPalette.HpRed);
            col.AddChild(line);
        }

        // Gate + fit hints.
        if (!r.Unlocked)
            col.AddChild(new Label
            {
                Text = r.RequiredCategory != null ? $"Locked — requires {r.RequiredCategory}" : "Locked",
                ThemeTypeVariation = "HintLabel",
            });
        else if (!r.Fits)
            col.AddChild(new Label { Text = "Won't fit your carry.", ThemeTypeVariation = "HintLabel" });

        string id = r.RecipeId;
        var craft = new Button
        {
            Text = "Craft",
            ThemeTypeVariation = "AccentButton",
            Disabled = !r.CanCraft,
        };
        craft.Pressed += () => CraftRequested?.Invoke(id, 1);
        col.AddChild(craft);

        return panel;
    }
}
