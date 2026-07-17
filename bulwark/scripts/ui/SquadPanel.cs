using System;
using System.Collections.Generic;
using Bulwark.Cozy;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Passive squad panel for out-of-combat Treat Wounds: shows the four members (name, HP, notable
/// conditions), and drives the pick-target → pick-healer → pick-DC → confirm flow. Renders only the
/// <see cref="SquadPanelView"/> pushed via <see cref="Render"/> and raises the
/// <see cref="TreatWoundsRequested"/> intent — no game rules, no engine types, per CLAUDE.md.
/// The host scene reacts to <see cref="Toggled"/> to freeze the player and the day clock while the
/// panel is open; the full-rect backdrop (MouseFilter.Stop) swallows mouse events meanwhile.
/// Toggled by the "toggle_squad_panel" input action (C); Esc closes.
/// </summary>
public partial class SquadPanel : TogglePanel
{
    private const int MemberCount = 4;

    /// <summary>Intent: player confirmed a treatment (healerId, targetId, dc).</summary>
    public event Action<string, string, int>? TreatWoundsRequested;

    private readonly Label[] _nameLabels = new Label[MemberCount];
    private readonly ProgressBar[] _hpBars = new ProgressBar[MemberCount];
    private readonly Label[] _hpLabels = new Label[MemberCount];
    private readonly Label[] _condLabels = new Label[MemberCount];
    private readonly Label[] _immuneLabels = new Label[MemberCount];
    private readonly Button[] _treatButtons = new Button[MemberCount];
    private readonly Button[] _healerButtons = new Button[MemberCount];
    private readonly Button[] _dcButtons = new Button[MemberCount];

    private Control _flowSection = null!;
    private Label _flowLabel = null!;
    private Button _confirmButton = null!;
    private Button _cancelButton = null!;
    private Label _resultLabel = null!;

    private SquadPanelView? _view;
    private string? _targetId;
    private string? _healerId;
    private int _dc; // 0 = none selected

    public SquadPanel() => ToggleAction = "toggle_squad_panel";

    public override void _Ready()
    {
        for (int i = 0; i < MemberCount; i++)
        {
            _nameLabels[i] = GetNode<Label>($"%Name{i}");
            _hpBars[i] = GetNode<ProgressBar>($"%HpBar{i}");
            _hpLabels[i] = GetNode<Label>($"%Hp{i}");
            _condLabels[i] = GetNode<Label>($"%Cond{i}");
            _immuneLabels[i] = GetNode<Label>($"%Immune{i}");
            _treatButtons[i] = GetNode<Button>($"%Treat{i}");
            _healerButtons[i] = GetNode<Button>($"%Healer{i}");
            _dcButtons[i] = GetNode<Button>($"%Dc{i}");

            int index = i; // capture per-button
            _treatButtons[i].Pressed += () => OnTreatPressed(index);
            _healerButtons[i].Pressed += () => OnHealerPressed(index);
            _dcButtons[i].Pressed += () => OnDcPressed(index);
        }

        _flowSection = GetNode<Control>("%FlowSection");
        _flowLabel = GetNode<Label>("%FlowLabel");
        _confirmButton = GetNode<Button>("%ConfirmButton");
        _cancelButton = GetNode<Button>("%CancelButton");
        _resultLabel = GetNode<Label>("%ResultLabel");

        _confirmButton.Pressed += OnConfirmPressed;
        _cancelButton.Pressed += ClearSelection;

        Visible = false;
    }

    /// <summary>Render a fresh view-model. Selections that became invalid are dropped.</summary>
    public void Render(SquadPanelView view)
    {
        _view = view;

        // Drop a selection the new state no longer supports (target healed up / became immune,
        // healer died); the result readout stays so the player sees what just happened.
        if (_targetId != null && FindMember(_targetId)?.CanBeTreated != true)
            _targetId = null;
        if (_healerId != null && (FindMember(_healerId)?.DcOptions.Count ?? 0) == 0)
            _healerId = null;

        for (int i = 0; i < MemberCount; i++)
        {
            if (i >= view.Members.Count)
            {
                SetRowVisible(i, false);
                continue;
            }
            SetRowVisible(i, true);

            var m = view.Members[i];
            _nameLabels[i].Text = m.Name;
            _hpLabels[i].Text = m.IsDead ? "Dead" : $"{m.CurrentHp}/{m.MaxHp}";
            RenderHpBar(_hpBars[i], m.CurrentHp, m.MaxHp);
            _condLabels[i].Text = m.ConditionsText;

            bool immune = m.ImmunityMinutesRemaining > 0;
            _immuneLabels[i].Visible = immune;
            _immuneLabels[i].Text = immune ? $"Immune {m.ImmunityMinutesRemaining}m" : "";
            _treatButtons[i].Visible = !immune;
            _treatButtons[i].Disabled = !m.CanBeTreated;
            _treatButtons[i].SetPressedNoSignal(m.Id == _targetId);
        }

        RenderFlow();
    }

    /// <summary>Show the outcome of the last treatment (pushed by the host from the command event).</summary>
    public void ShowResult(TreatWoundsResultView r)
    {
        string effect = r.HealingOrDamage > 0
            ? $"healed {r.HealingOrDamage} HP ({r.HealingFormula})"
            : r.HealingOrDamage < 0
                ? $"dealt {-r.HealingOrDamage} damage ({r.HealingFormula})"
                : "no effect";
        string wounded = r.RemovedWounded ? " Wounded removed." : "";
        _resultLabel.Text =
            $"{r.HealerName} treats {r.TargetName} — d20 {r.D20Roll} = {r.Total} vs DC {r.Dc}: "
            + $"{r.DegreeText} — {effect}.{wounded} "
            + $"Took {r.MinutesSpent} min; immune for {r.ImmunityMinutesRemaining} min.";
    }

    /// <summary>Pure presentation: bar value + green→amber→red fill tint by remaining-HP ratio.</summary>
    private static void RenderHpBar(ProgressBar bar, int currentHp, int maxHp)
    {
        bar.MaxValue = Math.Max(1, maxHp);
        bar.Value = Math.Clamp(currentHp, 0, Math.Max(1, maxHp));

        float ratio = maxHp > 0 ? (float)currentHp / maxHp : 0f;
        // HP bar fill tint by remaining-HP ratio (shared warm palette).
        Color fillColor = ratio > 0.5f ? UiPalette.HpGreen : ratio > 0.25f ? UiPalette.HpAmber : UiPalette.HpRed;
        if (bar.GetThemeStylebox("fill") is StyleBoxFlat themed)
        {
            var fill = (StyleBoxFlat)themed.Duplicate();
            fill.BgColor = fillColor;
            bar.AddThemeStyleboxOverride("fill", fill);
        }
    }

    // ------------------------------------------------------------------ Flow (view state only)

    private void OnTreatPressed(int index)
    {
        var m = MemberAt(index);
        if (m == null || !m.CanBeTreated)
            return;

        _targetId = m.Id;
        // Default healer: highest Medicine bonus among the living (built by the system).
        if (_healerId == null || FindMember(_healerId) == null)
            _healerId = _view?.DefaultHealerId;
        _dc = FirstDcOf(_healerId);
        RenderFlow();
    }

    private void OnHealerPressed(int index)
    {
        var m = MemberAt(index);
        if (m == null || m.DcOptions.Count == 0)
            return;

        _healerId = m.Id;
        _dc = FirstDcOf(_healerId);
        RenderFlow();
    }

    private void OnDcPressed(int index)
    {
        var healer = FindMember(_healerId);
        if (healer == null || index >= healer.DcOptions.Count)
            return;

        _dc = healer.DcOptions[index].Dc;
        RenderFlow();
    }

    private void OnConfirmPressed()
    {
        if (_targetId == null || _healerId == null || _dc <= 0)
            return;

        TreatWoundsRequested?.Invoke(_healerId, _targetId, _dc);
        // The command's change events re-render the panel; selection resets for the next flow.
        _targetId = null;
    }

    private void ClearSelection()
    {
        _targetId = null;
        _dc = 0;
        RenderFlow();
        Render(_view ?? new SquadPanelView());
    }

    private void RenderFlow()
    {
        bool hasTarget = _targetId != null;
        _flowSection.Visible = hasTarget;
        _flowLabel.Text = hasTarget
            ? $"Treating {FindMember(_targetId!)?.Name} — choose healer and DC:"
            : "";

        if (!hasTarget)
            return;

        var healer = FindMember(_healerId);
        for (int i = 0; i < MemberCount; i++)
        {
            var m = MemberAt(i);
            bool usable = m is { IsDead: false } && m.DcOptions.Count > 0;
            _healerButtons[i].Visible = m != null;
            _healerButtons[i].Disabled = !usable;
            _healerButtons[i].Text = m == null ? "" : $"{m.Name} ({Signed(m.MedicineBonus)})";
            _healerButtons[i].SetPressedNoSignal(m != null && m.Id == _healerId);
        }

        var options = healer?.DcOptions ?? new List<DcOptionView>();
        for (int i = 0; i < MemberCount; i++)
        {
            bool has = i < options.Count;
            _dcButtons[i].Visible = has;
            if (!has)
                continue;
            _dcButtons[i].Text = $"DC {options[i].Dc} — {options[i].SuccessFormula}";
            _dcButtons[i].SetPressedNoSignal(options[i].Dc == _dc);
        }

        _confirmButton.Disabled = healer == null || _dc <= 0;
    }

    /// <summary>Opening resets the treat-wounds selection flow so a stale pick from the last visit
    /// never lingers. Host reacts to <see cref="TogglePanel.Toggled"/>: pauses the day clock + player
    /// input, and pushes a fresh view when opening.</summary>
    protected override void SetOpen(bool open)
    {
        if (open && !Visible)
        {
            _targetId = null;
            _healerId = null;
            _dc = 0;
            _resultLabel.Text = "";
        }
        base.SetOpen(open);
    }

    private void SetRowVisible(int i, bool visible)
    {
        _nameLabels[i].GetParent<Control>().Visible = visible;
    }

    private SquadMemberView? MemberAt(int index)
        => _view != null && index < _view.Members.Count ? _view.Members[index] : null;

    private SquadMemberView? FindMember(string? id)
        => id == null ? null : _view?.Members.Find(m => m.Id == id);

    private int FirstDcOf(string? healerId)
    {
        var healer = FindMember(healerId);
        return healer != null && healer.DcOptions.Count > 0 ? healer.DcOptions[0].Dc : 0;
    }

    private static string Signed(int value) => value >= 0 ? $"+{value}" : value.ToString();
}
