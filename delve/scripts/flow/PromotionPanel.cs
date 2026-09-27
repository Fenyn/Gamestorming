using System;
using System.Linq;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>Character-sheet tree. Selecting a card previews; only Confirm writes to the live member.</summary>
public partial class PromotionPanel : PanelContainer
{
    [Export] public PackedScene CardScene { get; set; } = null!;
    public event Action? Promoted;
    private PF2eCharacter? _character;
    private string? _selected;
    private int _revision;
    private GridContainer _tree = null!;
    private Label _heading = null!;
    private Label _summary = null!;
    private Label _preview = null!;
    private Button _confirm = null!;
    private Button _save = null!;
    private readonly System.Collections.Generic.List<Button> _cards = new();
    private readonly System.Collections.Generic.List<Button> _choosable = new();

    public override void _Ready()
    {
        _tree = GetNode<GridContainer>("%FeatTree");
        _heading = GetNode<Label>("%PromotionHeading");
        _summary = GetNode<Label>("%PromotionSummary");
        _preview = GetNode<Label>("%FeatPreview");
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
        UiFocus.GrabFirst(_choosable.Count > 0 ? _choosable : _cards);
    }

    private void Render()
    {
        if (_character is not { } c) return;
        var state = CharacterPromotion.For(c);
        _revision = state.Revision;
        int target = state.ChoiceLevel(c);
        int pending = state.PendingLevels(c);
        bool canChoose = state.HasChoice(c) && !c.Health.IsDead;
        _heading.Text = $"{c.Name} · {PromotionFeats.Name(c.Id)} · "
            + (pending > 0 ? $"Level {c.Stats.Level} → {target}" : $"Level {c.Stats.Level}");
        _summary.Text = pending > 0
            ? (pending == 1 ? "One promotion is available." : $"{pending} promotions are available.")
                + " Choose one feat, then confirm. Earlier feats remain available.\n"
                + "Confirmation also applies this level's HP, proficiency, skill and spell progression."
            : state.SavedChoices.Count > 0
                ? "Spend an unspent choice on an available feat. Your level stays the same."
                : "Your build is up to date. Earn XP to unlock the next promotion.";
        if (state.SavedChoices.Count > 0)
            _summary.Text += $"\nUnspent feat choices: {state.SavedChoices.Count}.";
        if (c.Health.IsDead) _summary.Text = "This character cannot be promoted while dead.";
        _preview.Text = "Select a feat to read its effects. Nothing is granted until you confirm.";
        _confirm.Disabled = true;
        _confirm.Text = "Confirm promotion";
        foreach (var child in _tree.GetChildren()) { _tree.RemoveChild(child); child.QueueFree(); }
        _cards.Clear();
        _choosable.Clear();
        var options = PromotionFeats.For(c);
        var group = new ButtonGroup();
        foreach (var feat in options)
        {
            var feature = feat.Build();
            var card = CardScene.Instantiate<Button>();
            card.ToggleMode = true;
            card.ButtonGroup = group;
            var tip = HeroSheetGearTips.Feature(feature);
            string description = tip.Meta is { Count: > 0 }
                ? string.Join("\n", tip.Meta.Select(m => $"{m.Label}: {m.Text}")) : tip.Body;
            card.Name = feat.Id;
            string? reason = PromotionFeats.LockReason(c, feat, target);
            bool learned = PromotionFeats.Learned(c, feat.Id);
            int learnedAt = c.Features.ChosenFeats.Concat(c.Features.FreeArchetypeFeats)
                .FirstOrDefault(f => f.Feature.FeatureId.Replace('_', '-') == feat.Id)?.Level ?? feat.Level;
            string status = learned ? $"Learned at level {learnedAt}" : reason ?? (canChoose ? "Available" : "Next choice");
            card.Text = $"LEVEL {feat.Level} · {feat.Theme}\n{feature.DisplayName}\n{feat.Source} · {status}";
            card.TooltipText = description;
            card.Modulate = reason != null && !learned ? new Color(1, 1, 1, 0.6f) : Colors.White;
            card.Pressed += () =>
            {
                _selected = reason == null && canChoose ? feat.Id : null;
                _preview.Text = $"{feature.DisplayName} · {feat.Source} · Level {feat.Level}\n{description}"
                    + (reason != null ? $"\n{reason}" : "");
                _confirm.Text = pending > 0 ? $"Promote to level {target} · {feature.DisplayName}" : $"Learn {feature.DisplayName}";
                _confirm.Disabled = _selected == null;
                if (_selected != null) UiFocus.Grab(_confirm);
            };
            _tree.AddChild(card);
            _cards.Add(card);
            if (reason == null && !learned && canChoose) _choosable.Add(card);
        }
        _save.Visible = pending > 0 && !c.Health.IsDead
            && options.All(f => PromotionFeats.LockReason(c, f, target) != null);
        if (_save.Visible)
        {
            _summary.Text += "\nNo unlearned feat is available at this level. You can promote and keep the choice for later.";
            _save.Text = $"Promote to level {target} · Keep feat choice";
        }
    }

    private void Confirm()
    {
        if (_character is not { } c || _selected == null || _confirm.Disabled) return;
        if (!CharacterPromotion.For(c).Confirm(c, _selected, _revision, out string error))
        { _selected = null; Render(); _preview.Text = error; return; }
        _selected = null;
        Render();
        Promoted?.Invoke();
    }

    private void SaveChoice()
    {
        if (_character is not { } c || !_save.Visible) return;
        if (!CharacterPromotion.For(c).SaveChoiceAndPromote(c, _revision, out string error))
        { Render(); _preview.Text = error; return; }
        Render();
        Promoted?.Invoke();
    }
}
