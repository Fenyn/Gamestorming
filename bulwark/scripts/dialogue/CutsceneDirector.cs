using System;
using System.Collections.Generic;
using Bulwark.Data.Dialogues;
using Godot;

namespace Bulwark.Dialogue;

/// <summary>
/// Godot Node that executes staging commands emitted by <see cref="DialogueRunner.StageCommand"/>
/// against a 3D world (1 cell = 1 m). Fade and wait use tweens/timers; <c>camera</c> pans the active
/// <see cref="Camera3D"/> and <c>sfx</c> plays a one-shot sound; <c>move</c>/<c>exit</c> walk an actor
/// across the ground plane to a marker (exit then hides it), <c>face</c> turns one instantly, and
/// <c>emote</c> remains a log-and-continue placeholder. Every command signals completion back to the
/// runner, and every command degrades to a <see cref="GD.Print"/> log plus an immediate completion when
/// its actor or marker cannot be resolved — a headless/F6 run never stalls.
///
/// The <c>enter</c> command stages a REAL actor when the host supplies an actor lookup via
/// <see cref="PrepareStaging"/> (the outpost hands one that resolves an id to its spawned resident
/// NPC): the staged actors are hidden up front, and each <c>enter</c> reveals its actor at its home
/// marker and plays a short walk-in tween. Without a lookup — or when the actor isn't placed (an F6
/// or headless spike run has no <see cref="Bulwark.Cozy.VillagerLoader"/>) — <c>enter</c> degrades to
/// the old log-and-continue with no crash. Every command signals completion back to the runner via
/// <see cref="DialogueRunner.StagingComplete"/>.
///
/// UNITS. The dialogue JSON is authored in the old top-down PIXEL space (48 px per tile) and is never
/// edited for the 3D port, so this class converts on the way in: a marker's authored offsets became
/// metres when the sets were rebuilt (px / 48), and a step's <c>speed</c> is divided by
/// <see cref="PixelsPerMetre"/> here — the 90 px/s default walk becomes 1.875 m/s, an authored 120
/// becomes 2.5 m/s, and the relative pace the writer intended is preserved exactly.
/// </summary>
public partial class CutsceneDirector : Node
{
    /// <summary>Pixels per metre in the authored dialogue data: the old top-down sets were 48 px tiles
    /// and the 3D contract is 1 cell = 1 m, so every authored <c>speed</c> divides by this.</summary>
    public const float PixelsPerMetre = 48f;

    /// <summary>Duration (s) of the modest walk-in tween a markerless <c>enter</c> step plays.</summary>
    private const float EnterWalkSeconds = 0.6f;

    /// <summary>Offset from the home marker an entering actor starts at, then walks in from. In 2D this
    /// was one tile BELOW the mark (+64 px on Y) so the puppet rose into place; rising out of the ground
    /// reads wrong in 3D, so the same "one tile toward the viewer" becomes +1.3 m on Z — the actor walks
    /// up to its mark from the camera-near side, playing its walk cycle. The JSON <c>enter</c> step
    /// carries no position/direction data, so a fixed offset is used.</summary>
    private static readonly Vector3 EnterOffset = new(0f, 0f, 1.3f);

    /// <summary>Default seconds a <c>camera</c> pan (to a target or back home) tweens over.</summary>
    private const float CameraPanSeconds = 1.0f;

    /// <summary>Default walk speed a <c>move</c>/<c>exit</c> step uses when none is given: the authored
    /// 90 px/s over <see cref="PixelsPerMetre"/> = 1.875 m/s.</summary>
    private const float MoveSpeedDefault = 90f / PixelsPerMetre;

    /// <summary>Distance (m) below which a walk settles instantly instead of tweening — the metric twin
    /// of the old half-pixel threshold (0.5 px / 48 ≈ 0.01 m), rounded to 1 cm.</summary>
    private const float ArriveEpsilon = 0.01f;

    private DialogueRunner? _runner;
    private ColorRect? _fadeOverlay;

    /// <summary>The camera a <c>camera</c> step is currently panning, its pre-pan world position (home)
    /// and local transform, and whether it was top-level — recorded on the first pan-away and restored
    /// when a return step (or the sequence ending) brings it back, so a cutscene never leaves the camera
    /// parked off the player. Top-level is forced ON for the duration: it detaches the camera from any
    /// follow arm it hangs off (the outpost avatar's pitched %CameraPivot) so the tween drives the frame
    /// precisely — the 3D counterpart of the Camera2D smoothing suspend.</summary>
    private Camera3D? _pannedCamera;
    private Vector3? _cameraHome;
    private Transform3D _cameraLocalWas;
    private bool _cameraTopLevelWas;

