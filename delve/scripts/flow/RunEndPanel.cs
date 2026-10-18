using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// End of a run: the outcome, how deep the party got, and the way into the next run. No rewards or
/// scoring yet - the meta layer plugs in here.
/// </summary>
public partial class RunEndPanel : ScreenFrame
{
    private Label _outcomeLabel = null!;
    private Label _detailLabel = null!;
    private Button _newRunButton = null!;
    private PairReport _figures = null!;
    private Label _campaignCaption = null!;
    private RuledRows _campaign = null!;

    /// <summary>Shown under the caption when the expedition changed nothing in the campaign.</summary>
    public const string NothingGained = "No campaign progress";

    public event Action? NewRunPressed;

    public override void _Ready()
    {
        _figures = GetNode<PairReport>("%EndFigures");
        _outcomeLabel = GetNode<Label>("%OutcomeLabel");
        _detailLabel = GetNode<Label>("%DetailLabel");
        _newRunButton = GetNode<Button>("%NewRunButton");
        _campaignCaption = GetNode<Label>("%CampaignCaption");
        _campaign = GetNode<RuledRows>("%CampaignRows");
        _newRunButton.Pressed += () => NewRunPressed?.Invoke();
        base._Ready();
    }

    public const string PartyFell = "The party fell.";
    public const string WardOut = "The ward went out.";

    public PairReport Figures => _figures;
    public string DetailText => _detailLabel.Text;

    /// <summary>The campaign rows on show, for spikes.</summary>
    public RuledRows Campaign => _campaign;

    /// <summary>Show how the run ended: the floor and day as figures, the cause of a defeat, then the
    /// campaign's progress as one banded row per gain. Colors come from the palette, never from a literal.</summary>
    public void Show(RunState state, bool dungeon = false, IReadOnlyList<CampaignLine>? campaign = null)
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
        _detailLabel.Text = won ? "" : state.Wardstone.IsSpent ? WardOut : PartyFell;
        _detailLabel.Visible = _detailLabel.Text.Length > 0;
        var lines = campaign ?? Array.Empty<CampaignLine>();
        _campaignCaption.Visible = true;
        _campaign.Render(lines.Count > 0
            ? lines.Select(line => new RuledRow(line.Who, line.What, line.Status))
            : new[] { new RuledRow("", NothingGained) });
        OpenFrame();
        UiFocus.Grab(_newRunButton);
    }
}
