using System.Linq;
using System.Threading.Tasks;
using Godot;
using PF2e.MapGen;
using Ungilded.Look;
using Ungilded.Story;
using Ungilded.Story.Cutscene;
using Ungilded.Terrain;
using Ungilded.Tutorial.Encounters;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

public partial class CutsceneSpike
{
    /// <summary>The actor that speaks each speaker's lines.</summary>
    private static readonly System.Collections.Generic.Dictionary<string, string> SpeakerActors = new()
    {
        ["The Player"] = "player",
        ["The Friend"] = "friend",
    };

    /// <summary>Shortest blend allowed after a scene's opening shot, seconds.</summary>
    private const float MinBlendSeconds = 1.5f;

    /// <summary>Widest spread of shot yaws within one scene, degrees.</summary>
    private const float MaxYawArc = 80f;

    /// <summary>The scene keeps one side of the action and never cuts after its opening: every shot
    /// after the first blends at least <see cref="MinBlendSeconds"/>, and every yaw sits within
    /// <see cref="MaxYawArc"/> of the others.</summary>
    private void CheckCameraGrammar(string shot, DialogueSequence sequence)
    {
        var shots = sequence.Lines.SelectMany(l => l.StageCues.OfType<ShotCue>()).ToList();
        if (shots.Count == 0) return;
        var later = shots.Skip(1).ToList();
        float shortest = later.Select(s => s.Seconds).DefaultIfEmpty(0f).Min();
        float longest = later.Select(s => s.Seconds).DefaultIfEmpty(0f).Max();
        Check($"{shot}: every shot after the first blends {MinBlendSeconds} s or more (blends {shortest:0.0} to {longest:0.0} s)",
            later.All(s => s.Seconds >= MinBlendSeconds));
        var offsets = shots.Select(s => Mathf.Wrap(s.Yaw - shots[0].Yaw, -180f, 180f)).ToList();
        float low = shots[0].Yaw + offsets.Min(), high = shots[0].Yaw + offsets.Max();
        Check($"{shot}: every yaw sits within a {MaxYawArc} degree arc ({low:0} to {high:0})", high - low <= MaxYawArc);
    }

    private async Task CheckReveal(PrologueDirector director, CutsceneSet set)
    {
        Check("the set's camera is current behind the revealing page", GetViewport().GetCamera3D() == set.Camera);
        Check("the black overlay is down under the narration", director.Fade.IsClear);
        var before = set.Camera.GlobalPosition;
        await WaitSeconds(Headless ? 1f : RevealHoldSeconds);
        Check("the revealing page shows the set behind its text", director.Narration.ShowsSet);
        Check("the camera moves during the revealing page",
            set.Camera.IsBlending && set.Camera.GlobalPosition.DistanceTo(before) > 0.001f);
        if (!Headless) SaveViewportCapture(ShotDirectory.PathJoin("cutscene_page6.png"));
    }

