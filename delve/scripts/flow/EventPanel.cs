using System;
using System.Collections.Generic;
using System.Linq;
using Delve.Run;
using Delve.Run.Events;
using Delve.UI;
using Godot;
using PF2e.Core;
using PF2e.Utilities;

namespace Delve.Flow;

/// <summary>
/// A Happenstance node, one decision at a time: the scene's prose, then its options with their
/// chance at a glance ("Elara 55%" or "No roll"). Only the selected option opens below: the check,
/// who tries (best suited first, already picked, any other member a click away) and what each degree
/// does. Attempt, or the selected option pressed again, commits; where a bonus comes from is in
/// hovers. Passive - the resolver runs in the flow layer, this only shows and signals.
/// </summary>
public partial class EventPanel : ScreenFrame
{
    private readonly List<(PF2eCharacter Actor, Button Button)> _actors = new();
    private readonly List<Button> _optionButtons = new();

    private Label _body = null!, _heading = null!, _result = null!;
    private VBoxContainer _options = null!;
    private Container _actorRow = null!;
    private RuledRows _outcomes = null!;
    private Button _attempt = null!, _continue = null!;
    private ButtonGroup _actorGroup = new();
    private EventDefinition? _definition;
    private Party? _party;
    private PF2eCharacter? _chosen;
    private int _selected;
    private bool _resolved;

    /// <summary>Option index plus the member the player named, or null to let the resolver pick.</summary>
    public event Action<int, PF2eCharacter?>? OptionPicked;

    public event Action? Continued;

    /// <summary>The option whose details show, for spikes.</summary>
    public int SelectedOption => _selected;

    /// <summary>The outcome rows on show, "Success: Heal 10% of maximum HP" one per line, for spikes.</summary>
    public string OutcomeText => _outcomes.Text;

    /// <summary>Rules drawn between the outcome rows, for spikes.</summary>
    public int OutcomeRules => _outcomes.Rules;

    public Button AttemptButton => _attempt;
    public IReadOnlyList<Button> OptionButtons => _optionButtons;

    public override void _Ready()
    {
        _body = GetNode<Label>("%BodyLabel");
        _options = GetNode<VBoxContainer>("%OptionBox");
        _heading = GetNode<Label>("%PreviewHeading");
        _actorRow = GetNode<Container>("%ActorRow");
        _outcomes = GetNode<RuledRows>("%OutcomeRows");
        _result = GetNode<Label>("%ResultLabel");
        _attempt = GetNode<Button>("%AttemptButton");
        _continue = GetNode<Button>("%ContinueButton");
        _attempt.Pressed += Commit;
        _continue.Pressed += () => Continued?.Invoke();
        base._Ready();
    }

    /// <summary>Before the result Esc reaches the pause menu (an event is left through its own
    /// choice); after it, Esc continues like the Continue button.</summary>
    public override void _Input(InputEvent e)
    {
        if (IsVisibleInTree() && _continue.Visible && !e.IsEcho() && e.IsActionPressed(InputNames.UiCancel))
        {
            GetViewport().SetInputAsHandled();
            Continued?.Invoke();
            return;
        }
        base._Input(e);
    }

    /// <summary>Show an event with its first option selected. Clears any previous result.</summary>
    public void Show(EventDefinition definition, RunState state)
    {
        _definition = definition;
        _party = state.Party;
        _resolved = false;
        _chosen = null;
        SetTitle(definition.Title);
        _body.Text = definition.Body;
        _body.Visible = true;
        if (Report != null) Report.Visible = false;
        _result.Text = "";
        _result.Visible = false;
        _continue.Visible = false;
        _attempt.Visible = true;
        _options.Visible = true;
        _outcomes.Visible = true;

        BuildOptions(definition);
        Select(0);
        if (!Visible) OpenFrame();
        UiFocus.Grab(_optionButtons[_selected]);
    }

    /// <summary>Swap the options for the outcome text and the way back.</summary>
    public void ShowResult(EventResult result)
    {
        _resolved = true;
        _heading.Text = "Outcome";
        _heading.TooltipText = "";
        _heading.Visible = true;
        _options.Visible = false;
        _actorRow.Visible = false;
        _outcomes.Visible = false;
        _attempt.Visible = false;
        var text = new System.Text.StringBuilder();
        if (!result.Resolved && result.Reason != null)
            text.Append(result.Reason);
        foreach (string line in result.Lines)
        {
            if (text.Length > 0) text.Append('\n');
            text.Append(line);
        }

        _result.Text = text.ToString();
        _result.Visible = true;
        _continue.Visible = true;
        UiFocus.Grab(_continue);
        foreach (var button in _optionButtons) button.Disabled = true;
    }

    /// <summary>The pair-style report, when the scene carries one.</summary>
    public PairReport? Report => GetNodeOrNull<PairReport>("%Report");

    /// <summary>A result in pair style: a short title, the party figures, one row per changed hero.</summary>
    public void ShowReport(string title, IReadOnlyList<Delve.Combat.FigureView> figures, IReadOnlyList<ResultMemberRow> rows)
    {
        ShowResult(new EventResult { Resolved = true });
        SetTitle(title);
        if (Report != null) Report.Visible = true;
        _body.Visible = false;
        _heading.Visible = false;
        _result.Visible = false;
        Report?.Render(figures, rows);
    }

