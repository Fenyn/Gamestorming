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
        CombatLogSamples.Fill(log);
        await Settle();
        var strike = log.Rows.First(r => r.PlainText.Contains("Longsword"));
        var details = strike.GetNode<RichTextLabel>("%EntryDetails");
        Check("action details start collapsed", !details.Visible);
        Check("roll outcome remains in the compact summary", strike.PlainText.Contains("CRITICAL HIT"));
        strike.GetNode<Button>("%Disclosure").ButtonPressed = true;
        await Settle();
        Check("clicking disclosure expands in place", details.Visible && !log.Expanded);
        Check("expanded entry contains its roll and damage", details.GetParsedText().Contains("19+10 = 29 vs AC 17")
            && details.GetParsedText().Contains("18 slashing damage"));
        Check("each detail occupies its own line", details.GetParsedText().Contains("17\nHunting Spider"));
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
        log.DiceVisibilityChanged += dice.SetEnabled;
        var toggle = log.GetNode<CheckButton>("%DiceToggle");
        bool original = Delve.Settings.ViewPreferences.ShowDiceRolls;
        toggle.ButtonPressed = false;
        log.AppendEntry("Aldric Strikes Hunting Spider with Longsword", 8, false);
        log.AppendEntry("d20(19)+10=29 vs AC 17 → CriticalSuccess", 2, true);
        Check("dice display is optional", !dice.Visible);
        toggle.ButtonPressed = true;
        log.AppendEntry("d20(19)+10=29 vs AC 17 → CriticalSuccess", 2, true);
        Check("enabled dice display receives the logged roll", dice.Visible);
        dice._Process(dice.RevealSeconds + 0.01);
        Check("dice reveal shows the resolved value", dice.GetNode<Label>("%DieValue").Text == "19"
            && dice.GetNode<Label>("%RollMath").Text.Contains("29 vs AC 17"));
        var details = log.Rows[^1].GetNode<RichTextLabel>("%EntryDetails");
        Check("roll numbers are larger than log text", details.GetParsedText().Contains("29")
            && log.GetThemeConstant("roll_font_size", "CombatLogText") > log.GetThemeFontSize("normal_font_size", "CombatLogText"));
        toggle.ButtonPressed = false;
        Check("turning dice off immediately hides the popup", !dice.Visible);
        Check("invalid d20 values never animate", CombatRoll.Parse("d20(25)+10=35 vs AC 17 → Success") == null);
        toggle.ButtonPressed = original;
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
}
