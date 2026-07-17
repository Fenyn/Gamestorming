using System;
using System.Collections.Generic;
using Bulwark.Data.Dialogues;
using Godot;

namespace Bulwark.Dialogue;

/// <summary>
/// Godot Node that executes staging commands emitted by <see cref="DialogueRunner.StageCommand"/>.
/// Fade and wait use tweens/timers; <c>camera</c> pans the active Camera2D and <c>sfx</c> plays a
/// one-shot sound; exit/move/emote remain log-and-continue placeholders.
///
/// The <c>enter</c> command stages a REAL actor when the host supplies an actor lookup via
/// <see cref="PrepareStaging"/> (the outpost hands one that resolves an id to its spawned resident
/// NPC): the staged actors are hidden up front, and each <c>enter</c> reveals its actor at its home
/// marker and plays a short walk-in tween. Without a lookup — or when the actor isn't placed (an F6
/// or headless spike run has no <see cref="Bulwark.Cozy.VillagerLoader"/>) — <c>enter</c> degrades to
/// the old log-and-continue with no crash. Every command signals completion back to the runner via
/// <see cref="DialogueRunner.StagingComplete"/>.
/// </summary>
public partial class CutsceneDirector : Node
{
    /// <summary>Duration (s) of the modest walk-in tween an <c>enter</c> step plays.</summary>
    private const float EnterWalkSeconds = 0.6f;

    /// <summary>Offset from the home marker an entering actor starts at, then walks up from — a
    /// modest reveal (~one tile below), not a full pathfinding entrance. The JSON <c>enter</c> step
    /// carries no position/direction data, so a fixed offset is used.</summary>
    private static readonly Vector2 EnterOffset = new(0f, 64f);

    /// <summary>Default seconds a <c>camera</c> pan (to a target or back home) tweens over.</summary>
    private const float CameraPanSeconds = 1.0f;

    private DialogueRunner? _runner;
    private ColorRect? _fadeOverlay;

    /// <summary>The camera a <c>camera</c> step is currently panning, its pre-pan world position (home),
    /// and its original smoothing setting — recorded on the first pan-away and restored when a
    /// return step (or the sequence ending) brings it back, so a cutscene never leaves the camera
    /// parked off the player.</summary>
    private Camera2D? _pannedCamera;
    private Vector2? _cameraHome;
    private bool _cameraSmoothingWas;

    /// <summary>Resolves an actor id to its spawned world node (set per-play by <see cref="PrepareStaging"/>).
    /// Null for plays that don't stage against real NPCs (talk pools, the road scenes, headless spikes).</summary>
    private Func<string, Node2D?>? _actorLookup;

    /// <summary>Actors this play hides up front (via <see cref="PrepareStaging"/>) and reveals on their
    /// <c>enter</c> step: id → (node, home marker position). Restored (shown, returned home) when the
    /// sequence ends — a safety net for a play that hides an actor but never reaches its enter.</summary>
    private readonly Dictionary<string, (Node2D Node, Vector2 Home)> _staged = new();

