using System.Threading.Tasks;
using PF2e.Core;
using PF2e.Utilities;
using Ungilded.Combat;
using Ungilded.Content;
using Ungilded.Story;

namespace Ungilded.Tutorial.Encounters;

/// <summary>
/// Encounter 1, "The 3-Action System" (spec section 3): the action squares, a Stride to a gold
/// tile, a Strike that hits, a Strike that misses at -5 MAP, End Turn. The Friend holds back. The
/// rat flees through the Player's reach; the stride pauses for the flee event and the reaction tip, and the forced
/// Reactive Strike kills it.
/// </summary>
internal sealed class Encounter1Script : EncounterScript
{
	internal const string FriendHoldsBack = "The Friend holds back.";
	internal const string WrongTile = "Click one of the gold tiles to move adjacent to the rat.";
	internal const string ActionsTip = "You get 3 actions each turn. Stride and Strike cost 1 action each.";
	internal const string PreviewTip = "A total that meets or beats the rat's AC deals the Damage shown. The rat's AC is unknown yet, "
		+ "so the preview shows ? for it.";
	internal const string FleeEvent = "The wounded rat begins to flee!";
	internal const string MapTip = "Each extra attack made in a turn takes the multiple attack penalty (MAP): -5, then -10.";
	internal const string EndTurnStep = "You are out of actions. End your turn.";
	internal const string FleePopup = "The Player has Reactive Strike: Strike an enemy that moves out of your reach. "
		+ "Use it on the fleeing rat.";
	private const int FleeTiles = 3;

	private ICharacter _rat = null!;
	private bool _fleeShown;

	/// <summary>The turn stays open at 0 actions so e1_07_end_turn can teach End Turn.</summary>
	public override bool AutoEndTurn => false;

	/// <summary>The Stride tip with the Player's Speed from the engine.</summary>
	internal static string MoveTip(ICharacter hero)
		=> $"The rat is out of reach. Stride moves a character up to their movement speed ({StatsCalculator.GetEffectiveSpeed(hero)} feet). Use Stride to approach the rat.";

	/// <summary>The Strike tip with the hero's attack bonus for the weapon they strike with.</summary>
	internal static string StrikeTip(ICharacter hero)
		=> "Try to Strike the rat with your weapon. A Strike rolls a d20 and adds your Attack bonus "
		   + $"({WeaponAttackCalculator.CalculateAttackBonus(hero, WeaponAttackCalculator.ResolveWeapon(hero)):+0;-0;0}).";

	protected override void OnArm()
	{
		_rat = S.Enemy(PrologueMaps.RatAnchor);
		S.Hooks.AutoPass(S.Friend, FriendHoldsBack);
		S.Hooks.BeforeEnemyStride(async stride =>
		{
			if (_fleeShown || !ReferenceEquals(stride.Unit, _rat)) return;
			_fleeShown = true;
			await S.Rule("e1_08_flee", TutorialFocus.Units(_rat), FleeEvent);
			await S.Rule("e1_08_reaction", TutorialFocus.Reaction(S.Player), FleePopup, "Reactive Strike");
			S.ForceOnCommit(() => TutorialRolls.ReactionStrike(S.Player, _rat, EncounterStage.Hit), 6);
		});
	}

	public override async Task<EncounterOutcome> Play()
	{
		var player = S.Player;
		var gate = await S.NextTurn();
		if (gate == null) return await Outcome();

		S.Allow();
		S.Release(gate);
		await S.Rule("e1_01_actions", TutorialFocus.ActionPips(player), ActionsTip, "3 actions");

		// One tip covers the Move entry and the gold tiles for the whole move. The menu closes once
		// Move is picked, so the cutout then holds the gold tiles alone.
		S.MoveTo(S.FreeNeighbours(player, _rat), WrongTile);
		S.Allow("Move");
		var moveFocus = (TutorialFocus.Command("Move") + TutorialFocus.GuideTiles
			+ TutorialFocus.Units(player, _rat).AsContext()).Undimmed();
		if (!await S.StepUntilSpent(player, "e1_02_move", moveFocus, MoveTip(player), "Stride")) return await Outcome();
		S.ClearMove();

		S.TargetOnly(_rat);
		S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat, EncounterStage.Hit), 4);
		S.Allow("Strike");
		if (!await FirstStrike(player)) return await Outcome();
		S.Allow();

		await S.Say(S.Lines.FriendStrike);
		S.ForceOnCommit(() => TutorialRolls.Strike(player, _rat, EncounterStage.Miss));
		S.Allow("Strike");
		if (!await S.StepUntilSpent(player, "e1_06_map", Strike, MapTip, "multiple attack penalty (MAP)")) return await Outcome();

		S.Allow("End Turn");
		await S.StepUntilTurnEnd(player, "e1_07_end_turn", TutorialFocus.Command("End Turn"), EndTurnStep);
		S.Unlock();

		await RunTurns(turn =>
		{
			if (ReferenceEquals(turn.Unit, _rat))
				S.Hooks.ScriptEnemyTurn(_rat, turn.Round, new ScriptedTurn().StrideAwayFrom(player, FleeTiles));
			S.Release(turn);
			return Task.CompletedTask;
		});
		var outcome = await Outcome();
		await S.Delay(1);
		return outcome;
	}

	/// <summary>The Strike tip on the menu entry until Strike aims, then the preview tip on the held
	/// preview until the Strike is committed; backing out of Strike brings the first tip back.
	/// False when the turn or the encounter ended first.</summary>
	private async Task<bool> FirstStrike(ICharacter player)
	{
		int start = player.Actions?.TotalActionsRemaining ?? 0;
		var entryFocus = (TutorialFocus.Command("Strike") + TutorialFocus.Units(_rat).AsContext()).Undimmed();
		var previewFocus = (TutorialFocus.AttackPreview(_rat) + TutorialFocus.Units(_rat).AsContext()).Undimmed();
		bool Committed() => S.Scene.Controller is { Busy: true } || S.Spent(player, start);
		bool Aiming() => S.Scene.Controller?.Mode == PlayerTurnMode.SelectingStrike;
		while (true)
		{
			using (S.Step("e1_04_strike", entryFocus, StrikeTip(player), "Strike", "Attack bonus"))
				if (!await S.WaitUntil(player, () => Aiming() || Committed())) return false;
			using (S.Step("e1_05_preview", previewFocus, PreviewTip, "AC", "Damage"))
				if (!await S.WaitUntil(player, () => !Aiming() || Committed())) return false;
			if (Committed()) return await S.WaitUntil(player, () => S.Spent(player, start));
		}
	}

	private TutorialFocus Strike =>TutorialFocus.Command("Strike") + TutorialFocus.Units(_rat);
}
