using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Conditions;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// The party screen: one member's character sheet or progression, with the members as face tiles
/// in the header. Q and E (or the tiles) page through them, 1 and 2 switch pages, Esc goes back.
/// The crawl, the results and the map open it on a live party; the outpost opens it on its
/// residents with an Add to party / Remove button.
/// </summary>
public partial class CharacterDetailsOverlay : ScreenFrame
{
    public const int CharacterPage = 0;
    public const int ProgressionPage = 1;

    [Export] public PackedScene? MemberTileScene { get; set; }

    /// <summary>Tiles shown at once; a longer roster slides the window with the current member.</summary>
    [Export] public int MaxTiles { get; set; } = 4;

    public event Action? Promoted;

    /// <summary>The outpost asked to add or remove this resident.</summary>
    public event Action<string>? PickRequested;

    private HeroSheet _sheet = null!;
    private Button _next = null!;
    private Button _pick = null!;
    private PromotionPanel _progression = null!;
    private PF2eCharacter? _character;
    private IReadOnlyList<PF2eCharacter> _party = Array.Empty<PF2eCharacter>();
    private bool _confirmed;
    private Roster? _roster;
    private string? _rosterId;

    /// <summary>The outpost's residents: every id, how to read one's sheet and status, and
    /// whether one is in the party.</summary>
    public sealed record Roster(IReadOnlyList<string> Ids, Func<string, HeroSheetData> Sheet, Func<string, string> Line,
        Func<string, bool> Picked, Func<string, bool> CanPick);

    public PF2eCharacter? Character => _character;
    public string? CurrentId => _character?.Id ?? _rosterId;
    public Button NextButton => _next;
    public Button PickButton => _pick;
    public HeroSheet Sheet => _sheet;
    public IReadOnlyList<MemberTile> MemberTiles => GetNode<Control>("%Members").GetChildren().OfType<MemberTile>().ToList();

    public override void _Ready()
    {
        _sheet = GetNode<HeroSheet>("%Sheet");
        _next = GetNode<Button>("%NextHero");
        _pick = GetNode<Button>("%PickMember");
        _progression = GetNode<PromotionPanel>("%Progression");
        base._Ready();
        _next.Pressed += OpenNext;
        _pick.Pressed += () => { if (_rosterId != null) PickRequested?.Invoke(_rosterId); };
        GetNode<Button>("%PrevMember").Pressed += () => PageMember(-1);
        GetNode<Button>("%NextMember").Pressed += () => PageMember(1);
        PageChanged += _ => _sheet.HideTips();
        _progression.Promoted += () =>
        {
            if (_character == null) return;
            _confirmed = true;
            _sheet.Show(HeroSheetBuilder.Read(_character), HeroPortraits.For(_character.Id), UiColors.CharacterAccent(_character.Id));
            RenderMembers();
            UpdateTabLabel();
            UpdateNext();
            Promoted?.Invoke();
        };
    }

    /// <summary>The members Q/E page through and "Next" steps through after a confirm, in party order.</summary>
    public void SetPromotionQueue(IReadOnlyList<PF2eCharacter> party) => _party = party;

    /// <summary>A live party member, from the crawl, the results or the map.</summary>
    public void Open(PF2eCharacter character, Texture2D? portrait, Color accent)
    {
        _roster = null;
        _rosterId = null;
        if (!Visible) _confirmed = false;
        _character = character;
        if (_party.All(m => m.Id != character.Id)) _party = new[] { character };
        _pick.Hide();
        _sheet.Show(HeroSheetBuilder.Read(character), portrait, accent);
        _progression.ShowCharacter(character);
        SetPageVisible(ProgressionPage, true);
        RenderMembers();
        UpdateTabLabel();
        UpdateNext();
        bool wasOpen = Visible;
        if (!wasOpen) OpenFrame();
        SelectPage(!wasOpen && CharacterPromotion.For(character).HasChoice(character) ? ProgressionPage : wasOpen ? Page : CharacterPage);
    }

    /// <summary>An outpost resident, built at the run's start level; there is no progression yet.</summary>
    public void OpenRoster(Roster roster, string id, Control? opener = null)
    {
        _roster = roster;
        _character = null;
        _rosterId = id;
        _next.Hide();
        _sheet.Show(roster.Sheet(id), HeroPortraits.For(id), UiColors.CharacterAccent(id));
        SetPageVisible(ProgressionPage, false);
        RenderMembers();
        RefreshPick();
        if (!Visible) OpenFrame(opener);
        SelectPage(CharacterPage);
    }

    /// <summary>Repaint the tiles and the pick button after the outpost's party changed.</summary>
    public void RefreshRoster()
    {
        if (_roster == null) return;
        RenderMembers();
        RefreshPick();
    }

    private void RefreshPick()
    {
        if (_roster == null || _rosterId == null) return;
        bool picked = _roster.Picked(_rosterId);
        _pick.Show();
        _pick.Text = picked ? "Remove from party" : "Add to party";
        _pick.Disabled = !picked && !_roster.CanPick(_rosterId);
        _pick.TooltipText = _pick.Disabled ? "Unavailable: the party is full" : "";
    }

