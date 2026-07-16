using System;
using Godot;

namespace Bulwark.UI;

/// <summary>
/// Name entry screen shown before the intro on a new game. Prompts the player for a character
/// name with a LineEdit pre-filled with the default "Warden". Confirm is disabled when the
/// input is empty. Emits <see cref="NameConfirmed"/> with the trimmed name.
/// </summary>
public partial class NameEntryScreen : Control
{
    /// <summary>Raised when the player confirms their name.</summary>
    public event Action<string>? NameConfirmed;

    private LineEdit _input = null!;
    private Button _confirm = null!;

    public override void _Ready()
    {
        _input = GetNode<LineEdit>("%NameInput");
        _confirm = GetNode<Button>("%ConfirmButton");

        _input.TextChanged += OnTextChanged;
        _confirm.Pressed += OnConfirmPressed;

        _input.Text = "Warden";
        _confirm.Disabled = false;
        _input.GrabFocus();
        _input.SelectAll();
    }

    private void OnTextChanged(string text)
    {
        _confirm.Disabled = string.IsNullOrWhiteSpace(text);
    }

    private void OnConfirmPressed()
    {
        string name = _input.Text.Trim();
        if (!string.IsNullOrEmpty(name))
            NameConfirmed?.Invoke(name);
    }
}
