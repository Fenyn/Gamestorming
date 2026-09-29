using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// The one decision slot above the action bar: the attack, spell or skill forecast as labelled
/// figures, tags and a line of labelled modifiers, and under it the hint line (targeting keys, Delay pick, the hovered move's
/// cost as pips, or why the actor cannot Stride) with the multi-target Cast and staged-order Confirm buttons. The forecast's full
/// sentences are the card's hover. Passive: renders what the action bar forwards and raises intents.
/// </summary>
public partial class DecisionSlot : VBoxContainer
{
    [Export] public PackedScene? FigureScene { get; set; }
    [Export] public ConditionIconSet? Icons { get; set; }
    [Export] public int ModifierIconSize { get; set; } = 22;

    public event Action? ConfirmTargetsPressed;
    public event Action? ConfirmOrderPressed;

    private const string DelayPickHint = "Act after";

    private PanelContainer _card = null!;
    private Label _header = null!;
    private HBoxContainer _tags = null!;
    private HFlowContainer _figures = null!;
    private HFlowContainer _modifiers = null!;
    private Label _stats = null!;
    private Label _detail = null!;
    private Control _hintRow = null!;
    private Label _hint = null!;
    private PipRow _moveCost = null!;
    private Button _confirmTargets = null!;
    private Button _confirmOrder = null!;

    private bool _interactable = true;
    private bool _targeting;
    private bool _pickingDelaySlot;
    private MoveHoverView? _moveHover;
    private string? _moveRestriction;
    private int _selectedTargets;
    private int _targetLimit;

    public Control Card => _card;
    public string HintText => _hint.Text;
    public Button ConfirmTargetsButton => _confirmTargets;
    public Button ConfirmOrderButton => _confirmOrder;
    public bool CanConfirmTargets => _confirmTargets.Visible && !_confirmTargets.Disabled;

    public IReadOnlyList<FigureLabel> FigureLabels
    {
        get
        {
            var labels = new List<FigureLabel>();
            foreach (var child in _figures.GetChildren())
                if (child is FigureLabel label) labels.Add(label);
            return labels;
        }
    }

    /// <summary>The modifier line as drawn: "MAP -5", "Off-guard (Prone) +2".</summary>
    public IReadOnlyList<string> ModifierTexts
    {
        get
        {
            var texts = new List<string>();
            foreach (var item in _modifiers.GetChildren())
                foreach (var child in item.GetChildren())
                    if (child is Label label) texts.Add(label.Text);
            return texts;
        }
    }

    public override void _Ready()
    {
        _card = GetNode<PanelContainer>("%PreviewCard");
        _header = GetNode<Label>("%PreviewHeaderLabel");
        _tags = GetNode<HBoxContainer>("%Tags");
        _figures = GetNode<HFlowContainer>("%Figures");
        _modifiers = GetNode<HFlowContainer>("%Modifiers");
        _stats = GetNode<Label>("%PreviewStatsLabel");
        _detail = GetNode<Label>("%PreviewDetailLabel");
        _hintRow = GetNode<Control>("%HintRow");
        _hint = GetNode<Label>("%TargetingHint");
        _moveCost = GetNode<PipRow>("%MoveCostPips");
        _confirmTargets = GetNode<Button>("%ConfirmTargets");
        _confirmOrder = GetNode<Button>("%ConfirmOrder");
        _confirmTargets.Pressed += () => ConfirmTargetsPressed?.Invoke();
        _confirmOrder.Pressed += () => ConfirmOrderPressed?.Invoke();
        RefreshHint();
    }

