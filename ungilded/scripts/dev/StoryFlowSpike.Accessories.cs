using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Story;

namespace Ungilded.Dev;

/// <summary>
/// Accessory checks: during the director run the Player wears the spectacles on every line after
/// the scene 3b cue and the Friend only between his two cues; on a worn portrait the overlay shows
/// the face's frame and flip on every sampled frame.
/// </summary>
public partial class StoryFlowSpike
{
    /// <summary>Seconds the frame check samples a worn portrait while it talks and then rests.</summary>
    [Export] public float AccessorySampleSeconds { get; set; } = 3f;

    private const string RatsAppearId = "tutorial_scene3_rats_appear";
    private const string AfterRatsAppearId = "tutorial_scene4_dead_truthseeker";
    private const string Player = "The Player";
    private const string Friend = "The Friend";
    private const string Spectacles = "spectacles";

    /// <summary>The start of the Friend's one line with the spectacles on.</summary>
    private const string FriendWearsText = "The glass...";

    private sealed record WornFace(string Sequence, DialogueLine Line, bool Shown);

    private const string PostEncounter1Id = "tutorial_scene3_post_enc1";

    /// <summary>The spectacles' carrier as each line of a sequence starts: (line, Friend, Player).</summary>
    private sealed record Carrier(string Sequence, int Line, AccessoryState Friend, AccessoryState Player, bool? PlayerActorGlows);

    /// <summary>Scene 3b, lines 1 to 9: the Friend puts them on, takes them off, hands them over, and
    /// the Player puts them on.</summary>
    private static readonly (AccessoryState Friend, AccessoryState Player)[] RatsAppearCarriers =
    {
        (AccessoryState.Worn, AccessoryState.Hidden),
        (AccessoryState.Worn, AccessoryState.Hidden),
        (AccessoryState.Carried, AccessoryState.Hidden),
        (AccessoryState.Carried, AccessoryState.Hidden),
        (AccessoryState.Hidden, AccessoryState.Carried),
        (AccessoryState.Hidden, AccessoryState.Carried),
        (AccessoryState.Hidden, AccessoryState.Carried),
        (AccessoryState.Hidden, AccessoryState.Carried),
        (AccessoryState.Hidden, AccessoryState.Worn),
    };

    private static List<Carrier> RecordCarriers(PrologueDirector director, Func<PrologueBeat?> beat)
    {
        var carriers = new List<Carrier>();
        director.Dialogue.LineStarted += line =>
        {
            if (beat()?.Sequence is not { } sequence) return;
            bool? glows = director.LiveSet is { } set && set.Speakers.TryGetValue(Player, out var id)
                && set.Actors.FirstOrDefault(a => a.Name == id) is { Visible: true } actor ? actor.GlowOn : null;
            carriers.Add(new Carrier(sequence.Id, sequence.Lines.IndexOf(line) + 1,
                director.Wardrobe.StateOf(Friend, Spectacles), director.Wardrobe.StateOf(Player, Spectacles), glows));
        };
        return carriers;
    }

    private void CheckCarriers(List<Carrier> carriers)
    {
        var scene3a = carriers.Where(c => c.Sequence == PostEncounter1Id).ToList();
        Check($"Scene 3a: the Friend carries the spectacles from its last line ({scene3a.Count} lines)",
            scene3a.Count > 0 && scene3a.All(c => c.Player == AccessoryState.Hidden
                && c.Friend == (c.Line == scene3a.Max(l => l.Line) ? AccessoryState.Carried : AccessoryState.Hidden)));
        var scene3b = carriers.Where(c => c.Sequence == RatsAppearId).ToList();
        Check($"Scene 3b: {scene3b.Count} lines of {RatsAppearCarriers.Length}", scene3b.Count == RatsAppearCarriers.Length);
        foreach (var c in scene3b)
        {
            var (friend, player) = RatsAppearCarriers[c.Line - 1];
            Check($"Scene 3b line {c.Line}: the Friend {c.Friend} (expected {friend}), the Player {c.Player} (expected {player})",
                c.Friend == friend && c.Player == player);
        }
        int after = carriers.FindLastIndex(c => c.Sequence == RatsAppearId) + 1;
        var later = carriers.Skip(after).Where(c => c.PlayerActorGlows != null).ToList();
        Check($"the Player's cutscene actor glows on all {later.Count} set lines after Scene 3b",
            later.Count > 0 && later.All(c => c.PlayerActorGlows == true));
    }

