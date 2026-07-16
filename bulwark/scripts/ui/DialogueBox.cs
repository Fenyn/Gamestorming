using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data.Dialogues;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Stardew-style dialogue box: bottom-of-screen panel with portrait, speaker name, typewriter text
/// reveal, advance indicator, and choice buttons. Thin Node adapter — wired to a
/// <see cref="DialogueRunner"/> via events; the runner owns the state machine.
/// </summary>
public partial class DialogueBox : PanelContainer
{
    /// <summary>Characters revealed per second during typewriter effect.</summary>
    [Export] public float CharsPerSecond { get; set; } = 30f;

    private TextureRect? _portrait;
    private Label? _speakerLabel;
    private RichTextLabel? _textLabel;
    private Label? _advanceIndicator;
    private VBoxContainer? _choiceContainer;
    private DialogueRunner? _runner;
    private bool _typewriterActive;
    private int _targetVisibleChars;
    private double _charTimer;

    /// <summary>Raised when the dialogue box opens (for modal freeze).</summary>
    public event System.Action? Opened;

    /// <summary>Raised when the dialogue box closes (for modal unfreeze).</summary>
    public event System.Action? Closed;

    public override void _Ready()
    {
        _portrait = GetNodeOrNull<TextureRect>("%Portrait");
        _speakerLabel = GetNodeOrNull<Label>("%SpeakerName");
        _textLabel = GetNodeOrNull<RichTextLabel>("%DialogueText");
        _advanceIndicator = GetNodeOrNull<Label>("%AdvanceIndicator");
        _choiceContainer = GetNodeOrNull<VBoxContainer>("%ChoiceContainer");

        Visible = false;
        ClearChoices();
    }

    public override void _Process(double delta)
    {
        if (!_typewriterActive || _textLabel == null)
            return;

        _charTimer += delta;
        float interval = 1f / CharsPerSecond;
        while (_charTimer >= interval && _textLabel.VisibleCharacters < _targetVisibleChars)
        {
            _textLabel.VisibleCharacters++;
            _charTimer -= interval;
        }

        if (_textLabel.VisibleCharacters >= _targetVisibleChars)
        {
            _typewriterActive = false;
            if (_advanceIndicator != null && !(_runner?.IsWaitingForChoice ?? false))
                _advanceIndicator.Visible = true;
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (!Visible || _runner == null || !_runner.IsRunning)
            return;

        if (@event.IsActionPressed("ui_accept") || (@event is InputEventMouseButton mb && mb.Pressed && mb.ButtonIndex == MouseButton.Left))
        {
            if (_typewriterActive)
            {
                // Skip to full text
                SkipTypewriter();
            }
            else if (_runner.IsWaitingForAdvance)
            {
                _runner.Advance();
            }
            GetViewport().SetInputAsHandled();
        }
    }

    /// <summary>Bind to a runner and begin displaying its output.</summary>
    public void Bind(DialogueRunner runner)
    {
        Unbind();
        _runner = runner;
        _runner.LineReady += OnLineReady;
        _runner.ChoicesReady += OnChoicesReady;
        _runner.SequenceEnded += OnSequenceEnded;

        Visible = true;
        Opened?.Invoke();
    }

    /// <summary>Unbind from the current runner.</summary>
    public void Unbind()
    {
        if (_runner != null)
        {
            _runner.LineReady -= OnLineReady;
            _runner.ChoicesReady -= OnChoicesReady;
            _runner.SequenceEnded -= OnSequenceEnded;
            _runner = null;
        }
    }

    /// <summary>Close the dialogue box.</summary>
    public void Close()
    {
        Unbind();
        Visible = false;
        _typewriterActive = false;
        ClearChoices();
        Closed?.Invoke();
    }

    private void OnLineReady(string speaker, string text, string emotion, bool isChoice)
    {
        if (_speakerLabel != null)
            _speakerLabel.Text = speaker;

        if (_textLabel != null)
        {
            _textLabel.Text = text;
            _textLabel.VisibleCharacters = 0;
            _targetVisibleChars = text.Length;
            _typewriterActive = true;
            _charTimer = 0;
        }

        if (_advanceIndicator != null)
            _advanceIndicator.Visible = false;

        ClearChoices();
        LoadPortrait(speaker, emotion);
    }

    private void OnChoicesReady(List<string> options)
    {
        // Skip typewriter so the player can read the full prompt before choosing
        SkipTypewriter();

        if (_advanceIndicator != null)
            _advanceIndicator.Visible = false;

        ClearChoices();
        if (_choiceContainer == null)
            return;

        _choiceContainer.Visible = true;
        for (int i = 0; i < options.Count; i++)
        {
            int index = i; // capture for closure
            var button = new Button { Text = options[i] };
            button.Pressed += () =>
            {
                ClearChoices();
                _runner?.SelectChoice(index);
            };
            _choiceContainer.AddChild(button);
        }
    }

    private void OnSequenceEnded()
    {
        Close();
    }

    private void SkipTypewriter()
    {
        if (_textLabel != null)
            _textLabel.VisibleCharacters = _targetVisibleChars;
        _typewriterActive = false;
        if (_advanceIndicator != null && !(_runner?.IsWaitingForChoice ?? false))
            _advanceIndicator.Visible = true;
    }

    private void ClearChoices()
    {
        if (_choiceContainer == null)
            return;

        foreach (Node child in _choiceContainer.GetChildren())
            child.QueueFree();
        _choiceContainer.Visible = false;
    }

    private void LoadPortrait(string speaker, string emotion)
    {
        if (_portrait == null)
            return;

        // Try speaker_emotion.png, then speaker.png, then hide
        string basePath = $"res://assets/portraits/{speaker}";
        string emotionPath = $"{basePath}_{emotion}.png";
        string fallbackPath = $"{basePath}.png";

        if (ResourceLoader.Exists(emotionPath))
        {
            _portrait.Texture = GD.Load<Texture2D>(emotionPath);
            _portrait.Visible = true;
        }
        else if (ResourceLoader.Exists(fallbackPath))
        {
            _portrait.Texture = GD.Load<Texture2D>(fallbackPath);
            _portrait.Visible = true;
        }
        else
        {
            _portrait.Texture = null;
            _portrait.Visible = false;
        }
    }
}
