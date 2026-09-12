using System;
using System.Collections.Generic;
using Delve.Autoload;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Flow;

/// <summary>
/// First screen of a run: one featured character filling the left of the frame and the roster down
/// the right. Choose a leader, then three AI companions. Selection stays editable until embark.
///
/// Reads the roster from <see cref="CharacterCatalog"/> and the <see cref="UnlockState"/> handed to
/// <see cref="Setup"/>, and signals the pick outward: it builds no party and starts no run.
/// </summary>
public partial class HeroSelectPanel : Control
{
    /// <summary>The roster card. Assigned in hero_select.tscn.</summary>
    [Export] public PackedScene? CardScene { get; set; }

    private readonly List<string> _companions = new();

    private readonly List<RosterCard> _cards = new();
    private readonly Dictionary<string, HeroSheetData> _sheets = new();

    private VBoxContainer _list = null!;
    private Label _hint = null!;
    private Label _focus = null!;
    private Button _embark = null!;
    private Button _changeLeader = null!;
    private ScrollContainer _scroll = null!;
    private Button _recruitmentButton = null!;
    private RecruitmentPanel _recruitment = null!;
    private CampaignProgress? _campaign;
    private HeroSheet _sheet = null!;

    private UnlockState _unlocks = new();
    private string? _chosen;
    private string? _hovered;

    /// <summary>The leader and three distinct companions selected for this run.</summary>
    public event Action<string, IReadOnlyList<string>>? Confirmed;
    public event Action<string>? RecruitmentRequested;

    /// <summary>Catalog id of the starting character, or null.</summary>
    public string? Chosen => _chosen;

    public IReadOnlyList<string> Companions => _companions.AsReadOnly();

    /// <summary>Normal expeditions require one leader and three companions.</summary>
    public bool CanEmbark => _chosen != null && _companions.Count == Party.MaxSize - 1;

    /// <summary>The gate line under the title - what the screen is waiting for.</summary>
    public string HintText => _hint.Text;

    public override void _Ready()
    {
        _list = GetNode<VBoxContainer>("%RosterList");
        _hint = GetNode<Label>("%HintLabel");
        _focus = GetNode<Label>("%LeaderFocus");
        _embark = GetNode<Button>("%EmbarkButton");
        _changeLeader = GetNode<Button>("%ChangeLeaderButton");
        _scroll = GetNode<ScrollContainer>("%RosterScroll");
        _recruitmentButton = GetNode<Button>("%RecruitmentButton");
        _recruitment = GetNode<RecruitmentPanel>("%Recruitment");
        _recruitmentButton.Pressed += _recruitment.Open;
        _recruitment.StayRequested += id => RecruitmentRequested?.Invoke(id);
        _sheet = GetNode<HeroSheet>("%Sheet");
        _embark.Pressed += Embark;
        _changeLeader.Pressed += Unpick;
    }

    /// <summary>Build the roster. Safe to call again for a second run.</summary>
    public void Setup(UnlockState unlocks, CampaignProgress? campaign = null)
    {
        _unlocks = unlocks;
        _campaign = campaign;
        _recruitment.Hide();
        _recruitmentButton.Disabled = campaign == null;
        _recruitmentButton.TooltipText = campaign == null ? "Unavailable: no campaign loaded" : "Review shared recruitment requirements";
        _chosen = null;
        _companions.Clear();
        _hovered = null;

        BuildRoster();
        RefreshRecruitment();
    }

    public void RefreshRecruitment()
    {
        if (_campaign != null) _recruitment.Setup(_campaign);
        Refresh();
    }

    /// <summary>
    /// Choose one character, exactly as a click on that card would. Public so the flow can be
    /// driven without synthetic input. Ignores an id the roster would not take.
    /// </summary>
    public void Pick(string id)
    {
        if (_recruitment.Visible || !CanPick(id)) return;
        if (_chosen == null) _chosen = id;
        else if (_chosen == id) { Unpick(); return; }
        else if (!_companions.Remove(id)) _companions.Add(id);
        _hovered = id;
        Refresh();
    }

