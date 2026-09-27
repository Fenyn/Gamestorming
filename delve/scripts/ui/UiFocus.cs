using System.Collections.Generic;
using System.Linq;
using Godot;

namespace Delve.UI;

public static class UiFocus
{
    /// <summary>Deferred so the grab lands after the panel finishes showing.</summary>
    public static void Grab(Control? control)
    {
        if (control == null) return;
        Callable.From(() =>
        {
            if (GodotObject.IsInstanceValid(control) && control.IsVisibleInTree()) control.GrabFocus();
        }).CallDeferred();
    }

    public static void GrabFirst(IEnumerable<BaseButton> buttons) =>
        Grab(buttons.FirstOrDefault(b => !b.Disabled && b.Visible));
}
