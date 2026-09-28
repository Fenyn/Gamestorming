using System.Threading.Tasks;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatLogSpike
{
    /// <summary>Which beat each roll gets, the degree zones and their tones, the short beat, skipping,
    /// the reaction promotion and the two hero stages.</summary>
    private async Task CheckBeats(Control frame)
    {
        var known = CombatRoll.Parse("d20(12)+10=22 vs AC 16 → Success")!;
        var masked = CombatRoll.Parse("d20(12)+10=22 vs AC ? → Success")!;
        var maskedCheck = CombatRoll.Parse("Athletics: 12 + 5 = 17 vs DC ? → Success")!;
        var enemy = known with { EnemyRoll = true };
        Check("an unknown defence picks centre stage and a known one the degree track",
            RollBeat.For(masked, true).Stage == RollStage.CentreStage && RollBeat.For(maskedCheck, true).Stage == RollStage.CentreStage
            && RollBeat.For(known, true).Stage == RollStage.DegreeTrack && RollBeat.For(enemy, true).Stage == RollStage.DegreeTrack);
        Check("the party's own rolls get the full beat and routine enemy rolls the short beat",
            RollBeat.For(known, true).Pace == RollPace.Full && RollBeat.For(enemy, true).Pace == RollPace.Short);
        Check("an enemy natural 20, natural 1, critical result or reaction trigger gets the full beat",
            RollBeat.For(enemy with { Die = 20 }, true).Pace == RollPace.Full
            && RollBeat.For(enemy with { Die = 1, Degree = "Failure" }, true).Pace == RollPace.Full
            && RollBeat.For(enemy with { Degree = "CriticalFailure" }, true).Pace == RollPace.Full
            && RollBeat.For(enemy, true, reaction: true).Pace == RollPace.Full);
        Check("only a critical success adds the freeze", RollBeat.For(known with { Degree = "CriticalSuccess" }, true).Freeze
            && !RollBeat.For(known, true).Freeze && !RollBeat.For(known with { Degree = "CriticalFailure" }, true).Freeze);
        Check("with the dice reveal off every roll is settled", RollBeat.For(known, false).Pace == RollPace.Settled);

        Check("the zones break at DC-10, DC and DC+10",
            DegreeZones.Of(6, 16) == DegreeZones.CriticalFailure && DegreeZones.Of(7, 16) == DegreeZones.Failure
            && DegreeZones.Of(15, 16) == DegreeZones.Failure && DegreeZones.Of(16, 16) == DegreeZones.Success
            && DegreeZones.Of(25, 16) == DegreeZones.Success && DegreeZones.Of(26, 16) == DegreeZones.CriticalSuccess);
        Check("a party attack colours its zones bad to good",
            RollTone.For(0, false) == UiColors.HpLow && RollTone.For(1, false) == UiColors.TextDim
            && RollTone.For(2, false) == UiColors.HpHigh && RollTone.For(3, false) == UiColors.Accent);
        Check("an enemy's save inverts them, so its failure reads as good news",
            RollTone.For(0, true) == UiColors.Accent && RollTone.For(1, true) == UiColors.HpHigh
            && RollTone.For(2, true) == UiColors.Enemy && RollTone.For(3, true) == UiColors.HpLow);
        Check("attack zones read as hits and misses, checks as successes and failures",
            DegreeZones.Label(0, true) == "Crit miss" && DegreeZones.Label(2, true) == "Hit"
            && DegreeZones.Label(0, false) == "Crit fail" && DegreeZones.Label(2, false) == "Success");

        var skill = CombatRoll.Parse("Athletics: 12 + 0 MAP-5 = 12 vs DC 18 → Failure");
        Check($"a skill check line parses with its penalty split out ({skill})", skill is { Die: 12, Total: 12, DC: 18, Defense: "DC", Modifiers: "+5 MAP-5" }
            && !DiceRollPanel.FormatAdjustments(skill).Contains("Other"));
        Check("a skill check DC masks as ?", CombatRoll.MaskCheckDc("Athletics: 12 + 5 = 17 vs DC 18 → Failure") == "Athletics: 12 + 5 = 17 vs DC ? → Failure"
            && CombatRoll.Parse(CombatRoll.MaskCheckDc("Athletics: 12 + 5 = 17 vs DC 18 → Failure"))!.DcMasked);

        var dice = DiceScene.Instantiate<DiceRollPanel>();
        frame.AddChild(dice);
        var hero = dice.Hero!;
        ulong started = Time.GetTicksMsec();
        dice.ShowRoll(enemy, "Routine");
        Check("the short beat fills the row with no hero", dice.Beat?.Pace == RollPace.Short && !hero.Visible
            && dice.Visible && Mathf.IsEqualApprox(dice.SelfModulate.A, 1f));
        await dice.WaitForResultsAsync();
        float shortGate = (Time.GetTicksMsec() - started) / 1000f;
        Check($"the short beat opens the gate in about {dice.GateSeconds(dice.Beat!):0.0} s ({shortGate:0.00} s)", shortGate < 0.5f);

        dice.ClearRoll();
        dice.ShowRoll(known, "Skipped");
        await Seconds(0.1f);
        var gate = dice.WaitForResultsAsync();
        dice._Input(new InputEventAction { Action = InputNames.Confirm, Pressed = true });
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("Enter skips the full beat to the settled row and opens the gate", dice.Settled && !hero.Visible && gate.IsCompleted
            && Mathf.IsEqualApprox(dice.SelfModulate.A, 1f) && dice.GetNode<Label>("%RollOutcome").Text == "HIT");
        dice.ClearRoll();
        dice.ShowRoll(known, "Clicked");
        dice._Input(new InputEventMouseButton { ButtonIndex = MouseButton.Left, Pressed = true });
        Check("a click skips it too", dice.Settled && !hero.Visible);
        dice.ClearRoll();
        dice.ShowRoll(enemy, "Declined");
        dice._Input(new InputEventAction { Action = InputNames.Decline, Pressed = true });
        Check("Esc skips a short beat", dice.Settled);

        dice.ClearRoll();
        dice.ShowRoll(enemy, "Reaction trigger");
        dice.PromoteLatest();
        Check("a routine enemy roll that raises a reaction prompt restarts as the full beat",
            dice.Beat?.Pace == RollPace.Full && hero.Visible);

        dice.ClearRoll();
        dice.ShowRoll(masked, "Unknown AC");
        await dice.WaitForResultsAsync();
        Check($"centre stage prints vs ? and counts the modifier into the total ('{hero.TargetText}', '{hero.Total.Text}')",
            hero.Stage == RollStage.CentreStage && hero.TargetText == "?" && hero.Total.Text == "22"
            && Mathf.IsEqualApprox(hero.Chip.Modulate.A, 1f) && hero.Word.Text == "HIT");
        Check("the settled row after centre stage has no track", !dice.RowTrack.Visible);
        dice.ClearRoll();
        var save = CombatRoll.Parse("Fortitude d20(3)+7=10 vs DC 21 → CriticalFailure")! with { EnemyRoll = true };
        dice.ShowRoll(save, "Enemy save");
        await dice.WaitForResultsAsync();
        Check("an enemy's critically failed save plays the track and lights its zone in the accent",
            hero.Stage == RollStage.DegreeTrack && hero.Track.LitZone == DegreeZones.CriticalFailure
            && hero.Track.ZoneColor(DegreeZones.CriticalFailure) == UiColors.Accent
            && hero.Track.ZoneColor(DegreeZones.CriticalSuccess) == UiColors.HpLow);
        dice.ClearRoll();
        dice.QueueFree();
    }
}