    private void BuildOptions(EventDefinition definition)
    {
        FreeChildren(_options);
        _optionButtons.Clear();
        for (int i = 0; i < definition.Options.Count; i++)
        {
            var button = new Button
            {
                Alignment = HorizontalAlignment.Left,
                ThemeTypeVariation = ThemeNames.EventOption,
                AutowrapMode = TextServer.AutowrapMode.WordSmart,
                CustomMinimumSize = new Vector2(0, 48)
            };
            int index = i;
            // A click selects; the selected option pressed again (a second click, or Enter on the
            // focused option) commits, as Attempt does.
            button.Pressed += () =>
            {
                if (_resolved || button.Disabled) return;
                if (index == _selected) Commit();
                else Select(index);
            };
            // Arrow keys move the selection with the focus; a mouse press selects through Pressed.
            button.FocusEntered += () =>
            {
                if (!Input.IsMouseButtonPressed(MouseButton.Left)) Select(index);
            };
            _options.AddChild(button);
            _optionButtons.Add(button);
        }
    }

    /// <summary>Open one option's details and mark it selected; any member picked for another
    /// option goes back to the best suited.</summary>
    private void Select(int index)
    {
        if (_resolved || _definition == null || index >= _definition.Options.Count) return;
        if (index != _selected) _chosen = null;
        _selected = index;
        for (int i = 0; i < _optionButtons.Count; i++)
            _optionButtons[i].ThemeTypeVariation = i == index ? ThemeNames.EventOptionSelected : ThemeNames.EventOption;
        BuildActors(_definition.Options[index]);
        Refresh();
    }

    /// <summary>Option chances, the selected option's check, outcome rows and the Attempt button,
    /// for whoever tries now.</summary>
    private void Refresh()
    {
        if (_definition == null || _party == null || _resolved) return;
        for (int i = 0; i < _optionButtons.Count; i++)
        {
            var each = _definition.Options[i];
            var button = _optionButtons[i];
            button.Text = $"{each.Label}\n{EventCheckPreview.ChanceLine(each, _party, i == _selected ? _chosen : null)}";
            button.Disabled = each.Check is { } c && EventResolver.ActorFor(_party, c, null) == null;
        }

        var option = _definition.Options[_selected];
        var actor = option.Check is { } check ? EventResolver.ActorFor(_party, check, _chosen) : null;
        bool picks = _actors.Count > 0;
        _heading.Visible = true;
        _heading.Text = EventCheckPreview.CheckCaption(option)
            + (option.Check != null && !picks && actor != null ? $" · {EventCheckPreview.ChanceLine(option, _party, actor)}" : "");
        _heading.TooltipText = actor != null ? EventCheckPreview.Breakdown(option, actor) : "";

        _outcomes.Render(EventCheckPreview.Outcomes(option).Select(o => new RuledRow(o.Caption, o.Effects)));

        bool possible = option.Check == null || actor != null;
        _attempt.Disabled = !possible;
        _attempt.Text = option.Check == null ? "Choose" : actor != null ? $"Attempt · {actor.Name}" : "Attempt";
    }

    /// <summary>Who tries, best suited first and already picked, when the option lets the player
    /// name the member; nothing when it does not.</summary>
    private void BuildActors(EventOption option)
    {
        FreeChildren(_actorRow);
        _actors.Clear();
        _actorGroup = new ButtonGroup();
        bool picks = option.Check is { AllowPickActor: true } && _party != null;
        _actorRow.Visible = picks;
        if (!picks) return;
        var check = option.Check!;
        var best = EventResolver.ActorFor(_party!, check, null);
        var members = _party!.Members.Where(m => m.Health == null || !m.Health.IsDead)
            .OrderByDescending(m => SkillCalculator.CalculateSkillBonus(m, check.Skill));
        foreach (var member in members)
        {
            int bonus = SkillCalculator.CalculateSkillBonus(member, check.Skill);
            var button = new Button
            {
                Text = $"{member.Name} {EventCheckPreview.SuccessPercent(bonus, check.Dc)}%",
                TooltipText = EventCheckPreview.Breakdown(option, member),
                ToggleMode = true,
                ButtonGroup = _actorGroup,
            };
            button.SetPressedNoSignal(member == (_chosen ?? best));
            button.Toggled += pressed =>
            {
                if (!pressed) return;
                _chosen = member == best ? null : member;
                Refresh();
            };
            _actorRow.AddChild(button);
            _actors.Add((member, button));
        }
    }

    private void Commit()
    {
        if (_resolved || _definition == null || _attempt.Disabled) return;
        _resolved = true;
        foreach (var button in _optionButtons) button.Disabled = true;
        _attempt.Disabled = true;
        OptionPicked?.Invoke(_selected, _chosen);
    }

    private static void FreeChildren(Node parent)
    {
        foreach (var child in parent.GetChildren())
        {
            parent.RemoveChild(child);
            child.QueueFree();
        }
    }
}
