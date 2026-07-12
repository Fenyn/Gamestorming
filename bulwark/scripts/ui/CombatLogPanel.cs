using Godot;

namespace Bulwark.UI;

/// <summary>
/// Scrolling combat log. Renders BBCode-colored entries by severity, indents detail lines, and
/// auto-scrolls. Passive: <c>CombatScene</c> forwards engine log entries as plain
/// (message, severity, isDetail) tuples so no engine type reaches this Control.
/// </summary>
public partial class CombatLogPanel : Control
{
    private RichTextLabel _label = null!;

    // Severity ramp lives in the shared warm palette (UiPalette.LogSeverity).
    private static readonly Color[] SeverityColors = UiPalette.LogSeverity;

    public override void _Ready()
    {
        _label = GetNode<RichTextLabel>("%Log");
    }

    public void AppendEntry(string message, int severity, bool isDetail)
    {
        Color color = severity >= 0 && severity < SeverityColors.Length
            ? SeverityColors[severity]
            : SeverityColors[0];

        string indent = isDetail ? "    " : "";
        string escaped = message.Replace("[", "[lb]");
        _label.AppendText($"{indent}[color=#{color.ToHtml(false)}]{escaped}[/color]\n");
    }

    public void ClearLog() => _label.Clear();
}
