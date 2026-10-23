using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Core;
using Ungilded.Story;

namespace Ungilded.Tutorial.Encounters;

/// <summary>The stage's tutorial tips: modal rule tips, step tips that stay up until their step is
/// done, and the waits a step needs. Every tip goes to <see cref="PopupLog"/> as plain text. A tip
/// with a focus resolves it through the combat scene and keeps its pinned cards and held banner
/// up while it shows.</summary>
internal sealed partial class EncounterStage
{
    private readonly List<TipHandle> _steps = new();

    /// <summary>A modal tip with Continue, beside <paramref name="focus"/> or centred when it is null.</summary>
    public async Task Rule(string id, TutorialFocus? focus, string text, params string[] gold)
    {
        PopupLog.Add(PopupText.Plain(text));
        await Popup.ShowRule(Request(id, focus, PopupText.Build(Popup, text, gold))).WaitAsync(_cts.Token);
    }

    /// <summary>A centred modal of labels and values; no highlight.</summary>
    public async Task ShowValues(string id, string text)
    {
        PopupLog.Add(text);
        await Popup.ShowRule(Request(id, null, text)).WaitAsync(_cts.Token);
    }

    /// <summary>A step tip beside <paramref name="focus"/>. Dispose the handle once the step is done.</summary>
    public TipHandle Step(string id, TutorialFocus focus, string text, params string[] gold)
    {
        PopupLog.Add(PopupText.Plain(text));
        var handle = Popup.OpenStep(Request(id, focus, PopupText.Build(Popup, text, gold)));
        _steps.Add(handle);
        return handle;
    }

    /// <summary>A step tip that closes as the actor commits the order, then waits until that action
    /// is spent and has played; false when the turn or the encounter ended first.</summary>
    public async Task<bool> StepUntilSpent(ICharacter actor, string id, TutorialFocus focus, string text, params string[] gold)
    {
        int start = actor.Actions?.TotalActionsRemaining ?? 0;
        using (Step(id, focus, text, gold))
            if (!await WaitUntil(actor, () => Scene.Controller is { Busy: true } || Spent(actor, start))) return false;
        return await WaitUntil(actor, () => Spent(actor, start));
    }

    /// <summary>A step tip that closes when the actor's turn ends.</summary>
    public async Task StepUntilTurnEnd(ICharacter actor, string id, TutorialFocus focus, string text, params string[] gold)
    {
        using (Step(id, focus, text, gold))
            await WaitTurnEnd(actor);
    }

    /// <summary>True once <paramref name="done"/> holds; false when the actor's turn or the
    /// encounter ended first.</summary>
    public async Task<bool> WaitUntil(ICharacter actor, Func<bool> done)
    {
        while (true)
        {
            if (Finished || Scene.Session == null) return false;
            if (done()) return true;
            if (!ReferenceEquals(Scene.Session.CurrentActor, actor)) return false;
            await NextFrame();
        }
    }

    /// <summary>True when the actor has <paramref name="count"/> fewer actions than
    /// <paramref name="start"/> and the action has finished playing.</summary>
    public bool Spent(ICharacter actor, int start, int count = 1)
        => (actor.Actions?.TotalActionsRemaining ?? 0) <= start - count && Scene.Controller is { Busy: false };

    private TipRequest Request(string id, TutorialFocus? focus, string bbcode)
    {
        var scene = Scene;
        if (focus == null) return new TipRequest(id, bbcode) { Panels = scene.HudPanels };
        return new TipRequest(id, bbcode)
        {
            Panels = scene.HudPanels,
            Resolve = (quads, clear) => scene.ResolveFocus(focus, quads, clear),
            Shown = () => scene.HoldFocus(focus, true),
            Hidden = () => scene.HoldFocus(focus, false),
            Dimmed = focus.Dimmed,
        };
    }

    private void CloseSteps()
    {
        foreach (var handle in _steps) handle.Dispose();
        _steps.Clear();
    }
}
