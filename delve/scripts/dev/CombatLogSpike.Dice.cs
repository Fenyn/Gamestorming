using System.Threading.Tasks;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatLogSpike
{
    private async Task DiceAndPacing(Control frame, CombatLogPanel log)
    {
        var dice = DiceScene.Instantiate<DiceRollPanel>();
        frame.AddChild(dice);
        log.RollObserved += dice.ShowRoll;
        var hero = dice.Hero!;
        Check("the log panel carries no dice toggle", log.GetNodeOrNull("%DiceToggle") == null);
        Check("dice display starts hidden with no roll", !dice.Visible && !hero.Visible);
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(19)+10=29 vs AC 17 → CriticalSuccess", 2, true);
        Check("the dice display receives the logged roll without any opt-in", dice.Visible && hero.Visible);
        Check($"a party crit against a known AC plays the degree track with the freeze ({dice.Beat})",
            dice.Beat == new RollBeat(RollStage.DegreeTrack, RollPace.Full, true));
        var mathLabel = dice.GetNode<RichTextLabel>("%RollMath");
        var outcomeLabel = dice.GetNode<Label>("%RollOutcome");
        await Seconds(dice.TrackTumbleSeconds * 0.5f);
        Check("mid-tumble the hero die shows a number, the word is withheld and the row is hidden",
            dice.Tumbling && int.TryParse(hero.FaceText, out int face) && face is >= 1 and <= 20
            && hero.Word.Modulate.A == 0 && dice.SelfModulate.A == 0);
        ulong started = Time.GetTicksMsec();
        await dice.WaitForResultsAsync();
        Check($"at the gate the word has arrived, the marker sits at the total and Critical is lit ('{hero.Word.Text}')",
            hero.Word.Text == "CRITICAL HIT" && Mathf.IsEqualApprox(hero.Word.Modulate.A, 1f) && hero.FaceText == "19"
            && hero.Track.MarkerValue == 29 && hero.Track.LitZone == DegreeZones.CriticalSuccess && hero.Total.Text == "29");
        GD.Print($"  [INFO] full H3 gate {dice.GateSeconds(dice.Beat!):0.00} s, measured past mid-tumble {(Time.GetTicksMsec() - started) / 1000f:0.00} s");
        await Until(() => !hero.Visible, 2f);
        string detail = dice.GetNode<RichTextLabel>("%RollDetail").GetParsedText();
        Check($"the hero shrinks into the settled row: total vs target, outcome, die and modifiers ('{mathLabel.GetParsedText()}', '{detail}')",
            !hero.Visible && dice.Settled && Mathf.IsEqualApprox(dice.SelfModulate.A, 1f)
            && mathLabel.GetParsedText() == "29 vs 17" && detail == "19 +10" && outcomeLabel.Text == "CRITICAL HIT");
        Check("the settled row keeps a thin track with the landed zone lit",
            dice.RowTrack.Visible && dice.RowTrack.LitZone == DegreeZones.CriticalSuccess && dice.RowTrack.MarkerValue == 29);
        Check($"the settled row keeps its size ({dice.Size})", Mathf.IsEqualApprox(dice.Size.X, 600) && dice.Size.Y <= 72.5f);
        Check("total and target share primary size and total is accented",
            mathLabel.Text.Contains($"[font_size={dice.SumFontSize}][b][color=#{UiColors.Accent.ToHtml()}]29")
            && mathLabel.Text.Contains($"[font_size={dice.SumFontSize}][b][color=#{UiColors.Text.ToHtml()}]17")
            && dice.SumFontSize > dice.SumDetailFontSize);
        var details = log.Rows[^1].GetNode<RichTextLabel>("%EntryDetails");
        Check("roll numbers are larger than log text", details.GetParsedText().Contains("29")
            && log.GetThemeConstant("roll_font_size", "CombatLogText") > log.GetThemeFontSize("normal_font_size", "CombatLogText"));
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(3)+10=13 vs AC 17 → Failure", 2, true);
        await dice.WaitForResultsAsync();
        Check("a miss colours its total in the miss tone",
            mathLabel.Text.Contains($"[color=#{UiColors.LogSeverity[3].ToHtml()}]13") && outcomeLabel.Text == "MISS");
        log.SetActors(new[] { ("Aldric", UiColors.LogAlly), ("Hunting Spider", UiColors.LogEnemy) });
        log.SetEnemies(new[] { "Hunting Spider" });
        log.AppendEntry("Hunting Spider Strikes Aldric with Fangs", 8, false);
        log.AppendEntry("d20(14)+8=22 vs AC 19 → Success", 1, true);
        await dice.WaitForResultsAsync();
        Check("an enemy hit on a hero reads in the enemy tone", outcomeLabel.Text == "HIT"
            && outcomeLabel.GetThemeColor("font_color") == UiColors.Enemy);
        log.AppendEntry("Hunting Spider Strikes Aldric with Fangs", 8, false);
        log.AppendEntry("d20(4)+8=12 vs AC 19 → Failure", 3, true);
        await dice.WaitForResultsAsync();
        Check("an enemy miss reads as good news", outcomeLabel.Text == "MISS"
            && outcomeLabel.GetThemeColor("font_color") == UiColors.HpHigh);
        log.SetEnemies(System.Array.Empty<string>());
        log.AppendEntry("Hunting Spider Strikes Aldric with Fangs", 8, false);
        log.AppendEntry("d20(15)+8=23 vs AC 19 → Success", 1, true, enemyRoll: true);
        await dice.WaitForResultsAsync();
        Check("the roller's team, not a name lookup, colours an enemy hit",
            outcomeLabel.Text == "HIT" && outcomeLabel.GetThemeColor("font_color") == UiColors.Enemy);
        dice.ClearRoll();
        Check("clearing the roll hides the row and the hero", !dice.Visible && !hero.Visible);
        await CheckDiceGate(dice);
        Check("invalid d20 values never animate", CombatRoll.Parse("d20(25)+10=35 vs AC 17 → Success") == null);
        string adjustments = DiceRollPanel.FormatAdjustments(new CombatRoll("", 15, "+10 MAP-5", 18, "AC", 20, "Failure"));
        Check("modifier signs are colored and unreported adjustments reconcile the total",
            adjustments.Contains($"[color=#{UiColors.HpHigh.ToHtml()}]+10")
            && adjustments.Contains($"MAP[color=#{UiColors.HpLow.ToHtml()}]-5")
            && adjustments.Contains($"Other [color=#{UiColors.HpLow.ToHtml()}]-2"));
        using var cancellation = new System.Threading.CancellationTokenSource();
        var cue = new PF2e.Core.BattleEvent { Type = PF2e.Core.BattleEventType.AttackRolled };
        Check("player actions incur no AI pause", Delve.Combat.AiActionPacing.Wait(GetTree(), cue, true, 0.35f, cancellation.Token).IsCompleted);
        cue.Type = PF2e.Core.BattleEventType.MovementStep;
        Check("movement tiles incur no extra pause", Delve.Combat.AiActionPacing.Wait(GetTree(), cue, false, 0.35f, cancellation.Token).IsCompleted);
        cue.Type = PF2e.Core.BattleEventType.AttackRolled;
        var pause = Delve.Combat.AiActionPacing.Wait(GetTree(), cue, false, 0.35f, cancellation.Token);
        Check("AI action cue waits", !pause.IsCompleted);
        cancellation.Cancel();
        try { await pause; Check("AI pause cancels with encounter", false); }
        catch (System.OperationCanceledException) { Check("AI pause cancels with encounter", true); }
        dice.QueueFree();
    }

    /// <summary>Short, uneven stage durations exercise tween completion instead of a guessed timer.</summary>
    private static void Quicken(DiceRollPanel dice)
    {
        dice.TumbleStepSeconds = 0.04f;
        dice.CentreTumbleSeconds = dice.TrackTumbleSeconds = 0.09f;
        dice.CentreLandSeconds = dice.TrackLandSeconds = dice.CountSeconds = dice.SlideSeconds = 0.03f;
        dice.WordSeconds = dice.FreezeSeconds = dice.ShrinkSeconds = dice.ShortStepSeconds = 0.03f;
        dice.HoldSeconds = 0.16f;
        dice.FadeSeconds = 0.03f;
    }

    private async Task CheckDiceGate(DiceRollPanel dice)
    {
        Quicken(dice);
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
        while (!dice.ResultShowing)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("queued rolls preserve the first result", dice.Hero!.Word.Text == "CRITICAL HIT"
            && dice.Context == "First strike" && !nextActionPlayed);
        await next;
        await first;
        Check("the gate releases only after the final queued outcome", dice.ResultShowing && !dice.Tumbling
            && dice.Context == "Second strike" && dice.Hero.Word.Text == "MISS"
            && Mathf.IsEqualApprox(dice.Hero.Word.Modulate.A, 1));
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
        Check("with the dice reveal off only the settled row shows and combat never waits",
            dice.Visible && dice.Settled && !dice.Hero.Visible && dice.WaitForResultsAsync().IsCompleted
            && dice.Beat?.Pace == RollPace.Settled && dice.GetNode<Label>("%RollOutcome").Text == "CRITICAL HIT");
        dice.AnimationsEnabled = true;
    }

    private async Task Seconds(float seconds)
        => await ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);

    private async Task Until(System.Func<bool> done, float timeout)
    {
        ulong end = Time.GetTicksMsec() + (ulong)(timeout * 1000);
        while (!done() && Time.GetTicksMsec() < end)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }
}
