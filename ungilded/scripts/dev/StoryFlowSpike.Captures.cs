using System;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Story;

namespace Ungilded.Dev;

public partial class StoryFlowSpike
{
    /// <summary>Seconds a screen settles before a capture.</summary>
    [Export] public float CaptureSettleSeconds { get; set; } = 0.5f;

    private async Task SaveCaptures()
    {
        var title = TitleScene!.Instantiate<Control>();
        AddChild(title);
        await WaitSeconds(CaptureSettleSeconds);
        Capture("title.png");
        title.QueueFree();

        var director = PrologueScene!.Instantiate<PrologueDirector>();
        director.AutoStart = false;
        AddChild(director);

        var intro = Sequences.First(s => s.Backdrop == DialogueBackdrop.Black && IsNarrationOnly(s));
        var narration = director.Narration.Play(intro);
        await WaitUntil(() => director.Narration.IsWaiting);
        await WaitSeconds(CaptureSettleSeconds);
        Capture("narration.png");
        while (!narration.IsCompleted)
        {
            director.Narration.Advance();
            await NextFrame();
        }

        var banter = SequenceOf("tutorial_scene1_sewer_banter");
        director.Fade.SetOpaque(true);
        await ShowLineAndCapture(director, banter, line => line.IsNarration, "dialogue_narration.png");
        await ShowLineAndCapture(director, banter, line => line.Speaker == "The Player", "dialogue_black.png");

        var board = BoardScene!.Instantiate();
        AddChild(board);
        MoveChild(board, 0);
        await WaitSeconds(BoardSettleSeconds);
        director.Fade.SetOpaque(false);
        await ShowLineAndCapture(director, SequenceOf("tutorial_scene2_rat_encounter"),
            line => line.Speaker == "The Friend", "dialogue_board.png");

        var popup = director.Popup;
        var message = popup.ShowMessage($"Each turn you have {popup.Highlight("3 actions")}. Every action you take in combat (moving, striking, raising a shield) costs 1 or more actions. Spend them wisely.");
        await WaitSeconds(CaptureSettleSeconds);
        Capture("popup.png");
        popup.Dismiss();
        await message;
        director.QueueFree();
        board.QueueFree();
        await NextFrame();
    }

    /// <summary>Play <paramref name="sequence"/> up to the first line that matches, reveal it fully,
    /// capture, then advance through the rest.</summary>
    private async Task ShowLineAndCapture(PrologueDirector director, DialogueSequence sequence,
        Func<DialogueLine, bool> pick, string file)
    {
        var box = director.Dialogue;
        var play = box.Play(sequence);
        await NextFrame();
        while (box.CurrentLine != null && !pick(box.CurrentLine))
        {
            box.Advance();
            if (box.IsRevealing) box.Advance();
            await NextFrame();
        }
        if (box.IsRevealing) box.Advance();
        await WaitSeconds(CaptureSettleSeconds);
        Check($"{file}: the box shows the chosen line", box.CurrentLine != null && pick(box.CurrentLine));
        Capture(file);
        while (!play.IsCompleted)
        {
            box.Advance();
            await NextFrame();
        }
    }

    private void Capture(string file)
    {
        string path = ShotDirectory.PathJoin(file);
        Check($"{file} saved", SaveViewportCapture(path, ShotSize) == Error.Ok);
    }

    private DialogueSequence SequenceOf(string id) => Sequences.First(s => s.Id == id);

    private static bool IsNarrationOnly(DialogueSequence sequence) => sequence.Lines.All(l => l.IsNarration);

    private async Task WaitUntil(Func<bool> done)
    {
        for (float waited = 0; !done() && waited < RunTimeoutSeconds; waited += (float)GetProcessDeltaTime())
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
