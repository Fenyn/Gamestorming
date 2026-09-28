using System;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// End of a run: the outcome, how deep the party got, and the way into the next run. No rewards or
/// scoring yet - the meta layer plugs in here.
/// </summary>
public partial class RunEndPanel : Control
{
    private Label _outcomeLabel = null!;
    private Label _detailLabel = null!;
    private Button _newRunButton = null!;
    private PairReport _figures = null!;

    public event Action? NewRunPressed;

    public override void _Ready()
    {
        _figures = GetNode<PairReport>("%EndFigures");
        _outcomeLabel = GetNode<Label>("%OutcomeLabel");
        _detailLabel = GetNode<Label>("%DetailLabel");
        _newRunButton = GetNode<Button>("%NewRunButton");
        _newRunButton.Pressed += () => NewRunPressed?.Invoke();
    }

    public const string PartyFell = "The party fell.";
    public const string WardOut = "The ward went out.";

    public PairReport Figures => _figures;
    public string DetailText => _detailLabel.Text;

    /// <summary>Show how the run ended: the floor and day as figures, the cause of a defeat, then the
    /// campaign summary. Colors come from the palette, never from a literal.</summary>
    public void Show(RunState state, bool dungeon = false, string campaignSummary = "")
    {
        bool won = state.Outcome == RunOutcome.Victory;
        _outcomeLabel.Text = won ? "Victory" : "Defeat";
        _outcomeLabel.AddThemeColorOverride("font_color", won ? UiColors.Victory : UiColors.Defeat);

        int floorReached = dungeon ? state.Stratum + 1 : state.CurrentNodeId == null ? 0 : state.Floor + 1;
        int totalFloors = dungeon ? Delve.Data.FloorThemes.Count : state.Map.Floors;
        _figures.Render(new[]
        {
            new Delve.Combat.FigureView("Floor", $"{floorReached} of {totalFloors}"),
            new Delve.Combat.FigureView("Day", state.Clock.Day.ToString()),
        }, Array.Empty<ResultMemberRow>());
        string cause = won ? "" : state.Wardstone.IsSpent ? WardOut : PartyFell;
        _detailLabel.Text = string.Join("\n\n", new[] { cause, campaignSummary }.Where(s => s.Length > 0));
        _detailLabel.Visible = _detailLabel.Text.Length > 0;
        GetNode<Control>("%Frame").CustomMinimumSize = new Vector2(Mathf.Min(620, Mathf.Max(240, Size.X - 64)), 0);
        Visible = true;
        UiFocus.Grab(_newRunButton);
    }
}
