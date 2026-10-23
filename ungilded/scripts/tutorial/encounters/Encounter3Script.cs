using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Equipment;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Story;
using DamageType = PF2e.Data.DamageType;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Encounter 3, "Fight Together", the PDF roll table (spec sections 3 and 8). Round 1: two hits on
/// Rat 1, the Friend bombs Rat 3 (splashing Rat 4) and then flanks Rat 1; the rats miss and Rat 4's hidden
/// bite gives the Friend bleed. Round 2: the Critical Hit on flanked Rat 1, the Critical Miss and a
/// hit on Rat 2, the Friend's Sneak Attack kills Rat 2 and the second flask kills Rat 3; the bleed
/// ticks for 2 and the recovery check ends it. Round 3 is guided, not scripted: the full menu, gold
/// flank tiles that lock nothing, and every hero Strike forced to hit with dice chosen by its target
/// (Encounter3Script.RoundThree.cs). A turn ends at 0 actions; the Friend's round 1 turn, which
/// stops with an action left, is ended by the script. After a win the Friend treats both heroes'
/// wounds. The rats' turns are in Encounter3Script.Rats.cs.
/// </summary>
internal sealed partial class Encounter3Script : EncounterScript
{
    internal const string FlankingTip = "Allies on opposite sides of an enemy flank it. A flanked enemy is off-guard "
        + "to its flankers: -2 AC against their attacks.";
    internal const string FlankStep = "Stride to the gold tile to flank the rat.";
    /// <summary>The start of the tip after the first flask lands.</summary>
    internal const string SplashTipStart = "The flask hit ";
    internal const string FlankedTip = "This rat is off-guard. Sneak Attack adds {0} to the Friend's Strikes against it.";
    internal const string CritPopup = "Beating AC by 10 or more is a critical hit: double damage.";
    internal const string FumbleNaturalTip = "A natural 1 drops the result one step: this miss is a critical miss.";
    internal const string FumbleMarginTip = "Missing AC by 10 or more is a critical miss.";
    internal const string StrikeNextStep = "The first rat is down. Strike the next one. The -5 MAP still applies.";
    internal const string BleedTip = "Bleed deals {0} at the end of the Friend's turn until a DC {1} flat check ends it.";
    internal const string SneakStep = "This rat is off-guard too, so Sneak Attack applies.";
    private const string WrongTile = Encounter1Script.WrongTile;
    private const string Strike = "Strike";
    private const string StrikeRat = "Strike the rat.";

    private ICharacter _rat1 = null!, _rat2 = null!, _rat3 = null!, _rat4 = null!, _rat5 = null!;
    private PF2e.Vector2Int _rat3Anchor, _rat5Anchor;
    private readonly BombDefinition _flask = AlchemicalItems.AcidFlaskLesser();
    private bool _fumbleByNaturalOne;

    /// <summary>The flask tip with the flask's damage from its definition.</summary>
    internal static string FlaskTip(BombDefinition flask)
        => $"An Acid Flask is a thrown attack. Its {flask.SplashDamage} acid splash also hits everything next to the "
           + "target. Throw it at the far rat.";

    protected override void OnArm()
    {
        _rat1 = S.Enemy(PrologueMaps.RatAnchorN(1));
        _rat2 = S.Enemy(PrologueMaps.RatAnchorN(2));
        _rat3 = S.Enemy(PrologueMaps.RatAnchorN(3));
        _rat4 = S.Enemy(PrologueMaps.RatAnchorN(4));
        _rat5 = S.Enemy(PrologueMaps.RatAnchorN(5));
        _rat3Anchor = S.Battle.Anchor(PrologueMaps.RatAnchorN(3));
        _rat5Anchor = S.Battle.Anchor(PrologueMaps.RatAnchorN(5));
    }

    public override async Task<EncounterOutcome> Play()
    {
        await RunTurns(HeroTurn);
        var outcome = await Outcome();
        if (outcome == EncounterOutcome.Victory)
        {
            await TreatWoundsBeat.Play(S, "e3_27_treat_wounds", healer: S.Friend, patient: S.Player);
            await TreatWoundsBeat.Play(S, "e3_28_treat_wounds", healer: S.Friend, patient: S.Friend);
        }
        await S.Delay(1);
        return outcome;
    }

