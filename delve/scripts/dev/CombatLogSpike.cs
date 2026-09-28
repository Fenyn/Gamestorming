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
        string condensed = strike.HeaderText;
        Check($"a compact strike leads with its result and shortens the enemy ('{condensed}')",
            condensed == "CRIT 29 vs 17  Aldric → Spider A  18 slashing");
        var compactRows = log.Rows.Where(r => r.Visible).ToList();
        var headers = compactRows.Select(r => r.GetNode<RichTextLabel>("%EntryHeader")).ToList();
        Check($"the compact log shows three rows and no stride ({compactRows.Count}: {string.Join(" | ", compactRows.Select(r => r.HeaderText))})",
            compactRows.Count == 3 && compactRows.All(r => !r.IsMove));
        Check($"compact rows wrap between figure groups, show at most two lines and never clip sideways ({string.Join(", ", headers.Select(h => $"{h.GetLineCount()} lines {h.GetContentWidth():0}/{h.Size.X:0} x {h.Size.Y:0}"))})",
            headers.All(h => h.GetContentWidth() <= h.Size.X + 1)
            && compactRows.All(r => r.Size.Y <= 2.5f * r.CompactRowHeight)
            && strike.GetNode<RichTextLabel>("%EntryHeader").GetLineCount() <= 2);
        var spellSummary = log.Rows.First(r => r.PlainText.Contains("Breathe Fire")).HeaderText;
        Check($"compact spell retains every target's save and damage outcomes ('{spellSummary}')",
            spellSummary.Contains("Spider A fails the save") && spellSummary.Contains("9 fire")
            && spellSummary.Contains("Rat B saves") && spellSummary.Contains("4 fire") && !spellSummary.Contains("\n"));
        strike.GetNode<Button>("%Disclosure").ButtonPressed = true;
        await Settle();
        Check("clicking disclosure expands in place", details.Visible && !log.Expanded);
        Check("an expanded row keeps the compact log within its height cap",
            log.GetNode<ScrollContainer>("%LogScroll").Size.Y <= log.CompactMaxHeight + 1);
        string opened = details.GetParsedText().Replace(CombatLogFormat.Tie, ' ');
        Check("expanded entry contains its roll and damage", opened.Contains("19+10 = 29 vs AC 17")
            && opened.Contains("18 slashing damage"));
        Check("the roll arithmetic is one tied group, so it never splits across lines",
            details.GetParsedText().Contains($"19+10{CombatLogFormat.Tie}={CombatLogFormat.Tie}29{CombatLogFormat.Tie}vs"));
        Check("an opened row keeps its one-line header instead of the prose title",
            strike.HeaderText == "CRIT 29 vs 17  Aldric → Spider A  18 slashing");
        Check("details have a blank line between results", opened.Contains("17\n\nHunting Spider A"));
        for (int i = 0; i < 6; i++) log.AppendEntry($"Aldric action {i}", 8, false);
        await Settle();
        Check("incoming actions preserve an opened entry", strike.Visible && details.Visible);
        log.SetExpanded(true);
        await Settle();
        Check("sidebar shows the full action history, strides included", log.Rows.All(r => r.Visible) && log.Rows.Any(r => r.IsMove));
        Check("sidebar preserves disclosure state", details.Visible);
        Check($"history keeps full enemy names ('{strike.HeaderText}')", strike.HeaderText.Contains("Aldric → Hunting Spider A"));
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
        await CheckBeats(frame);
        await CheckArmorClassMasking(frame, data);
        await CheckAppliedModifiers(frame, data);
        frame.QueueFree();
    }

    private async Task Settle()
    {
        for (int i = 0; i < 10; i++) await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    }

}
