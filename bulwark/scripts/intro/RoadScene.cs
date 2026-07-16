using System;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data.Dialogues;
using Bulwark.UI;
using Godot;

namespace Bulwark.Intro;

/// <summary>
/// Simple scene for the intro cutscene Scenes 0 and 1. Plays the dialogue sequences over a
/// dark background, then transitions to the outpost. Uses the existing dialogue framework.
/// </summary>
public partial class RoadScene : Node2D
{
    private DialogueBox? _dialogueBox;
    private CutsceneDirector? _director;
    private ColorRect? _fadeOverlay;

    private enum Phase { FadeIn, Scene0, Transition, Scene1, FadeOut, Done }
    private Phase _phase = Phase.FadeIn;

    public override void _Ready()
    {
        var bg = new ColorRect
        {
            Color = new Color(0.05f, 0.05f, 0.08f, 1f),
            AnchorsPreset = (int)Control.LayoutPreset.FullRect,
        };
        var bgLayer = new CanvasLayer { Name = "Background", Layer = -10 };
        AddChild(bgLayer);
        bgLayer.AddChild(bg);

        _fadeOverlay = new ColorRect
        {
            Color = new Color(0f, 0f, 0f, 1f),
            AnchorsPreset = (int)Control.LayoutPreset.FullRect,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        var fadeLayer = new CanvasLayer { Name = "FadeLayer", Layer = 100 };
        AddChild(fadeLayer);
        fadeLayer.AddChild(_fadeOverlay);

        var boxScene = GD.Load<PackedScene>("res://scenes/ui/dialogue_box.tscn");
        if (boxScene != null)
        {
            _dialogueBox = boxScene.Instantiate<DialogueBox>();
            AddChild(_dialogueBox);
        }

        _director = new CutsceneDirector { Name = "CutsceneDirector" };
        AddChild(_director);

        Callable.From(BeginFadeIn).CallDeferred();
    }

    private void BeginFadeIn()
    {
        _phase = Phase.FadeIn;
        FadeTo(0f, 1.0f, OnFadeInComplete);
    }

    private void OnFadeInComplete()
    {
        _phase = Phase.Scene0;
        PlaySequence("intro_scene_0", OnScene0Complete);
    }

    private void OnScene0Complete()
    {
        GameState.Instance?.SetStoryFlag("intro_scene_0");
        _phase = Phase.Transition;
        FadeTo(1f, 0.5f, () =>
        {
            GetTree().CreateTimer(0.3).Timeout += () =>
            {
                FadeTo(0f, 0.5f, OnTransitionComplete);
            };
        });
    }

    private void OnTransitionComplete()
    {
        _phase = Phase.Scene1;
        PlaySequence("intro_scene_1", OnScene1Complete);
    }

    private void OnScene1Complete()
    {
        GameState.Instance?.SetStoryFlag("intro_scene_1");
        _phase = Phase.FadeOut;
        FadeTo(1f, 1.0f, () =>
        {
            _phase = Phase.Done;
            SceneRouter.Instance?.GoToOutpost();
        });
    }

    private void FadeTo(float targetAlpha, float duration, Action onComplete)
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

    private void PlaySequence(string sequenceId, Action onComplete)
    {
        var gs = GameState.Instance;
        if (gs == null || _dialogueBox == null)
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

        var handler = new GameStateEffectHandler(gs);
        var runner = new DialogueRunner(seq.Steps, handler, sequenceId, seq.Once);

        _dialogueBox.Bind(runner);
        _director?.Bind(runner);

        runner.SequenceEnded += () =>
        {
            if (seq.Once)
                gs.MarkDialogueSeen(sequenceId);
            _dialogueBox.Close();
            onComplete();
        };

        runner.Start();
    }
}
