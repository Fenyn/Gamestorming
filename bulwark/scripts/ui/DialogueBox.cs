using System.Collections.Generic;
using Bulwark.Cozy;
using Bulwark.Data.Dialogues;
using Godot;

using Bulwark.Dialogue;
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
    private Control? _portraitColumn;
    private Label? _speakerLabel;
    private RichTextLabel? _textLabel;
    private Label? _advanceIndicator;
    private VBoxContainer? _choiceContainer;
    private DialogueRunner? _runner;
    private bool _typewriterActive;
    private int _targetVisibleChars;
    private double _charTimer;

    /// <summary>Loaded portrait textures keyed by res:// path, so a repeated speaker/emotion never
    /// re-hits the disk. Populated on demand (hits only) as lines resolve.</summary>
    private readonly Dictionary<string, Texture2D> _portraitCache = new();

    /// <summary>Speakers we have already warned about a missing portrait folder for — one warning per
    /// character per session, never a per-line spam (portraits are populated by a parallel pass and may
    /// legitimately be absent early).</summary>
    private readonly HashSet<string> _warnedMissingPortraits = new();

    /// <summary>Raised when the dialogue box opens (for modal freeze).</summary>
    public event System.Action? Opened;

    /// <summary>Raised when the dialogue box closes (for modal unfreeze).</summary>
    public event System.Action? Closed;

    public override void _Ready()
    {
        _portrait = GetNodeOrNull<TextureRect>("%Portrait");
        _portraitColumn = GetNodeOrNull<Control>("%PortraitColumn");
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

    private void OnLineReady(string speakerId, string speakerName, string text, string emotion, bool isChoice)
    {
        if (_speakerLabel != null)
            _speakerLabel.Text = speakerName;

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
        LoadPortrait(speakerId, emotion);
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

    /// <summary>
    /// Resolve the portrait for the current line and show or hide the whole right-hand column
    /// accordingly: <c>res://assets/portraits/&lt;speakerId&gt;/&lt;emotion&gt;.png</c>, falling back to
    /// that character's <c>neutral.png</c>, and hiding the column when neither exists (or the speaker id
    /// is empty). Everything degrades to "no portrait" — the portraits are populated by a parallel pass
    /// and may legitimately be absent, so a missing sheet is never an error, only a hidden column.
    /// </summary>
    private void LoadPortrait(string speaker, string emotion)
    {
        if (_portrait == null)
            return;

        Texture2D? tex = string.IsNullOrEmpty(speaker)
            ? null
            : ResolvePortrait(speaker, string.IsNullOrEmpty(emotion) ? "neutral" : emotion);

        _portrait.Texture = tex;
        if (_portraitColumn != null)
            _portraitColumn.Visible = tex != null;
    }

    /// <summary>Emotion texture if present, else the character's neutral, else null (warned once).</summary>
    private Texture2D? ResolvePortrait(string speaker, string emotion)
    {
        Texture2D? tex = LoadCachedTexture($"res://assets/portraits/{speaker}/{emotion}.png")
                         ?? LoadCachedTexture($"res://assets/portraits/{speaker}/neutral.png");

        if (tex == null && _warnedMissingPortraits.Add(speaker))
            GD.PushWarning($"[DialogueBox] No portrait for '{speaker}' (res://assets/portraits/{speaker}/).");

        return tex;
    }

    /// <summary>Load a portrait texture with a per-path cache; returns null (uncached) when the path
    /// does not resolve, so a still-absent asset stays cheap to re-check as it lands.</summary>
    private Texture2D? LoadCachedTexture(string path)
    {
        if (_portraitCache.TryGetValue(path, out Texture2D? cached))
            return cached;
        if (!ResourceLoader.Exists(path))
            return null;

        var tex = GD.Load<Texture2D>(path);
        if (tex != null)
            _portraitCache[path] = tex;
        return tex;
    }
}
