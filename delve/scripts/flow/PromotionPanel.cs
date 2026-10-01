using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Combat;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// The progression page, laid out like a rank ladder: the member and what the next level brings
/// ("HP 32 → 42") on the left, the feats by level in class and archetype columns in the middle,
/// and the picked feat's rules with Confirm on the right. Learned feats stay in place as the build
/// record. Selecting a card only previews; only Confirm writes to the live member.
/// </summary>
public partial class PromotionPanel : PanelContainer
{
    [Export] public PackedScene CardScene { get; set; } = null!;
    [Export] public PackedScene FigureScene { get; set; } = null!;

    /// <summary>The tallest the rail portrait may draw, at a whole scale.</summary>
    [Export] public int PortraitHeight { get; set; } = 216;

    public event Action? Promoted;
    private PF2eCharacter? _character;
    private string? _selected;
    private string? _shown;
    private int _revision;
    private GridContainer _tree = null!;
    private Label _heading = null!;
    private Label _summary = null!;
    private Button _confirm = null!;
    private Button _save = null!;
    private readonly Dictionary<string, Button> _cards = new();
    private readonly List<Button> _choosable = new();
    private readonly Dictionary<(string, int), PF2eCharacter?> _fresh = new();

    public bool PreviewShown => _shown != null;
    public Button? Card(string featId) => _cards.GetValueOrDefault(featId);
    public IReadOnlyList<FigureView> Gains { get; private set; } = Array.Empty<FigureView>();

    /// <summary>The rail's level pair as read: "3 → 4" while a promotion waits, else "3".</summary>
    public string LevelText { get; private set; } = "";

    public override void _Ready()
    {
        _tree = GetNode<GridContainer>("%FeatTree");
        _heading = GetNode<Label>("%PromotionHeading");
        _summary = GetNode<Label>("%PromotionSummary");
        _confirm = GetNode<Button>("%ConfirmPromotion");
        _save = GetNode<Button>("%SaveFeatChoice");
        _confirm.Pressed += Confirm;
        _save.Pressed += SaveChoice;
    }

    public void ShowCharacter(PF2eCharacter character)
    {
        _character = character;
        _selected = null;
        Render();
        UiFocus.GrabFirst(_choosable.Count > 0 ? _choosable : _cards.Values);
    }

    private void Render()
    {
        if (_character is not { } c) return;
        var state = CharacterPromotion.For(c);
        _revision = state.Revision;
        int target = state.ChoiceLevel(c);
        int pending = state.PendingLevels(c);
        bool canChoose = state.HasChoice(c) && !c.Health.IsDead;
        RenderRail(c, target, pending, state.SavedChoices.Count);
        ShowDetail(null, "", "", null);
        _confirm.Disabled = true;
        _confirm.Text = pending > 0 ? $"Promote to level {target}" : "Confirm promotion";

        foreach (var child in _tree.GetChildren()) { _tree.RemoveChild(child); child.QueueFree(); }
        _cards.Clear();
        _choosable.Clear();
        var options = PromotionFeats.For(c);
        bool archetypes = options.Any(o => !IsClassFeat(o));
        GetNode<Control>("%ArchetypeCaption").Visible = archetypes;
        _tree.Columns = archetypes ? 3 : 2;
        var group = new ButtonGroup { AllowUnpress = false };
        foreach (int level in options.Select(o => o.Level).Distinct().OrderBy(l => l))
        {
            _tree.AddChild(new Label { Text = $"Lv {level}", ThemeTypeVariation = ThemeNames.HeadingLabel,
                CustomMinimumSize = new Vector2(72, 0), VerticalAlignment = VerticalAlignment.Center });
            foreach (bool classColumn in archetypes ? new[] { true, false } : new[] { true })
            {
                var cell = new VBoxContainer { SizeFlagsHorizontal = SizeFlags.ExpandFill };
                cell.AddThemeConstantOverride("separation", 8);
                _tree.AddChild(cell);
                foreach (var feat in options.Where(o => o.Level == level && IsClassFeat(o) == classColumn))
                    cell.AddChild(BuildCard(c, feat, target, pending, canChoose, group));
            }
        }
        _save.Visible = pending > 0 && !c.Health.IsDead
            && options.All(f => PromotionFeats.LockReason(c, f, target) != null);
        if (_save.Visible)
        {
            _summary.Text += "\nNo unlearned feat is available at this level. You can promote and keep the choice for later.";
            _save.Text = $"Promote to level {target} · Keep feat choice";
        }
        // The detail pane opens on the first feat the player can take, read but not picked.
        if (_choosable.FirstOrDefault() is { } first) first.EmitSignal(Control.SignalName.FocusEntered);
    }

    private static bool IsClassFeat(PromotionFeats.Option feat) => feat.Source == "Class feat";