    private Task HeroTurn(TurnGate turn)
    {
        bool player = ReferenceEquals(turn.Unit, S.Player);
        if (!player && !ReferenceEquals(turn.Unit, S.Friend)) return EnemyTurn(turn);
        return turn.Round switch
        {
            1 => player ? PlayerRoundOne(turn) : FriendRoundOne(turn),
            2 => player ? PlayerRoundTwo(turn) : FriendRoundTwo(turn),
            3 => player ? PlayerRoundThree(turn) : FriendRoundThree(turn),
            _ => FreeTurn(turn),
        };
    }

    /// <summary>A turn past round 3: no restriction, live dice.</summary>
    private Task FreeTurn(TurnGate turn)
    {
        S.Unlock();
        S.Release(turn);
        return Task.CompletedTask;
    }

    // ---------------------------------------------------------------- Round 1

    private async Task PlayerRoundOne(TurnGate gate)
    {
        var player = S.Player;
        S.Allow();
        S.Release(gate);

        S.MoveTo(new[] { S.Battle.Anchor(PrologueMaps.PlayerFlankRat1Mark) }, WrongTile);
        if (!await Move(player, "e3_02_move", TutorialFocus.GuideTiles, "Stride next to the front rat.")) return;

        S.TargetOnly(_rat1);
        S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat1, EncounterStage.Hit), 6);
        if (!await Act(player, Strike, "e3_03_strike", StrikeAt(_rat1), StrikeRat)) return;

        S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat1, EncounterStage.Hit), 1);
        await Act(player, Strike, "e3_04_strike_map", StrikeAt(_rat1), "Strike again at -5 MAP.", "-5 MAP");
        S.Unlock();
    }

    private async Task FriendRoundOne(TurnGate gate)
    {
        var friend = S.Friend;
        S.Release(gate);
        if (!await FirstFlask(friend)) return;

        await S.Rule("e3_07_flanking", TutorialFocus.Units(_rat1, S.Player, friend), FlankingTip, "flank", "off-guard");
        S.MoveTo(new[] { S.Battle.Anchor(PrologueMaps.FriendFlankRat1Mark) }, WrongTile);
        if (!await Move(friend, "e3_07_flank", TutorialFocus.GuideTiles, FlankStep)) return;
        await S.EndTurn(friend);
        S.Unlock();
    }

    /// <summary>The first flask at Rat 3, then a rule tip with what it hit and splashed, read from
    /// the throw's damage events.</summary>
    private async Task<bool> FirstFlask(ICharacter friend)
    {
        var hits = new Dictionary<ICharacter, BattleEvent>();
        void Note(BattleEvent evt)
        {
            if (evt.Type == BattleEventType.DamageDealt && evt.Target != null
                && evt.Extra?.ContainsKey(BombEventKeys.Splash) == true) hits[evt.Target] = evt;
        }
        var session = S.Session;
        session.EventPresented += Note;
        bool thrown;
        try { thrown = await ThrowFlask(friend, _rat3, "e3_06_flask", FlaskTip(_flask), "Acid Flask", "splash"); }
        finally { session.EventPresented -= Note; }
        if (!thrown || !hits.TryGetValue(_rat3, out var direct)) return thrown;

        // The combat log's short names, so the tip and the log rows beside it agree.
        string target = Ungilded.UI.CombatLogFormat.ShortName(_rat3.Name);
        string text = $"{SplashTipStart}{target} for {direct.IntValue ?? 0} {DamageWord(direct.DamageType)} damage";
        var gold = new List<string>();
        if (hits.TryGetValue(_rat4, out var splash))
        {
            text += $" and splashed {Ungilded.UI.CombatLogFormat.ShortName(_rat4.Name)} for {splash.IntValue ?? 0}";
            gold.Add("splashed");
        }
        text += ".";
        await S.Rule("e3_06b_splash", TutorialFocus.Units(_rat3, _rat4), text, gold.ToArray());
        return true;
    }

    private static string DamageWord(DamageType? type) => type?.ToString().ToLowerInvariant() ?? "";

    // ---------------------------------------------------------------- Round 2

    private async Task PlayerRoundTwo(TurnGate gate)
    {
        var player = S.Player;
        S.Allow();
        S.Release(gate);
        await S.Rule("e3_09_flanked", TutorialFocus.Units(_rat1, player, S.Friend),
            string.Format(FlankedTip, $"1d{PrologueCast.FriendSneakAttackDie}"), "off-guard", "Sneak Attack");

        S.TargetOnly(_rat1);
        S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat1, EncounterStage.Crit), 6);
        if (!await Act(player, Strike, "e3_10_strike", StrikeAt(_rat1), "Strike the flanked rat.")) return;
        await S.Rule("e3_11_crit", TutorialFocus.RollBanner, CritPopup, "critical hit");

        S.TargetOnly(_rat2);
        S.ForceOnCommit(() =>
        {
            int d20 = TutorialRolls.Strike(player, _rat2, EncounterStage.Fumble);
            _fumbleByNaturalOne = TutorialRolls.FumbleByNaturalOne(player, _rat2, d20);
            return d20;
        });
        if (!await Act(player, Strike, "e3_12_strike_map", StrikeAt(_rat2), StrikeNextStep, "-5 MAP")) return;
        await S.Rule("e3_12b_fumble", TutorialFocus.RollBanner,
            _fumbleByNaturalOne ? FumbleNaturalTip : FumbleMarginTip, "critical miss");

        S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat2, EncounterStage.Hit), 1);
        await Act(player, Strike, "e3_13_strike_map", StrikeAt(_rat2), "Strike again at -10 MAP.", "-10 MAP");
        S.Unlock();
    }

    private async Task FriendRoundTwo(TurnGate gate)
    {
        var friend = S.Friend;
        S.Allow();
        S.Release(gate);
        await S.Rule("e3_15_bleed", TutorialFocus.Condition(friend, BleedIcon),
            string.Format(BleedTip, PrologueBestiary.ViciousBleed, TutorialRolls.FlatDc), "Bleed", "flat check");

        S.MoveTo(new[] { EncounterStage.Opposite(_rat2, S.Player) }, WrongTile);
        if (!await Move(friend, "e3_16_flank", TutorialFocus.GuideTiles + TutorialFocus.Units(_rat2, S.Player),
                "Stride to flank this rat too.")) return;

        S.TargetOnly(_rat2);
        S.ForceOnCommit(() => TutorialRolls.Strike(friend, _rat2, EncounterStage.Hit), 2, 3);
        if (!await Act(friend, Strike, "e3_17_sneak", StrikeAt(_rat2), SneakStep,
                "Sneak Attack")) return;

        // The turn stays open past the flask so the bleed's tick (2) and its recovery check (a
        // success) are queued before the turn ends.
        S.AutoEndTurn = false;
        try
        {
            if (!await ThrowFlask(friend, _rat3, "e3_18_flask", "Throw the second flask at the far rat.")) return;
            S.ForceOnCommit(() => TutorialRolls.Flat(EncounterStage.Hit), 2);
            await S.EndTurn(friend);
        }
        finally { S.AutoEndTurn = true; }
        S.Unlock();
    }

    // ---------------------------------------------------------------- Steps

    /// <summary>The condition icon key of persistent bleed on the timeline.</summary>
    private const string BleedIcon = "Bleed";

    private static TutorialFocus StrikeAt(ICharacter rat) => TutorialFocus.Command(Strike) + TutorialFocus.Units(rat);

    /// <summary>Allow Move, show the step tip on the Move entry and <paramref name="focus"/> with no
    /// dim until the move is made, then lock the menu. A board click moves only once Move is picked.</summary>
    private async Task<bool> Move(ICharacter actor, string id, TutorialFocus focus, string text, params string[] gold)
    {
        S.Allow("Move");
        bool moved = await S.StepUntilSpent(actor, id, (TutorialFocus.Command("Move") + focus).Undimmed(), text, gold);
        S.ClearMove();
        S.Allow();
        return moved;
    }

    /// <summary>Allow one command, show the step tip until it is spent, then lock the menu again.</summary>
    private async Task<bool> Act(ICharacter actor, string command, string id, TutorialFocus focus, string text,
        params string[] gold)
    {
        S.Allow(command);
        bool acted = await S.StepUntilSpent(actor, id, focus, text, gold);
        S.Allow();
        return acted;
    }

    private async Task<bool> ThrowFlask(ICharacter thrower, ICharacter target, string id, string text, params string[] gold)
    {
        S.TargetOnly(target);
        S.ForceOnCommit(() => TutorialRolls.Bomb(thrower, target, _flask, EncounterStage.Hit));
        S.Allow("Abilities", "Throw Acid Flask");
        bool thrown = await S.StepUntilSpent(thrower, id,
            TutorialFocus.Command("Abilities") + TutorialFocus.Units(target), text, gold);
        S.Allow();
        return thrown;
    }
}
