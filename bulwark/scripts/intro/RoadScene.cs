using Bulwark.Autoload;
using Bulwark.Dialogue;
using Godot;

namespace Bulwark.Intro;

/// <summary>
/// Intro Scene 0 host: the road / river-ford approach. Plays intro_scene_0 (whose JSON carries its own
/// fade-in and ends on a fade-out), sets the scene-0 story flag, then routes on to the homestead exterior
/// scene under black. The Continue router only sends us here while scene 0 is unplayed
/// (<see cref="SceneRouter.ResumeRoute"/>), so there is no resume branch — this scene always plays scene
/// 0. All cutscene plumbing (dialogue box, director, fade overlay, actor lookup) lives in the reusable
/// <see cref="CutsceneHostScene"/> base.
/// </summary>
public partial class RoadScene : CutsceneHostScene
{
    protected override void OnHostReady()
    {
        // The overlay starts black and scene 0's JSON owns its fade-in — play straight in with no competing
        // host fade. A missing/empty intro_scene_0 (F6/headless) completes immediately and routes on.
        PlaySequence("intro_scene_0", OnScene0Complete);
    }

    private void OnScene0Complete()
    {
        GameState.Instance?.SetStoryFlag("intro_scene_0");
        // Scene 0's JSON already faded to black at its end. Stay black and hand off to the homestead
        // exterior host, whose fade overlay also starts opaque so scene 1a's JSON fade-in makes the reveal
        // — the hand-off is black end to end, so no fade here.
        SceneRouter.Instance?.GoToHomesteadExterior();
    }
}
