using System;
using System.Collections.Generic;
using Godot;

namespace Delve.UI;

/// <summary>
/// One entry a <see cref="ChipFlyout"/> draws as a chip. Pure data: the flyout knows nothing about
/// what an entry means, only how to draw it and what to hand back when it is pressed.
/// <see cref="Id"/> plus <see cref="Variant"/> are the caller's payload, echoed on
/// <see cref="ChipFlyout.ChipPressed"/>.
/// </summary>
public sealed record ChipSpec
{
    public required string Id { get; init; }
    /// <summary>Second payload field for callers whose entries come in variants (-1 = none).</summary>
    public int Variant { get; init; } = -1;
    public required string Name { get; init; }
    /// <summary>Actions the entry costs, drawn as that many cost pips. 0 or less falls back to
    /// <see cref="CostText"/> drawn as dim text.</summary>
    public int ActionCost { get; init; }
    /// <summary>Cost in words, already formatted by the caller. Used in the tooltip always, and on
    /// the chip itself when <see cref="ActionCost"/> resolved to no pip count.</summary>
    public string CostText { get; init; } = "";
    /// <summary>Short badge drawn after the cost (empty/null = no badge).</summary>
    public string? BadgeText { get; init; }
    /// <summary>False greys the chip out and blocks the press.</summary>
    public bool Enabled { get; init; }
    /// <summary>Optional third tooltip part after name and cost.</summary>
    public string Detail { get; init; } = "";
    /// <summary>Optional one-line description, its own tooltip line.</summary>
    public string Description { get; init; } = "";
    /// <summary>Why a disabled chip is greyed out; appends as an "Unavailable: reason" line.</summary>
    public string UnavailableReason { get; init; } = "";
}

/// <summary>
/// Reusable chip panel: a column of optional section headers over centered chip flows. Hosts any
/// list of <see cref="ChipSpec"/> — it holds no combat, spell or skill knowledge, and it neither
/// shows nor hides itself. The owner clears it, adds sections and flows, fills them with chips,
/// and listens on <see cref="ChipPressed"/> for the pressed spec.
/// </summary>
public partial class ChipFlyout : PanelContainer
{
    /// <summary>Raised with the spec of the pressed chip. The owner decides what that means and
    /// whether the panel closes.</summary>
    public event Action<ChipSpec>? ChipPressed;

    /// <summary>Chip scene instanced per entry. Assigned in the scene that hosts the flyout.</summary>
    [Export] public PackedScene? ChipScene { get; set; }

    private VBoxContainer _column = null!;

    public override void _Ready() => _column = GetNode<VBoxContainer>("%Column");

    /// <summary>Drop every section and chip. The owner rebuilds from scratch on each state change.</summary>
    public void Clear()
    {
        foreach (var child in _column.GetChildren())
            child.QueueFree();
    }

    /// <summary>Add a centered HintLabel header. The owner omits it for an unlabelled flow.</summary>
    public void AddSection(string header)
        => _column.AddChild(new Label
        {
            Text = header,
            ThemeTypeVariation = ThemeNames.HintLabel,
            HorizontalAlignment = HorizontalAlignment.Center,
        });

    /// <summary>Add a centered wrapping row and return it, to be filled with
    /// <see cref="AddChip"/>.</summary>
    public Container AddFlow()
    {
        var flow = new HFlowContainer { Alignment = FlowContainer.AlignmentMode.Center };
        flow.AddThemeConstantOverride("h_separation", 5);
        flow.AddThemeConstantOverride("v_separation", 5);
        _column.AddChild(flow);
        return flow;
    }

    /// <summary>Instance one chip into a flow returned by <see cref="AddFlow"/>.</summary>
    public void AddChip(Container parent, ChipSpec spec)
    {
        if (ChipScene == null)
        {
            GD.PushError("[ChipFlyout] ChipScene is not assigned.");
            return;
        }

        var chip = ChipScene.Instantiate<Button>();
        chip.Disabled = !spec.Enabled;
        chip.TooltipText = BuildChipTooltip(spec);

        // Internal labels don't track the button's disabled font color (same as the bar captions)
        // — chips are rebuilt on every state change, so a one-shot override at build time is enough.
        var nameLabel = chip.GetNode<Label>("%NameLabel");
        nameLabel.Text = spec.Name;
        nameLabel.AddThemeColorOverride("font_color",
            spec.Enabled ? UiColors.Text : UiColors.TextDisabled);

        // Cost pips: one square per action. A cost the caller could not resolve to an action count
        // falls back to the raw text, dim.
        var pipRow = chip.GetNode<PipRow>("%PipRow");
        if (spec.ActionCost > 0)
        {
            pipRow.SetCost(spec.ActionCost, spec.Enabled);
        }
        else if (!string.IsNullOrEmpty(spec.CostText))
        {
            var costLabel = new Label
            {
                Text = spec.CostText,
                ThemeTypeVariation = ThemeNames.HintLabel,
                MouseFilter = MouseFilterEnum.Ignore,
            };
            if (!spec.Enabled)
                costLabel.AddThemeColorOverride("font_color", UiColors.TextDisabled);
            pipRow.AddChild(costLabel);
        }

        var badgeLabel = chip.GetNode<Label>("%SlotLabel");
        badgeLabel.Visible = !string.IsNullOrEmpty(spec.BadgeText);
        badgeLabel.Text = spec.BadgeText ?? "";
        if (!spec.Enabled)
            badgeLabel.AddThemeColorOverride("font_color", UiColors.TextDisabled);

        chip.Pressed += () => ChipPressed?.Invoke(spec);
        parent.AddChild(chip);
    }

    /// <summary>Name, cost in words, and the caller's detail part on one line; the description on
    /// its own line when there is one. A disabled chip's <see cref="ChipSpec.UnavailableReason"/>
    /// (empty otherwise) appends as a final "Unavailable: reason" line so the grey-out always
    /// explains itself.</summary>
    private static string BuildChipTooltip(ChipSpec spec)
    {
        var parts = new List<string> { spec.Name, spec.CostText };
        if (!string.IsNullOrEmpty(spec.Detail))
            parts.Add(spec.Detail);

        string tooltip = string.Join(" · ", parts);
        if (!string.IsNullOrEmpty(spec.Description))
            tooltip += $"\n{spec.Description}";
        if (!string.IsNullOrEmpty(spec.UnavailableReason))
            tooltip += $"\nUnavailable: {spec.UnavailableReason}";
        return tooltip;
    }
}
