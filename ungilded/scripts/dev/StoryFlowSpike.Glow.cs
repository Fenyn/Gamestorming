using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Combat;
using Ungilded.Story;
using Ungilded.Tutorial.Encounters;

namespace Ungilded.Dev;

/// <summary>
/// Token glow check: Scene 3a's last line, then Encounter 2 prepared with the real runner, then
/// Scene 3b over its board. The Friend's token glows at satchel height when the board shows, at his
/// eyes on line 1 and back at the satchel on line 3; line 5 moves it to the Player at satchel height
/// and line 9 to his eyes. Rendered, it saves lines 1, 5 and 9 over the board.
/// </summary>
public partial class StoryFlowSpike
{
    /// <summary>Scene 3b lines captured over the board when rendered.</summary>
    [Export] public int[] GlowCaptureLines { get; set; } = { 1, 5, 9 };

    /// <summary>Metres above the feet a worn glow may sit at: the heroes' eyes.</summary>
    [Export] public Vector2 EyeHeightRange { get; set; } = new(0.9f, 1.15f);

    /// <summary>Metres a glow may be off its target once its move has settled.</summary>
    [Export] public float GlowHeightTolerance { get; set; } = 0.01f;

    private async Task CheckTokenGlow()
    {
        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        director.TitleScenePath = "";
        AddChild(director);
        if (director.Runner is not PrologueEncounterRunner runner)
        {
            Check("the Prologue uses the real encounter runner", false);
            director.QueueFree();
            return;
        }
        var box = director.Dialogue;
        await PlayThrough(box, SequenceOf(PostEncounter1Id));
        await runner.Prepare(2);
        director.Fade.SetOpaque(false);

        var friend = runner.TokenOf(Friend);
        var player = runner.TokenOf(Player);
        Check("Encounter 2 has both hero tokens", friend != null && player != null);
        if (friend == null || player == null)
        {
            runner.Release(2);
            director.QueueFree();
            return;
        }
        Check($"Scene 3b opens with the Friend's token glow at satchel height ({friend.GlowHeight:0.00} m)",
            friend.GlowLit && IsCarried(friend) && !player.GlowLit);

        var sequence = SequenceOf(RatsAppearId);
        var play = box.Play(sequence);
        int shown = 0;
        while (!play.IsCompleted)
        {
            await NextFrame();
            if (box.CurrentLine is not { } line) continue;
            int index = sequence.Lines.IndexOf(line) + 1;
            if (index != shown)
            {
                shown = index;
                CheckLineGlow(index, friend, player);
                if (!Headless && GlowCaptureLines.Contains(index))
                {
                    if (box.IsRevealing) box.Advance();
                    await WaitSeconds(friend.GlowMoveSeconds + CaptureSettleSeconds);
                    Capture($"glow_3b_{index:00}.png");
                }
            }
            box.Advance();
        }
        await WaitSeconds(player.GlowMoveSeconds + CaptureSettleSeconds);
        Check($"after Scene 3b the Player's glow is at his eyes ({player.GlowShownHeight:0.00} m) and the Friend's is out",
            player.GlowLit && IsWorn(player) && Mathf.Abs(player.GlowShownHeight - player.GlowHeight) <= GlowHeightTolerance
            && !friend.GlowLit);

        runner.Release(2);
        director.QueueFree();
        await NextFrame();
    }

    private void CheckLineGlow(int line, UnitVisual3D friend, UnitVisual3D player)
    {
        switch (line)
        {
            case 1:
                Check($"3b line 1: the Friend's glow rises to his eyes ({friend.GlowHeight:0.00} m)", friend.GlowLit && IsWorn(friend));
                break;
            case 3:
                Check($"3b line 3: the Friend's glow drops to satchel height ({friend.GlowHeight:0.00} m)", friend.GlowLit && IsCarried(friend));
                break;
            case 5:
                Check("3b line 5: the glow moves to the Player at satchel height", !friend.GlowLit && player.GlowLit && IsCarried(player));
                break;
            case 9:
                Check($"3b line 9: the Player's glow rises to his eyes ({player.GlowHeight:0.00} m)", player.GlowLit && IsWorn(player));
                break;
        }
    }

    private static bool IsCarried(UnitVisual3D token) => Mathf.IsEqualApprox(token.GlowHeight, token.CarriedGlowHeight);

    private bool IsWorn(UnitVisual3D token) => token.GlowHeight >= EyeHeightRange.X && token.GlowHeight <= EyeHeightRange.Y;
}