    /// <summary>Resolves an actor id to its spawned world node (set per-play by <see cref="PrepareStaging"/>).
    /// Null for plays that don't stage against real NPCs (talk pools, the road scenes, headless spikes).</summary>
    private Func<string, Node3D?>? _actorLookup;

    /// <summary>Actors this play hides up front (via <see cref="PrepareStaging"/>) and reveals on their
    /// <c>enter</c> step: id → (node, home marker position). Restored (shown, returned home) when the
    /// sequence ends — a safety net for a play that hides an actor but never reaches its enter.</summary>
    private readonly Dictionary<string, (Node3D Node, Vector3 Home)> _staged = new();

    /// <summary>
    /// Pre-stage a sequence against real actor instances before it starts: record and hide every actor
    /// named by a top-level <c>enter</c> step (resolved through <paramref name="actorLookup"/>), so it
    /// is absent until its enter reveals it. Call BEFORE <see cref="Bind"/>/Start. A null lookup, or an
    /// actor the lookup can't resolve, stages nothing for that actor — the sequence then degrades to
    /// log-and-continue on its enter step.
    /// </summary>
    public void PrepareStaging(IEnumerable<DialogueStep>? steps, Func<string, Node3D?>? actorLookup)
    {
        RestoreStaged(); // drop any leftover from a prior play before staging this one
        _actorLookup = actorLookup;
        if (steps == null)
            return;

        foreach (var step in steps)
        {
            if (step.Type != "enter" || string.IsNullOrEmpty(step.Actor) || _staged.ContainsKey(step.Actor))
                continue;

            Node3D? node = _actorLookup?.Invoke(step.Actor);
            if (node == null || !GodotObject.IsInstanceValid(node))
                continue;

            _staged[step.Actor] = (node, node.GlobalPosition);
            node.Visible = false; // hidden until its enter step reveals it
        }
    }

    /// <summary>Bind the director to a runner so it can signal staging completion.</summary>
    public void Bind(DialogueRunner runner)
    {
        if (_runner != null)
        {
            _runner.StageCommand -= OnStageCommand;
            _runner.SequenceEnded -= OnSequenceEnded;
        }

        _runner = runner;
        _runner.StageCommand += OnStageCommand;
        _runner.SequenceEnded += OnSequenceEnded;
    }

    /// <summary>Unbind from the current runner.</summary>
    public void Unbind()
    {
        if (_runner != null)
        {
            _runner.StageCommand -= OnStageCommand;
            _runner.SequenceEnded -= OnSequenceEnded;
        }
        _runner = null;
    }

    /// <summary>Sequence finished: reveal and re-home any actor still staged (the normal path already
    /// revealed them on their enter step, so this is an idempotent safety net for an aborted play), and
    /// snap the camera back home if a pan was left hanging (a sequence that panned but never returned).</summary>
    private void OnSequenceEnded()
    {
        RestoreStaged();
        RestoreCameraHomeImmediate();
    }

    private void OnStageCommand(DialogueStep step)
    {
        switch (step.Type)
        {
            case "fade":
                ExecuteFade(step);
                break;

            case "wait":
                ExecuteWait(step);
                break;

            case "enter":
                ExecuteEnter(step);
                break;

            case "exit":
                ExecuteExit(step);
                break;

            case "move":
                ExecuteMove(step);
                break;

            case "face":
                ExecuteFace(step);
                break;

            case "camera":
                ExecuteCamera(step);
                break;

            case "sfx":
                ExecuteSfx(step);
                break;

            case "prop":
                ExecuteProp(step);
                break;

            case "emote":
                GD.Print($"[CutsceneDirector] Emote: actor={step.Actor}, emotion={step.Emotion}");
                _runner?.StagingComplete();
                break;

            default:
                GD.PushWarning($"[CutsceneDirector] Unknown staging command: {step.Type}");
                _runner?.StagingComplete();
                break;
        }
    }

