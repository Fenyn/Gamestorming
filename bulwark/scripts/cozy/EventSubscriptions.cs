using System;
using System.Collections.Generic;

namespace Bulwark.Cozy;

/// <summary>
/// Pairs each subscription with the exact call that undoes it, so a scene can drop everything it
/// wired to a longer-lived source without a hand-mirrored teardown list. <see cref="Add"/> runs the
/// subscribe immediately and records the matching unsubscribe; <see cref="DrainAll"/> runs every
/// recorded unsubscribe (in registration order) and clears. Replaces CozyWorldScene's old
/// WireStateEvents/_ExitTree mirror — where one missed <c>-=</c> leaked the freed scene through the
/// GameState autoload — with a shape where drift is structurally impossible, because a single call
/// supplies both halves. Not thread-safe; used only on the scene-tree thread.
/// </summary>
public sealed class EventSubscriptions
{
    private readonly List<Action> _unsubscribes = new();

    /// <summary>Run <paramref name="subscribe"/> now and remember <paramref name="unsubscribe"/> for
    /// <see cref="DrainAll"/>. The two must be exact inverses (e.g. <c>gs.X += H</c> / <c>gs.X -= H</c>).</summary>
    public void Add(Action subscribe, Action unsubscribe)
    {
        subscribe();
        _unsubscribes.Add(unsubscribe);
    }

    /// <summary>Run every recorded unsubscribe and clear the list.</summary>
    public void DrainAll()
    {
        foreach (Action unsubscribe in _unsubscribes)
            unsubscribe();
        _unsubscribes.Clear();
    }
}
