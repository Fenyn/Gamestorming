using System;
using Godot;
using Bulwark.Cozy;

namespace Bulwark.UI;

/// <summary>
/// Passive planning-table / build-menu panel. Renders only the <see cref="PlanningTableView"/> pushed
/// via <see cref="Render"/> and raises intents (<see cref="CommissionRequested"/>,
/// <see cref="ContributeRequested"/>, <see cref="UpgradeRequested"/>) that the host forwards to
/// GameState commands — no game rules, no engine types, per CLAUDE.md. Building rows are built
/// programmatically from the data-driven roster into <c>%BuildingList</c>.
///
/// The host reacts to <see cref="Toggled"/> to freeze the player + day clock while open (the
/// squad-panel precedent). Toggled by the "toggle_build_panel" input action (B); Esc closes.
/// </summary>
public partial class BuildPanel : CanvasLayer
{
    /// <summary>Intent: commission a building (pay its construction bundle).</summary>
    public event Action<string>? CommissionRequested;

    /// <summary>Intent: contribute (buildingId, itemId, qty) toward the next-tier upgrade bundle.</summary>
    public event Action<string, string, int>? ContributeRequested;

    /// <summary>Intent: advance a building to its next tier.</summary>
    public event Action<string>? UpgradeRequested;

    /// <summary>Raised when the panel opens (true) or closes (false).</summary>
    public event Action<bool>? Toggled;

    private VBoxContainer _list = null!;

    public override void _Ready()
    {
        _list = GetNode<VBoxContainer>("%BuildingList");
        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("toggle_build_panel"))
        {
            SetOpen(!Visible);
            GetViewport().SetInputAsHandled();
        }
        else if (Visible && @event.IsActionPressed("ui_cancel"))
        {
            SetOpen(false);
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Host command: close the panel if open (fires Toggled(false) so the host unfreezes).</summary>
    public void Close() => SetOpen(false);

    /// <summary>Render a fresh planning-table view — rebuilds every building row from the view-model.</summary>
    public void Render(PlanningTableView view)
    {
        foreach (Node child in _list.GetChildren())
            child.QueueFree();

        foreach (var b in view.Buildings)
            _list.AddChild(BuildRow(b));
    }

    // ------------------------------------------------------------------ Row construction (view only)

    private Control BuildRow(BuildingView b)
    {
        var panel = new PanelContainer { ThemeTypeVariation = "InnerPanel" };
        var col = new VBoxContainer();
        col.AddThemeConstantOverride("separation", 6);
        panel.AddChild(col);

        // Header: name + status.
        var header = new HBoxContainer();
        header.AddThemeConstantOverride("separation", 12);
        header.AddChild(new Label { Text = b.DisplayName, ThemeTypeVariation = "TitleLabel" });
        header.AddChild(new Label { Text = b.StatusText, SizeFlagsHorizontal = Control.SizeFlags.ExpandFill });
        col.AddChild(header);

        // Active effects (declarative preview of what the building does).
        if (b.ActiveEffects.Count > 0)
            col.AddChild(new Label { Text = "Active: " + Join(b.ActiveEffects), ThemeTypeVariation = "HintLabel" });

        if (b.AtMaxTier)
        {
            col.AddChild(new Label { Text = "Fully upgraded.", ThemeTypeVariation = "HintLabel" });
            return panel;
        }

        if (!b.HasTarget)
            return panel;

        col.AddChild(new Label { Text = b.TargetLabel, ThemeTypeVariation = "HintLabel" });

        // Bundle lines: "Wood  3/8  (inv 2)" plus a per-item Contribute button for upgrades.
        foreach (var line in b.Bundle)
            col.AddChild(BuildBundleLine(b, line));

        // Next-tier effect preview.
        if (b.NextEffects.Count > 0)
            col.AddChild(new Label { Text = "Unlocks: " + Join(b.NextEffects), ThemeTypeVariation = "HintLabel" });

        // Action button: Commission (not built) or Upgrade (built).
        string id = b.Id;
        if (!b.Commissioned)
        {
            var commission = new Button
            {
                Text = "Commission",
                ThemeTypeVariation = "AccentButton",
                Disabled = !b.CanCommission,
            };
            commission.Pressed += () => CommissionRequested?.Invoke(id);
            col.AddChild(commission);
        }
        else
        {
            var upgrade = new Button
            {
                Text = $"Upgrade to Tier {b.Tier + 1}",
                ThemeTypeVariation = "AccentButton",
                Disabled = !b.CanUpgrade,
            };
            upgrade.Pressed += () => UpgradeRequested?.Invoke(id);
            col.AddChild(upgrade);
        }

        return panel;
    }

    private Control BuildBundleLine(BuildingView b, BundleLineView line)
    {
        var row = new HBoxContainer();
        row.AddThemeConstantOverride("separation", 10);

        row.AddChild(new Label
        {
            Text = line.DisplayName,
            CustomMinimumSize = new Vector2(140, 0),
        });

        // For upgrades show accumulated/need; for construction (Contributed always 0) show need + held.
        string progress = b.Commissioned
            ? $"{line.Contributed}/{line.Need}"
            : $"need {line.Need}";
        var progressLabel = new Label
        {
            Text = progress,
            CustomMinimumSize = new Vector2(90, 0),
        };
        if (line.Complete)
            progressLabel.AddThemeColorOverride("font_color", new Color(0.55f, 0.85f, 0.45f));
        row.AddChild(progressLabel);

        row.AddChild(new Label
        {
            Text = $"(inv {line.InventoryCount})",
            ThemeTypeVariation = "HintLabel",
            SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
        });

        // Contribute button only for upgrade bundles (construction is paid all-at-once via Commission).
        if (b.Commissioned && !line.Complete)
        {
            string id = b.Id;
            string itemId = line.ItemId;
            int qty = line.ContributableNow;
            var contribute = new Button
            {
                Text = qty > 0 ? $"Contribute {qty}" : "Contribute",
                ThemeTypeVariation = "ActionChip",
                Disabled = qty <= 0,
            };
            contribute.Pressed += () => ContributeRequested?.Invoke(id, itemId, qty);
            row.AddChild(contribute);
        }

        return row;
    }

    private static string Join(System.Collections.Generic.List<EffectLineView> effects)
    {
        var parts = new System.Collections.Generic.List<string>(effects.Count);
        foreach (var e in effects)
            parts.Add(e.Text);
        return string.Join(", ", parts);
    }

    private void SetOpen(bool open)
    {
        if (Visible == open)
            return;
        Visible = open;
        Toggled?.Invoke(open);
    }
}
