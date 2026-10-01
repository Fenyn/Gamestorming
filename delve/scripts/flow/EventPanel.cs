using System;
using System.Collections.Generic;
using Delve.Run;
using Delve.Run.Events;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// A Happenstance node: title, body, one button per option and the result the resolver produced.
/// The option buttons spell out their check ("Athletics DC 15") so the player never guesses what a
/// choice rolls. Passive - the resolver runs in the flow layer, this only shows and signals.
/// </summary>
public partial class EventPanel : ScreenFrame
{
    private readonly List<(PF2eCharacter Actor, Button Button)> _actors = new();

    private Label _body = null!;
    private VBoxContainer _options = null!;
    private Container _actorRow = null!;
    private Label _actorHeading = null!;
    private Label _result = null!;
    private Button _continue = null!;
    private ButtonGroup _actorGroup = new();
    private EventDefinition? _definition;
    private Party? _party;
    private Label _preview = null!;
    private Label _previewHeading = null!;
    private int _previewIndex;
    private bool _resolved;
    private readonly List<Button> _optionButtons = new();

    /// <summary>Option index plus the member the player named, or null to let the resolver pick.</summary>
    public event Action<int, PF2eCharacter?>? OptionPicked;

    public event Action? Continued;

    public override void _Ready()
    {
        _body = GetNode<Label>("%BodyLabel");
        _options = GetNode<VBoxContainer>("%OptionBox");
        _actorRow = GetNode<Container>("%ActorRow");
        _actorHeading = GetNode<Label>("%ActorHeading");
        _result = GetNode<Label>("%ResultLabel");
        _continue = GetNode<Button>("%ContinueButton");
        _preview = GetNode<Label>("%CheckPreview");
        _previewHeading = GetNode<Label>("%PreviewHeading");
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

    /// <summary>Show an event and let the player choose. Clears any previous result.</summary>
    public void Show(EventDefinition definition, RunState state)
    {
        _definition = definition;
        _party = state.Party;
        _resolved = false;
        _previewIndex = 0;
        SetTitle(definition.Title);
        _body.Text = definition.Body;
        _body.Visible = true;
        if (Report != null) Report.Visible = false;
        _result.Text = "";
        _result.Visible = false;
        _continue.Visible = false;
        _options.Visible = true;
        GetNode<Label>("%ChoiceHeading").Visible = true;

        BuildActors(definition, state.Party);
        BuildOptions(definition);
        RefreshPreviews();
        if (!Visible) OpenFrame();
        UiFocus.GrabFirst(_optionButtons);
    }

    /// <summary>Swap the options for the outcome text and the way back to the map.</summary>
    public void ShowResult(EventResult result)
    {
        _resolved = true;
        _preview.Visible = false;
        _previewHeading.Text = "OUTCOME";
        _previewHeading.Visible = true;
        _options.Visible = false;
        GetNode<Label>("%ChoiceHeading").Visible = false;
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
        SetOptionsEnabled(false);
        _actorRow.Visible = false;
        _actorHeading.Visible = false;
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
        _previewHeading.Visible = false;
        _result.Visible = false;
        Report?.Render(figures, rows);
    }

    private void BuildOptions(EventDefinition definition)
    {
        FreeChildren(_options);
        _optionButtons.Clear();

        for (int i = 0; i < definition.Options.Count; i++)
        {
            var option = definition.Options[i];
            var button = new Button {
                Alignment = HorizontalAlignment.Left,
                ThemeTypeVariation = ThemeNames.EventOption,
                AutowrapMode = TextServer.AutowrapMode.WordSmart,
                CustomMinimumSize = new Vector2(0, 48)
            };
            int index = i;
            button.Pressed += () =>
            {
                if (_resolved || button.Disabled) return;
                _resolved = true;
                SetOptionsEnabled(false);
                OptionPicked?.Invoke(index, SelectedActor());
            };
            button.MouseEntered += () => ShowPreview(index);
            button.FocusEntered += () => ShowPreview(index);
            _options.AddChild(button);
            _optionButtons.Add(button);
        }
    }

    private void RefreshPreviews()
    {
        if (_definition == null || _party == null || _resolved) return;
        for (int i = 0; i < _optionButtons.Count; i++)
        {
            var option = _definition.Options[i];
            var button = _optionButtons[i];
            button.Text = option.Label + (option.Check == null ? "" : "\n" + EventCheckPreview.CheckLine(option, _party, SelectedActor()));
            button.Disabled = option.Check is { } check && EventResolver.ActorFor(_party, check, SelectedActor()) == null;
            button.TooltipText = option.Check == null ? "This choice needs no roll."
                : "Base chance includes natural 1 and 20 degree shifts. Features that adjust a check when it resolves may change the result.";
        }
        ShowPreview(_previewIndex);
    }

    private void ShowPreview(int index)
    {
        if (_resolved || _definition == null || _party == null || index >= _definition.Options.Count) return;
        _previewIndex = index;
        RenderActorOdds(_definition.Options[index]);
        _previewHeading.Text = _definition.Options[index].Check == null ? "WHAT HAPPENS · NO ROLL" : "CHECK & POSSIBLE OUTCOMES";
        _preview.Text = EventCheckPreview.Details(_definition.Options[index], _party, SelectedActor());
        _preview.Visible = true;
        _previewHeading.Visible = true;
    }

    /// <summary>Actor toggles, shown only when an option lets the player name who tries.</summary>
    private void BuildActors(EventDefinition definition, Party party)
    {
        FreeChildren(_actorRow);
        _actors.Clear();
        _actorGroup = new ButtonGroup();

        bool allowed = false;
        foreach (var option in definition.Options)
        {
            if (option.Check is { AllowPickActor: true }) { allowed = true; break; }
        }

        _actorRow.Visible = allowed;
        _actorHeading.Visible = allowed;
        if (!allowed) return;

        var automatic = new Button { Text = "Best suited", ToggleMode = true, ButtonGroup = _actorGroup,
            Alignment = HorizontalAlignment.Left, SizeFlagsHorizontal = SizeFlags.ExpandFill };
        automatic.SetPressedNoSignal(true);
        automatic.Toggled += pressed => { if (pressed) RefreshPreviews(); };
        _actorRow.AddChild(automatic);

        foreach (var member in party.Members)
        {
            if (member.Health != null && member.Health.IsDead) continue;

            var button = new Button
            {
                Text = member.Name,
                ToggleMode = true,
                ButtonGroup = _actorGroup,
                Alignment = HorizontalAlignment.Left,
                SizeFlagsHorizontal = SizeFlags.ExpandFill,
            };
            _actorRow.AddChild(button);
            _actors.Add((member, button));
            button.Toggled += pressed => { if (pressed) RefreshPreviews(); };
        }
    }

    /// <summary>Each member's odds on the previewed option ("Elara  +8 · 55%"), and who "Best
    /// suited" would send.</summary>
    private void RenderActorOdds(EventOption option)
    {
        foreach (var (actor, button) in _actors)
        {
            string odds = EventCheckPreview.ActorForecast(option, actor);
            button.Text = odds.Length > 0 ? $"{actor.Name}  {odds}" : actor.Name;
        }
        if (_actorRow.GetChildCount() > 0 && _actorRow.GetChild(0) is Button automatic && _party != null)
            automatic.Text = option.Check is { } check && EventResolver.ActorFor(_party, check, null) is { } best
                ? $"Best suited: {best.Name}" : "Best suited";
    }

    private PF2eCharacter? SelectedActor()
    {
        foreach (var (actor, button) in _actors)
        {
            if (button.ButtonPressed) return actor;
        }
        return null;
    }

    private void SetOptionsEnabled(bool enabled)
    {
        foreach (var child in _options.GetChildren())
        {
            if (child is Button button) button.Disabled = !enabled;
        }
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
