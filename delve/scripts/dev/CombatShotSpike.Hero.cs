using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatShotSpike
{
    /// <summary>The hero beats over the live board: centre stage for an unknown AC, the degree track
    /// for a known AC and for an enemy's save against the party's DC, each at its reveal frame and
    /// settled.</summary>
    private async Task CaptureHeroRolls(CombatScene scene)
    {
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        var hero = dice.Hero!;
        var rolls = new (string File, CombatRoll Roll)[]
        {
            ("dice_hero_h1", CombatRoll.Parse("d20(19)+8=27 vs AC ? → CriticalSuccess")!),
            ("dice_hero_h3_attack", CombatRoll.Parse("d20(19)+8=27 vs AC 16 → CriticalSuccess")!),
            ("dice_hero_h3_save", CombatRoll.Parse("Fortitude d20(3)+7=10 vs DC 21 → CriticalFailure")! with { EnemyRoll = true }),
        };
        foreach (var (file, roll) in rolls)
        {
            dice.ClearRoll();
            dice.ShowRoll(roll, file);
            for (int i = 0; i < 300 && !(hero.Visible && hero.Word.Modulate.A >= 0.999f); i++)
                await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            dice.ProcessMode = ProcessModeEnum.Disabled;
            await WaitSeconds(0.1f);
            var rect = hero.GetGlobalRect();
            Check($"{file}: the hero sits inside the frame above the roll row ({rect})",
                new Rect2(0, 0, 1920, 1080).Encloses(rect) && rect.End.Y <= dice.GetGlobalRect().Position.Y);
            if (file == "dice_hero_h1")
                CheckBudget(scene, "transient H1 hero roll", HeroTransientBudgetPercent, null, ("hero roll", rect));
            Capture($"{file}_reveal.png");
            dice.ProcessMode = ProcessModeEnum.Inherit;
            await WaitSettled(dice);
            Capture($"{file}_settled.png");
        }
        dice.ClearRoll();
    }

    private async Task WaitSettled(DiceRollPanel dice)
    {
        for (int i = 0; i < 300 && !(dice.Settled && dice.Hero?.Visible != true); i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        await WaitSeconds(0.1f);
    }
}