    private void SetPageVisible(int page, bool visible)
    {
        if (page < Tabs.Count) Tabs[page].Visible = visible;
        GetNode<Control>("%FrameTabs").Visible = Tabs.Count(t => t.Visible) > 1;
    }

    private IReadOnlyList<string> MemberIds => _roster?.Ids ?? _party.Select(m => m.Id).ToList();

    /// <summary>Q/E: the previous or next member, wrapping.</summary>
    public void PageMember(int delta)
    {
        var ids = MemberIds;
        if (ids.Count < 2 || CurrentId == null) return;
        int index = ids.ToList().IndexOf(CurrentId);
        ShowMember(ids[((index + delta) % ids.Count + ids.Count) % ids.Count]);
    }

    private void ShowMember(string id)
    {
        if (_roster != null) OpenRoster(_roster, id);
        else if (_party.FirstOrDefault(m => m.Id == id) is { } member)
            Open(member, HeroPortraits.For(member.Id), UiColors.CharacterAccent(member.Id));
    }

    private void RenderMembers()
    {
        var row = GetNode<Control>("%Members");
        bool hadFocus = GetViewport().GuiGetFocusOwner() is { } owner && row.IsAncestorOf(owner);
        foreach (var child in row.GetChildren()) { row.RemoveChild(child); child.QueueFree(); }
        var ids = MemberIds;
        int current = CurrentId == null ? 0 : Math.Max(0, ids.ToList().IndexOf(CurrentId));
        int start = Math.Clamp(current - MaxTiles / 2, 0, Math.Max(0, ids.Count - MaxTiles));
        foreach (string id in ids.Skip(start).Take(MaxTiles))
        {
            var tile = MemberTileScene!.Instantiate<MemberTile>();
            row.AddChild(tile);
            var (name, line, alert) = Describe(id);
            tile.Show(id, name, line, alert);
            tile.SetPressedNoSignal(id == CurrentId);
            tile.Pressed += () => ShowMember(id);
            // The tile the player just used is rebuilt; focus moves to its replacement.
            if (hadFocus && id == CurrentId) UiFocus.Grab(tile);
        }
        bool paging = ids.Count > 1;
        GetNode<Control>("%PrevMember").Visible = paging;
        GetNode<Control>("%NextMember").Visible = paging;
    }

    private (string Name, string Line, bool Alert) Describe(string id)
    {
        if (_roster != null)
            return (CharacterCatalog.Find(id)?.DisplayName ?? id, _roster.Line(id), false);
        var member = _party.First(m => m.Id == id);
        return (member.Name, MemberLine(member), NeedsCare(member));
    }

    /// <summary>"HP 26/26", then Wounded and a pending promotion when present.</summary>
    public static string MemberLine(PF2eCharacter member)
    {
        var parts = new List<string> { $"HP {member.Health?.CurrentHP ?? 0}/{member.Health?.MaxHP ?? 0}" };
        int wounded = member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0;
        if (wounded > 0) parts.Add($"Wounded {wounded}");
        else if (CharacterPromotion.For(member).HasChoice(member)) parts.Add("Feat");
        return string.Join("  ", parts);
    }

    private static bool NeedsCare(PF2eCharacter member)
        => (member.Conditions?.GetConditionValue(Condition.Wounded) ?? 0) > 0
           || (member.Health?.CurrentHP ?? 0) * 2 < (member.Health?.MaxHP ?? 0);

    private void UpdateNext()
    {
        var next = _confirmed && _character != null ? CombatResults.NextWithChoice(_party, _character) : null;
        _next.Visible = next != null;
        if (next == null) return;
        _next.Text = $"Next: {next.Name}";
        UiFocus.Grab(_next);
    }

    private void OpenNext()
    {
        if (_character == null || CombatResults.NextWithChoice(_party, _character) is not { } next) return;
        Open(next, HeroPortraits.For(next.Id), UiColors.CharacterAccent(next.Id));
        SelectPage(ProgressionPage);
    }

    private void UpdateTabLabel()
    {
        if (_character == null) return;
        string status = CharacterPromotion.Status(_character);
        SetPageCaption(ProgressionPage, status.Length > 0 ? $"Progression · {status}" : "Progression");
    }

    public override void _Input(InputEvent e)
    {
        if (IsVisibleInTree() && !e.IsEcho() && (e.IsActionPressed(InputNames.MenuPrev) || e.IsActionPressed(InputNames.MenuNext)))
        {
            PageMember(e.IsActionPressed(InputNames.MenuPrev) ? -1 : 1);
            GetViewport().SetInputAsHandled();
            return;
        }
        // The key that opened the party screen from the crawl menu closes it again.
        if (IsVisibleInTree() && !e.IsEcho() && _roster == null && e.IsActionPressed(InputNames.ExploreParty))
        {
            Close();
            GetViewport().SetInputAsHandled();
            return;
        }
        base._Input(e);
    }

    public override void Close()
    {
        _sheet.HideTips();
        base.Close();
    }
}
