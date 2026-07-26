using Bulwark.Autoload;
using Bulwark.Dialogue;
using Godot;

namespace Bulwark.Intro;

/// <summary>
/// Intro Scene 1a host: the abandoned homestead's EXTERIOR — the ford, yard, and camp beats, ending when
/// the squad decides to go inside. Plays intro_scene_1a (whose JSON stages the actors at the ford marks,
/// cuts the camera to the homestead behind black, reveals with its own fade-in, walks them to %MarkDoor
/// where they vanish inside, and ends on a fade-out), sets the scene-1a story flag idempotently, then
/// routes on to the homestead interior — mirroring how the road scene closes out scene 0.
///
/// The fade overlay starts opaque so the hand-off from the road scene stays black end to end until scene
/// 1a's JSON fade-in. All cutscene plumbing lives in the reusable <see cref="CutsceneHostScene"/> base.
/// </summary>
public partial class HomesteadExteriorScene : CutsceneHostScene
{
    protected override void OnHostReady()
    {
        // Overlay starts black; scene 1a's JSON owns its fade-in (its first steps run behind black —
        // teleport the actors to the ford marks, cut the camera to the homestead, then fade in). Play
        // straight in. A missing/empty intro_scene_1a (F6/headless) completes immediately and routes on
        // under black.
        PlaySequence("intro_scene_1a", OnScene1aComplete);
    }

    private void OnScene1aComplete()
    {
        GameState.Instance?.SetStoryFlag("intro_scene_1a");
        // Scene 1a's JSON already faded to black at its end; fade to black defensively (a no-op when
        // already opaque, and the reveal-cover when the sequence never ran) and hand off to the interior
        // host, whose fade overlay also starts opaque so scene 1b's JSON fade-in makes the reveal.
        FadeTo(1f, 1.0f, () => SceneRouter.Instance?.GoToHomesteadInterior());
    }
}
