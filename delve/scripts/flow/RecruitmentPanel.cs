using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>Live unlock journal with a filtered index and a focused character page.</summary>
public partial class RecruitmentPanel : Control
{
    [Export] public PackedScene? EntryScene { get; set; }
    [Export] public PackedScene? StepScene { get; set; }
    private GridContainer _entries = null!;
    private VBoxContainer _steps = null!;
    private OptionButton _filter = null!;
    private Button _stay = null!;
    private readonly List<RecruitmentEntry> _cards = new();
    private CampaignProgress? _campaign;
    private string? _selected;
    private static readonly string[] Filters = { "All travelers", "Undiscovered", "In progress", "Ready to join", "Joined" };
    public event Action<string>? StayRequested;
    public string? SelectedId => _selected;

    public override void _Ready()
    {
        _entries = GetNode<GridContainer>("%RecruitEntries");
        _steps = GetNode<VBoxContainer>("%JournalSteps");
        _filter = GetNode<OptionButton>("%JournalFilter");
        _stay = GetNode<Button>("%StayButton");
        foreach (string filter in Filters) _filter.AddItem(filter);
        _filter.ItemSelected += _ => RefreshIndex();
        _stay.Pressed += () =>
        {
            if (_selected != null && _campaign?.CanBindAtOutpost(_selected) == true)
                StayRequested?.Invoke(_selected);
        };
        GetNode<Button>("%CloseRecruitment").Pressed += Hide;
    }

    public void Open() { RefreshIndex(); Show(); _filter.GrabFocus(); }
    public void Setup(CampaignProgress campaign) { _campaign = campaign; RefreshIndex(); }
    public static string StatusFor(RecruitmentArc arc, CampaignProgress campaign) => Filters[Stage(arc, campaign)];
    private static int Stage(RecruitmentArc arc, CampaignProgress campaign) =>
        campaign.Unlocks.IsUnlocked(arc.CharacterId) ? 4 : campaign.CanBindAtOutpost(arc.CharacterId) ? 3
        : arc.Steps.Any(step => campaign.RecruitmentCount(arc.CharacterId, step.Id) > 0) ? 2 : 1;
    public void SelectFilter(int index) { _filter.Select(index); RefreshIndex(); }

    private void RefreshIndex()
    {
        if (_campaign == null || EntryScene == null) return;
        foreach (var card in _cards) { _entries.RemoveChild(card); card.QueueFree(); }
        _cards.Clear();
        for (int i = 0; i < Filters.Length; i++)
        {
            int count = RecruitmentCatalog.All.Count(arc => i == 0 || Stage(arc, _campaign) == i);
            _filter.SetItemText(i, $"{Filters[i]} ({count})");
        }
        int joined = RecruitmentCatalog.All.Count(arc => _campaign.Unlocks.IsUnlocked(arc.CharacterId));
        GetNode<Label>("%JournalSummary").Text = $"{joined} / {RecruitmentCatalog.All.Count} companions joined  |  Progress carries between expeditions";
        var arcs = RecruitmentCatalog.All.Where(arc => _filter.Selected == 0 || Stage(arc, _campaign) == _filter.Selected)
            .OrderBy(arc => Stage(arc, _campaign) switch { 3 => 0, 2 => 1, 1 => 2, _ => 3 }).ToArray();
        foreach (var arc in arcs)
        {
            var card = EntryScene.Instantiate<RecruitmentEntry>();
            _entries.AddChild(card);
            card.ShowProgress(arc, _campaign);
            card.Pressed += () => SelectCharacter(arc.CharacterId);
            _cards.Add(card);
        }
        GetNode<Label>("%JournalEmpty").Visible = arcs.Length == 0;
        if (!arcs.Any(arc => arc.CharacterId == _selected)) _selected = arcs.FirstOrDefault()?.CharacterId;
        RenderPage();
    }

    public void SelectCharacter(string id)
    {
        if (!_cards.Any(card => card.CharacterId == id)) return;
        _selected = id;
        RenderPage();
    }

    private void RenderPage()
    {
        foreach (var card in _cards) card.SetPressedNoSignal(card.CharacterId == _selected);
        foreach (Node step in _steps.GetChildren()) { _steps.RemoveChild(step); step.QueueFree(); }
        var arc = _selected == null ? null : RecruitmentCatalog.Find(_selected);
        GetNode<Control>("%JournalPage").Visible = arc != null;
        if (arc == null || _campaign == null || StepScene == null) return;
        var def = CharacterCatalog.Find(arc.CharacterId)!;
        Color accent = UiColors.CharacterAccent(def.Id);
        var title = GetNode<Label>("%RecruitTitle");
        title.Text = def.DisplayName;
        title.AddThemeColorOverride("font_color", accent);
        GetNode<Label>("%JournalRole").Text = def.Role;
        GetNode<Label>("%JournalArc").Text = arc.Title;
        GetNode<Label>("%JournalStatus").Text = StatusFor(arc, _campaign);
        bool known = Stage(arc, _campaign) != 1;
        GetNode<TextureRect>("%JournalPortrait").Texture = known ? HeroPortraits.For(def.Id) : null;
        GetNode<Label>("%UnknownPortrait").Visible = !known;
        GetNode<Label>("%JournalStory").Text = known ? BulwarkWayfarers.Find(def.Id)?.Introduction ?? arc.Title
            : "An unfamiliar traveler may cross your path. Explore the dungeon to begin this journal entry.";
        var visibleSteps = known ? arc.Steps : arc.Steps.Take(1);
        foreach (var step in visibleSteps)
        {
            var row = StepScene.Instantiate<Control>();
            _steps.AddChild(row);
            int count = Math.Min(step.Required, _campaign.RecruitmentCount(def.Id, step.Id));
            row.GetNode<Label>("%ObjectiveText").Text = step.Description;
            row.GetNode<Label>("%ObjectiveCount").Text = count >= step.Required ? "Complete" : $"{count} / {step.Required}";
            var bar = row.GetNode<ProgressBar>("%ObjectiveProgress");
            bar.MaxValue = step.Required;
            bar.Value = count;
            var fill = (StyleBoxFlat)bar.GetThemeStylebox("fill").Duplicate();
            fill.BgColor = accent;
            bar.AddThemeStyleboxOverride("fill", fill);
        }
        bool joined = _campaign.Unlocks.IsUnlocked(def.Id);
        _stay.Visible = !joined;
        _stay.Disabled = !_campaign.CanBindAtOutpost(def.Id);
        _stay.TooltipText = _stay.Disabled ? "Complete this traveler's objectives before inviting them to stay."
            : "An overnight stay makes this companion available for future expeditions.";
        GetNode<Label>("%JournalNext").Text = joined ? "At home in the outpost. Available for future expeditions."
            : !_stay.Disabled ? "Your bond is strong enough. Invite this companion to make the outpost their home."
            : known ? "Bring this companion into your party to continue their objectives." : "Further objectives appear after you meet.";
    }
}
