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
/// The journal's bestiary page: every species in the campaign's creature pool as a sprite tile,
/// grouped under the floor it lives on. A species the party has met shows its idle sprite; one not
/// met yet is a dark silhouette named "???". The page beside the grid holds the sprite on a plinth,
/// the species' level and traits, and all eleven journal fields, "?" until Recall Knowledge reveals
/// them. Arrow keys move through the grid and the page follows focus.
/// </summary>
public partial class BestiaryPanel : HBoxContainer
{
    /// <summary>The page title and tile name for a species not met yet.</summary>
    public const string Unknown = "???";

    /// <summary>The tallest the portrait may draw; the idle frame takes the largest whole scale under it.</summary>
    [Export] public int PortraitHeight { get; set; } = 448;

    /// <summary>The tallest a tile's sprite may draw, at a whole scale when the frame allows it.</summary>
    [Export] public int TileSpriteHeight { get; set; } = 96;

    [Export] public int TileColumns { get; set; } = 4;
    [Export] public PackedScene? TileScene { get; set; }

    private VBoxContainer _entries = null!;
    private Control _page = null!;
    private Label _empty = null!;
    private JournalFactsGrid _facts = null!;
    private TextureRect _portrait = null!;
    private Color _portraitTint;
    private readonly List<Button> _buttons = new();
    private IReadOnlyList<(string Id, string Name)> _species = Array.Empty<(string, string)>();
    private MonsterJournal? _journal;
    private Func<string, EnemyDefinition?> _lookup = _ => null;
    private string? _selected;

