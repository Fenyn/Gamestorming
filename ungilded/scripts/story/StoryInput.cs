using Godot;

namespace Ungilded.Story;

/// <summary>The input the story screens read to advance a line or a page.</summary>
internal static class StoryInput
{
    /// <summary>Godot's built-in accept action: Enter, Space and keypad Enter by default.</summary>
    public const string Advance = "ui_accept";

    public static bool IsAdvanceKey(InputEvent e) => e.IsActionPressed(Advance);

    public static bool IsAdvanceClick(InputEvent e) =>
        e is InputEventMouseButton { ButtonIndex: MouseButton.Left, Pressed: true };
}
