using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// The FFT combat timeline down the left edge: one portrait tile per combatant, numbered from the
/// current actor (1) onward, stacked bottom-up so the actor sits by the unit card. Each tile has a
/// team-coloured frame, a thin HP strip and up to two condition icons then "+N"; a "Round N" divider
/// marks where the order wraps. Rows past <see cref="MaxHeight"/> drop from the far end. Dead
/// combatants dim; a delayed combatant shows faded at the slot it returns to. The board plates carry
/// the same numbers (<see cref="Numbers"/>). Passive: the one thing it takes back is a click on a
/// tile offered as a Delay slot (<see cref="UnitView.IsPickable"/>), raised as <see cref="ChipPressed"/>.
/// </summary>
public partial class TurnOrderBar : VBoxContainer
{
    public event Action<int>? ChipPressed;

    /// <summary>A tile that is not a Delay pick was clicked: the combatant's id, to inspect it.</summary>
    public event Action<int>? UnitPressed;

    [Export] public PackedScene? ChipScene { get; set; }
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int MaxMarks { get; set; } = 2;
    [Export] public int MarkIconSize { get; set; } = 22;
    [Export] public float MaxHeight { get; set; } = 560;
    [Export] public float DividerHeight { get; set; } = 24;

    /// <summary>Stack the actor at the bottom and later turns above it, as FFT does.</summary>
    [Export] public bool BottomUp { get; set; } = true;

    private readonly Dictionary<int, int> _numbers = new();

    /// <summary>Timeline number (1 = acting now) by combatant id, as last rendered.</summary>
    public IReadOnlyDictionary<int, int> Numbers => _numbers;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DeadAlpha { get; set; } = 0.45f;
    [Export(PropertyHint.Range, "0,1,0.05")] public float DelayedAlpha { get; set; } = 0.7f;

    private const string DelayedPrefix = "~ ";

    private VBoxContainer _row = null!;

    public Control Row => _row;

    /// <summary>Hidden until the first render with combatants, so the intro shows no empty "Timeline".</summary>
    public override void _Ready()
    {
        _row = GetNode<VBoxContainer>("%Row");
        Visible = false;
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

        _numbers.Clear();
        Visible = units.Count > 0;
        var rows = new List<Control>(units.Count + 1);
        for (int i = 0; i < units.Count; i++)
        {
            if (i == wrapIndex) rows.Add(Divider(nextRound));
            _numbers[units[i].Id] = i + 1;
            rows.Add(Chip(units[i], i + 1));
        }
        if (BottomUp) rows.Reverse();
        foreach (var row in rows) _row.AddChild(row);
        Cap();
    }

    /// <summary>The rows in turn order, nearest turn first, whichever way they stack.</summary>
    public IEnumerable<Control> RowsInTurnOrder()
    {
        var rows = _row.GetChildren().OfType<Control>();
        return BottomUp ? rows.Reverse() : rows;
    }

    private Control Chip(UnitView unit, int number)
    {
        var chip = ChipScene!.Instantiate<Control>();
        chip.SetMeta(IdMeta, unit.Id);
        chip.GetNode<PanelContainer>("%Frame").ThemeTypeVariation = unit.IsCurrent ? ThemeNames.TurnChipActive
            : unit.IsPickable ? ThemeNames.TurnChipPick
            : unit.IsDelayed ? ThemeNames.TurnChipDelayed
            : unit.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;

        var numberLabel = chip.GetNode<Label>("%Number");
        numberLabel.Text = number.ToString();
        numberLabel.ThemeTypeVariation = unit.IsAlly ? ThemeNames.TimelineNumberAlly : ThemeNames.TimelineNumberEnemy;
        chip.GetNode<TextureRect>("%Portrait").Texture = UnitPortraits.For(unit.HeroId, unit.SpriteFolder);
        // Enemies keep the letter the log and the cards use, so "Goblin C" can be found on the timeline.
        chip.GetNode<Control>("%LetterBadge").Visible = !unit.IsAlly && unit.Letter.Length > 0;
        chip.GetNode<Label>("%Letter").Text = unit.Letter;

        string name = unit.Letter.Length > 0 && unit.BaseName.Length > 0 ? $"{unit.BaseName} {unit.Letter}" : unit.Name;
        var label = chip.GetNode<Label>("%Label");
        label.Text = unit.IsDelayed ? $"{DelayedPrefix}{name}" : name;

        var hpBar = chip.GetNode<ProgressBar>("%HpBar");
        hpBar.ThemeTypeVariation = unit.IsAlly ? ThemeNames.HpBarAlly : ThemeNames.HpBarEnemy;
        int maxHp = Math.Max(1, unit.MaxHp);
        hpBar.MaxValue = maxHp;
        hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);

        AddMarks(chip.GetNode<HBoxContainer>("%Marks"), unit.Conditions, ThemeNames.ChipLabel);

        if (unit.IsDead || unit.IsDelayed) chip.Modulate = Faded(unit.IsDead ? DeadAlpha : DelayedAlpha);
        chip.MouseFilter = MouseFilterEnum.Pass;
        chip.TooltipText = string.Join("\n", new[] { name }.Concat(unit.Conditions.Select(c => c.Label)));

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
        else
        {
            int id = unit.Id;
            chip.GuiInput += @event =>
            {
                if (@event is not InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left }) return;
                chip.AcceptEvent();
                UnitPressed?.Invoke(id);
            };
        }
        return chip;
    }

    /// <summary>The first <see cref="MaxMarks"/> conditions as 1x icons, the rest as "+N". The row's hover lists them all.</summary>
    private void AddMarks(HBoxContainer marks, IReadOnlyList<ConditionMarkView> conditions, StringName textVariation)
        => ConditionMarkRow.Fill(marks, conditions, Icons, MaxMarks, MarkIconSize, textVariation);

    /// <summary>The round divider. It carries a %Label like a tile so row readers treat both alike.</summary>
    private Control Divider(int round)
    {
        var label = new Label
        {
            Name = "Label",
            UniqueNameInOwner = true,
            Text = $"Round {round}",
            ThemeTypeVariation = ThemeNames.HintLabel,
            CustomMinimumSize = new Vector2(0, DividerHeight),
            VerticalAlignment = VerticalAlignment.Center,
            MouseFilter = MouseFilterEnum.Ignore,
        };
        var divider = new MarginContainer { MouseFilter = MouseFilterEnum.Ignore };
        divider.AddChild(label);
        label.Owner = divider;
        return divider;
    }

    /// <summary>Drop the farthest turns until the list fits: the top rows when stacking bottom-up.</summary>
    private void Cap()
    {
        while (_row.GetChildCount() > 1 && _row.GetCombinedMinimumSize().Y > MaxHeight)
        {
            RemoveRow(BottomUp ? 0 : _row.GetChildCount() - 1);
        }
        // A divider with no turns past it announces a round the list no longer shows.
        int edge = BottomUp ? 0 : _row.GetChildCount() - 1;
        if (_row.GetChildCount() > 1 && _row.GetChild(edge) is MarginContainer) RemoveRow(edge);
    }

    private const string IdMeta = "combatant_id";

    private void RemoveRow(int index)
    {
        var row = _row.GetChild(index);
        if (row.HasMeta(IdMeta)) _numbers.Remove(row.GetMeta(IdMeta).AsInt32());
        _row.RemoveChild(row);
        row.QueueFree();
    }

    private static Color Faded(float alpha) => new Color(1, 1, 1, alpha);
}
