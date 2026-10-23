using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Story.Cutscene;

namespace Ungilded.Story;

/// <summary>The cutscene set behind <see cref="DialogueBackdrop.Set"/> beats and revealing narration pages.</summary>
public partial class PrologueDirector
{
    /// <summary>Fires when a set is built (the set) or freed (null).</summary>
    public event Action<CutsceneSet?>? SetChanged;

    /// <summary>The live cutscene set, or null.</summary>
    public CutsceneSet? LiveSet => _set;

    private CutsceneSet? _set;
    private PackedScene? _setSource;

    /// <summary>Build <paramref name="scene"/> behind the black unless it is already live, framed on
    /// the opening of <paramref name="opening"/> so the black lifts onto its first shot. The set and
    /// a combat board share the shader globals, the sprite tint and the world environment, so a
    /// parked board is released first.</summary>
    private async Task EnsureSet(PackedScene scene, DialogueLine? opening = null)
    {
        if (_set != null && _setSource == scene) return;
        await Fade.FadeIn(BlackoutSeconds);
        FreeSet();
        if (_prepared != 0) Runner.Release(_prepared);
        _prepared = 0;
        var set = scene.Instantiate<CutsceneSet>();
        AddChild(set);
        set.Build();
        if (opening != null) set.Frame(opening);
        _set = set;
        _setSource = scene;
        ShowWardrobe();
        Letterbox.ShowBars();
        SetChanged?.Invoke(set);
    }

    /// <summary>Black out and free the set after beat <paramref name="index"/>, unless the next beat
    /// plays on the same set.</summary>
    private async Task LeaveSet(int index)
    {
        if (_set == null || SetAt(index + 1) == _setSource) return;
        await Fade.FadeIn(BlackoutSeconds);
        FreeSet();
    }

    /// <summary>Free the set now. Removing it from the tree first lets its look and cutaway release the
    /// shader globals before a combat board claims them.</summary>
    private void FreeSet()
    {
        if (_set == null) return;
        RemoveChild(_set);
        _set.QueueFree();
        _set = null;
        _setSource = null;
        Letterbox.HideBars();
        SetChanged?.Invoke(null);
    }

    /// <summary>The set scene of beat <paramref name="index"/>, or null when it plays on no set.</summary>
    private PackedScene? SetAt(int index) =>
        index < Beats.Count && Beats[index] is { Kind: BeatKind.Dialogue, Sequence: { Backdrop: DialogueBackdrop.Set } sequence }
            ? sequence.CutsceneSet : null;

    /// <summary>Light the glow of each speaker's actor that carries or wears an accessory, and put
    /// out the others. An actor with nothing to show is not spawned for it.</summary>
    private void ShowWardrobe()
    {
        if (_set == null) return;
        foreach (var (speaker, id) in _set.Speakers)
        {
            var state = Wardrobe.ShownOn(speaker);
            if (state == AccessoryState.Hidden && !_set.Actors.Any(a => a.Name == id)) continue;
            _set.Actor(id).ShowAccessory(state);
        }
    }

    /// <summary>Start the line's stage cues on the live set, then hop its speaker.</summary>
    private Task PlayCues(DialogueLine line)
    {
        if (_set == null) return Task.CompletedTask;
        var cues = line.StageCues.Count > 0 ? _set.Play(line.StageCues) : Task.CompletedTask;
        _set.HopSpeaker(line);
        return cues;
    }
}
