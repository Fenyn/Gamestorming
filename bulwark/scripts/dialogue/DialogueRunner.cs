using System;
using System.Collections.Generic;
using Bulwark.Data.Dialogues;

namespace Bulwark.Dialogue;

/// <summary>
/// Callback interface for applying dialogue effects. GameState implements this, routing through
/// its existing commands (SetStoryFlag, AddFriendship, AddItem, MarkDialogueSeen).
/// </summary>
public interface IDialogueEffectHandler
{
    void SetFlag(string flagId);
    void AddFriendship(string charId, int amount);
    void GiveItem(string itemId, int quantity);
    void MarkSeen(string dialogueId);

    /// <summary>
    /// The player's runtime-chosen name (or null if not yet set). Injected through the same seam as
    /// the effect commands — the runner already receives this handler at every construction site — so
    /// line text and the player speaker label can be resolved at the push point without the runner or
    /// the box reading a singleton.
    /// </summary>
    string? PlayerName { get; }
}

/// <summary>
/// Plain C# state machine that walks a list of <see cref="DialogueStep"/>s, emitting events for
/// the UI (lines, choices) and the director (staging commands). No Godot dependency — testable.
/// Constructed with a step list and an effect handler; the UI/director drives it via
/// <see cref="Advance"/>, <see cref="SelectChoice"/>, and <see cref="StagingComplete"/>.
/// </summary>
public sealed class DialogueRunner
{
    private readonly List<DialogueStep> _steps;
    private readonly IDialogueEffectHandler _handler;
    private readonly string? _dialogueId;
    private readonly bool _once;
    private int _index;
    private bool _waitingForAdvance;
    private bool _waitingForChoice;
    private bool _waitingForStaging;
    private bool _running;

    /// <summary>Fired when a line is ready for display. The speaker id (for portrait lookup) and the
    /// resolved speaker display name (for the name label) are pushed separately; the text has had its
    /// inline tokens (e.g. {player_name}) substituted.</summary>
    public event Action<string, string, string, string, bool>? LineReady; // speakerId, speakerName, text, emotion, isChoice

    /// <summary>Fired when choice buttons should appear.</summary>
    public event Action<List<string>>? ChoicesReady;

    /// <summary>Fired when a staging command needs execution by the director.</summary>
    public event Action<DialogueStep>? StageCommand;

    /// <summary>Fired when the sequence ends.</summary>
    public event Action? SequenceEnded;

    /// <summary>Fired when a choice option requests a jump to another sequence.</summary>
    public event Action<string>? SequenceJumpRequested;

    /// <summary>Whether the runner is actively processing a sequence.</summary>
    public bool IsRunning => _running;

    /// <summary>Whether the runner is waiting for the player to pick a choice.</summary>
    public bool IsWaitingForChoice => _waitingForChoice;

    /// <summary>Whether the runner is waiting for the player to advance past a line.</summary>
    public bool IsWaitingForAdvance => _waitingForAdvance;

    /// <summary>The current choice options (when waiting for a choice), or null.</summary>
    public List<DialogueOption>? CurrentOptions { get; private set; }

    public DialogueRunner(List<DialogueStep> steps, IDialogueEffectHandler handler,
        string? dialogueId = null, bool once = false)
    {
        _steps = new List<DialogueStep>(steps);
        _handler = handler;
        _dialogueId = dialogueId;
        _once = once;
    }

    /// <summary>Begin the sequence from the first step.</summary>
    public void Start()
    {
        _index = 0;
        _running = true;
        ProcessCurrentStep();
    }

    /// <summary>Player pressed advance (past a displayed line). No-op if not waiting.</summary>
    public void Advance()
    {
        if (!_waitingForAdvance)
            return;
        _waitingForAdvance = false;
        _index++;
        ProcessCurrentStep();
    }

