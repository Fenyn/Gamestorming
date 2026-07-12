using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive Stardew-style end-of-day summary modal: renders a <see cref="DaySummaryView"/> pushed
/// via <see cref="Open"/> (title date, Harvest &amp; Gains, Battles, XP, Level-ups, and the
/// all-nighter fatigue line — zero-content sections are hidden) and raises <see cref="Closed"/>
/// when dismissed via the Onward button, interact (E) or Esc. No game rules, no engine types, per
/// CLAUDE.md; item display names resolve through the <see cref="Items"/> data class like the rest
/// of the UI. The host scene freezes the player/clock while the panel is open (the squad-panel
/// pattern); while visible, other key input is swallowed so overlapping modals cannot fight.
/// </summary>
public partial class DaySummaryPanel : CanvasLayer
{
    /// <summary>Raised when the panel is dismissed (host unfreezes the world).</summary>
    public event Action? Closed;

    private Label _titleLabel = null!;
    private Label _fatigueLabel = null!;
    private Control _harvestSection = null!;
    private Label _harvestLabel = null!;
    private Control _battlesSection = null!;
    private Label _battlesLabel = null!;
    private Control _xpSection = null!;
    private Label _xpLabel = null!;
    private Control _levelUpsSection = null!;
    private Label _levelUpsLabel = null!;

    public override void _Ready()
    {
        _titleLabel = GetNode<Label>("%TitleLabel");
        _fatigueLabel = GetNode<Label>("%FatigueLabel");
        _harvestSection = GetNode<Control>("%HarvestSection");
        _harvestLabel = GetNode<Label>("%HarvestLabel");
        _battlesSection = GetNode<Control>("%BattlesSection");
        _battlesLabel = GetNode<Label>("%BattlesLabel");
        _xpSection = GetNode<Control>("%XpSection");
        _xpLabel = GetNode<Label>("%XpLabel");
        _levelUpsSection = GetNode<Control>("%LevelUpsSection");
        _levelUpsLabel = GetNode<Label>("%LevelUpsLabel");

        GetNode<Button>("%OnwardButton").Pressed += Close;
        Visible = false;
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (!Visible)
            return;

        if (@event.IsActionPressed("ui_cancel") || @event.IsActionPressed("interact"))
        {
            Close();
            GetViewport().SetInputAsHandled();
        }
        else if (@event is InputEventKey { Pressed: true })
        {
            // Modal: swallow remaining key input (e.g. the squad-panel toggle) while open, so no
            // second panel can open underneath and unfreeze the world on its own close.
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Render the day's summary and show the modal.</summary>
    public void Open(DaySummaryView view)
    {
        Render(view);
        Visible = true;
    }

    /// <summary>Dismiss the modal (Onward button, E, Esc). Raises <see cref="Closed"/> once.</summary>
    public void Close()
    {
        if (!Visible)
            return;
        Visible = false;
        Closed?.Invoke();
    }

    // ------------------------------------------------------------------ Rendering (pure presentation)

    private void Render(DaySummaryView view)
    {
        _titleLabel.Text = $"Day complete — {view.Date}";

        bool fatigued = !string.IsNullOrEmpty(view.FatigueNotice);
        _fatigueLabel.Visible = fatigued;
        _fatigueLabel.Text = fatigued ? view.FatigueNotice! : "";

        RenderHarvest(view);
        RenderBattles(view);

        _xpSection.Visible = view.XpAwarded > 0;
        _xpLabel.Text = view.XpAwarded > 0 ? $"+{view.XpAwarded} XP for every squad member" : "";

        _levelUpsSection.Visible = view.LevelUps.Count > 0;
        if (view.LevelUps.Count > 0)
        {
            var lines = new List<string>(view.LevelUps.Count);
            foreach (var lu in view.LevelUps)
                lines.Add($"{lu.MemberName} — Level {lu.ToLevel}!");
            _levelUpsLabel.Text = string.Join("\n", lines);
        }
    }

    private void RenderHarvest(DaySummaryView view)
    {
        bool any = view.ItemsGained.Count > 0 || view.CropsHarvested > 0;
        _harvestSection.Visible = any;
        if (!any)
            return;

        // One line per item, sorted by display name (resolved via the Items data registry).
        var lines = new List<string>();
        foreach (var (id, count) in view.ItemsGained)
        {
            if (count <= 0)
                continue;
            string name = Items.TryGet(id, out ItemDefinition def) ? def.DisplayName : id;
            lines.Add($"{name} × {count}");
        }
        lines.Sort(StringComparer.Ordinal);

        if (view.CropsHarvested > 0)
            lines.Add($"Crops harvested: {view.CropsHarvested}");

        _harvestLabel.Text = string.Join("\n", lines);
    }

    private void RenderBattles(DaySummaryView view)
    {
        bool any = view.EncountersWon > 0 || view.EncountersLost > 0 || view.TreatWoundsUses > 0;
        _battlesSection.Visible = any;
        if (!any)
            return;

        var lines = new List<string>();
        if (view.EncountersWon > 0 || view.EncountersLost > 0)
            lines.Add($"Won {view.EncountersWon} — Lost {view.EncountersLost}");
        if (view.TreatWoundsUses > 0)
            lines.Add($"Wounds treated: {view.TreatWoundsUses}");
        _battlesLabel.Text = string.Join("\n", lines);
    }
}
