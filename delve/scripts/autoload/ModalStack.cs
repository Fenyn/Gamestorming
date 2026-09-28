using System;
using System.Collections.Generic;
using Godot;

namespace Delve.Autoload;

/// <summary>
/// Scene-wide modal ownership. Each owner holds at most one entry, so a double push or pop cannot
/// skew the count, and an owner that leaves the tree releases its entry by itself.
/// </summary>
public partial class ModalStack : Node
{
    public static ModalStack? Instance { get; private set; }

    /// <summary>True when the first owner opens a modal, false when the last one closes.</summary>
    public event Action<bool>? Changed;

    private readonly List<(Node Owner, Action Release)> _owners = new();

    public bool IsOpen => _owners.Count > 0;
    public int Count => _owners.Count;

    public override void _EnterTree() => Instance = this;

    public override void _ExitTree()
    {
        if (ReferenceEquals(Instance, this)) Instance = null;
    }

    public bool Holds(Node owner) => _owners.FindIndex(o => ReferenceEquals(o.Owner, owner)) >= 0;

    /// <summary>True when anyone other than <paramref name="owner"/> holds a modal.</summary>
    public bool IsOpenFor(Node owner) => _owners.Exists(o => !ReferenceEquals(o.Owner, owner));

    public void Push(Node owner)
    {
        if (Holds(owner)) return;
        Action release = () => Pop(owner);
        owner.TreeExiting += release;
        _owners.Add((owner, release));
        if (_owners.Count == 1) Changed?.Invoke(true);
    }

    public void Pop(Node owner)
    {
        int index = _owners.FindIndex(o => ReferenceEquals(o.Owner, owner));
        if (index < 0) return;
        var (_, release) = _owners[index];
        _owners.RemoveAt(index);
        if (GodotObject.IsInstanceValid(owner)) owner.TreeExiting -= release;
        if (_owners.Count == 0) Changed?.Invoke(false);
    }
}
