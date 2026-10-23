using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using PF2e.Utilities;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>
/// The control surface an encounter script uses to run a tutorial fight. Set it on
/// <c>CombatScene.Tutorial</c> before <c>StartEncounter</c>; null keeps normal combat unchanged.
/// Plain C#: the scene, the session and the player-turn controller read this state and await the
/// registered callbacks at their pause points. The object outlives encounters, so a director can
/// keep one across a wipe and a restart.
/// </summary>
public sealed partial class TutorialHooks
{
    /// <summary>Raised when the command list, the move tiles, the move hint or the callout change,
    /// so the scene redraws the menu, the board and the card.</summary>
    public event Action? Changed;

    // ---------------------------------------------------------------- 1. Command restriction

    /// <summary>Allow-list names that match a menu label other than their own.</summary>
    private static readonly IReadOnlyDictionary<string, string> CommandAliases =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { ["Skills"] = "Abilities" };

    private string[]? _allowedCommands;

    public bool CommandsRestricted => _allowedCommands != null;

    /// <summary>
    /// Only menu entries and sub-entries whose label contains one of <paramref name="allowed"/>
    /// (case-insensitive) stay enabled; every other entry shows disabled, and its hotkey is refused.
    /// No names disables every entry. "Skills" also names the Abilities entry.
    /// </summary>
    public void RestrictCommands(params string[] allowed)
    {
        _allowedCommands = allowed.Where(n => !string.IsNullOrWhiteSpace(n)).ToArray();
        Changed?.Invoke();
    }

    public void ClearCommandRestriction()
    {
        _allowedCommands = null;
        Changed?.Invoke();
    }

