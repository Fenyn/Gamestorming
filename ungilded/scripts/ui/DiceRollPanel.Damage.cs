using Godot;

namespace Ungilded.UI;

/// <summary>Damage dice for the roll they belong to. The engine applies a Strike's damage in the same
/// frame it logs the attack roll, so the newest roll owns it when it is an attack that hit and has
/// no damage yet.</summary>
public partial class DiceRollPanel
{
    private RichTextLabel _damage = null!;

    /// <summary>True from the start of a full beat until its outcome hold ends; damage arriving later
    /// shows only in the settled row.</summary>
    private bool _awaitingDamage;

    /// <summary>The damage the engine just applied, for the newest roll if it is an attack that hit.</summary>
    public void ShowDamage(DamageRoll damage)
    {
        var latest = _pending.Count > 0 ? _pending.ToArray()[^1] : _current;
        if (latest is not { Damage: null } || !latest.Roll.IsAttack || latest.Roll.DegreeIndex < DegreeZones.Success) return;
        if (latest == _current && _phase != Phase.Beat && Beat?.Pace != RollPace.Settled) return;
        latest.Damage = damage;
        if (latest != _current) return;
        FillDamage(damage);
        if (_awaitingDamage) Hero?.SetDamage(damage);
    }

    private void FillDamage(DamageRoll? damage)
    {
        _damage.Visible = damage != null;
        if (damage == null) return;
        string dim = UiColors.TextDim.ToHtml();
        var colour = Ungilded.Fx.DamageColors.For(damage.Type) ?? (damage.Doubled ? UiColors.PopupCrit : UiColors.Text);
        _damage.Text = $"[font_size={SumDetailFontSize}][color=#{dim}]Damage[/color][/font_size] "
            + $"[font_size={SumFontSize}][b][color=#{colour.ToHtml()}]{damage.Total}[/color][/b][/font_size]";
    }
}