    /// <summary>Reveal an entering actor. With a <c>marker</c>, snap it to the resolved marker and show
    /// it, completing immediately — no walk-in tween (a following <c>move</c> step does the walking).
    /// Without a marker, reveal it one step toward the viewer (<see cref="EnterOffset"/>) and walk it up
    /// to its home mark (the outpost relies on this). When no real instance was staged for the actor (no
    /// lookup, or the NPC isn't placed — F6/headless), falls back to the log-and-continue.</summary>
    private void ExecuteEnter(DialogueStep step)
    {
        if (string.IsNullOrEmpty(step.Actor)
            || !_staged.TryGetValue(step.Actor, out var staged)
            || !GodotObject.IsInstanceValid(staged.Node))
        {
            GD.Print($"[CutsceneDirector] Enter: actor={step.Actor}, marker={step.Marker} (no staged instance — log only)");
            _runner?.StagingComplete();
            return;
        }

        Node3D node = staged.Node;

        // Marker-carrying enter: place at the marker (or home if it won't resolve) and reveal, no walk-in.
        if (!string.IsNullOrEmpty(step.Marker))
        {
            Node3D? marker = ResolveSceneNode(step.Marker);
            node.GlobalPosition = marker != null && GodotObject.IsInstanceValid(marker)
                ? marker.GlobalPosition
                : staged.Home;
            node.Visible = true;
            _runner?.StagingComplete();
            return;
        }

        // No marker: reveal one step toward the viewer and walk up to the home mark, walk cycle running.
        var puppet = node as CutsceneActor;
        node.GlobalPosition = staged.Home + EnterOffset;
        node.Visible = true;
        puppet?.SetFacing(CutsceneFacing.North);
        puppet?.StartWalk();

        var tween = CreateTween();
        tween.TweenProperty(node, "global_position", staged.Home, EnterWalkSeconds);
        tween.Finished += () =>
        {
            puppet?.StopWalk();
            _runner?.StagingComplete();
        };
    }

    /// <summary>Walk an actor to a marker at the step's speed (default <see cref="MoveSpeedDefault"/>),
    /// playing the walk animation en route and facing the dominant travel direction. Degrades to a log +
    /// immediate completion when the actor or marker cannot be resolved.</summary>
    private void ExecuteMove(DialogueStep step)
    {
        Node3D? actor = ResolveActor(step.Actor);
        Node3D? marker = ResolveMarker(step.Marker);
        if (actor == null || marker == null)
        {
            GD.Print($"[CutsceneDirector] Move: actor={step.Actor}, marker={step.Marker} (unresolved — log only)");
            _runner?.StagingComplete();
            return;
        }

        WalkTo(actor, marker.GlobalPosition, StepSpeed(step), hideOnArrival: false);
    }

    /// <summary>Same walk as <see cref="ExecuteMove"/>, then hides the actor on arrival (a walk-off exit).
    /// Degrades to a log + immediate completion when the actor or marker cannot be resolved.</summary>
    private void ExecuteExit(DialogueStep step)
    {
        Node3D? actor = ResolveActor(step.Actor);
        Node3D? marker = ResolveMarker(step.Marker);
        if (actor == null || marker == null)
        {
            GD.Print($"[CutsceneDirector] Exit: actor={step.Actor}, marker={step.Marker} (unresolved — log only)");
            _runner?.StagingComplete();
            return;
        }

        WalkTo(actor, marker.GlobalPosition, StepSpeed(step), hideOnArrival: true);
    }

    /// <summary>A step's authored walk speed in metres per second: the JSON carries the old px/s figure,
    /// so divide by <see cref="PixelsPerMetre"/>. Missing speed falls back to the metric default.</summary>
    private static float StepSpeed(DialogueStep step)
        => step.Speed is { } px ? px / PixelsPerMetre : MoveSpeedDefault;

    /// <summary>Instantly turn a <see cref="CutsceneActor"/> to face a cardinal direction, then complete.
    /// A plain (non-puppet) actor or an unresolvable one just logs. Never stalls.</summary>
    private void ExecuteFace(DialogueStep step)
    {
        if (ResolveActor(step.Actor) is CutsceneActor puppet
            && CutsceneActor.TryParseFacing(step.Direction, out CutsceneFacing facing))
        {
            puppet.SetFacing(facing);
        }
        else
        {
            GD.Print($"[CutsceneDirector] Face: actor={step.Actor}, direction={step.Direction} (no puppet to turn — log only)");
        }
        _runner?.StagingComplete();
    }