    /// <summary>Clear formation so the next pick chooses a new leader.</summary>
    public void Unpick()
    {
        if (_recruitment.Visible) return;
        _chosen = null;
        _companions.Clear();
        Refresh();
    }

    /// <summary>Whether a click on that card would do anything right now.</summary>
    public bool CanPick(string id) => GateFor(id) == null;

    /// <summary>Put one of the featured sheet's tooltips on screen with no pointer involved,
    /// addressed by its title. The rendered shot uses it; nothing in the game does.</summary>
    public bool ShowTipForTesting(string title) => _sheet.ShowTipForTesting(title);

    /// <summary>See <see cref="HeroSheet.ShowCardForTesting"/>.</summary>
    public bool ShowCardForTesting(SheetTip tip) => _sheet.ShowCardForTesting(tip);

    /// <summary>Signal a snapshot of the complete formation.</summary>
    public void Embark()
    {
        if (CanEmbark && !_recruitment.Visible) Confirmed?.Invoke(_chosen!, _companions.ToArray());
    }

    public override void _Input(InputEvent @event)
    {
        if (!Visible) return;
        if (_recruitment.Visible)
        {
            if (@event.IsActionPressed(InputNames.Decline))
            {
                _recruitment.Hide();
                GetViewport().SetInputAsHandled();
            }
            return;
        }

        if (@event.IsActionPressed(InputNames.UiDown)) Step(1);
        else if (@event.IsActionPressed(InputNames.UiUp)) Step(-1);
        else if (@event.IsActionPressed(InputNames.Confirm))
        {
            if (_embark.HasFocus()) Embark();
            else if (_changeLeader.HasFocus()) Unpick();
            else if (_recruitmentButton.HasFocus() && !_recruitmentButton.Disabled) _recruitment.Open();
            else if (_hovered != null) Pick(_hovered);
        }
        else if (@event.IsActionPressed(InputNames.Decline) && _chosen != null) Unpick();
        else return;

        GetViewport().SetInputAsHandled();
    }

    // ---------------------------------------------------------------- Build

    private void BuildRoster()
    {
        foreach (var card in _cards)
        {
            _list.RemoveChild(card);
            card.QueueFree();
        }
        _cards.Clear();
        if (CardScene == null)
        {
            GD.PushError("[HeroSelect] CardScene is not assigned.");
            return;
        }

        bool dataReady = DataManager.Instance is { IsLoaded: true };
        foreach (var def in CharacterCatalog.All)
        {
            if (!_sheets.ContainsKey(def.Id)) _sheets[def.Id] = ReadSheet(def, dataReady);

            var card = CardScene.Instantiate<RosterCard>();
            _list.AddChild(card);
            card.Setup(def, HeroPortraits.For(def.Id));
            card.Clicked += Pick;
            card.Hovered += Preview;
            _cards.Add(card);
        }
    }

    /// <summary>
    /// Assemble one roster entry at the run's start level and read its sheet. Building a preset
    /// needs the equipment packs, so the panel owns the "is the data pack loaded" question and a
    /// build that throws yields an empty sheet rather than taking the screen down with it.
    /// </summary>
    private static HeroSheetData ReadSheet(CharacterDef def, bool dataReady)
    {
        if (!dataReady) return HeroSheetData.Unknown(def.DisplayName);
        try
        {
            return HeroSheetBuilder.Read(def.Builder(Party.DefaultLevel));
        }
        catch (Exception e)
        {
            GD.PushWarning($"[HeroSelect] Could not build '{def.Id}': {e.Message}");
            return HeroSheetData.Unknown(def.DisplayName);
        }
    }

    // ---------------------------------------------------------------- Render

