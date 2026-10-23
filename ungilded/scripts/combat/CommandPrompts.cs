using System.Collections.Generic;

namespace Ungilded.Combat;

/// <summary>One button hint along the bottom edge: the key (an input action, several joined by
/// "+" to share one keycap, or a literal such as "LMB" when <see cref="IsAction"/> is false) and
/// what it does. <see cref="MouseButton"/> shares the keycap ahead of the key ("RMB Esc").</summary>
public readonly record struct KeyHint(string Key, string Label, bool IsAction = true, string MouseButton = "");

/// <summary>What the FFT-style prompts say in one turn mode: the instruction pill at the top
/// centre (empty hides it) and the button hints along the bottom.</summary>
public sealed record CommandPrompt(string Instruction, IReadOnlyList<KeyHint> Hints);

/// <summary>
/// The per-mode table behind the instruction pill and the button-hint row. One entry per
/// <see cref="PlayerTurnMode"/>; plain data, so a wording change never touches the HUD code.
/// </summary>
public static class CommandPrompts
{
    private const string Click = "LMB";
    private const string RightClick = "RMB";

    private static readonly KeyHint Rotate = new($"{Ungilded.UI.InputNames.RotateLeft}+{Ungilded.UI.InputNames.RotateRight}", "Rotate");
    private static readonly KeyHint Zoom = new("Wheel", "Zoom", IsAction: false);
    private static readonly KeyHint Cancel = new(Ungilded.UI.InputNames.UiCancel, "Cancel", MouseButton: RightClick);

    private static readonly CommandPrompt Idle = new("", new[]
    {
        new KeyHint(Ungilded.UI.InputNames.Move, "Move"),
        Rotate, Zoom,
        new KeyHint(Ungilded.UI.InputNames.Focus, "Centre"),
        new KeyHint(Ungilded.UI.InputNames.Help, "Help"),
    });

    private static readonly IReadOnlyDictionary<PlayerTurnMode, CommandPrompt> Table =
        new Dictionary<PlayerTurnMode, CommandPrompt>
        {
            [PlayerTurnMode.Idle] = Idle,
            [PlayerTurnMode.Moving] = new("Move", new[] { new KeyHint(Click, "Move here", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingMove] = new("Move", new[] { new KeyHint(Click, "Move here", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingStrike] = new("Strike", new[] { new KeyHint(Click, "Strike", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingSpellTarget] = new("Cast", new[] { new KeyHint(Click, "Cast", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingSpellTargets] = new("Cast", new[] { new KeyHint(Click, "Add target", false), new KeyHint(Ungilded.UI.InputNames.Confirm, "Cast"), Cancel }),
            [PlayerTurnMode.SelectingAreaOrigin] = new("Cast", new[] { new KeyHint(Click, "Cast", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingSkillTarget] = new("Skill", new[] { new KeyHint(Click, "Use", false), Cancel, Rotate }),
            [PlayerTurnMode.SelectingDelaySlot] = new("Delay", new[] { new KeyHint(Click, "Act after", false), Cancel }),
            [PlayerTurnMode.SelectingBombTarget] = new("Throw", new[] { new KeyHint(Click, "Throw", false), Cancel, Rotate }),
        };

    public static CommandPrompt For(PlayerTurnMode mode) => Table.TryGetValue(mode, out var prompt) ? prompt : Idle;
}
