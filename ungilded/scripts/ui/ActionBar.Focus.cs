using System;
using System.Collections.Generic;
using Godot;

namespace Ungilded.UI;

/// <summary>The menu parts a tutorial tip can point at.</summary>
public partial class ActionBar
{
    private bool _signatureChipEnabled;

    /// <summary>The drawn parts that belong to the entry whose label starts with
    /// <paramref name="label"/> ("Strike" also finds "Strike -5"): the entry, its open sub-menu, and
    /// for Abilities the quick-slot row while it offers an enabled chip.</summary>
    public IEnumerable<Control> CommandParts(string label)
    {
        foreach (var button in _captions)
        {
            if (!button.ActionText.StartsWith(label, StringComparison.OrdinalIgnoreCase) || !button.IsVisibleInTree()) continue;
            yield return button;
            bool opens = button == _skillsBtn && _openCategory == FlyoutCategory.Skills
                || button == _spellsBtn && _openCategory == FlyoutCategory.Spells;
            if (opens && _flyout.IsVisibleInTree()) yield return _flyout;
            if (button == _skillsBtn && _signatureChipEnabled && _signatures.IsVisibleInTree()) yield return _signatures;
        }
    }
}