    /// <summary>
    /// Pre-stage a sequence against real actor instances before it starts: record and hide every actor
    /// named by a top-level <c>enter</c> step (resolved through <paramref name="actorLookup"/>), so it
    /// is absent until its enter reveals it. Call BEFORE <see cref="Bind"/>/Start. A null lookup, or an
    /// actor the lookup can't resolve, stages nothing for that actor — the sequence then degrades to
    /// log-and-continue on its enter step.
    /// </summary>
    public void PrepareStaging(IEnumerable<DialogueStep>? steps, Func<string, Node2D?>? actorLookup)
    {
        RestoreStaged(); // drop any leftover from a prior play before staging this one
        _actorLookup = actorLookup;
        if (steps == null)
            return;

        foreach (var step in steps)
        {
            if (step.Type != "enter" || string.IsNullOrEmpty(step.Actor) || _staged.ContainsKey(step.Actor))
                continue;

            Node2D? node = _actorLookup?.Invoke(step.Actor);
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
                GD.Print($"[CutsceneDirector] Exit: actor={step.Actor}");
                _runner?.StagingComplete();
                break;

            case "move":
                GD.Print($"[CutsceneDirector] Move: actor={step.Actor}, marker={step.Marker}, speed={step.Speed}");
                _runner?.StagingComplete();
                break;

            case "camera":
                ExecuteCamera(step);
                break;

            case "sfx":
                ExecuteSfx(step);
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

    /// <summary>Reveal an entering actor at its home marker and play a short walk-in tween. When no
    /// real instance was staged for the actor (no lookup, or the NPC isn't placed — F6/headless),
    /// falls back to the old log-and-continue.</summary>
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

        Node2D node = staged.Node;
        node.GlobalPosition = staged.Home + EnterOffset;
        node.Visible = true;

        var tween = CreateTween();
        tween.TweenProperty(node, "global_position", staged.Home, EnterWalkSeconds);
        tween.Finished += () => _runner?.StagingComplete();
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
    /// Pan the active Camera2D to a named target, then hold. The target is an <c>actor</c> (resolved
    /// through the staging lookup, then by scene node name) or a <c>marker</c> (a scene node — a
    /// <c>%UniqueName</c> Marker2D or a direct child by name, e.g. a placed building instance). A step
    /// with no target — or <c>marker</c> = "return"/"player"/"back" — pans back to where the camera
    /// started. Smoothing is suspended for the duration so the tween drives the frame precisely, and is
    /// restored on the return (or when the sequence ends). Degrades to an immediate completion when no
    /// active camera exists (headless/F6) or a target can't be resolved to pan to.
    /// </summary>
    private void ExecuteCamera(DialogueStep step)
    {
        Camera2D? cam = GetViewport()?.GetCamera2D();
        if (cam == null || !GodotObject.IsInstanceValid(cam))
        {
            GD.Print($"[CutsceneDirector] Camera: no active camera — log only (marker={step.Marker}, actor={step.Actor}).");
            _runner?.StagingComplete();
            return;
        }

        float duration = step.Duration ?? CameraPanSeconds;
        Node2D? target = ResolveCameraTarget(step);

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

        // First pan-away this sequence: record home + suspend smoothing so we can restore both later.
        if (_cameraHome == null)
        {
            _pannedCamera = cam;
            _cameraHome = cam.GlobalPosition;
            _cameraSmoothingWas = cam.PositionSmoothingEnabled;
            cam.PositionSmoothingEnabled = false;
        }

        var tween = CreateTween();
        tween.TweenProperty(cam, "global_position", target.GlobalPosition, duration).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        tween.Finished += () => _runner?.StagingComplete();
    }

    /// <summary>Resolve a <c>camera</c> step's target node: an <c>actor</c> first (staging lookup, then
    /// scene node), else a <c>marker</c> scene node, else null (= pan back home).</summary>
    private Node2D? ResolveCameraTarget(DialogueStep step)
    {
        if (!string.IsNullOrEmpty(step.Actor))
        {
            Node2D? actor = _actorLookup?.Invoke(step.Actor);
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

    /// <summary>Find a Node2D in the running scene by unique name (<c>%name</c>) or direct child name.
    /// Resolves placed building instances (e.g. "Tavern") and hand-placed markers (e.g. "%Villager_tharr").</summary>
    private Node2D? ResolveSceneNode(string name)
    {
        Node? scene = GetTree()?.CurrentScene;
        if (scene == null)
            return null;
        return scene.GetNodeOrNull<Node2D>($"%{name}") ?? scene.GetNodeOrNull<Node2D>(name);
    }

    /// <summary>Snap the panned camera back home and restore its smoothing immediately (no tween). Safe
    /// when nothing was panned. Used as the return tween's tail and the end-of-sequence safety net.</summary>
    private void RestoreCameraHomeImmediate()
    {
        if (_cameraHome is { } home && GodotObject.IsInstanceValid(_pannedCamera))
        {
            _pannedCamera!.GlobalPosition = home;
            _pannedCamera.PositionSmoothingEnabled = _cameraSmoothingWas;
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

        // Add to the scene tree at the highest z level
        var canvas = new CanvasLayer { Name = "FadeCanvas", Layer = 100 };
        AddChild(canvas);
        canvas.AddChild(_fadeOverlay);
    }
}