    /// <summary>Tween an actor's global position to <paramref name="dest"/> at <paramref name="speed"/>
    /// m/s (duration = distance/speed), auto-facing the dominant travel direction on the ground plane and
    /// playing the walk cycle (if it is a <see cref="CutsceneActor"/>) for the duration. Returns to the
    /// stand frame on arrival, optionally hiding the actor, and signals staging completion. A
    /// zero-distance or non-positive speed settles instantly rather than dividing by zero.</summary>
    private void WalkTo(Node3D actor, Vector3 dest, float speed, bool hideOnArrival)
    {
        var puppet = actor as CutsceneActor;
        Vector3 delta = dest - actor.GlobalPosition;
        float distance = delta.Length();

        if (puppet != null && distance > 0.001f)
            puppet.SetFacing(DominantFacing(delta));

        if (distance < ArriveEpsilon || speed <= 0f)
        {
            actor.GlobalPosition = dest;
            puppet?.StopWalk();
            if (hideOnArrival)
                actor.Visible = false;
            _runner?.StagingComplete();
            return;
        }

        puppet?.StartWalk();
        var tween = CreateTween();
        tween.TweenProperty(actor, "global_position", dest, distance / speed);
        tween.Finished += () =>
        {
            puppet?.StopWalk();
            if (hideOnArrival)
                actor.Visible = false;
            _runner?.StagingComplete();
        };
    }

    /// <summary>The cardinal direction a ground-plane travel vector points most strongly along (ties to
    /// the X axis). The cozy camera looks down -Z, so +Z is South (toward the viewer) and +X is East —
    /// the same screen reading the old 2D X/Y mapping had.</summary>
    private static CutsceneFacing DominantFacing(Vector3 delta)
    {
        if (Mathf.Abs(delta.X) >= Mathf.Abs(delta.Z))
            return delta.X >= 0f ? CutsceneFacing.East : CutsceneFacing.West;
        return delta.Z >= 0f ? CutsceneFacing.South : CutsceneFacing.North;
    }

    /// <summary>Resolve an actor id to its world node: the staging lookup first (dialogue ids like
    /// "player"/"fenwick"), then a scene node by name (mirrors how camera targets resolve). Null when
    /// the id is empty or nothing valid resolves.</summary>
    private Node3D? ResolveActor(string? id)
    {
        if (string.IsNullOrEmpty(id))
            return null;
        Node3D? actor = _actorLookup?.Invoke(id);
        if (actor != null && GodotObject.IsInstanceValid(actor))
            return actor;
        Node3D? scene = ResolveSceneNode(id);
        return scene != null && GodotObject.IsInstanceValid(scene) ? scene : null;
    }

    /// <summary>Resolve a marker name to its scene node (a <c>%UniqueName</c> Marker3D or a child by name),
    /// or null when the name is empty or nothing valid resolves.</summary>
    private Node3D? ResolveMarker(string? name)
    {
        if (string.IsNullOrEmpty(name))
            return null;
        Node3D? node = ResolveSceneNode(name);
        return node != null && GodotObject.IsInstanceValid(node) ? node : null;
    }

    /// <summary>Show every staged actor and return it to its home marker, then clear the staging set.
    /// Idempotent — safe to call when nothing is staged.</summary>
    private void RestoreStaged()
    {
        foreach (var (_, staged) in _staged)
        {
            if (!GodotObject.IsInstanceValid(staged.Node))
                continue;
            staged.Node.Visible = true;
            staged.Node.GlobalPosition = staged.Home;
        }
        _staged.Clear();
    }

    /// <summary>Toggle a staged prop's visibility. Resolve the node named by the step's <c>marker</c>
    /// (a <c>%UniqueName</c> or direct child) through <see cref="ResolveSceneNode"/>, then reveal it on
    /// <c>direction</c>="on" (Visible = true) or hide it on "off" (Visible = false), completing
    /// immediately. Reveals Scene 1b's lit hearth (%HearthFire — an emissive grate plus its OmniLight3D)
    /// and switches on the dusk key light (%EveningTint) — both hidden-by-default Node3Ds in the
    /// homestead sets; 3D visibility propagates to children, so one toggle carries the whole group. An
    /// unresolvable node, or a missing/unrecognised direction, degrades to a <see cref="GD.Print"/> log +
    /// immediate completion so a headless/F6 run never stalls.</summary>
    private void ExecuteProp(DialogueStep step)
    {
        Node3D? node = ResolveMarker(step.Marker);
        bool on = step.Direction == "on";
        bool off = step.Direction == "off";
        if (node == null || (!on && !off))
        {
            GD.Print($"[CutsceneDirector] Prop: marker={step.Marker}, direction={step.Direction} (unresolved node or bad direction — log only)");
            _runner?.StagingComplete();
            return;
        }

        node.Visible = on;
        _runner?.StagingComplete();
    }

