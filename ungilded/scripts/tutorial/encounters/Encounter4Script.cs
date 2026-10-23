using System.Collections.Generic;
using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Data;
using PF2e.Equipment;
using PF2e.MapGen;
using Ungilded.Content;
using Ungilded.Story;
using EncounterOutcome = Ungilded.Story.EncounterOutcome;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Encounter 4, "The Capstone" (spec section 3): the difficult terrain tip on the sludge, a Recall
/// Knowledge forced to a critical success that reveals the Tyrant's AC and acid weakness, the
/// Friend's Acid Flask forced to hit, then a live fight. The half-HP lines fire at 50% of the
/// Tyrant's HP; the quarter lines at 25% or when the last Dire Rat falls, whichever comes first. A
/// win plays the victory lines and the closing narration. A wipe shows the post-mortem popup; the
/// retry skips the opening steps and starts live.
/// </summary>
internal sealed class Encounter4Script : EncounterScript
{
    internal const string HalfLog = "The Sewer Tyrant's hide splits; something beneath it convulses.";
    internal const string QuarterLog = "The Sewer Tyrant staggers. Its movements grow desperate.";

    /// <summary>Not in the spec. The PDF asks for a post-mortem popup that names the tools for this
    /// fight but writes no text, so this is a list of them.</summary>
    internal const string PostMortem = "[b]Defeat[/b]\nThe encounter restarts.\n"
        + "Tools: Recall Knowledge for Weakness, Acid Flask splash, flanking, Reactive Strike.";

    internal const string SludgeTip = "Sludge is difficult terrain. Each sludge tile costs {0} extra feet.";
    internal static readonly string WeaknessPopup = $"The Sewer Tyrant takes {PrologueBestiary.TyrantAcidWeakness} extra damage from acid.";
    internal const string UnlockedTip = "All actions are unlocked.";
    private const string RecallKnowledge = "recall-knowledge";

    private ICharacter _tyrant = null!;
    private ICharacter[] _direRats = System.Array.Empty<ICharacter>();
    private bool _halfFired, _quarterFired;

    protected override void OnArm()
    {
        _tyrant = S.Enemy(PrologueMaps.TyrantAnchor);
        _direRats = new[] { S.Enemy(PrologueMaps.DireRatNorthAnchor), S.Enemy(PrologueMaps.DireRatSouthAnchor) };
        S.Hooks.OnHpBelow(_tyrant, 0.5f, () => { Half(); return Task.CompletedTask; });
        S.Hooks.OnHpBelow(_tyrant, 0.25f, () => { Quarter(); return Task.CompletedTask; });
        S.Hooks.OnDamageTaken((unit, _) =>
        {
            if (System.Array.IndexOf(_direRats, unit) >= 0 && System.Array.TrueForAll(_direRats, IsDown)) Quarter();
            return Task.CompletedTask;
        });
        S.Hooks.OnPartyWiped(() => S.ShowValues("e4_post_mortem", PostMortem));
    }

    public override async Task<EncounterOutcome> Play()
    {
        var gate = await S.NextTurn();
        if (gate != null && S.Attempt == 1 && ReferenceEquals(gate.Unit, S.Player))
        {
            await PlayerOpening(gate);
            gate = await S.NextTurn();
            if (gate != null && ReferenceEquals(gate.Unit, S.Friend)) await FriendOpening(gate);
        }
        var outcome = await Outcome();
        if (outcome != EncounterOutcome.Victory) return outcome;
        await S.Delay(1);
        await S.Say(S.Lines.Victory);
        await S.Say(S.Lines.Closing);
        return outcome;
    }

