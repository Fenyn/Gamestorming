using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatLogSpike : SpikeBase
{
    [Export] public PackedScene LogScene { get; set; } = null!;
    [Export] public Theme UiTheme { get; set; } = null!;
    [Export] public PackedScene DiceScene { get; set; } = null!;

    protected override async Task RunSpikeAsync(DataManager data)
    {
        var frame = new Control { Size = new Vector2(1920, 1080), Theme = UiTheme };
        AddChild(frame);
        var log = LogScene.Instantiate<CombatLogPanel>();
        frame.AddChild(log);
        Check("empty compact log is hidden", !log.GetNode<Control>("%Shell").Visible);
        log.BeginTurn("Aldric");
        Check("a turn alone does not repeat initiative in the compact log", !log.GetNode<Control>("%Shell").Visible);
        log.SetExpanded(true);
        Check("turn headings remain available in history", log.Rows.All(r => r.Visible));
        log.ClearLog();
        CombatLogSamples.Fill(log);
        await Settle();
        var strike = log.Rows.First(r => r.PlainText.Contains("Longsword"));
        var details = strike.GetNode<RichTextLabel>("%EntryDetails");
        Check("action details start collapsed", !details.Visible);
        Check("roll outcome remains in the compact summary", strike.PlainText.Contains("CRITICAL HIT"));
        string condensed = strike.GetNode<RichTextLabel>("%EntryHeader").GetParsedText();
        Check("compact result includes total and target without die arithmetic", condensed.Contains("29 vs AC 17")
            && !condensed.Contains("19+10") && condensed.Contains("18 slashing damage"));
        var spellSummary = log.Rows.First(r => r.PlainText.Contains("Breathe Fire"))
            .GetNode<RichTextLabel>("%EntryHeader").GetParsedText();
        Check("compact spell retains every target's save and damage outcomes",
            spellSummary.Contains("Hunting Spider fails the save") && spellSummary.Contains("9 fire damage")
            && spellSummary.Contains("Cave Rat saves") && spellSummary.Contains("4 fire damage"));
        strike.GetNode<Button>("%Disclosure").ButtonPressed = true;
        await Settle();
        Check("clicking disclosure expands in place", details.Visible && !log.Expanded);
        Check("expanded entry contains its roll and damage", details.GetParsedText().Contains("19+10 = 29 vs AC 17")
            && details.GetParsedText().Contains("18 slashing damage"));
        Check("details have a blank line between results", details.GetParsedText().Contains("17\n\nHunting Spider"));
        for (int i = 0; i < 6; i++) log.AppendEntry($"Aldric action {i}", 8, false);
        await Settle();
        Check("incoming actions preserve an opened entry", strike.Visible && details.Visible);
        log.SetExpanded(true);
        await Settle();
        Check("sidebar shows the full action history", log.Rows.All(r => r.Visible));
        Check("sidebar preserves disclosure state", details.Visible);
        strike.GetNode<RichTextLabel>("%EntryHeader").EmitSignal(Control.SignalName.GuiInput,
            new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true });
        Check("clicking text also collapses details", !details.Visible);
        for (int i = 0; i < 35; i++) log.AppendEntry($"Hunting Spider uses action {i}", 8, false);
        await Settle();
        var scroll = log.GetNode<ScrollContainer>("%LogScroll");
        scroll.ScrollVertical = 0;
        await Settle();
        log.AppendEntry("Aldric uses a new action", 8, false);
        await Settle();
        Check("new messages do not move a reader away from older history", scroll.ScrollVertical == 0);
        Check("new messages are counted while reading history", log.GetNode<Button>("%Latest").Text.Contains("new"));
        log.JumpToLatest();
        await Settle();
        var bar = scroll.GetVScrollBar();
        Check("latest returns to the bottom", bar.Value >= bar.MaxValue - bar.Page - 2);
        log.AppendEntry("Aldric [color=red]literal[/color]", 0, false);
        Check("engine messages cannot inject markup", log.HistoryText.Contains("[color=red]literal[/color]"));
        log.SetExpanded(false);
        await Settle();
        Check("compact log stays within its height cap", scroll.Size.Y <= log.CompactMaxHeight + 1);
        log.ClearLog();
        Check("encounter reset removes history and disclosure state", log.Rows.Count == 0 && log.EntryCount == 0 && !log.Expanded);
        await DiceAndPacing(frame, log);
        frame.QueueFree();
    }

    private async Task Settle()
    {
        for (int i = 0; i < 10; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

    private async Task DiceAndPacing(Control frame, CombatLogPanel log)
    {
        var dice = DiceScene.Instantiate<DiceRollPanel>();
        frame.AddChild(dice);
        log.RollObserved += dice.ShowRoll;
        Check("the log panel carries no dice toggle", log.GetNodeOrNull("%DiceToggle") == null);
        Check("dice display starts hidden with no roll", !dice.Visible);
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(19)+10=29 vs AC 17 → CriticalSuccess", 2, true);
        Check("the dice display receives the logged roll without any opt-in", dice.Visible);
        var dieLabel = dice.GetNode<Label>("%DieValue");
        var mathLabel = dice.GetNode<RichTextLabel>("%RollMath");
        var outcomeLabel = dice.GetNode<Label>("%RollOutcome");
        await ToSignal(GetTree().CreateTimer(dice.TumbleSeconds * 0.5f), SceneTreeTimer.SignalName.Timeout);
        Check("mid-tumble the face shows a number and the sum and outcome are still withheld",
            dice.Tumbling && int.TryParse(dieLabel.Text, out int face) && face is >= 1 and <= 20
            && mathLabel.GetParsedText() == "" && outcomeLabel.Text == "");
        await ToSignal(GetTree().CreateTimer(dice.SettleSeconds), SceneTreeTimer.SignalName.Timeout);
        Check("the face lands on the rolled value", !dice.Tumbling && dieLabel.Text == "19");
        Check("total and target lead with modifiers below and no repeated die", mathLabel.GetParsedText() == "29 vs 17\nTOTAL / AC\nModifiers +10"
            && Mathf.IsEqualApprox(mathLabel.Modulate.A, 1f) && mathLabel.Scale.IsEqualApprox(Vector2.One));
        Check("total and target share primary size and total is accented",
            mathLabel.Text.Contains($"[font_size={dice.SumFontSize}][b][color=#{UiColors.Accent.ToHtml()}]29")
            && mathLabel.Text.Contains($"[font_size={dice.SumFontSize}][b][color=#{UiColors.Text.ToHtml()}]17")
            && dice.SumFontSize > dice.SumDetailFontSize);
        Check("then the outcome word arrives at full size", outcomeLabel.Text == "CRITICAL HIT"
            && Mathf.IsEqualApprox(outcomeLabel.Modulate.A, 1f) && outcomeLabel.Scale.IsEqualApprox(Vector2.One));
        string shotDirectory = OS.GetEnvironment("DELVE_SHOT_DIRECTORY");
        if (DisplayServer.GetName() != "headless" && !string.IsNullOrEmpty(shotDirectory))
        {
            await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
            using var image = GetViewport().GetTexture().GetImage();
            image.Convert(Image.Format.Rgba8);
            if (GetViewport().UseHdr2D) image.LinearToSrgb();
            DirAccess.MakeDirRecursiveAbsolute(shotDirectory);
            Check("settled dice preview saved", image.SavePng(shotDirectory + "/dice_settled.png") == Error.Ok);
        }
        var details = log.Rows[^1].GetNode<RichTextLabel>("%EntryDetails");
        Check("roll numbers are larger than log text", details.GetParsedText().Contains("29")
            && log.GetThemeConstant("roll_font_size", "CombatLogText") > log.GetThemeFontSize("normal_font_size", "CombatLogText"));
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(3)+10=13 vs AC 17 → Failure", 2, true);
        await dice.WaitForResultsAsync();
        Check("a miss colours its total in the miss tone",
            mathLabel.Text.Contains($"[color=#{UiColors.LogSeverity[3].ToHtml()}]13")
            && outcomeLabel.Text == "MISS");
        dice.ClearRoll();
        Check("clearing the roll hides the popup", !dice.Visible);
        await CheckDiceGate(dice);
        Check("invalid d20 values never animate", CombatRoll.Parse("d20(25)+10=35 vs AC 17 → Success") == null);
        string adjustments = DiceRollPanel.FormatAdjustments(new CombatRoll("", 15, "+10 MAP-5", 18, "AC", 20, "Failure"));
        Check("modifier signs are colored and unreported adjustments reconcile the total",
            adjustments.Contains($"[color=#{UiColors.HpHigh.ToHtml()}]+10")
            && adjustments.Contains($"MAP[color=#{UiColors.HpLow.ToHtml()}]-5")
            && adjustments.Contains($"Other [color=#{UiColors.HpLow.ToHtml()}]-2"));
        using var cancellation = new System.Threading.CancellationTokenSource();
        var cue = new PF2e.Core.BattleEvent { Type = PF2e.Core.BattleEventType.AttackRolled };
        Check("player actions incur no AI pause", Delve.Combat.AiActionPacing.Wait(cue, true, 0.35f, cancellation.Token).IsCompleted);
        cue.Type = PF2e.Core.BattleEventType.MovementStep;
        Check("movement tiles incur no extra pause", Delve.Combat.AiActionPacing.Wait(cue, false, 0.35f, cancellation.Token).IsCompleted);
        cue.Type = PF2e.Core.BattleEventType.AttackRolled;
        var pause = Delve.Combat.AiActionPacing.Wait(cue, false, 0.35f, cancellation.Token);
        Check("AI action cue waits", !pause.IsCompleted);
        cancellation.Cancel();
        try { await pause; Check("AI pause cancels with encounter", false); }
        catch (System.OperationCanceledException) { Check("AI pause cancels with encounter", true); }
    }

    private async Task CheckDiceGate(DiceRollPanel dice)
    {
        // Short, uneven stage durations exercise tween completion instead of a guessed timer.
        dice.TumbleSeconds = 0.09f;
        dice.TumbleStepSeconds = 0.04f;
        dice.LandPopSeconds = dice.SumDelaySeconds = dice.SumFadeSeconds = 0.03f;
        dice.OutcomeDelaySeconds = dice.OutcomePopSeconds = 0.03f;
        dice.HoldSeconds = 0.16f;
        dice.FadeSeconds = 0.03f;
        var hit = CombatRoll.Parse("d20(19)+10=29 vs AC 17 → CriticalSuccess")!;
        var miss = CombatRoll.Parse("d20(3)+10=13 vs AC 17 → Failure")!;
        dice.ShowRoll(hit, "First strike");
        var first = dice.WaitForResultsAsync();
        dice.ShowRoll(miss, "Second strike");
        bool nextActionPlayed = false;
        async Task NextAction()
        {
            await dice.WaitForResultsAsync();
            nextActionPlayed = true;
        }
        var next = NextAction();
        Check("a future action is gated while dice roll", !nextActionPlayed && !next.IsCompleted);
        // Inspect the actual first outcome before allowing the queued roll to begin.
        while (!dice.ResultShowing)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("queued rolls preserve the first result", dice.GetNode<Label>("%RollOutcome").Text == "CRITICAL HIT"
            && dice.GetNode<Label>("%RollContext").Text == "First strike" && !nextActionPlayed);
        await next;
        await first;
        Check("the gate releases only after the final queued outcome", dice.ResultShowing && !dice.Tumbling
            && dice.GetNode<Label>("%RollOutcome").Text == "MISS"
            && Mathf.IsEqualApprox(dice.GetNode<Label>("%RollOutcome").Modulate.A, 1));
        dice.ClearRoll();
        dice.ShowRoll(hit, "Cancelled encounter");
        using var cancelled = new System.Threading.CancellationTokenSource();
        var waiting = dice.WaitForResultsAsync(cancelled.Token);
        cancelled.Cancel();
        try { await waiting; Check("dice gate cancels with the encounter", false); }
        catch (System.OperationCanceledException) { Check("dice gate cancels with the encounter", true); }
        var cleared = dice.WaitForResultsAsync();
        dice.ClearRoll();
        await cleared;
        Check("reset drains queued rolls and releases the gate", !dice.Visible && dice.WaitForResultsAsync().IsCompleted);
        dice.AnimationsEnabled = false;
        dice.ShowRoll(hit, "Disabled dice");
        Check("disabled dice never block combat", !dice.Visible && dice.WaitForResultsAsync().IsCompleted);
        dice.AnimationsEnabled = true;
    }
}
