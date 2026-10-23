using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Data;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Story;
using EncounterOutcome = Ungilded.Story.EncounterOutcome;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Encounter 2, "Recall Knowledge" (spec section 3, PDF version per section 8): Recall Knowledge
/// fills in the rat's Abilities row, a Move and a Strike kill Rat 1, Rat 2 bites the Player for
/// about a quarter of his HP, a second Recall Knowledge reveals AC, a Strike kills Rat 2. The Friend
/// holds back. After the fight the Friend treats the Player's wounds. The PDF's first reveal is the
/// name, but this build always shows the name, so the first reveal is a row the card hides.
/// </summary>
internal sealed class Encounter2Script : EncounterScript
{
	internal const string RecallTip = "Recall Knowledge, under Abilities, is a skill check. A success reveals one ??? "
		+ "on the rat's card.";
	internal const string HpTip = "HP doesn't refill between fights. At 0 HP a hero is dying.";
	private const string RecallKnowledge = "recall-knowledge";

	/// <summary>The AC tip, naming the studied creature's kind: what is learned is kept per kind.</summary>
	internal static string AcTip(ICharacter creature)
		=> $"Facts you learn apply to every {creature.CreatureStats?.SourceDefinition?.CreatureName ?? creature.Name}.";

	private ICharacter _rat1 = null!, _rat2 = null!;

	public override CombatSetup Configure(CombatSetup setup)
		=> base.Configure(setup) with { RecallAfterSuccess = true };

	protected override void OnArm()
	{
		_rat1 = S.Enemy(PrologueMaps.RatAnchorN(1));
		_rat2 = S.Enemy(PrologueMaps.RatAnchorN(2));
		S.Hooks.AutoPass(S.Friend, Encounter1Script.FriendHoldsBack);
	}

	public override async Task<EncounterOutcome> Play()
	{
		await RunTurns(turn =>
		{
			if (ReferenceEquals(turn.Unit, S.Player))
				return turn.Round == 1 ? PlayerRoundOne(turn) : PlayerRoundTwo(turn);
			if (ReferenceEquals(turn.Unit, _rat2) && turn.Round == 1) ScriptBite(turn.Round);
			S.Release(turn);
			return Task.CompletedTask;
		});
		var outcome = await Outcome();
		if (outcome == EncounterOutcome.Victory)
			await TreatWoundsBeat.Play(S, "e2_10_treat_wounds", healer: S.Friend, patient: S.Player);
		await S.Delay(1);
		return outcome;
	}

	private async Task PlayerRoundOne(TurnGate gate)
	{
		var player = S.Player;
		S.Hooks.ForceNextReveal(PrologueBestiary.SewerRatId, CreatureKnowledgeField.Strikes);
		S.ForceOnCommit(() => TutorialHooks.D20ForSkill(player, _rat1, RecallKnowledge, EncounterStage.Hit));
		S.Allow("Skills", "Recall Knowledge", "Back");
		S.Release(gate);
		if (!await S.StepUntilSpent(player, "e2_01_recall", Recall(_rat1, _rat2), RecallTip, "Recall Knowledge", "Abilities"))
			return;
		S.Allow();

		S.MoveTo(S.FreeNeighbours(player, _rat1), Encounter1Script.WrongTile);
		S.Allow("Move");
		if (!await S.StepUntilSpent(player, "e2_03_move", (TutorialFocus.Command("Move") + TutorialFocus.GuideTiles).Undimmed(),
				"Stride next to the rat.")) return;
		S.ClearMove();

		S.TargetOnly(_rat1);
		S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat1, EncounterStage.Hit), 8);
		S.Allow("Strike");
		if (!await S.StepUntilSpent(player, "e2_04_strike", Strike(_rat1), "Strike the rat.")) return;
		S.Unlock();
		// The third action ends the turn.
		await S.WaitTurnEnd(player);
	}

	/// <summary>Rat 2 closes in without provoking and bites for 1d6+1 with the die forced to 4:
	/// 5 of the Player's 19 HP.</summary>
	private void ScriptBite(int round)
	{
		var script = new ScriptedTurn();
		if (!EncounterStage.Adjacent(_rat2, S.Player) && S.ApproachTile(_rat2, S.Player) is { } tile)
			script.StrideTo(tile, provokes: false);
		S.Hooks.ScriptEnemyTurn(_rat2, round, script.Strike(S.Player).EndTurn());
		S.Force(TutorialRolls.Strike(_rat2, S.Player, EncounterStage.Hit), 4);
	}

	private async Task PlayerRoundTwo(TurnGate gate)
	{
		var player = S.Player;
		S.Allow();
		S.Release(gate);
		await S.Rule("e2_06_hp", TutorialFocus.HpBar(player), HpTip, "HP", "dying");

		S.Hooks.ForceNextReveal(PrologueBestiary.SewerRatId, CreatureKnowledgeField.AC);
		S.ForceOnCommit(() => TutorialHooks.D20ForSkill(player, _rat2, RecallKnowledge, EncounterStage.Hit));
		S.Allow("Skills", "Recall Knowledge", "Back");
		if (!await S.StepUntilSpent(player, "e2_07_recall", Recall(_rat2), "Use Recall Knowledge on the other rat.",
				"Recall Knowledge")) return;
		S.Allow();
		await S.Rule("e2_08_ac", TutorialFocus.KnowledgeRow(_rat2, CreatureKnowledgeField.AC), AcTip(_rat2), "every");

		S.TargetOnly(_rat2);
		S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat2, EncounterStage.Hit), 6);
		S.Allow("Strike");
		await S.StepUntilSpent(player, "e2_09_strike", Strike(_rat2), "Strike the rat.");
		S.Unlock();
	}

	private static TutorialFocus Recall(params ICharacter[] rats) => TutorialFocus.Command("Abilities") + TutorialFocus.Units(rats);

	private static TutorialFocus Strike(ICharacter rat) => TutorialFocus.Command("Strike") + TutorialFocus.Units(rat);
}