    /// <summary>
    /// Repaint every card, the featured sheet and the Embark gate from the one choice. Each
    /// disabled control names the gate that failed (design/ui_guidelines.md section 7).
    /// </summary>
    private void Refresh()
    {
        foreach (var card in _cards)
        {
            bool unlocked = _unlocks.IsUnlocked(card.Id);
            card.SetState(new RosterCardState(
                card.Id == _chosen || _companions.Contains(card.Id), GateFor(card.Id), Locked: !unlocked,
                Caption: card.Id == _chosen ? "LEADER" : "AI COMPANION"));
            if (card.Id == _chosen) card.TooltipText = "Clear this formation and choose a new leader";
            else if (_companions.Contains(card.Id)) card.TooltipText = "Remove this companion from the formation";
        }

        _hint.Text = _chosen == null
            ? "Choose your leader. You control their turns and follow their story."
            : CanEmbark ? "Party ready. You control the leader; companions act automatically."
            : $"Choose three AI companions ({_companions.Count}/3). Click a selected companion to remove them.";
        var objective = _chosen == null ? null : LeaderObjectiveCatalog.Find(_chosen);
        _focus.Visible = objective != null;
        _focus.Text = objective == null ? "" : $"Leader focus: {objective.Description}"
            + (_campaign?.HasPersonalProgress(_chosen!, objective.Id) == true ? " (Completed)" : "");
        _embark.Disabled = !CanEmbark;
        _embark.TooltipText = CanEmbark ? "" : "Unavailable: choose a leader and three companions";
        _changeLeader.Disabled = _chosen == null;
        _changeLeader.TooltipText = _chosen == null ? "Unavailable: no leader chosen" : "Clear this formation and choose a new leader";
        if (CanEmbark && !_recruitment.Visible) _embark.GrabFocus();

        RenderSheet();
    }

    /// <summary>Why a click on that card would do nothing, or null when it would work.</summary>
    private string? GateFor(string id)
    {
        var def = CharacterCatalog.Find(id);
        if (def == null) return "not on the roster";
        if (!_unlocks.IsUnlocked(id)) return "locked";
        if (_chosen == null) return def.CanLead ? null : "cannot lead a run";
        if (id == _chosen || _companions.Contains(id)) return null;
        return CanEmbark ? "remove a companion to make room" : null;
    }

    /// <summary>The sheet reads the hovered card, falls back to the choice, then to the first
    /// character the player could take - the frame is never without a hero in it.</summary>
    private void RenderSheet()
    {
        string? id = _hovered ?? _chosen ?? FirstSelectable();
        var def = id == null ? null : CharacterCatalog.Find(id);
        if (def == null) return;
        _sheet.Show(
            _sheets.TryGetValue(def.Id, out var sheet) ? sheet : HeroSheetData.Unknown(def.DisplayName),
            HeroPortraits.For(def.Id),
            Delve.UI.UiColors.CharacterAccent(def.Id));
    }

    /// <summary>
    /// Feature one character's sheet without choosing them - what hovering a roster card does.
    /// Null gives the frame back to the choice. Public so the sheet can be read without synthetic
    /// input; the roster wires its own hover straight to it.
    /// </summary>
    public void Preview(string? id)
    {
        // A pointer leaving one card and arriving on the next fires exit then enter; only the exit
        // of the card actually being read should fall back to the choice.
        if (id == null && _hovered == null) return;
        _hovered = id;
        RenderSheet();
    }

    /// <summary>Move the preview without changing formation. Confirm selects the preview.</summary>
    private void Step(int delta)
    {
        if (_cards.Count == 0) return;
        int start = _hovered == null ? -1 : _cards.FindIndex(c => c.Id == _hovered);
        for (int step = 1; step <= _cards.Count; step++)
        {
            int index = ((start + delta * step) % _cards.Count + _cards.Count) % _cards.Count;
            if (!CanPick(_cards[index].Id)) continue;
            _embark.ReleaseFocus();
            Preview(_cards[index].Id);
            _scroll.EnsureControlVisible(_cards[index]);
            return;
        }
    }

    private string? FirstSelectable()
    {
        foreach (var card in _cards)
        {
            if (CanPick(card.Id)) return card.Id;
        }
        return _cards.Count > 0 ? _cards[0].Id : null;
    }
}
