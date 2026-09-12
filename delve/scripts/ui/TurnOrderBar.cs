using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// Horizontal initiative strip: one chip per combatant in turn order — name, a thin team-colored
/// HP bar, a hard highlight on the current actor, dead combatants dimmed, a delayed combatant
/// shown faded at the slot it returns to. Passive — renders from <see cref="UnitView"/> data. The
/// one thing it takes back is a click on a chip offered as a Delay slot (<see cref="UnitView.IsPickable"/>),
/// raised as <see cref="ChipPressed"/> with the combatant's id; every other chip ignores the mouse.
/// All chip styling comes from theme variations (TurnChipAlly/Enemy/Active/Delayed/Pick, ChipLabel,
/// HpBarAlly/Enemy) — no stylebox duplication.
/// </summary>
public partial class TurnOrderBar : Control
{
    /// <summary>A chip offered as a Delay slot was clicked. Carries the combatant id.</summary>
    public event Action<int>? ChipPressed;

    /// <summary>Chip scene instanced once per combatant. Assigned in turn_order_bar.tscn.</summary>
    [Export] public PackedScene? ChipScene { get; set; }

    /// <summary>Label prefix of a combatant waiting out a Delay, the way ">" marks the actor.</summary>
    private const string DelayedPrefix = "~ ";

    private HBoxContainer _row = null!;

    public override void _Ready() => _row = GetNode<HBoxContainer>("%Row");

    public void Render(IReadOnlyList<UnitView> units)
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

        foreach (var unit in units)
        {
            var chip = ChipScene.Instantiate<PanelContainer>();
            chip.ThemeTypeVariation = unit.IsCurrent ? ThemeNames.TurnChipActive
                : unit.IsPickable ? ThemeNames.TurnChipPick
                : unit.IsDelayed ? ThemeNames.TurnChipDelayed
                : unit.IsAlly ? ThemeNames.TurnChipAlly : ThemeNames.TurnChipEnemy;

            var label = chip.GetNode<Label>("%Label");
            label.Text = unit.IsCurrent ? $"> {unit.Name}"
                : unit.IsDelayed ? $"{DelayedPrefix}{unit.Name}" : unit.Name;
            // The arrow and brass frame identify the actor without relying on a bright fill.
            label.ThemeTypeVariation = ThemeNames.ChipLabel;
            label.AddThemeColorOverride("font_color",
                unit.IsPickable ? UiColors.Accent : UiColors.Text);

            var hpBar = chip.GetNode<ProgressBar>("%HpBar");
            hpBar.ThemeTypeVariation = unit.IsAlly ? ThemeNames.HpBarAlly : ThemeNames.HpBarEnemy;
            int maxHp = Math.Max(1, unit.MaxHp);
            hpBar.MaxValue = maxHp;
            hpBar.Value = Math.Clamp(unit.Hp, 0, maxHp);

            // Dead chips fade as a whole; the chip keeps its slot so the order stays readable. A
            // waiting delayer fades less: it is still in the fight, just not yet in the order.
            chip.Modulate = unit.IsDead ? new Color(1, 1, 1, 0.45f)
                : unit.IsDelayed ? new Color(1, 1, 1, 0.7f) : Colors.White;

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
    }
}
