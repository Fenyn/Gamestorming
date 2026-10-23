using System.Collections.Generic;
using Godot;

namespace Ungilded.Combat;

/// <summary>Keeps the reaction prompt beside the creature that set it off, every frame, with the
/// pointer at it. The box never covers the reactor and keeps off the HUD panels, the combat log
/// and the roll banner where it can. With the creature off screen the box sits beside the reactor;
/// with neither on screen it docks at the bottom centre.</summary>
public partial class CombatScene
{
    private readonly List<Rect2> _promptPanels = new();
    private readonly List<Rect2> _promptKeepOff = new();

    /// <summary>Dev use: the rect the prompt sits beside (the triggering creature and its plate, or
    /// the reactor when the creature is off screen), or null while it is docked.</summary>
    public Rect2? ReactionTriggerRect { get; private set; }

    /// <summary>Dev use: the reactor and its plate, which the prompt keeps off, or null when it is
    /// the trigger rect or off screen.</summary>
    public Rect2? ReactionReactorRect { get; private set; }

    /// <summary>Dev use: the prompt box, in HUD pixels.</summary>
    public Rect2 ReactionPromptRect => _reactionPrompt.BoxRect;

    /// <summary>Dev use: the farthest the box may sit from its trigger.</summary>
    public float ReactionPromptReach => _reactionPrompt.MaxReach;

    /// <summary>Dev use: true when the whole prompt box is on screen.</summary>
    public bool ReactionPromptOnScreen => _tacticalHud.GetGlobalRect().Encloses(_reactionPrompt.BoxRect);

    /// <summary>Dev use: true while the prompt's pointer aims at its trigger.</summary>
    public bool ReactionPromptPointing => _reactionPrompt.Pointing;

    private void LayoutReactionPrompt()
    {
        if (!_reactionPrompt.Visible) return;
        var screen = _tacticalHud.GetGlobalRect();
        var source = OnScreen(UnitWithPlate(_reactionSourceId), screen);
        var reactor = OnScreen(UnitWithPlate(_reactorId), screen);
        var trigger = source ?? reactor;
        ReactionTriggerRect = trigger;
        ReactionReactorRect = source != null ? reactor : null;
        if (trigger is not { } bounds)
        {
            _reactionPrompt.DockBottom();
            return;
        }
        HudPanels(_promptPanels);
        if (_log.IsVisibleInTree()) _promptPanels.Add(_log.GetGlobalRect());
        if (_dice.IsVisibleInTree()) _promptPanels.Add(_dice.GetGlobalRect());
        _promptKeepOff.Clear();
        if (ReactionReactorRect is { } reactorRect) _promptKeepOff.Add(reactorRect);
        _reactionPrompt.Place(bounds, bounds.GetCenter(), _promptPanels, _promptKeepOff);
    }

    /// <summary>The unit's screen rect merged with its name plate when the plate shows.</summary>
    private Rect2? UnitWithPlate(int? id)
    {
        if (id is not { } uid || !_tacticalUnits.TryGetValue(uid, out var visual)
            || UnitScreenRect(visual.Character) is not { } rect) return null;
        return visual.Plate.PlateVisible ? rect.Merge(visual.Plate.PlateRect(_cameraRig.Camera)) : rect;
    }

    private static Rect2? OnScreen(Rect2? rect, Rect2 screen)
        => rect is { } r && r.Intersects(screen) ? r.Intersection(screen) : null;
}
