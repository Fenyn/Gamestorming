using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>Stable party identities. Focus never changes turn ownership.</summary>
public partial class SquadPanel : VBoxContainer
{
    [Export] public PackedScene CardScene { get; set; } = null!;
    private readonly Dictionary<int, Button> _cards = new();
    public event Action<int>? FocusRequested;
    public event Action? OverviewRequested, ConfirmRequested, StagingChanged;
    public bool StageOrders => GetNode<CheckBox>("%StageOrders").ButtonPressed;

    public override void _Ready()
    {
        GetNode<CheckBox>("%StageOrders").Toggled += _ => StagingChanged?.Invoke();
        GetNode<Button>("%Overview").Pressed += () => OverviewRequested?.Invoke();
        GetNode<Button>("%ConfirmOrder").Pressed += () => ConfirmRequested?.Invoke();
    }

    public void Setup(IEnumerable<SquadMemberView> party)
    {
        foreach (var (_, card) in _cards) { card.GetParent().RemoveChild(card); card.QueueFree(); }
        _cards.Clear();
        foreach (var member in party)
        {
            var card = CardScene.Instantiate<Button>();
            GetNode<HBoxContainer>("%Members").AddChild(card);
            card.GetNode<TextureRect>("%Portrait").Texture = HeroPortraits.For(member.HeroId);
            card.GetNode<Label>("%Name").Text = member.Name;
            card.Pressed += () => FocusRequested?.Invoke(member.Id);
            _cards.Add(member.Id, card);
        }
        SetStaged(false);
    }

    public void Render(IEnumerable<SquadMemberView> party)
    {
        foreach (var member in party)
        {
            if (!_cards.TryGetValue(member.Id, out var card)) continue;
            card.SetPressedNoSignal(member.Focused);
            card.GetNode<Label>("%Name").Modulate = member.Acting ? UiColors.CharacterAccent(member.HeroId) : Colors.White;
            card.GetNode<Label>("%Health").Text = $"{member.Hp}/{member.MaxHp}";
            card.GetNode<Label>("%State").Text = member.State + (member.Conditions.Length > 0 ? " *" : "");
            card.TooltipText = member.Name + " · " + member.State + (member.Conditions.Length > 0 ? "\n" + member.Conditions : "")
                + "\nFocus and inspect";
        }
    }

    public void SetStaged(bool staged) => GetNode<Button>("%ConfirmOrder").Visible = staged;
}
