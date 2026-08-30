using System;
using System.Collections.Generic;
using Delve.Run;
using Delve.Run.Events;
using Godot;
using PF2e.Core;

namespace Delve.Flow;

/// <summary>
/// A Happenstance node: title, body, one button per option and the result the resolver produced.
/// The option buttons spell out their check ("Athletics DC 15") so the player never guesses what a
/// choice rolls. Passive - the resolver runs in the flow layer, this only shows and signals.
/// </summary>
public partial class EventPanel : Control
{
    private readonly List<(PF2eCharacter Actor, Button Button)> _actors = new();

    private Label _title = null!;
    private Label _body = null!;
    private VBoxContainer _options = null!;
    private HBoxContainer _actorRow = null!;
    private Label _actorHeading = null!;
    private Label _result = null!;
    private Button _continue = null!;
    private ButtonGroup _actorGroup = new();

    /// <summary>Option index plus the member the player named, or null to let the resolver pick.</summary>
    public event Action<int, PF2eCharacter?>? OptionPicked;

    public event Action? Continued;

    public override void _Ready()
    {
        _title = GetNode<Label>("%TitleLabel");
        _body = GetNode<Label>("%BodyLabel");
        _options = GetNode<VBoxContainer>("%OptionBox");
        _actorRow = GetNode<HBoxContainer>("%ActorRow");
        _actorHeading = GetNode<Label>("%ActorHeading");
        _result = GetNode<Label>("%ResultLabel");
        _continue = GetNode<Button>("%ContinueButton");
        _continue.Pressed += () => Continued?.Invoke();
    }

    /// <summary>Show an event and let the player choose. Clears any previous result.</summary>
    public void Show(EventDefinition definition, RunState state)
    {
        _title.Text = definition.Title;
        _body.Text = definition.Body;
        _result.Text = "";
        _result.Visible = false;
        _continue.Visible = false;

        BuildActors(definition, state.Party);
        BuildOptions(definition);
        Visible = true;
    }

    /// <summary>Swap the options for the outcome text and the way back to the map.</summary>
    public void ShowResult(EventResult result)
    {
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
        SetOptionsEnabled(false);
        _actorRow.Visible = false;
        _actorHeading.Visible = false;
    }

    private void BuildOptions(EventDefinition definition)
    {
        FreeChildren(_options);

        for (int i = 0; i < definition.Options.Count; i++)
        {
            var option = definition.Options[i];
            var button = new Button { Text = OptionText(option) };
            int index = i;
            button.Pressed += () => OptionPicked?.Invoke(index, SelectedActor());
            _options.AddChild(button);
        }
    }

    private static string OptionText(EventOption option)
        => option.Check == null ? option.Label : $"{option.Label}  ({option.Check.Skill} DC {option.Check.Dc})";

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

        foreach (var member in party.Members)
        {
            if (member.Health != null && member.Health.IsDead) continue;

            var button = new Button
            {
                Text = member.Name,
                ToggleMode = true,
                ButtonGroup = _actorGroup,
            };
            _actorRow.AddChild(button);
            _actors.Add((member, button));
        }
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
