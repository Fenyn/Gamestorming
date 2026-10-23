using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using Godot;
using PF2e.Core;
using Ungilded.Combat;
using Ungilded.Tutorial;
using Ungilded.Tutorial.Encounters;
using Ungilded.UI;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Dev;

/// <summary>The tutorial pacing pass (spec section 8, 2026-10-22): the bot's play of Encounter 3's
/// unrestricted turns, and the checks on the step id lists, the guided round 3, the forced round 3
/// Strikes, End Turn taught once, the hovers, and the Treat Wounds beat that brings both heroes into
/// Encounter 4.</summary>
public partial class PrologueRunSpike
{
    private static readonly string[] E2Steps =
    {
        "e2_01_recall", "e2_03_move", "e2_04_strike", "e2_06_hp", "e2_07_recall", "e2_08_ac", "e2_09_strike",
        "e2_10_treat_wounds",
    };

    private static readonly string[] E3Steps =
    {
        "e3_02_move", "e3_03_strike", "e3_04_strike_map", "e3_06_flask", "e3_06b_splash", "e3_07_flanking",
        "e3_07_flank", "e3_09_flanked", "e3_10_strike", "e3_11_crit", "e3_12_strike_map", "e3_12b_fumble",
        "e3_13_strike_map", "e3_15_bleed", "e3_16_flank", "e3_17_sneak", "e3_18_flask", "e3_20_free", "e3_24_free",
        "e3_27_treat_wounds", "e3_28_treat_wounds",
    };

    private static readonly string[] E4Steps = { "e4_01_sludge", "e4_02_recall", "e4_03_weak", "e4_05_unlocked", "e4_04_flask" };

    /// <summary>Tip ids the pacing pass removed.</summary>
    private static readonly string[] RemovedSteps =
    {
        "e3_01_timeline", "e2_02_learned", "e2_05_end_turn", "e3_05_end_turn", "e3_08_end_turn", "e3_14_end_turn",
        "e3_19_end_turn", "e3_23_end_turn", "e3_26_end_turn",
    };

    private readonly List<string> _guidedStarts = new();
    private readonly List<string> _guidedStartsLocked = new();
    private readonly List<(ICharacter Hero, StrikeInfo Strike)> _roundThreeStrikes = new();
    private readonly Dictionary<ICharacter, int> _hpAtE3End = new();
    private readonly Dictionary<ICharacter, int> _hpAtE4 = new();

    private ICharacter? _freeTarget;
    private PF2eVec? _freeGoal;
    private readonly HashSet<(ICharacter, int)> _freeMoves = new();

    // ---------------------------------------------------------------- Bot

    /// <summary>An unrestricted Encounter 3 turn (round 3 on): Strike a rat that is off-guard to the
    /// hero, or one in reach with all 3 actions left, else Stride once to the first gold flank tile
    /// while 2 actions are left, else Strike any rat in reach, else End Turn.</summary>
    private bool PlayFreeTurn(CombatScene scene, PlayerTurnController controller, CombatSession session)
    {
        var hero = session.CurrentActor!;
        var bar = scene.CommandBar;
        if (controller.Mode == PlayerTurnMode.SelectingStrike) return ClickTarget(scene, controller, session, _freeTarget);
        if (controller.Mode == PlayerTurnMode.Moving)
        {
            if (_freeGoal is { } goal && controller.CanStageOrder(goal)) Click(scene, goal);
            else controller.Cancel();
            _freeGoal = null;
            return true;
        }
        var targets = session.PlayerActions.GetStrikeTargets(hero).Where(c => c.Health?.IsAlive == true).ToList();
        var flanked = targets.FirstOrDefault(t => TutorialRolls.OffGuardTo(hero, t));
        bool canStrike = bar.IsCommandEnabled("Strike");
        int actions = hero.Actions?.TotalActionsRemaining ?? 0;
        GD.Print($"[PrologueRun] free turn {hero.Name} at {hero.GridPosition.x},{hero.GridPosition.y} actions {actions} "
            + $"in reach {targets.Count} flanked {flanked?.Name ?? "-"} gold {string.Join(" ", _runner.Hooks.MoveTiles?.Select(t => $"{t.x},{t.y}") ?? [])} "
            + $"rats {string.Join(" ", session.Team2.Where(c => c.Health?.IsAlive == true).Select(c => $"{c.Name}@{c.GridPosition.x},{c.GridPosition.y} hp {c.Health.CurrentHP}"))}");
        if (canStrike && flanked != null) return BeginFreeStrike(scene, controller, flanked);
        // The turn opens with a Strike on a rat already in reach, as the PDF table does.
        if (canStrike && targets.Count > 0 && actions == 3) return BeginFreeStrike(scene, controller, targets[0]);
        var turn = (hero, session.RoundNumber);
        if (!_freeMoves.Contains(turn) && _runner.Hooks.MoveTiles is { Count: > 0 } gold
            && actions >= 2 && bar.IsCommandEnabled("Move"))
        {
            _freeMoves.Add(turn);
            _freeGoal = gold.OrderBy(t => t.x).ThenBy(t => t.y).First();
            Press(scene, "Move");
            controller.BeginMove();
            return true;
        }
        if (canStrike && targets.Count > 0) return BeginFreeStrike(scene, controller, targets[0]);
        Press(scene, "End Turn");
        controller.EndTurn();
        return true;
    }

    private bool BeginFreeStrike(CombatScene scene, PlayerTurnController controller, ICharacter target)
    {
        _freeTarget = target;
        Press(scene, "Strike");
        controller.BeginStrike();
        return true;
    }

    // ---------------------------------------------------------------- Observers