    private static List<WornFace> RecordWornFaces(PrologueDirector director, Func<PrologueBeat?> beat)
    {
        var faces = new List<WornFace>();
        director.Dialogue.LineStarted += line =>
        {
            if (line.IsNarration) return;
            faces.Add(new WornFace(beat()?.Sequence?.Id ?? "", line, director.Dialogue.SpeakerPortrait?.OverlayShown == true));
        };
        return faces;
    }

    private void CheckWornFaces(PrologueDirector director, List<WornFace> faces)
    {
        var order = director.Beats.Where(b => b.Sequence != null).Select(b => b.Sequence!.Id).ToList();
        int cue = order.IndexOf(RatsAppearId);
        bool PlayerWears(WornFace f) => order.IndexOf(f.Sequence) > cue;
        bool FriendWears(WornFace f) => f.Sequence == RatsAppearId && f.Line.Text.StartsWith(FriendWearsText);

        var player = faces.Where(f => f.Line.Speaker == Player).ToList();
        int after = player.Count(PlayerWears);
        Check($"the Player's spectacles show on all {after} lines after the 3b cue",
            after > 0 && player.Where(PlayerWears).All(f => f.Shown));
        Check("the Player's spectacles show on no line before the 3b cue",
            player.Where(f => !PlayerWears(f)).All(f => !f.Shown));

        var friend = faces.Where(f => f.Line.Speaker == Friend).ToList();
        Check($"the Friend wears the spectacles on \"{FriendWearsText}\"", friend.Any(f => FriendWears(f) && f.Shown));
        int takenOff = friend.FindIndex(FriendWears) + 1;
        Check($"the Friend's spectacles are hidden on all {friend.Count - takenOff} lines after he takes them off",
            takenOff > 0 && friend.Skip(takenOff).All(f => !f.Shown));
        Check("the Friend wears nothing before his 3b cue", friend.Take(Math.Max(takenOff - 1, 0)).All(f => !f.Shown));
        Check("after the run the Player still wears the spectacles and the Friend does not",
            director.Wardrobe.IsWearing(Player, Spectacles) && !director.Wardrobe.IsWearing(Friend, Spectacles));
    }

    /// <summary>After the 3b cue, the Player's overlay shows the face's atlas region and flip on every frame.</summary>
    private async Task CheckAccessoryFrames()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        AddChild(director);
        var box = director.Dialogue;
        await PlayThrough(box, SequenceOf(RatsAppearId));

        var play = box.Play(SequenceOf(AfterRatsAppearId));
        await NextFrame();
        while (box.CurrentLine != null && box.CurrentLine.Speaker != Player)
        {
            box.Advance();
            if (box.IsRevealing) box.Advance();
            await NextFrame();
        }

        int samples = 0, off = 0;
        var regions = new HashSet<Rect2>();
        for (float waited = 0; waited < AccessorySampleSeconds; waited += (float)GetProcessDeltaTime())
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            samples++;
            var view = box.SpeakerPortrait;
            if (view?.Texture is not AtlasTexture face || view.Overlay?.Texture is not AtlasTexture glasses
                || !view.OverlayShown || face.Region != glasses.Region || view.Overlay.FlipH != view.FlipH)
            {
                off++;
                continue;
            }
            regions.Add(face.Region);
        }
        Check($"the Player's spectacles track the face frame ({samples} samples, {off} off, {regions.Count} frames seen)",
            samples > 0 && off == 0 && regions.Count > 1);

        await PlayThrough(box, play);
        director.QueueFree();
        await NextFrame();
    }

    private Task PlayThrough(DialogueBox box, DialogueSequence sequence) => PlayThrough(box, box.Play(sequence));

    private async Task PlayThrough(DialogueBox box, Task play)
    {
        while (!play.IsCompleted)
        {
            box.Advance();
            await NextFrame();
        }
    }
}