    /// <summary>True when the menu label may be used under the current restriction.</summary>
    public bool IsCommandAllowed(string label)
    {
        if (_allowedCommands == null) return true;
        foreach (string name in _allowedCommands)
        {
            if (label.Contains(name, StringComparison.OrdinalIgnoreCase)) return true;
            if (CommandAliases.TryGetValue(name, out string? alias)
                && label.Contains(alias, StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    // ---------------------------------------------------------------- 2. Move restriction

    private HashSet<PF2eVec>? _moveTiles;

    /// <summary>The only tiles a move may end on, or null when moves are free.</summary>
    public IReadOnlyCollection<PF2eVec>? MoveTiles => _moveTiles;

    /// <summary>The line the forecast slot shows while the move is restricted.</summary>
    public string? MoveHint { get; private set; }

    /// <summary>Raised with the tile of a refused move click. No action is spent.</summary>
    public event Action<PF2eVec>? MoveRefused;

    /// <summary>Only <paramref name="tiles"/> accept a move click. They show as gold tiles on the
    /// board; the move bands still draw for the rest.</summary>
    public void RestrictMoveTo(IEnumerable<PF2eVec> tiles, string hint)
    {
        _moveTiles = new HashSet<PF2eVec>(tiles);
        MoveTilesAreHint = false;
        MoveHint = hint;
        Changed?.Invoke();
    }

    /// <summary>True when <see cref="MoveTiles"/> are only a suggestion: every tile accepts a move.</summary>
    public bool MoveTilesAreHint { get; private set; }

    /// <summary>Show <paramref name="tiles"/> as gold tiles over the move bands without restricting
    /// the move: every tile accepts a click, and no wrong-tile tip shows.</summary>
    public void HintMoveTo(IEnumerable<PF2eVec> tiles)
    {
        _moveTiles = new HashSet<PF2eVec>(tiles);
        MoveTilesAreHint = true;
        MoveHint = null;
        Changed?.Invoke();
    }

    public void ClearMoveRestriction()
    {
        _moveTiles = null;
        MoveTilesAreHint = false;
        MoveHint = null;
        Changed?.Invoke();
    }

    public bool IsMoveAllowed(PF2eVec tile) => _moveTiles == null || MoveTilesAreHint || _moveTiles.Contains(tile);

    internal void RaiseMoveRefused(PF2eVec tile) => MoveRefused?.Invoke(tile);

    // ---------------------------------------------------------------- 3. Forced dice

    /// <summary>Queue the next d20 results, in order. The queue is global: any d20 rolled first
    /// takes the value. Encounter reset and encounter end empty it.</summary>
    public void ForceNextD20(params int[] values) => DiceRoller.EnqueueD20(values);

    /// <summary>Queue the next non-d20 die results (damage, persistent damage), in order.</summary>
    public void ForceNextDice(params int[] values) => DiceRoller.EnqueueDie(values);

    public void ClearForcedDice() => DiceRoller.ClearAllOverrides();

    /// <summary>A d20 that gives <paramref name="degree"/> on the attacker's next Strike against
    /// the target, read from the live attack bonus (MAP, off-guard included) and AC.</summary>
    public static int D20For(ICharacter attacker, ICharacter target, DegreeOfSuccess degree)
        => TutorialDice.ForStrike(attacker, target, degree);

    /// <summary>A d20 that gives <paramref name="degree"/> on the actor's skill action (by
    /// SkillActionCatalog id, e.g. "recall-knowledge") against the target.</summary>
    public static int D20ForSkill(ICharacter actor, ICharacter target, string actionId, DegreeOfSuccess degree)
        => TutorialDice.ForSkill(actor, target, actionId, degree);

    /// <summary>A d20 that gives <paramref name="degree"/> for a check with this modifier against this DC.</summary>
    public static int D20ForCheck(int modifier, int dc, DegreeOfSuccess degree)
        => TutorialDice.ForCheck(modifier, dc, degree);

    // ---------------------------------------------------------------- 4. Turn control

    private readonly Dictionary<ICharacter, string> _autoPass = new();
    private readonly Dictionary<(ICharacter Unit, int Round), ScriptedTurn> _scripted = new();

    /// <summary>The character's turns end at once with <paramref name="logLine"/> in the log.</summary>
    public void AutoPass(ICharacter character, string logLine)
    {
        _autoPass[character] = logLine;
    }

    public void ClearAutoPass(ICharacter character) => _autoPass.Remove(character);

    /// <summary>Replace the AI for this enemy in this round (rounds count from 1). Unscripted
    /// enemies, and this one in other rounds, keep their AI.</summary>
    public void ScriptEnemyTurn(ICharacter character, int round, ScriptedTurn turn)
    {
        _scripted[(character, round)] = turn;
    }

    internal string? AutoPassLine(ICharacter character)
        => _autoPass.TryGetValue(character, out string? line) ? line : null;

    /// <summary>The script for this enemy and round. It stays registered, so a restarted fight
    /// replays it.</summary>
    internal ScriptedTurn? ScriptFor(ICharacter character, int round)
        => _scripted.TryGetValue((character, round), out var turn) ? turn : null;

    // ---------------------------------------------------------------- 6. Forced reveal order

    private readonly Dictionary<string, Queue<CreatureKnowledgeField>> _forcedReveals =
        new(StringComparer.OrdinalIgnoreCase);

    /// <summary>The next Recall Knowledge success against this species reveals this field first.
    /// Queue several to fix the order; a critical success takes two queued fields.</summary>
    public void ForceNextReveal(string creatureId, CreatureKnowledgeField field)
    {
        string key = Ungilded.Knowledge.MonsterJournal.Key(creatureId);
        if (!_forcedReveals.TryGetValue(key, out var queue))
            _forcedReveals[key] = queue = new Queue<CreatureKnowledgeField>();
        queue.Enqueue(field);
    }

    /// <summary>Up to <paramref name="count"/> queued fields for the species, removed from the queue.</summary>
    internal IReadOnlyList<CreatureKnowledgeField> TakeForcedReveals(string? creatureId, int count)
    {
        var taken = new List<CreatureKnowledgeField>();
        if (count <= 0 || !_forcedReveals.TryGetValue(Ungilded.Knowledge.MonsterJournal.Key(creatureId), out var queue))
            return taken;
        while (taken.Count < count && queue.Count > 0) taken.Add(queue.Dequeue());
        return taken;
    }

    // ---------------------------------------------------------------- 7. Hidden fields on the card

    /// <summary>True while the unit card draws the callout beside its ??? rows.</summary>
    public bool CalloutShown { get; private set; }

    public string CalloutText { get; private set; } = "";

    /// <summary>Draw <paramref name="text"/> beside the ??? rows of an enemy's card, or hide it.</summary>
    public void ShowHiddenFieldsCallout(bool show, string text = "")
    {
        CalloutShown = show;
        CalloutText = show ? text : "";
        Changed?.Invoke();
    }
}