    private void ExecuteFade(DialogueStep step)
    {
        float duration = step.Duration ?? 0.5f;
        bool fadeOut = step.Direction == "out";

        EnsureFadeOverlay();
        if (_fadeOverlay == null)
        {
            _runner?.StagingComplete();
            return;
        }

        float fromAlpha = fadeOut ? 0f : 1f;
        float toAlpha = fadeOut ? 1f : 0f;
        _fadeOverlay.Modulate = new Color(0, 0, 0, fromAlpha);
        _fadeOverlay.Visible = true;

        var tween = CreateTween();
        tween.TweenProperty(_fadeOverlay, "modulate:a", toAlpha, duration);
        tween.Finished += () =>
        {
            if (!fadeOut)
                _fadeOverlay.Visible = false;
            _runner?.StagingComplete();
        };
    }

    private void ExecuteWait(DialogueStep step)
    {
        float seconds = step.Seconds ?? 0.5f;
        GetTree().CreateTimer(seconds).Timeout += () => _runner?.StagingComplete();
    }

    /// <summary>
    /// Pan the active <see cref="Camera3D"/> to a named target, then hold. The target is an <c>actor</c>
    /// (resolved through the staging lookup, then by scene node name) or a <c>marker</c> (a scene node —
    /// a <c>%UniqueName</c> Marker3D or a direct child by name, e.g. a placed building instance). A step
    /// with no target — or <c>marker</c> = "return"/"player"/"back" — pans back to where the camera
    /// started.
    ///
    /// The pan slides the camera across the ground plane ONLY: height and orientation are untouched, and
    /// the destination is chosen so the target lands where the camera currently looks (see
    /// <see cref="GroundPanDestination"/>), which keeps the pitched cozy framing intact for the whole
    /// move. The camera is made top-level for the duration so a follow arm cannot drag the tween, and its
    /// original parenting/local transform is restored on the return (or when the sequence ends). Degrades
    /// to an immediate completion when no active camera exists (headless/F6) or a target can't be
    /// resolved to pan to.
    /// </summary>
    private void ExecuteCamera(DialogueStep step)
    {
        Camera3D? cam = GetViewport()?.GetCamera3D();
        if (cam == null || !GodotObject.IsInstanceValid(cam))
        {
            GD.Print($"[CutsceneDirector] Camera: no active camera — log only (marker={step.Marker}, actor={step.Actor}).");
            _runner?.StagingComplete();
            return;
        }

        float duration = step.Duration ?? CameraPanSeconds;
        Node3D? target = ResolveCameraTarget(step);

        if (target == null)
        {
            // Return-to-home (explicit "return"/no target). If nothing was panned, this is a no-op.
            if (_cameraHome is not { } home || !GodotObject.IsInstanceValid(_pannedCamera))
            {
                _runner?.StagingComplete();
                return;
            }

            var back = CreateTween();
            back.TweenProperty(cam, "global_position", home, duration).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
            back.Finished += () =>
            {
                RestoreCameraHomeImmediate();
                _runner?.StagingComplete();
            };
            return;
        }

        // First pan-away this sequence: record home + detach from any follow arm so we can restore both.
        if (_cameraHome == null)
        {
            _pannedCamera = cam;
            _cameraHome = cam.GlobalPosition;
            _cameraLocalWas = cam.Transform;
            _cameraTopLevelWas = cam.TopLevel;
            Transform3D worldWas = cam.GlobalTransform;
            cam.TopLevel = true;          // reinterprets the local transform as global — put it back:
            cam.GlobalTransform = worldWas;
        }

        var tween = CreateTween();
        tween.TweenProperty(cam, "global_position", GroundPanDestination(cam, target.GlobalPosition), duration)
             .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        tween.Finished += () => _runner?.StagingComplete();
    }

    /// <summary>Where a pitched camera must stand for <paramref name="target"/> to sit under its view
    /// centre, moving on the ground plane only. Traces the camera's current forward ray down to the
    /// target's height to find the point it frames now, then shifts the camera by the XZ difference —
    /// height, pitch and yaw all survive the pan. A camera that is level or looking up has no ground
    /// intersection, so it just matches the target's XZ.</summary>
    private static Vector3 GroundPanDestination(Camera3D cam, Vector3 target)
    {
        Vector3 pos = cam.GlobalPosition;
        Vector3 forward = -cam.GlobalBasis.Z;
        if (forward.Y >= -0.01f)
            return new Vector3(target.X, pos.Y, target.Z);

        Vector3 framed = pos + forward * ((pos.Y - target.Y) / -forward.Y);
        return new Vector3(pos.X + (target.X - framed.X), pos.Y, pos.Z + (target.Z - framed.Z));
    }