    /// <summary>Once the line's blend ends: the set's camera is current, every standing actor is on
    /// floor, and the speaker shows in frame above the dialogue box with no wall in front. Rendered,
    /// the first line and every line with a shot are saved to <paramref name="capture"/>.</summary>
    private async Task CheckLine(PrologueDirector director, CutsceneSet set, DialogueLine line, string tag, string capture, bool first)
    {
        for (float waited = 0; set.Camera.IsBlending && waited < BlendWaitSeconds; waited += (float)GetProcessDeltaTime())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (director.Dialogue.IsRevealing) director.Dialogue.Advance();
        await WaitSeconds(Headless ? 0f : 0.3f);

        Check($"{tag}: the set's camera is current", GetViewport().GetCamera3D() == set.Camera);
        var standing = set.Actors.Where(a => a.Visible && !a.IsWalking).ToList();
        foreach (var actor in standing)
        {
            var roles = actor.SpaceAt(actor.Tile).Select(set.RoleAt).ToList();
            bool grounded = Mathf.Abs(actor.Position.Y - set.StandPoint(actor.Tile, actor.Width).Y) < 0.01f;
            Check($"{tag}: {actor.Name} stands on floor at {actor.Tile} ({string.Join(" ", roles.Distinct())})",
                roles.All(r => r is TileRole.Ground or TileRole.Bridge) && grounded);
        }
        foreach (var wide in standing.Where(a => a.Width > 1))
        {
            var space = wide.SpaceAt(wide.Tile).ToHashSet();
            Check($"{tag}: no other actor stands in {wide.Name}'s {wide.Width}x{wide.Width} space",
                standing.All(a => a == wide || !a.SpaceAt(a.Tile).Any(space.Contains)));
        }
        if (first)
            Check($"{tag}: no actor draws a see-through silhouette", set.Actors.All(a => a.Sprite.MaterialOverlay == null));

        string? speaker = !line.IsNarration && SpeakerActors.TryGetValue(line.Speaker, out var id) ? id : null;
        var speaking = speaker == null ? null : set.Actors.FirstOrDefault(a => a.Name.ToString() == speaker && a.Visible);
        if (speaker != null)
        {
            Check($"{tag}: {speaker} is on the set", speaking != null);
            if (speaking != null) CheckInFrame(set.Camera, speaking, tag);
        }

        if (set.Stage.Skirt is { } skirt && set.Stage.Cutaway is { Map: { } map } cutaway)
        {
            var hidden = CutawaySight.Hidden(skirt, map, set.Stage.HeightMap.HeightScale, set.Stage.HeightMap,
                standing.Select(a => (a.Name.ToString(), new PF2eVec(a.Tile.X, a.Tile.Y))),
                set.Camera.GlobalPosition, cutaway.CameraQuadrant, SightHeight, WallHeightUnits);
            foreach (var b in hidden) GD.Print($"  {tag}: a wall hides {b.Unit} at ({b.Tile.x},{b.Tile.y})");
            if (speaking is { IsWalking: false })
                Check($"{tag}: no wall hides the speaker {speaker}", hidden.All(b => b.Unit != speaker));
        }
        if (!Headless && (first || line.StageCues.Any(c => c is ShotCue)))
            SaveViewportCapture(ShotDirectory.PathJoin(capture));
    }

    /// <summary>The actor's chest projects inside the viewport, above the dialogue box.</summary>
    private void CheckInFrame(Camera3D camera, CutsceneActor actor, string tag)
    {
        var chest = actor.GlobalPosition + Vector3.Up * SightHeight;
        var size = GetViewport().GetVisibleRect().Size;
        var screen = camera.UnprojectPosition(chest);
        bool inFrame = !camera.IsPositionBehind(chest) && screen.X >= 0f && screen.X <= size.X
            && screen.Y >= 0f && screen.Y <= size.Y * DialogueBoxTop;
        Check($"{tag}: {actor.Name} shows above the dialogue box at ({screen.X:0}, {screen.Y:0})", inFrame);
    }

    /// <summary>After a case: the next encounter prepares on the combat board, which takes the
    /// camera, the sprite tint and the cutaway back.</summary>
    private async Task CheckEncounterAfter(PrologueDirector director, PrologueEncounterRunner runner, int encounter)
    {
        await runner.Prepare(encounter);
        var scene = runner.Scene;
        Check($"Encounter {encounter} prepares after the set", scene != null);
        if (scene == null) return;
        var camera = GetViewport().GetCamera3D();
        Check($"Encounter {encounter}: the combat camera is current", camera != null && scene.IsAncestorOf(camera));
        var stage = scene.GetNode<TerrainStage>("%TerrainStage");
        Check($"Encounter {encounter}: the combat board is built", stage.Layout != null && stage.Look?.HaloOn == true);
        Check($"Encounter {encounter}: the combat look owns the sprite tint", LookScene.ActiveSpriteTint == stage.Look?.SpriteTint);
        Check($"Encounter {encounter}: the cutaway is on for the combat board", stage.Cutaway is { CameraQuadrant: >= 0 });
        if (!Headless)
        {
            director.Fade.SetOpaque(false);
            await WaitSeconds(1.5f);
            SaveViewportCapture(ShotDirectory.PathJoin($"cutscene_e{encounter}_after.png"));
            director.Fade.SetOpaque(true);
        }
        runner.Release(encounter);
    }

    private async Task CaptureAfter(float seconds, string file)
    {
        await WaitSeconds(seconds);
        SaveViewportCapture(ShotDirectory.PathJoin(file));
    }
}
