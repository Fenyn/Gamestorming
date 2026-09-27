using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>The party column: one <see cref="PartyChip"/> per party member in a stable order.
/// Clicking a chip focuses and inspects that member; focus never changes turn ownership.</summary>
public partial class SquadPanel : VBoxContainer
{
    [Export] public PackedScene CardScene { get; set; } = null!;
    private readonly Dictionary<int, PartyChip> _cards = new();
    private VBoxContainer _members = null!;
    public event Action<int>? FocusRequested;

    public IReadOnlyCollection<PartyChip> Chips => _cards.Values;

    public override void _Ready() => _members = GetNode<VBoxContainer>("%Members");

    public void Setup(IEnumerable<SquadMemberView> party)
    {
        foreach (var (_, card) in _cards) { _members.RemoveChild(card); card.QueueFree(); }
        _cards.Clear();
        foreach (var member in party)
        {
            var card = CardScene.Instantiate<PartyChip>();
            _members.AddChild(card);
            card.Setup(member);
            card.Render(member);
            int id = member.Id;
            card.Pressed += () => FocusRequested?.Invoke(id);
            _cards.Add(member.Id, card);
        }
    }

    public void Render(IEnumerable<SquadMemberView> party)
    {
        foreach (var member in party)
            if (_cards.TryGetValue(member.Id, out var card)) card.Render(member);
    }
}