    private async Task PlayerOpening(TurnGate gate)
    {
        var player = S.Player;
        S.Allow();
        S.Release(gate);
        // The grid adds one tile of movement cost per difficulty step (MapLayoutGridBuilder).
        int extraFeet = PF2eRules.FeetPerTile * (int)TerrainDifficulty.Difficult;
        await S.Rule("e4_01_sludge", TutorialFocus.Tiles(SludgeTiles()), string.Format(SludgeTip, extraFeet),
            "difficult terrain");

        S.TargetOnly(_tyrant);
        S.Hooks.ForceNextReveal(PrologueBestiary.SewerTyrantId, CreatureKnowledgeField.AC);
        S.Hooks.ForceNextReveal(PrologueBestiary.SewerTyrantId, CreatureKnowledgeField.Weaknesses);
        S.ForceOnCommit(() => TutorialHooks.D20ForSkill(player, _tyrant, RecallKnowledge, EncounterStage.Crit));
        S.Allow("Skills", "Recall Knowledge", "Back");
        if (!await S.StepUntilSpent(player, "e4_02_recall", TutorialFocus.Command("Abilities") + TutorialFocus.Units(_tyrant),
                $"Use Recall Knowledge on the {TyrantName}.", "Recall Knowledge")) return;
        S.AnyTarget();
        S.Allow();
        await S.Rule("e4_03_weak", TutorialFocus.KnowledgeRow(_tyrant, CreatureKnowledgeField.Weaknesses),
            WeaknessPopup, "10 extra damage");
        S.Unlock();
        await S.Rule("e4_05_unlocked", TutorialFocus.CommandMenu, UnlockedTip);
        await S.WaitTurnEnd(player);
    }

    private async Task FriendOpening(TurnGate gate)
    {
        var friend = S.Friend;
        S.TargetOnly(_tyrant);
        S.ForceOnCommit(() => TutorialRolls.Bomb(friend, _tyrant, AlchemicalItems.AcidFlaskLesser(), EncounterStage.Hit));
        S.Allow("Abilities", "Throw Acid Flask", "Back");
        S.Release(gate);
        if (!await S.StepUntilSpent(friend, "e4_04_flask", TutorialFocus.Command("Abilities") + TutorialFocus.Units(_tyrant),
                "Throw an Acid Flask at the Sewer Tyrant.", "Acid Flask")) return;
        S.AnyTarget();
        S.Unlock();
    }

    private string TyrantName => _tyrant.CreatureStats?.SourceDefinition?.CreatureName ?? _tyrant.Name;

    /// <summary>Rows from a hero that the sludge tip outlines: the stretch of the band level with the
    /// heroes, its full width, not the whole board's length of it.</summary>
    private const int SludgeTipReach = 3;

    /// <summary>The difficult tiles in the rows near either hero.</summary>
    private List<PF2eVec> SludgeTiles()
    {
        var layout = S.Battle.Layout;
        var tiles = new List<PF2eVec>();
        for (int y = 0; y < layout.Height; y++)
            for (int x = 0; x < layout.Width; x++)
                if (layout.GetTerrainDifficulty(x, y) == TerrainDifficulty.Difficult
                    && (Near(S.Player, y) || Near(S.Friend, y)))
                    tiles.Add(new PF2eVec(x, y));
        return tiles;
    }

    private static bool Near(ICharacter hero, int y) => System.Math.Abs(hero.GridPosition.y - y) <= SludgeTipReach;

    /// <summary>The half-HP line and log row. Combat keeps going while the box shows.</summary>
    private void Half()
    {
        if (_halfFired) return;
        _halfFired = true;
        S.Scene.AppendLog(HalfLog);
        if (S.Lines.HalfHp != null) _ = S.Dialogue.Play(S.Lines.HalfHp);
    }

    private void Quarter()
    {
        if (_quarterFired) return;
        _quarterFired = true;
        S.Scene.AppendLog(QuarterLog);
        if (S.Lines.QuarterHp != null) _ = S.Dialogue.Play(S.Lines.QuarterHp);
    }

    private static bool IsDown(ICharacter c) => c.Health == null || c.Health.IsDead || c.Health.CurrentHP <= 0;
}
