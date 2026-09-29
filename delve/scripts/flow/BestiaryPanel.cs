using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Data;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Data;

namespace Delve.Flow;

/// <summary>
/// The outpost bestiary: every species in the campaign's creature pool, one index entry each. A
/// species the party has met shows its idle sprite, its name and the facts Recall Knowledge has
/// revealed. One not met yet shows a dark silhouette and "???". Arrow keys move through the index
/// and the page follows focus.
/// </summary>
public partial class BestiaryPanel : Control
{
    /// <summary>The page title and index text for a species not met yet.</summary>
    public const string Unknown = "???";

    /// <summary>The tallest the portrait may draw; the idle frame takes the largest whole scale under it.</summary>
    [Export] public int PortraitHeight { get; set; } = 448;

    private VBoxContainer _entries = null!;
    private Control _page = null!;
    private Label _empty = null!;
    private JournalFactsGrid _facts = null!;
    private TextureRect _portrait = null!;
    private readonly List<Button> _buttons = new();
    private IReadOnlyList<(string Id, string Name)> _species = Array.Empty<(string, string)>();
    private MonsterJournal? _journal;
    private Func<string, EnemyDefinition?> _lookup = _ => null;
    private string? _selected;

    public event Action? Closed;
    public string? SelectedId => _selected;
    public IReadOnlyList<JournalFact> PageFacts { get; private set; } = Array.Empty<JournalFact>();
    public string PageKnownText => GetNode<Label>("%BestiaryKnown").Visible ? GetNode<Label>("%BestiaryKnown").Text : "";
    public string PageTitle => GetNode<Label>("%BestiaryTitle").Text;
    public int EntryCount => _buttons.Count;
    public int MetCount => _species.Count(s => _journal?.IsEncountered(s.Id) == true);
    public int ShownFactCount => _facts.GetChildCount();
    public TextureRect Portrait => _portrait;
    public bool PortraitSilhouette { get; private set; }

    public override void _Ready()
    {
        _entries = GetNode<VBoxContainer>("%BestiaryEntries");
        _page = GetNode<Control>("%BestiaryPage");
        _empty = GetNode<Label>("%BestiaryEmpty");
        _facts = GetNode<JournalFactsGrid>("%BestiaryFacts");
        _portrait = GetNode<TextureRect>("%BestiaryPortrait");
        _portraitTint = _portrait.SelfModulate;
        GetNode<Button>("%CloseBestiary").Pressed += Close;
    }

    /// <param name="lookup">Finds a species' definition by display name, for its printed values and size.</param>
    public void Setup(MonsterJournal journal, Func<string, EnemyDefinition?> lookup)
    {
        _journal = journal;
        _lookup = lookup;
    }

    public void Open()
    {
        RefreshIndex();
        Show();
        int index = _buttons.FindIndex(b => (string)b.GetMeta(IdMeta) == _selected);
        if (_buttons.Count > 0) _buttons[Math.Max(0, index)].GrabFocus();
        else GetNode<Button>("%CloseBestiary").GrabFocus();
    }

    public void Close()
    {
        if (!Visible) return;
        Hide();
        Closed?.Invoke();
    }

    private const string IdMeta = "species";

    /// <summary>The floors' creature pools in floor order, then any met species outside them.</summary>
    public static IReadOnlyList<(string Id, string Name)> CampaignPool(MonsterJournal? journal)
    {
        var pool = new List<(string Id, string Name)>();
        for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
            foreach (var creature in FloorThemes.ForStratum(stratum).Roster)
            {
                string id = MonsterJournal.Key(creature.Slug);
                if (pool.All(p => p.Id != id)) pool.Add((id, creature.DisplayName));
            }
        foreach (var (id, name) in journal?.Encountered ?? Array.Empty<(string, string)>())
            if (pool.All(p => p.Id != id)) pool.Add((id, name));
        return pool;
    }

    private bool Met(string id) => _journal?.IsEncountered(id) == true;

    private void RefreshIndex()
    {
        foreach (var button in _buttons) { _entries.RemoveChild(button); button.QueueFree(); }
        _buttons.Clear();
        _species = CampaignPool(_journal);
        GetNode<Label>("%BestiarySummary").Text = $"Met {MetCount} of {_species.Count}";
        foreach (var (id, name) in _species)
        {
            var button = new Button { Text = Met(id) ? name : Unknown, ToggleMode = true, Alignment = HorizontalAlignment.Left,
                CustomMinimumSize = new Vector2(0, 48), MouseDefaultCursorShape = CursorShape.PointingHand };
            button.SetMeta(IdMeta, id);
            button.FocusEntered += () => Select(id);
            button.Pressed += () => Select(id);
            _entries.AddChild(button);
            _buttons.Add(button);
        }
        _empty.Visible = _species.Count == 0;
        if (_selected == null || _species.All(s => s.Id != _selected))
            _selected = _species.FirstOrDefault(s => Met(s.Id)).Id ?? _species.FirstOrDefault().Id;
        RenderPage();
    }

    public void Select(string id)
    {
        if (_species.All(s => s.Id != id)) return;
        _selected = id;
        RenderPage();
    }

    private void RenderPage()
    {
        foreach (var button in _buttons) button.SetPressedNoSignal((string)button.GetMeta(IdMeta) == _selected);
        var entry = _species.FirstOrDefault(s => s.Id == _selected);
        _page.Visible = entry.Id != null && _journal != null;
        if (entry.Id == null || _journal == null) { PageFacts = Array.Empty<JournalFact>(); return; }
        bool met = Met(entry.Id);
        string name = met ? _journal.NameFor(entry.Id) : entry.Name;
        var def = _lookup(name);
        PageFacts = met
            ? CreatureFacts.Facts(def, def?.StatBlock ?? default, field => def != null && _journal.IsFieldRevealed(entry.Id, field))
            : Array.Empty<JournalFact>();
        GetNode<Label>("%BestiaryTitle").Text = met ? name : Unknown;
        var known = GetNode<Label>("%BestiaryKnown");
        known.Visible = met;
        known.Text = $"Known {_journal.KnownCount(entry.Id)} of {MonsterJournal.TotalFields}";
        _facts.Render(PageFacts.Where(f => f.Known).ToList());
        RenderPortrait(name, def, met);
    }

    /// <summary>The idle frame at the largest whole scale under <see cref="PortraitHeight"/>; a species
    /// not met yet draws as a solid dark silhouette of the same frame.</summary>
    private void RenderPortrait(string name, EnemyDefinition? def, bool met)
    {
        var size = def?.StatBlock.CreatureSize ?? CreatureSize.Medium;
        string folder = EnemySpriteMap.FolderForCreature(name, size);
        var texture = UnitPortraits.EnemyIdleFrame(folder);
        _portrait.Texture = texture;
        int scale = texture == null ? 1 : Math.Max(1, PortraitHeight / texture.GetHeight());
        _portrait.CustomMinimumSize = texture == null ? Vector2.Zero : texture.GetSize() * scale;
        PortraitSilhouette = !met;
        _portrait.SelfModulate = met ? _portraitTint : UiColors.Ink;
    }

    private Color _portraitTint;
}