    public string? SelectedId => _selected;
    public IReadOnlyList<JournalFact> PageFacts { get; private set; } = Array.Empty<JournalFact>();
    public string PageKnownText => GetNode<Label>("%BestiaryKnown").Visible ? GetNode<Label>("%BestiaryKnown").Text : "";
    public string PageTitle => GetNode<Label>("%BestiaryTitle").Text;
    public string SummaryText => GetNode<Label>("%BestiarySummary").Text;
    public string IdentityText => GetNode<Label>("%BestiaryIdentity").Text;
    public int EntryCount => _buttons.Count;
    public int MetCount => _species.Count(s => Met(s.Id));
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
    }

    /// <param name="lookup">Finds a species' definition by display name, for its printed values and size.</param>
    public void Setup(MonsterJournal journal, Func<string, EnemyDefinition?> lookup)
    {
        _journal = journal;
        _lookup = lookup;
    }

    /// <summary>Rebuild the grid from the journal and focus the selected tile.</summary>
    public void Refresh()
    {
        RefreshIndex();
        FocusSelected();
    }

    /// <summary>Deferred, and resolved then: a selection made before the grab lands keeps focus.</summary>
    public void FocusSelected() => Callable.From(() =>
    {
        if (!IsVisibleInTree() || _buttons.Count == 0) return;
        int index = _buttons.FindIndex(b => IsInstanceValid(b) && (string)b.GetMeta(IdMeta) == _selected);
        _buttons[Math.Max(0, index)].GrabFocus();
    }).CallDeferred();

    private const string IdMeta = "species";

    /// <summary>The floors' creature pools in floor order, then any met species outside them.</summary>
    public static IReadOnlyList<(string Id, string Name)> CampaignPool(MonsterJournal? journal)
        => CampaignFloors(journal).SelectMany(f => f.Species).ToList();

    /// <summary>The campaign pool grouped by the floor each species first appears on. Met species
    /// from outside every floor's roster come last under "Elsewhere".</summary>
    public static IReadOnlyList<(string Floor, IReadOnlyList<(string Id, string Name)> Species)> CampaignFloors(MonsterJournal? journal)
    {
        var floors = new List<(string, IReadOnlyList<(string, string)>)>();
        var seen = new HashSet<string>();
        for (int stratum = 0; stratum < FloorThemes.Count; stratum++)
        {
            var theme = FloorThemes.ForStratum(stratum);
            var species = new List<(string, string)>();
            foreach (var creature in theme.Roster)
            {
                string id = MonsterJournal.Key(creature.Slug);
                if (seen.Add(id)) species.Add((id, creature.DisplayName));
            }
            if (species.Count > 0) floors.Add((theme.DisplayName, species));
        }
        var elsewhere = (journal?.Encountered ?? Array.Empty<(string, string)>()).Where(s => seen.Add(s.Id)).ToList();
        if (elsewhere.Count > 0) floors.Add(("Elsewhere", elsewhere));
        return floors;
    }

    private bool Met(string id) => _journal?.IsEncountered(id) == true;

    private void RefreshIndex()
    {
        foreach (var child in _entries.GetChildren()) { _entries.RemoveChild(child); child.QueueFree(); }
        _buttons.Clear();
        var floors = CampaignFloors(_journal);
        _species = floors.SelectMany(f => f.Species).ToList();
        GetNode<Label>("%BestiarySummary").Text = $"Met {MetCount} of {_species.Count}";
        foreach (var (floor, species) in floors)
        {
            int met = species.Count(s => Met(s.Id));
            _entries.AddChild(new Label { Text = $"{floor}  {met} / {species.Count}", ThemeTypeVariation = ThemeNames.SheetCaption });
            var grid = new GridContainer { Columns = TileColumns };
            grid.AddThemeConstantOverride("h_separation", 12);
            grid.AddThemeConstantOverride("v_separation", 12);
            _entries.AddChild(grid);
            foreach (var (id, name) in species) grid.AddChild(BuildTile(id, name));
        }
        _empty.Visible = _species.Count == 0;
        if (_selected == null || _species.All(s => s.Id != _selected))
            _selected = _species.FirstOrDefault(s => Met(s.Id)).Id ?? _species.FirstOrDefault().Id;
        RenderPage();
    }

    private Button BuildTile(string id, string name)
    {
        var button = TileScene!.Instantiate<Button>();
        bool met = Met(id);
        button.SetMeta(IdMeta, id);
        button.TooltipText = met ? name : Unknown;
        button.FocusEntered += () => Select(id);
        button.Pressed += () => Select(id);
        var sprite = button.GetNode<TextureRect>("Sprite");
        var def = met ? _lookup(_journal!.NameFor(id)) : _lookup(name);
        var size = def?.StatBlock.CreatureSize ?? CreatureSize.Medium;
        string folder = EnemySpriteMap.FolderForCreature(name, size);
        // A species with no art yet shows a plain "?" rather than the placeholder sheet's box.
        var texture = folder == EnemySpriteMap.PlaceholderFolder(size) ? null : Trimmed(UnitPortraits.EnemyIdleFrame(folder));
        if (texture == null) button.Text = Unknown[..1];
        sprite.Texture = texture;
        sprite.CustomMinimumSize = texture == null ? Vector2.Zero : texture.GetSize() * TileScale(texture);
        sprite.SelfModulate = met ? sprite.SelfModulate : UiColors.Ink;
        _buttons.Add(button);
        return button;
    }

    /// <summary>The tallest a tile's sprite may draw before it touches the tile's frame.</summary>
    [Export] public int TileSpriteCap { get; set; } = 116;

    /// <summary>The whole scale nearest <see cref="TileSpriteHeight"/> that stays under
    /// <see cref="TileSpriteCap"/>, so a 60 px goblin draws at 2x rather than 1x.</summary>
    private float TileScale(Texture2D texture)
    {
        int tall = Math.Max(texture.GetHeight(), texture.GetWidth());
        if (tall >= TileSpriteCap) return TileSpriteCap / (float)tall;
        int scale = Math.Max(1, (int)Math.Round(TileSpriteHeight / (double)tall));
        while (scale > 1 && tall * scale > TileSpriteCap) scale--;
        return scale;
    }

    private static readonly Dictionary<Texture2D, Texture2D> TrimCache = new();

    /// <summary>The frame cut to its opaque pixels, so a rat and a bear fill a tile at their own
    /// whole scales instead of sitting small inside the same padded cell.</summary>
    private static Texture2D? Trimmed(Texture2D? texture)
    {
        if (texture == null) return null;
        if (TrimCache.TryGetValue(texture, out var cached)) return cached;
        var used = texture.GetImage()?.GetUsedRect() ?? new Rect2I();
        Texture2D trimmed = used.Size.X <= 0 || used.Size == texture.GetSize() ? texture : texture is AtlasTexture atlas
            ? new AtlasTexture { Atlas = atlas.Atlas, Region = new Rect2(atlas.Region.Position + used.Position, used.Size) }
            : new AtlasTexture { Atlas = texture, Region = new Rect2(used.Position, used.Size) };
        return TrimCache[texture] = trimmed;
    }

    /// <summary>The largest whole scale that keeps <paramref name="texture"/> under
    /// <paramref name="height"/>, or the fraction that fits when even 1x is too tall.</summary>
    public static float WholeScale(Texture2D texture, int height)
    {
        int tall = Math.Max(texture.GetHeight(), texture.GetWidth());
        return tall > height ? height / (float)tall : Math.Max(1, height / tall);
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
        var focusName = GetNode<Label>("%BestiaryFocusName");
        if (entry.Id == null || _journal == null) { PageFacts = Array.Empty<JournalFact>(); focusName.Text = ""; return; }
        bool met = Met(entry.Id);
        string name = met ? _journal.NameFor(entry.Id) : entry.Name;
        var def = _lookup(name);
        PageFacts = CreatureFacts.Facts(def, def?.StatBlock ?? default, field => met && def != null && _journal.IsFieldRevealed(entry.Id, field));
        GetNode<Label>("%BestiaryTitle").Text = met ? name : Unknown;
        focusName.Text = met ? name : Unknown;
        var identity = GetNode<Label>("%BestiaryIdentity");
        identity.Visible = met && def != null;
        if (def != null) identity.Text = Identity(def, _journal.IsFieldRevealed(entry.Id, CreatureKnowledgeField.Traits));
        var known = GetNode<Label>("%BestiaryKnown");
        known.Text = met ? $"Known {_journal.KnownCount(entry.Id)} of {MonsterJournal.TotalFields}" : "Not met yet";
        _facts.Render(PageFacts);
        RenderPortrait(name, def, met);
    }

    /// <summary>"Level -1 · Goblin, Humanoid". The level shows once the species is met; the traits
    /// wait for the journal's Traits field, like every other fact.</summary>
    public static string Identity(EnemyDefinition def, bool traitsKnown)
    {
        var traits = traitsKnown
            ? def.CreatureTraits?.Traits.Select(t => t.DisplayName).Where(t => !string.IsNullOrEmpty(t)).ToList() ?? new List<string>()
            : new List<string>();
        string level = $"Level {def.StatBlock.CreatureLevel}";
        return traits.Count == 0 ? level : $"{level} · {string.Join(", ", traits)}";
    }

    /// <summary>The idle frame at the largest whole scale under <see cref="PortraitHeight"/>; a species
    /// not met yet draws as a solid dark silhouette of the same frame.</summary>
    private void RenderPortrait(string name, EnemyDefinition? def, bool met)
    {
        var size = def?.StatBlock.CreatureSize ?? CreatureSize.Medium;
        var texture = Trimmed(UnitPortraits.EnemyIdleFrame(EnemySpriteMap.FolderForCreature(name, size)));
        _portrait.Texture = texture;
        _portrait.CustomMinimumSize = texture == null ? Vector2.Zero : texture.GetSize() * WholeScale(texture, PortraitHeight);
        PortraitSilhouette = !met;
        _portrait.SelfModulate = met ? _portraitTint : UiColors.Ink;
    }
}
