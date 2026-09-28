using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Vertical initiative list in the right rail, starting at the current actor: one row per
/// combatant with the enemy's letter badge, the full name, up to two condition icons then "+N",
/// and a thin team-coloured HP bar, and a
/// "Round N" divider where the order wraps. The current row is taller and filled. Rows past
/// <see cref="MaxHeight"/> drop from the tail. Dead combatants dim; a delayed combatant shows faded
/// at the slot it returns to. Passive: the one thing it takes back is a click on a row offered as a
/// Delay slot (<see cref="UnitView.IsPickable"/>), raised as <see cref="ChipPressed"/>.
/// </summary>
public partial class TurnOrderBar : VBoxContainer
{
    public event Action<int>? ChipPressed;

    [Export] public PackedScene? ChipScene { get; set; }
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int MaxMarks { get; set; } = 2;
    [Export] public int MarkIconSize { get; set; } = 22;
    [Export] public float MaxHeight { get; set; } = 560;
    [Export] public float ActiveChipHeight { get; set; } = 40;
    [Export] public float DividerHeight { get; set; } = 24;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DeadAlpha { get; set; } = 0.45f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DelayedAlpha { get; set; } = 0.7f;

    private const string DelayedPrefix = "~ ";

    private VBoxContainer _row = null!;

    public Control Row => _row;

    public override void _Ready() => _row = GetNode<VBoxContainer>("%Row");

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

        for (int i = 0; i < units.Count; i++)
        {
            if (i == wrapIndex) AddDivider(nextRound);
            AddChip(units[i]);
        }
        Cap();
    }

    private void AddChip(UnitView unit)
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

        AddMarks(chip.GetNode<HBoxContainer>("%Marks"), unit.Conditions, label.ThemeTypeVariation);

        if (unit.IsDead || unit.IsDelayed) chip.Modulate = Faded(unit.IsDead ? DeadAlpha : DelayedAlpha);
        chip.TooltipText = string.Join("\n", new[] { unit.Name }.Concat(unit.Conditions.Select(c => c.Label)));

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
    }

    /// <summary>The first <see cref="MaxMarks"/> conditions as 1x icons, the rest as "+N". The row's hover lists them all.</summary>
    private void AddMarks(HBoxContainer marks, IReadOnlyList<ConditionMarkView> conditions, StringName textVariation)
        => ConditionMarkRow.Fill(marks, conditions, Icons, MaxMarks, MarkIconSize, textVariation);

    private void AddDivider(int round)
    {
        var divider = ChipScene!.Instantiate<PanelContainer>();
        divider.ThemeTypeVariation = ThemeNames.ClearPanel;
        divider.CustomMinimumSize = new Vector2(0, DividerHeight);
        divider.GetNode<Control>("%HpBar").Visible = false;
        var label = divider.GetNode<Label>("%Label");
        label.Text = $"Round {round}";
        label.ThemeTypeVariation = ThemeNames.HintLabel;
        label.HorizontalAlignment = HorizontalAlignment.Center;
        _row.AddChild(divider);
    }

    private void Cap()
    {
        while (_row.GetChildCount() > 1 && _row.GetCombinedMinimumSize().Y > MaxHeight)
        {
            var last = _row.GetChild(_row.GetChildCount() - 1);
            _row.RemoveChild(last);
            last.QueueFree();
        }
    }

    private static Color Faded(float alpha) => new Color(1, 1, 1, alpha);
}
