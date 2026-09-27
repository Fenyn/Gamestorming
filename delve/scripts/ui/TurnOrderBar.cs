using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Initiative strip, starting at the current actor: one chip per combatant with its name, a thin
/// team-coloured HP bar, the enemy's letter badge, and a "Round N" divider where the order wraps.
/// The current chip is taller and filled. Dead combatants dim; a delayed combatant shows faded at
/// the slot it returns to. Passive: the one thing it takes back is a click on a chip offered as a
/// Delay slot (<see cref="UnitView.IsPickable"/>), raised as <see cref="ChipPressed"/>.
/// </summary>
public partial class TurnOrderBar : Control
{
    public event Action<int>? ChipPressed;

    [Export] public PackedScene? ChipScene { get; set; }

    /// <summary>Widest the strip may grow. Names shorten with an ellipsis past it.</summary>
    [Export] public float MaxWidth { get; set; } = 1200;
    [Export] public float ActiveChipHeight { get; set; } = 56;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DeadAlpha { get; set; } = 0.45f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DelayedAlpha { get; set; } = 0.7f;

    private const string DelayedPrefix = "~ ";

    private HBoxContainer _row = null!;

    public Control Row => _row;

    public override void _Ready()
    {
        _row = GetNode<HBoxContainer>("%Row");
        _row.Alignment = BoxContainer.AlignmentMode.Center;
    }

    /// <param name="wrapIndex">Index in <paramref name="units"/> where the next round starts; -1 for none.</param>
    public void Render(IReadOnlyList<UnitView> units, int wrapIndex = -1, int nextRound = 0)
    {
        foreach (var child in _row.GetChildren())
        {
            _row.RemoveChild(child);
            child.QueueFree();
        }

        if (ChipScene == null)
        {
            GD.PushError("[TurnOrderBar] ChipScene is not assigned.");
            return;
        }

        var labels = new List<(Label Label, float Natural)>();
        for (int i = 0; i < units.Count; i++)
        {
            if (i == wrapIndex) AddDivider(nextRound);
            labels.Add(AddChip(units[i]));
        }
        FitToWidth(labels);
        _row.OffsetLeft = 0;
        _row.OffsetRight = 0;
    }

    private (Label, float) AddChip(UnitView unit)
    {
        var chip = ChipScene!.Instantiate<PanelContainer>();
        chip.ThemeTypeVariation = unit.IsCurrent ? ThemeNames.TurnChipActive
            : unit.IsPickable ? ThemeNames.TurnChipPick
            : unit.IsDelayed ? ThemeNames.TurnChipDelayed
            : unit.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;
        if (unit.IsCurrent) chip.CustomMinimumSize = new Vector2(chip.CustomMinimumSize.X, ActiveChipHeight);

        bool lettered = unit.Letter.Length > 0;
        chip.GetNode<Control>("%Badge").Visible = lettered;
        chip.GetNode<Label>("%BadgeLabel").Text = unit.Letter;

        string name = lettered && unit.BaseName.Length > 0 ? unit.BaseName : unit.Name;
        var label = chip.GetNode<Label>("%Label");
        label.Text = unit.IsDelayed ? $"{DelayedPrefix}{name}" : name;
        label.ThemeTypeVariation = unit.IsCurrent ? ThemeNames.ChipLabelActive
            : unit.IsPickable ? ThemeNames.ChipLabelPick : ThemeNames.ChipLabel;

        var hpBar = chip.GetNode<ProgressBar>("%HpBar");
        hpBar.ThemeTypeVariation = unit.IsAlly ? ThemeNames.HpBarAlly : ThemeNames.HpBarEnemy;
        int maxHp = Math.Max(1, unit.MaxHp);
        hpBar.MaxValue = maxHp;
        hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);

        if (unit.IsDead || unit.IsDelayed) chip.Modulate = Faded(unit.IsDead ? DeadAlpha : DelayedAlpha);
        chip.TooltipText = unit.Name;

        if (unit.IsPickable)
        {
            chip.MouseFilter = MouseFilterEnum.Stop;
            chip.MouseDefaultCursorShape = CursorShape.PointingHand;
            chip.TooltipText = $"Delay until after {unit.Name}";
            int id = unit.Id;
            chip.GuiInput += @event =>
            {
                if (@event is not InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }) return;
                chip.AcceptEvent();
                ChipPressed?.Invoke(id);
            };
        }

        _row.AddChild(chip);
        float natural = label.GetThemeFont("font").GetStringSize(label.Text, HorizontalAlignment.Left, -1,
            label.GetThemeFontSize("font_size")).X;
        label.CustomMinimumSize = new Vector2(Mathf.Ceil(natural), 0);
        return (label, natural);
    }

    private void AddDivider(int round)
    {
        var divider = ChipScene!.Instantiate<PanelContainer>();
        divider.ThemeTypeVariation = ThemeNames.ClearPanel;
        divider.GetNode<Control>("%HpBar").Visible = false;
        var label = divider.GetNode<Label>("%Label");
        label.Text = $"Round {round}";
        label.ThemeTypeVariation = ThemeNames.HintLabel;
        label.TextOverrunBehavior = TextServer.OverrunBehavior.NoTrimming;
        _row.AddChild(divider);
    }

    /// <summary>Cap every name at one shared width so the strip fits <see cref="MaxWidth"/>.</summary>
    private void FitToWidth(List<(Label Label, float Natural)> labels)
    {
        float excess = _row.GetCombinedMinimumSize().X - MaxWidth;
        if (excess <= 0 || labels.Count == 0) return;
        float low = 0, high = 0;
        foreach (var (_, natural) in labels) high = Mathf.Max(high, natural);
        for (int step = 0; step < 16; step++)
        {
            float cap = (low + high) / 2;
            float saved = 0;
            foreach (var (_, natural) in labels) saved += Mathf.Max(0, natural - cap);
            if (saved >= excess) low = cap; else high = cap;
        }
        foreach (var (label, natural) in labels)
            label.CustomMinimumSize = new Vector2(Mathf.Floor(Mathf.Min(natural, low)), 0);
    }

    private static Color Faded(float alpha) => new Color(1, 1, 1, alpha);
}
