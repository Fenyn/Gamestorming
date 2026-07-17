using System;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Godot;
using PF2e.Conditions;
using PF2e.Data;
using PF2e.Utilities;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for out-of-combat Treat Wounds (RAW Player Core, pack
/// actions/skill/treat-wounds.json). Drives a REAL GameState (fresh, on a clean save slot — the
/// user's slot0.json is backed up and restored, mirroring AttritionSpike) through the command
/// surface only, no UI:
///  (1) squad-panel view: DC tiers gate on Medicine proficiency (Trained max DC 15, Expert 15+20),
///      default healer = highest Medicine bonus, Medic Dedication rider shown in the formula;
///  (2) forced-success treatment heals exactly the enqueued dice + tier bonus + rider and spends
///      exactly 10 game-minutes;
///  (3) RAW immunity: an immediate second treatment is rejected; the window is 60 minutes from the
///      treatment START (50 left after the 10-minute treatment), expires on the boundary;
///  (4) validation: Trained healer cannot attempt DC 20 (no time spent); Wounded-at-full-HP is a
///      legal target and success removes Wounded; crit failure deals the 1d8 damage and still
///      starts the immunity window; RAW self-treatment is legal;
///  (5) save → reload into a second fresh GameState → immunity expiry round-trips.
/// Dice are made deterministic via DiceRoller.EnqueueD20/EnqueueDie.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class TreatWoundsSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    private TreatWoundsResultView? _lastResult;

    public override void _Ready()
    {
        GD.Print("==================== TREAT WOUNDS SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[TreatWoundsSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunScenario();
        }
        catch (Exception e)
        {
            GD.PushError($"[TreatWoundsSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            DiceRoller.ClearAllOverrides();
            RestoreSlot0();
        }

        FinishAndQuit("TreatWoundsSpike");
    }

    private void RunScenario()
    {
        // Fresh GameState on the cleaned slot. Freeze real-time ticking so minute assertions are
        // exact — SpendTime (the seam the command charges) advances regardless of IsPaused.
        var gs1 = new GameState();
        AddChild(gs1);
        gs1.Clock.SetPaused("spike", true);
        gs1.TreatWoundsResolved += v => _lastResult = v;

        var squad = gs1.Squad;
        Check("(0) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        var vet = squad.FindMember(SquadRoster.PlayerId)!;
        var scout = squad.FindMember(SquadRoster.ElaraId)!;
        var medic = squad.FindMember(SquadRoster.TharrId)!;
        var scholar = squad.FindMember(SquadRoster.FenwickId)!;

        int schBonus = SkillCalculator.CalculateSkillBonus(scholar, Skill.Medicine);
        int medBonus = SkillCalculator.CalculateSkillBonus(medic, Skill.Medicine);

        // ── (1) Panel view: DC gating + default healer + rider formula ──
        GD.Print("-------------------- (1) View / DC tiers --------------------");
        var view = gs1.GetSquadPanelView();
        Check("(1) panel view built", view != null && view.Members.Count == 4);
        if (view == null)
            return;

        var scholarView = view.Members.First(m => m.Id == SquadRoster.FenwickId);
        var medicView = view.Members.First(m => m.Id == SquadRoster.TharrId);
        Check("(1) Scholar (Medicine Expert) offers DC 15 + 20",
            scholarView.DcOptions.Select(o => o.Dc).SequenceEqual(new[] { 15, 20 }));
        Check("(1) Medic (Trained) offers DC 15 only — cannot attempt DC 20+",
            medicView.DcOptions.Select(o => o.Dc).SequenceEqual(new[] { 15 }));
        // Party facts: the Medic (Wis-based, Trained) out-bonuses the Scholar (Expert, low Wis);
        // the Scholar's edge is the DC 20 tier + rider, not the raw modifier.
        int bestBonus = view.Members
            .Where(m => !m.IsDead && m.DcOptions.Count > 0)
            .Max(m => m.MedicineBonus);
        Check("(1) default healer carries the highest Medicine bonus among the living",
            view.DefaultHealerId != null
            && view.Members.First(m => m.Id == view.DefaultHealerId).MedicineBonus == bestBonus);
        Check("(1) Scholar DC 20 formula shows the Medic Dedication rider: \"2d8+10 (+5)\"",
            scholarView.DcOptions.First(o => o.Dc == 20).SuccessFormula == "2d8+10 (+5)");
        Check("(1) full-HP squad: nobody is a treatable target",
            view.Members.All(m => !m.CanBeTreated));

        // ── (2) Forced success: healing + rider applied, exactly 10 minutes spent ──
        GD.Print("-------------------- (2) Success + rider + clock --------------------");
        // A level-2 fighter has ~32 max HP: injure by 25 (safely above 0 — no dying pipeline)
        // and heal 20 (safely below max — no clamp) so the arithmetic is exact.
        int vetMax = vet.Health!.MaxHP;
        Check("(2) veteran max HP supports the fixture (>= 26)", vetMax >= 26);
        vet.Health.SetCurrentHP(vetMax - 25);

        int roll = 20 - schBonus; // meets DC 20 exactly → plain success
        Check("(2) forced d20 in the safe 2..19 band", roll >= 2 && roll <= 19);
        DiceRoller.EnqueueD20(roll);
        DiceRoller.EnqueueDie(2, 3); // 2d8 → 5

        long before = TreatWoundsSystem.AbsoluteMinute(gs1.Clock);
        _lastResult = null;
        bool ok = gs1.TreatWounds(SquadRoster.FenwickId, SquadRoster.PlayerId, 20);
        long after = TreatWoundsSystem.AbsoluteMinute(gs1.Clock);

        Check("(2) command accepted", ok);
        Check("(2) clock advanced exactly 10 game-minutes", after - before == 10);
        Check("(2) healed 5 (2d8) + 10 (Expert DC) + 5 (Medic Dedication rider) = 20 HP",
            vet.Health.CurrentHP == vetMax - 25 + 20);
        Check("(2) result event fired with formula \"2d8+10+5\" and degree Success",
            _lastResult != null && _lastResult.HealingFormula == "2d8+10+5"
            && _lastResult.DegreeText == "Success" && _lastResult.HealingOrDamage == 20);

        // ── (3) Immunity: immediate re-treat blocked; 60 min from treatment START ──
        GD.Print("-------------------- (3) Immunity window --------------------");
        Check("(3) immediate second treatment is rejected",
            !gs1.TreatWounds(SquadRoster.FenwickId, SquadRoster.PlayerId, 15));
        Check("(3) rejection spent no time",
            TreatWoundsSystem.AbsoluteMinute(gs1.Clock) == after);

        var vetView = gs1.GetSquadPanelView()!.Members.First(m => m.Id == SquadRoster.PlayerId);
        Check("(3) 50 minutes of immunity left after the 10-minute treatment (RAW overlap)",
            vetView.ImmunityMinutesRemaining == 50 && !vetView.CanBeTreated);

        gs1.Clock.SpendTime(49); // 59 minutes since treatment start
        Check("(3) still immune 1 minute before the hour",
            !gs1.TreatWounds(SquadRoster.FenwickId, SquadRoster.PlayerId, 15));

        gs1.Clock.SpendTime(1); // exactly 60 minutes since treatment start
        int vetHp = vet.Health.CurrentHP;
        DiceRoller.EnqueueD20(15 - schBonus);
        DiceRoller.EnqueueDie(1, 1); // 2d8 → 2
        Check("(3) treatable again exactly on the hour boundary",
            gs1.TreatWounds(SquadRoster.FenwickId, SquadRoster.PlayerId, 15));
        Check("(3) post-expiry treatment healed 2 HP (2d8, no tier bonus at DC 15)",
            vet.Health.CurrentHP == vetHp + 2);

        // ── (4) Validation: DC gate, Wounded target, crit failure, self-treatment ──
        GD.Print("-------------------- (4) Validation + outcomes --------------------");
        int schMax = scholar.Health!.MaxHP;
        scholar.Health.SetCurrentHP(schMax - 10);
        long tGate = TreatWoundsSystem.AbsoluteMinute(gs1.Clock);
        Check("(4) Trained Medic cannot attempt DC 20 (gated, no time spent)",
            !gs1.TreatWounds(SquadRoster.TharrId, SquadRoster.FenwickId, 20)
            && TreatWoundsSystem.AbsoluteMinute(gs1.Clock) == tGate);

        // Wounded at full HP is still "injured" per the target gate; success removes Wounded.
        var db = ConditionDatabase.Instance!;
        scout.Conditions!.AddCondition(db.GetCondition(Condition.Wounded)!, value: 1, duration: 0);
        var scoutView = gs1.GetSquadPanelView()!.Members.First(m => m.Id == SquadRoster.ElaraId);
        Check("(4) full-HP member carrying Wounded is a treatable target", scoutView.CanBeTreated);

        int medRoll = 15 - medBonus;
        Check("(4) forced d20 for the Medic in the safe 2..19 band", medRoll >= 2 && medRoll <= 19);
        DiceRoller.EnqueueD20(medRoll);
        DiceRoller.EnqueueDie(1, 1);
        Check("(4) Medic treats the Wounded scout at DC 15",
            gs1.TreatWounds(SquadRoster.TharrId, SquadRoster.ElaraId, 15));
        Check("(4) success removed Wounded (HP already at max, heal clamps)",
            !scout.Conditions.HasCondition(Condition.Wounded)
            && scout.Health!.CurrentHP == scout.Health.MaxHP);

        // Crit failure: nat 1 on a plain failure downgrades → 1d8 damage; immunity still starts.
        Check("(4) Medic bonus low enough that a nat 1 is a critical failure", medBonus + 1 < 15);
        int schHp = scholar.Health.CurrentHP;
        DiceRoller.EnqueueD20(1);
        DiceRoller.EnqueueDie(5); // 1d8 damage
        _lastResult = null;
        Check("(4) crit-fail treatment still executes",
            gs1.TreatWounds(SquadRoster.TharrId, SquadRoster.FenwickId, 15));
        Check("(4) critical failure dealt 5 damage (1d8)",
            scholar.Health.CurrentHP == schHp - 5
            && _lastResult != null && _lastResult.DegreeText == "Critical Failure"
            && _lastResult.HealingOrDamage == -5);
        Check("(4) immunity applies on every outcome, including critical failure",
            gs1.GetSquadPanelView()!.Members
                .First(m => m.Id == SquadRoster.FenwickId).ImmunityMinutesRemaining == 50);

        // RAW self-treatment: "targeting yourself, if you so choose".
        gs1.Clock.SpendTime(50); // clear the Scholar's immunity
        int schHp2 = scholar.Health.CurrentHP;
        DiceRoller.EnqueueD20(15 - schBonus);
        DiceRoller.EnqueueDie(1, 1);
        Check("(4) self-treatment is legal (Scholar treats the Scholar)",
            gs1.TreatWounds(SquadRoster.FenwickId, SquadRoster.FenwickId, 15));
        Check("(4) self-treatment healed 2 HP", scholar.Health.CurrentHP == schHp2 + 2);

        // ── (5) Save/load: immunity expiry round-trips (additive field) ──
        GD.Print("-------------------- (5) Save / load round-trip --------------------");
        var liveView = gs1.GetSquadPanelView()!;
        gs1.SaveGame();

        var gs2 = new GameState();
        AddChild(gs2); // _Ready: builds fresh presets, LoadGame restores squad + immunities
        gs2.Clock.SetPaused("spike", true);

        var loadedView = gs2.GetSquadPanelView();
        Check("(5) reloaded GameState built a panel view", loadedView != null);
        if (loadedView != null)
        {
            bool allMatch = true;
            foreach (var m in liveView.Members)
            {
                var loaded = loadedView.Members.First(x => x.Id == m.Id);
                if (loaded.ImmunityMinutesRemaining != m.ImmunityMinutesRemaining
                    || loaded.CurrentHp != m.CurrentHp)
                    allMatch = false;
            }
            Check("(5) immunity expiry + HP round-trip for all four members", allMatch);
            Check("(5) reloaded Scholar is still immune (fresh window survived the reload)",
                loadedView.Members.First(m => m.Id == SquadRoster.FenwickId)
                    .ImmunityMinutesRemaining == 50);
        }
    }

    // ─────────────────────────── Save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;

        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();

        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[TreatWoundsSpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[TreatWoundsSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[TreatWoundsSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
