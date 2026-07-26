using System;
using Bulwark.Autoload;
using Bulwark.Data.Dialogues;
using Bulwark.UI;
using Godot;

namespace Bulwark.Dialogue;

/// <summary>
/// Reusable base for any Node2D scene that hosts JSON cutscene sequences. Builds the shared plumbing once
/// in <see cref="_Ready"/> — a screen-space <see cref="DialogueBox"/> on a CanvasLayer (layer 50), a
/// <see cref="CutsceneDirector"/>, and a full-screen black fade <see cref="ColorRect"/> on a layer-100
/// CanvasLayer handed to the director via <see cref="CutsceneDirector.AdoptFadeOverlay"/> — then exposes
/// <see cref="PlaySequence"/> for derived scenes to drive their sequence(s).
///
/// The overlay starts FULLY OPAQUE: a derived scene reveals its scene through a JSON <c>fade</c>-in step
/// (the director drives the same rect) or an explicit <see cref="FadeTo"/>. Actor lookup is by CONVENTION
/// — id "elara" resolves the unique node <c>%ActorElara</c> — reusable in any scene; override
/// <see cref="ResolveActor"/> for puppets that do not follow it.
///
/// Null-safe throughout: an F6/headless run with no GameState/DialogueDb, or a scene missing the box
/// scene, degrades to log-and-continue (each PlaySequence completes immediately) rather than crashing.
/// </summary>
public abstract partial class CutsceneHostScene : Node2D
{
    /// <summary>The hosted dialogue box (screen-space, layer 50). Null in a run where the box scene fails
    /// to load — PlaySequence then completes immediately.</summary>
    protected DialogueBox? DialogueBox { get; private set; }

    /// <summary>The cutscene director executing staging commands for the active sequence.</summary>
    protected CutsceneDirector? Director { get; private set; }

    private ColorRect? _fadeOverlay;

    public override void _Ready()
    {
        // One fade overlay, owned by this host and handed to the director so the JSON fade steps and the
        // host's own FadeTo drive the SAME rect (never two competing black rects). It starts fully black
        // so a derived scene reveals through a JSON fade-in or an explicit FadeTo. Top layer (100) so the
        // scene fade covers the dialogue box below it.
        _fadeOverlay = new ColorRect
        {
            Name = "FadeOverlay",
            Color = new Color(0f, 0f, 0f, 1f),
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        _fadeOverlay.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        var fadeLayer = new CanvasLayer { Name = "FadeLayer", Layer = 100 };
        AddChild(fadeLayer);
        fadeLayer.AddChild(_fadeOverlay);

        var boxScene = GD.Load<PackedScene>("res://scenes/ui/dialogue_box.tscn");
        if (boxScene != null)
        {
            // The box is a Control — parent it under a CanvasLayer so it renders in screen space, not
            // through this Node2D host's Camera2D. Below the fade layer (100) so the scene fade still
            // covers the dialogue.
            DialogueBox = boxScene.Instantiate<DialogueBox>();
            var dialogueLayer = new CanvasLayer { Name = "DialogueLayer", Layer = 50 };
            AddChild(dialogueLayer);
            dialogueLayer.AddChild(DialogueBox);
        }

        Director = new CutsceneDirector { Name = "CutsceneDirector" };
        AddChild(Director);
        Director.AdoptFadeOverlay(_fadeOverlay);

        Callable.From(OnHostReady).CallDeferred();
    }

    /// <summary>Called deferred once the host plumbing is built. Derived scenes start their sequence here
    /// — typically a single <see cref="PlaySequence"/>, or a <see cref="FadeTo"/> then PlaySequence.</summary>
    protected abstract void OnHostReady();

    /// <summary>
    /// Look up, stage, and play a dialogue sequence, invoking <paramref name="onComplete"/> when it ends
    /// (or immediately when it cannot run — no GameState/box, an unknown/empty sequence, an F6/headless
    /// run). Pre-stages the sequence against the placed actors via <see cref="CutsceneDirector.PrepareStaging"/>
    /// with the convention <see cref="ResolveActor"/> lookup, builds and binds the runner, marks a
    /// once-sequence seen on completion, then closes the box and completes.
    /// </summary>
    protected void PlaySequence(string sequenceId, Action onComplete)
    {
        var gs = GameState.Instance;
        if (gs == null || DialogueBox == null)
        {
            onComplete();
            return;
        }

        var db = gs.DialogueDb;
        if (db == null || !db.TryGetSequence(sequenceId, out var seq) || seq.Steps == null)
        {
            onComplete();
            return;
        }

        // Pre-stage against the placed actors so each top-level enter reveals its puppet; the lookup maps
        // the dialogue ids to the %Actor* nodes in the hosting scene (null in an F6/headless run with no
        // placed actor => staging degrades to log-and-continue).
        Director?.PrepareStaging(seq.Steps, ResolveActor);

        var handler = new GameStateEffectHandler(gs);
        var runner = new DialogueRunner(seq.Steps, handler, sequenceId, seq.Once);

        DialogueBox.Bind(runner);
        Director?.Bind(runner);

        runner.SequenceEnded += () =>
        {
            if (seq.Once)
                gs.MarkDialogueSeen(sequenceId);
            DialogueBox.Close();
            onComplete();
        };

        runner.Start();
    }

    /// <summary>Map a dialogue actor id to its placed cutscene puppet by CONVENTION: capitalize the first
    /// letter and resolve the unique node <c>%Actor&lt;Id&gt;</c> (e.g. "elara" =&gt; <c>%ActorElara</c>).
    /// Returns null for an empty id or when the node is absent (an F6 run of the base without a scene).
    /// Virtual so a derived scene can override for puppets that do not follow the convention.</summary>
    protected virtual Node2D? ResolveActor(string id)
    {
        if (string.IsNullOrEmpty(id))
            return null;
        string unique = "%Actor" + char.ToUpperInvariant(id[0]) + id.Substring(1);
        return GetNodeOrNull<Node2D>(unique);
    }

    /// <summary>Tween the shared fade overlay to <paramref name="targetAlpha"/> over
    /// <paramref name="duration"/> seconds, then invoke <paramref name="onComplete"/>. Null-safe: with no
    /// overlay (headless) it completes immediately. Use for the fades the JSON does not cover (an explicit
    /// reveal, or a hand-off to the next scene under black).</summary>
    protected void FadeTo(float targetAlpha, float duration, Action onComplete)
    {
        if (_fadeOverlay == null)
        {
            onComplete();
            return;
        }
        var tween = CreateTween();
        tween.TweenProperty(_fadeOverlay, "modulate:a", targetAlpha, duration);
        tween.Finished += onComplete;
    }
}