    public void ShowPreview(AttackPreviewView? preview)
    {
        _card.Visible = preview != null;
        if (preview == null) return;

        _header.Text = preview.HeaderText ?? $"{preview.WeaponName} → {preview.TargetName}";
        Clear(_tags);
        foreach (string tag in preview.Tags)
        {
            var chip = new PanelContainer { ThemeTypeVariation = ThemeNames.TraitChip, MouseFilter = MouseFilterEnum.Ignore };
            chip.AddChild(new Label { Text = tag, ThemeTypeVariation = ThemeNames.TipTag, MouseFilter = MouseFilterEnum.Ignore });
            _tags.AddChild(chip);
        }

        Clear(_figures);
        if (FigureScene != null)
            foreach (var figure in preview.Figures)
            {
                var label = FigureScene.Instantiate<FigureLabel>();
                _figures.AddChild(label);
                label.Render(figure);
            }
        bool compact = _figures.GetChildCount() > 0;
        _figures.Visible = compact;
        RenderModifiers(preview.Modifiers);

        string outcome = preview.OutcomeText ?? $"{preview.HitChanceText} hit · {preview.CritChanceText} critical hit";
        string detail = preview.DetailText ??
            $"Attack {preview.TotalAttackBonus:+0;-0;0} vs AC {preview.TargetAcText} · {preview.DamageFormula} damage";
        _stats.Visible = !compact;
        _stats.Text = outcome;
        _detail.Visible = !compact && detail.Length > 0;
        _detail.Text = detail;
        _card.TooltipText = $"{outcome}\n{detail}".Trim();
    }

    public void SetInteractable(bool interactable)
    {
        _interactable = interactable;
        RefreshHint();
    }

    public void SetTargeting(bool targeting, bool pickingDelaySlot)
    {
        _targeting = targeting;
        _pickingDelaySlot = pickingDelaySlot;
        RefreshHint();
    }

    public void SetMoveHover(MoveHoverView? hover)
    {
        _moveHover = hover;
        RefreshHint();
    }

    /// <summary>Why the actor cannot Stride ("Prone: Crawl 5 ft or Stand"). Shown while no band
    /// tile is hovered; null clears it.</summary>
    public void SetMoveRestriction(string? restriction)
    {
        _moveRestriction = restriction;
        RefreshHint();
    }

    public void SetSpellTargetSelection(int count, int limit)
    {
        _selectedTargets = count;
        _targetLimit = limit;
        RefreshHint();
    }

    public void SetStaged(bool staged)
    {
        _confirmOrder.Visible = staged;
        RefreshHint();
    }

    private void RefreshHint()
    {
        _confirmTargets.Visible = _interactable && _targetLimit > 1;
        _confirmTargets.Disabled = !_interactable || _selectedTargets == 0;
        _moveCost.Visible = false;
        if (!_interactable) _hint.Text = "";
        else if (_targeting)
            _hint.Text = _targetLimit > 1 ? $"Targets {_selectedTargets} / {_targetLimit}"
                : _pickingDelaySlot ? DelayPickHint : "";
        else if (_moveHover == null) _hint.Text = _moveRestriction ?? "";
        else
        {
            _hint.Text = _moveHover.Kind.ToString();
            _moveCost.SetCost(_moveHover.Actions, enabled: true);
            _moveCost.Visible = true;
        }
        _hint.Visible = _hint.Text.Length > 0;
        _hintRow.Visible = _hint.Visible || _confirmTargets.Visible || _confirmOrder.Visible;
    }

    /// <summary>One labelled number per modifier, led by the icon of the condition that causes it.</summary>
    private void RenderModifiers(IReadOnlyList<ModifierChip> modifiers)
    {
        Clear(_modifiers);
        foreach (var modifier in modifiers)
        {
            var item = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
            if (modifier.IconKey.Length > 0 && Icons?.Tile(modifier.IconKey) is { } icon)
                item.AddChild(new TextureRect
                {
                    Texture = icon,
                    CustomMinimumSize = new Vector2(ModifierIconSize, ModifierIconSize),
                    ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
                    StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
                    TextureFilter = TextureFilterEnum.Nearest,
                    SizeFlagsVertical = SizeFlags.ShrinkCenter,
                    MouseFilter = MouseFilterEnum.Ignore,
                });
            item.AddChild(new Label { Text = modifier.Text, MouseFilter = MouseFilterEnum.Ignore });
            _modifiers.AddChild(item);
        }
        _modifiers.Visible = modifiers.Count > 0;
    }

    private static void Clear(Node parent)
    {
        foreach (var child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }
}
