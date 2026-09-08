using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>A party member's health at the point where recovery can be chosen.</summary>
public partial class MapPartyMember : VBoxContainer
{
    public void Render(PF2eCharacter member)
    {
        GetNode<Label>("%MemberName").Text = member.Name;
        var health = member.Health;
        GetNode<Label>("%MemberHealth").Text = $"{health.CurrentHP} / {health.MaxHP} HP";
        var bar = GetNode<ProgressBar>("%MemberBar");
        bar.MaxValue = System.Math.Max(1, health.MaxHP);
        bar.Value = health.CurrentHP;
        bar.ThemeTypeVariation = ThemeNames.MapHpBarFor((float)health.CurrentHP / System.Math.Max(1, health.MaxHP));
        var condition = GetNode<Label>("%MemberCondition");
        int wounded = PartyLines.Wounded(member);
        condition.Text = health.IsDead ? "Down" : wounded > 0 ? $"Wounded {wounded}" : "";
        condition.Visible = condition.Text.Length > 0;
        TooltipText = PartyLines.Describe(member);
    }
}
