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

    // Mirrors PF2e.Core.CombatLogSeverity ordinal values (kept as ints to stay engine-free).
    private static readonly Color[] SeverityColors =
    {
        new(0.82f, 0.82f, 0.85f), // Info
        new(0.55f, 0.9f, 0.55f),  // Hit
        new(0.35f, 1f, 0.35f),    // CriticalHit
        new(0.75f, 0.75f, 0.6f),  // Miss
        new(0.9f, 0.5f, 0.5f),    // CriticalMiss
        new(0.4f, 0.9f, 0.9f),    // Healing
        new(0.8f, 0.6f, 1f),      // ConditionApplied
        new(0.6f, 0.6f, 0.7f),    // ConditionRemoved
        new(1f, 0.85f, 0.4f),     // ActionHeader
        new(1f, 0.65f, 0.25f),    // Reaction
    };

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