    /// <summary>Player picked a choice option by index.</summary>
    public void SelectChoice(int index)
    {
        if (!_waitingForChoice || CurrentOptions == null || index < 0 || index >= CurrentOptions.Count)
            return;

        _waitingForChoice = false;
        var option = CurrentOptions[index];
        CurrentOptions = null;

        // Apply effects
        if (option.Effects != null)
        {
            foreach (var effect in option.Effects)
                ApplyEffect(effect);
        }

        // Handle next_id jump
        if (!string.IsNullOrEmpty(option.NextId))
        {
            _running = false;
            SequenceJumpRequested?.Invoke(option.NextId);
            return;
        }

        // Insert inline steps after the current position
        if (option.Steps != null && option.Steps.Count > 0)
        {
            int insertAt = _index + 1;
            _steps.InsertRange(insertAt, option.Steps);
        }

        _index++;
        ProcessCurrentStep();
    }

    /// <summary>The director signals that a staging command has completed.</summary>
    public void StagingComplete()
    {
        if (!_waitingForStaging)
            return;
        _waitingForStaging = false;
        _index++;
        ProcessCurrentStep();
    }

    private void ProcessCurrentStep()
    {
        while (_running && _index < _steps.Count)
        {
            var step = _steps[_index];

            switch (step.Type)
            {
                case "line":
                    _waitingForAdvance = true;
                    PushLine(step, isChoice: false);
                    return; // wait for Advance()

                case "choice":
                    // Show the prompt line first, then the choices
                    _waitingForChoice = true;
                    CurrentOptions = step.Options;
                    PushLine(step, isChoice: true);
                    if (step.Options != null)
                    {
                        var labels = new List<string>();
                        foreach (var opt in step.Options)
                            labels.Add(opt.Text);
                        ChoicesReady?.Invoke(labels);
                    }
                    return; // wait for SelectChoice()

                case "flag":
                    if (!string.IsNullOrEmpty(step.Set))
                        _handler.SetFlag(step.Set);
                    _index++;
                    continue; // immediate, advance to next

                case "friendship":
                    if (!string.IsNullOrEmpty(step.Character) && step.Amount.HasValue)
                        _handler.AddFriendship(step.Character, step.Amount.Value);
                    _index++;
                    continue;

                case "item":
                    if (!string.IsNullOrEmpty(step.ItemId))
                        _handler.GiveItem(step.ItemId, step.Quantity ?? 1);
                    _index++;
                    continue;

                case "emote":
                    // Staging command — director handles it
                    _waitingForStaging = true;
                    StageCommand?.Invoke(step);
                    return;

                case "fade":
                case "enter":
                case "exit":
                case "move":
                case "camera":
                case "sfx":
                case "wait":
                    _waitingForStaging = true;
                    StageCommand?.Invoke(step);
                    return; // wait for StagingComplete()

                default:
                    // Unknown step type — skip
                    _index++;
                    continue;
            }
        }

        // Reached the end of the sequence
        _running = false;
        if (_once && !string.IsNullOrEmpty(_dialogueId))
            _handler.MarkSeen(_dialogueId);
        SequenceEnded?.Invoke();
    }

    /// <summary>
    /// Push a line/choice-prompt to the UI, resolving presentation at this single seam: the speaker id
    /// travels for portrait lookup, its display name for the label, and the text has its inline tokens
    /// substituted — all keyed off the injected player name (see <see cref="DialogueText"/>).
    /// </summary>
    private void PushLine(DialogueStep step, bool isChoice)
    {
        string? playerName = _handler.PlayerName;
        LineReady?.Invoke(
            step.Speaker ?? "",
            DialogueText.ResolveSpeaker(step.Speaker, playerName),
            DialogueText.Format(step.Text, playerName),
            step.Emotion ?? "neutral",
            isChoice);
    }

    private void ApplyEffect(StepEffect effect)
    {
        switch (effect.Type)
        {
            case "friendship":
                if (!string.IsNullOrEmpty(effect.Character) && effect.Amount.HasValue)
                    _handler.AddFriendship(effect.Character, effect.Amount.Value);
                break;
            case "flag":
                if (!string.IsNullOrEmpty(effect.Set))
                    _handler.SetFlag(effect.Set);
                break;
            case "item":
                if (!string.IsNullOrEmpty(effect.ItemId))
                    _handler.GiveItem(effect.ItemId, effect.Quantity ?? 1);
                break;
        }
    }
}