    /// <summary>Resolve a <c>camera</c> step's target node: an <c>actor</c> first (staging lookup, then
    /// scene node), else a <c>marker</c> scene node, else null (= pan back home).</summary>
    private Node3D? ResolveCameraTarget(DialogueStep step)
    {
        if (!string.IsNullOrEmpty(step.Actor))
        {
            Node3D? actor = _actorLookup?.Invoke(step.Actor);
            if (actor != null && GodotObject.IsInstanceValid(actor))
                return actor;
            return ResolveSceneNode(step.Actor);
        }

        if (!string.IsNullOrEmpty(step.Marker) && !IsReturnKeyword(step.Marker))
            return ResolveSceneNode(step.Marker);

        return null; // no target => return home
    }

    private static bool IsReturnKeyword(string marker)
        => marker.Equals("return", StringComparison.OrdinalIgnoreCase)
           || marker.Equals("player", StringComparison.OrdinalIgnoreCase)
           || marker.Equals("back", StringComparison.OrdinalIgnoreCase);

    /// <summary>Find a Node3D in the running scene by unique name (<c>%name</c>) or direct child name.
    /// Resolves placed building instances (e.g. "Tavern") and hand-placed markers (e.g. "%Villager_tharr").</summary>
    private Node3D? ResolveSceneNode(string name)
    {
        Node? scene = GetTree()?.CurrentScene;
        if (scene == null)
            return null;
        return scene.GetNodeOrNull<Node3D>($"%{name}") ?? scene.GetNodeOrNull<Node3D>(name);
    }

    /// <summary>Snap the panned camera back home and re-attach it to its original parent transform
    /// immediately (no tween). Safe when nothing was panned. Used as the return tween's tail and the
    /// end-of-sequence safety net.</summary>
    private void RestoreCameraHomeImmediate()
    {
        if (_cameraHome != null && GodotObject.IsInstanceValid(_pannedCamera))
        {
            // Re-attach first, then restore the recorded local pose — which puts the camera back on its
            // follow arm (or back at its authored spot for a scene-owned %CutsceneCamera).
            _pannedCamera!.TopLevel = _cameraTopLevelWas;
            _pannedCamera.Transform = _cameraLocalWas;
        }
        _pannedCamera = null;
        _cameraHome = null;
    }

    /// <summary>Play a one-shot sound loaded from the step's <c>sound</c> path, then continue immediately
    /// (fire-and-forget — the following line carries the beat). A missing/empty/invalid asset degrades to
    /// a warning + immediate completion so an authored-but-not-yet-produced sound never stalls a cutscene.</summary>
    private void ExecuteSfx(DialogueStep step)
    {
        string? path = step.Sound;
        if (string.IsNullOrEmpty(path) || !ResourceLoader.Exists(path) || GD.Load<AudioStream>(path) is not { } stream)
        {
            GD.PushWarning($"[CutsceneDirector] Sfx asset missing or unloadable: {path ?? "(none)"} — skipping.");
            _runner?.StagingComplete();
            return;
        }

        var player = new AudioStreamPlayer { Name = "CutsceneSfx", Stream = stream };
        AddChild(player);
        player.Finished += player.QueueFree;
        player.Play();
        _runner?.StagingComplete();
    }

    /// <summary>Adopt an externally owned fade <see cref="ColorRect"/> so the director's <c>fade</c> steps
    /// drive it instead of creating a private one. A host that manages its own fades (the road scene) hands
    /// over its single overlay, so the JSON fade steps and the host's fades never fight two competing black
    /// rects. Pass an overlay whose current alpha is the scene's starting state (fully black for a JSON
    /// fade-in). Call before the sequence starts.</summary>
    public void AdoptFadeOverlay(ColorRect overlay) => _fadeOverlay = overlay;

    private void EnsureFadeOverlay()
    {
        if (_fadeOverlay != null)
            return;

        _fadeOverlay = new ColorRect
        {
            Name = "FadeOverlay",
            Color = Colors.Black,
            Visible = false,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        _fadeOverlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);

        // A CanvasLayer renders in screen space OVER the 3D viewport, so the same overlay covers a 3D
        // set exactly as it covered the old 2D one. Highest z level.
        var canvas = new CanvasLayer { Name = "FadeCanvas", Layer = 100 };
        AddChild(canvas);
        canvas.AddChild(_fadeOverlay);
    }
}