    /// <summary>At a round 3 tip: the menu is whole, no target filter, and the gold tiles lock nothing.</summary>
    private void NoteGuidedTurnStart(CombatScene? scene, string id)
    {
        if (id is not ("e3_20_free" or "e3_24_free") || scene == null) return;
        var hooks = _runner.Hooks;
        bool open = !hooks.CommandsRestricted && scene.TargetFilter == null && scene.CommandBar.IsCommandEnabled("Move")
            && (hooks.MoveTiles == null || hooks.MoveTilesAreHint);
        (open ? _guidedStarts : _guidedStartsLocked).Add(id);
        _reactionHover = scene.InspectPanel.ReactionHover;
        _timelineHover = scene.TurnBar.TitleHover;
    }

    private string _reactionHover = "", _timelineHover = "";

    private void NoteRoundThreeStrike(StrikeInfo strike)
    {
        if (_runner.Scene?.Session?.RoundNumber == 3 && strike.Attacker.TeamId == 1 && !strike.IsReaction)
            _roundThreeStrikes.Add((strike.Attacker, strike));
    }

    private void NoteHeroHp(Dictionary<ICharacter, int> into)
    {
        foreach (var hero in new ICharacter?[] { _runner.Player, _runner.Friend })
            if (hero != null) into[hero] = hero.Health.CurrentHP;
    }

    /// <summary>Encounter 4, first attempt: the Sewer Tyrant's HP after each hit, for the flask's
    /// persistent acid against its acid weakness.</summary>
    private void NoteTyrantHp(ICharacter unit, int hp)
    {
        if (unit.CreatureStats?.CreatureId != Content.PrologueBestiary.SewerTyrantId) return;
        var session = _runner.Scene?.Session;
        GD.Print($"[PrologueRun] E4 Tyrant HP {hp}/{unit.Health.MaxHP} round {session?.RoundNumber} turn of {session?.CurrentActor?.Name}");
    }

    // ---------------------------------------------------------------- Checks

    private void CheckPacing()
    {
        var ids = _director.Popup.Records.Select(t => t.Id).Where(id => id.Length > 0).ToArray();
        CheckSteps("E2", ids, "e2_", E2Steps);
        CheckSteps("E3", ids, "e3_", E3Steps);
        CheckSteps("E4", ids.Where(id => id != "e4_post_mortem"), "e4_", E4Steps);
        var removed = ids.Where(RemovedSteps.Contains).Distinct().ToArray();
        CheckWith("no removed tip shows (e3_01, e2_02, the removed End Turn steps)", removed.Length == 0, string.Join(", ", removed));
        var endTurnTips = ids.Where(id => id.Contains("end_turn") && !id.StartsWith("e1_")).Distinct().ToArray();
        CheckWith("no End Turn step tip shows after Encounter 1", endTurnTips.Length == 0, string.Join(", ", endTurnTips));

        Check($"E3 round 3 opens with the full menu, no target filter and no move lock ({string.Join(", ", _guidedStarts)})",
            _guidedStarts.Contains("e3_20_free") && _guidedStartsLocked.Count == 0);
        CheckRoundThreeStrikes();
        CheckTreatWoundsIntoE4();

        Check($"the reaction diamond's hover reads the reaction rule ({_reactionHover})",
            _reactionHover == UnitInspectPanel.ReactionTooltip);
        Check($"the timeline's hover reads the turn order rule ({_timelineHover})", _timelineHover == TurnOrderBar.TitleTooltip);
    }

    private void CheckSteps(string label, IEnumerable<string> ids, string prefix, string[] expected)
    {
        var seen = ids.Where(id => id.StartsWith(prefix)).ToArray();
        CheckWith($"{label} tips run in order ({string.Join(", ", seen)})", seen.SequenceEqual(expected),
            $"expected {string.Join(", ", expected)}");
    }

    /// <summary>Every round 3 hero Strike hit; Rat 4 and Rat 5 fell to them.</summary>
    private void CheckRoundThreeStrikes()
    {
        GD.Print($"[PrologueRun] E3 round 3 strikes: {Describe(_roundThreeStrikes.Select(s => s.Strike))}");
        var strikes = _roundThreeStrikes.Select(s => s.Strike).ToArray();
        Check($"E3: every round 3 hero Strike hit its committed target ({strikes.Length} strikes)",
            strikes.Length >= 2 && strikes.All(s => s.Degree == PF2e.Data.DegreeOfSuccess.Success));
        Check("E3: round 3 Strikes killed the last two rats", strikes.Count(s => s.Killed) == 2);
    }

    /// <summary>Each hero enters Encounter 4 with the HP Encounter 3's Treat Wounds left: full or one
    /// short, and no restore on Prepare.</summary>
    private void CheckTreatWoundsIntoE4()
    {
        foreach (var hero in new ICharacter?[] { _runner.Player, _runner.Friend })
        {
            if (hero == null) continue;
            int max = hero.Health.MaxHP;
            int end = _hpAtE3End.GetValueOrDefault(hero, -1);
            int e4 = _hpAtE4.GetValueOrDefault(hero, -1);
            var heal = Regex.Match(Log(3), $@"{Regex.Escape(hero.Name)} HP (\d+) → (\d+)");
            bool viaBeat = heal.Success
                ? int.Parse(heal.Groups[1].Value) == end && int.Parse(heal.Groups[2].Value) == e4
                : end == max && e4 == max;
            Check($"{hero.Name} entered E4 at {e4}/{max} through the Treat Wounds beat (E3 end {end}, heal {heal.Value})",
                e4 >= max - 1 && viaBeat);
        }
    }
}