    private Button BuildCard(PF2eCharacter c, PromotionFeats.Option feat, int target, int pending, bool canChoose, ButtonGroup group)
    {
        var feature = feat.Build();
        var tip = HeroSheetGearTips.Feature(feature);
        string rules = string.Join("\n", (tip.Meta ?? Array.Empty<SheetMetaRow>()).Select(m => $"{m.Label}: {m.Text}")
            .Append(tip.Body).Where(line => line.Length > 0));
        string? reason = PromotionFeats.LockReason(c, feat, target);
        bool learned = PromotionFeats.Learned(c, feat.Id);
        int learnedAt = c.Features.ChosenFeats.Concat(c.Features.FreeArchetypeFeats)
            .FirstOrDefault(f => f.Feature.FeatureId.Replace('_', '-') == feat.Id)?.Level ?? feat.Level;
        string status = learned ? $"Learned at level {learnedAt}" : reason ?? (canChoose ? "Available" : "Next choice");
        bool open = reason == null && !learned && canChoose;

        var card = CardScene.Instantiate<Button>();
        card.Name = feat.Id;
        card.ButtonGroup = group;
        card.Text = $"{feature.DisplayName}\n{status}";
        card.TooltipText = $"{feat.Theme} · {feat.Source}";
        card.ThemeTypeVariation = open ? ThemeNames.AccentButton : reason != null && !learned ? ThemeNames.FeatCardLocked : "";
        string meta = $"{feat.Source} · Level {feat.Level} · {feat.Theme}";
        card.Pressed += () =>
        {
            _selected = open ? feat.Id : null;
            ShowDetail(feature.DisplayName, meta, rules, learned ? status : reason);
            _confirm.Text = pending > 0 ? $"Promote to level {target} · {feature.DisplayName}" : $"Learn {feature.DisplayName}";
            _confirm.Disabled = _selected == null;
            if (_selected != null) UiFocus.Grab(_confirm);
        };
        card.FocusEntered += () => ShowDetail(feature.DisplayName, meta, rules, learned ? status : reason);
        _cards[feat.Id] = card;
        if (open) _choosable.Add(card);
        return card;
    }

    /// <summary>The member, their identity from the sheet, and what the next level changes.</summary>
    private void RenderRail(PF2eCharacter c, int target, int pending, int saved)
    {
        var portrait = GetNode<TextureRect>("%PromotionPortrait");
        portrait.Texture = HeroPortraits.For(c.Id);
        portrait.CustomMinimumSize = portrait.Texture == null ? Vector2.Zero
            : portrait.Texture.GetSize() * BestiaryPanel.WholeScale(portrait.Texture, PortraitHeight);
        _heading.Text = c.Name;
        GetNode<Label>("%PromotionIdentity").Text = HeroSheetBuilder.Read(c).Subtitle;

        var gains = GetNode<VBoxContainer>("%PromotionGains");
        foreach (var child in gains.GetChildren()) { gains.RemoveChild(child); child.QueueFree(); }
        Gains = pending > 0 && FreshAt(c.Id, c.Stats.Level) is { } now && FreshAt(c.Id, target) is { } next
            ? PromotionGains.Between(c, now, next) : Array.Empty<FigureView>();
        var level = new FigureView("Level", pending > 0 ? target.ToString() : c.Stats.Level.ToString())
            { Before = pending > 0 ? c.Stats.Level.ToString() : "" };
        LevelText = level.IsChange ? $"{level.Before} → {level.Value}" : level.Value;
        foreach (var figure in Gains.Prepend(level))
        {
            var label = FigureScene.Instantiate<FigureLabel>();
            gains.AddChild(label);
            label.Render(figure);
        }

        _summary.Text = c.Health.IsDead ? "This character cannot be promoted while dead."
            : pending > 0 ? (pending == 1 ? "Pick one feat, then promote." : $"{pending} promotions wait. Pick one feat for each.")
            : saved > 0 ? $"Unspent feat choices: {saved}. Your level stays the same."
            : "Your build is up to date. Earn XP to unlock the next promotion.";
    }

    /// <summary>The same character built fresh at <paramref name="level"/>, for the level-up pairs.</summary>
    private PF2eCharacter? FreshAt(string id, int level)
    {
        if (_fresh.TryGetValue((id, level), out var cached)) return cached;
        PF2eCharacter? built = null;
        try { built = CharacterCatalog.Find(id)?.Builder(level); }
        catch (Exception e) { GD.PushWarning($"[Promotion] Could not preview '{id}' at level {level}: {e.Message}"); }
        return _fresh[(id, level)] = built;
    }

    private void ShowDetail(string? title, string meta, string rules, string? note)
    {
        _shown = title;
        GetNode<Label>("%FeatTitle").Text = title ?? "Choose a feat";
        GetNode<Label>("%FeatMeta").Text = meta;
        GetNode<Label>("%FeatPreview").Text = title == null ? "Select a feat to read its rules. Nothing changes until you promote." : rules;
        var reason = GetNode<Label>("%FeatReason");
        reason.Text = note ?? "";
        reason.Visible = !string.IsNullOrEmpty(note);
    }

    private void Confirm()
    {
        if (_character is not { } c || _selected == null || _confirm.Disabled) return;
        if (!CharacterPromotion.For(c).Confirm(c, _selected, _revision, out string error))
        { _selected = null; Render(); ShowDetail("Could not promote", "", error, null); return; }
        _selected = null;
        Render();
        Promoted?.Invoke();
    }

    private void SaveChoice()
    {
        if (_character is not { } c || !_save.Visible) return;
        if (!CharacterPromotion.For(c).SaveChoiceAndPromote(c, _revision, out string error))
        { Render(); ShowDetail("Could not promote", "", error, null); return; }
        Render();
        Promoted?.Invoke();
    }
}
