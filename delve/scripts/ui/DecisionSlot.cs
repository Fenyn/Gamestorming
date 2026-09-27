using System;
using System.Collections.Generic;
using Delve.Combat;
using Godot;

namespace Delve.UI;

/// <summary>
/// The one decision slot above the action bar: the attack, spell or skill forecast as labelled
/// figures and tags, and under it the hint line (targeting keys, Delay pick, the hovered move's
/// cost as pips) with the multi-target Cast and staged-order Confirm buttons. The forecast's full
/// sentences are the card's hover. Passive: renders what the action bar forwards and raises intents.
/// </summary>
public partial class DecisionSlot : VBoxContainer
{
    [Export] public PackedScene? FigureScene { get; set; }

    public event Action? ConfirmTargetsPressed;
    public event Action? ConfirmOrderPressed;

    private const string TargetingHint = "LMB  confirm · Esc  cancel";
    private const string DelayPickHint = "LMB  a turn chip to act after · Esc  cancel";

    private PanelContainer _card = null!;
    private Label _header = null!;
    private HBoxContainer _tags = null!;
    private HFlowContainer _figures = null!;
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

    public override void _Ready()
    {
        _card = GetNode<PanelContainer>("%PreviewCard");
        _header = GetNode<Label>("%PreviewHeaderLabel");
        _tags = GetNode<HBoxContainer>("%Tags");
        _figures = GetNode<HFlowContainer>("%Figures");
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
        var tags = new List<string>(preview.Tags);
        if (preview.Figures.Count == 0 && preview.TargetOffGuard) tags.Add("Off-guard");
        foreach (string tag in tags)
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
            _hint.Text = _targetLimit > 1
                ? $"{_selectedTargets} / {_targetLimit} targets · Casts at {_targetLimit} · Enter cast fewer · Esc cancel"
                : _pickingDelaySlot ? DelayPickHint : TargetingHint;
        else if (_moveHover == null) _hint.Text = "";
        else
        {
            _hint.Text = _moveHover.Kind == MoveKind.Step ? "Step" : "Stride";
            _moveCost.SetCost(_moveHover.Actions, enabled: true);
            _moveCost.Visible = true;
        }
        _hint.Visible = _hint.Text.Length > 0;
        _hintRow.Visible = _hint.Visible || _confirmTargets.Visible || _confirmOrder.Visible;
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
