using Bulwark.Autoload;
using Bulwark.Dialogue;
using Godot;

namespace Bulwark.Intro;

/// <summary>
/// Intro Scene 1b host: the homestead INTERIOR — the hearth beat onward, where Fenwick lights the grate
/// with a cantrip and the talk turns to the empty roads and the post ahead. Plays intro_scene_1b (whose
/// JSON enter-stages the actors just inside the door at %MarkDoorInside, cuts the camera to the room,
/// reveals with its own fade-in, and ends on a fade-out), sets the scene-1 story flag — the SAME flag the
/// single homestead scene used to set, so downstream gating (the outpost's pending Scene 2) is untouched —
/// then routes on to the outpost.
///
/// The fade overlay starts opaque so the hand-off from the exterior host stays black end to end until
/// scene 1b's JSON fade-in. All cutscene plumbing lives in the reusable <see cref="CutsceneHostScene"/>
/// base.
/// </summary>
public partial class HomesteadInteriorScene : CutsceneHostScene
{
    protected override void OnHostReady()
    {
        // Overlay starts black; scene 1b's JSON owns its fade-in (enter-stage the actors at the door mark,
        // cut the camera to the room, then fade in). Play straight in. A missing/empty intro_scene_1b
        // (F6/headless) completes immediately and routes on under black.
        PlaySequence("intro_scene_1b", OnScene1bComplete);
    }

    private void OnScene1bComplete()
    {
        // The scene-1 flag stays on the interior (last) half so the two split scenes preserve the original
        // single-checkpoint contract: intro_scene_1 means "both homestead cutscenes done".
        GameState.Instance?.SetStoryFlag("intro_scene_1");
        // Scene 1b's JSON already faded to black at its end; fade defensively and hand off to the outpost,
        // where a still-pending scene 2 triggers.
        FadeTo(1f, 1.0f, () => SceneRouter.Instance?.GoToOutpost());
    }
}
