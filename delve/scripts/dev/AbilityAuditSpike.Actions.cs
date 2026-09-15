using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Presets;
using Delve.UI;
using PF2e.Actions;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Utilities;
using V = PF2e.Vector2Int;

namespace Delve.Dev;

public partial class AbilityAuditSpike
{
    private async Task CheckCombatAdapters()
    {
        var elara = PresetCharacters.BuildElara(2);
        var foe = PresetCharacters.BuildRecruit(2, teamId: 2);
        foe.Health.OverrideMaxHP(1000); foe.Health.SetCurrentHP(1000);
        var session = Session(elara, foe);
        try
        {
            var exec = session.PlayerActions;
            var before = exec.GetSkillEntries(elara).Single(e => e.ActionId == "double-slice");
            Check("Double Slice is a promoted, usable two-action ability", before.Castable
                && before.IsCharacterAbility && before.SignaturePriority > 0 && before.ActionCost == 2);
            foe.GridPosition = new V(9, 3); session.ReconcileOccupancy();
            Check("Double Slice rejects a foe outside both weapons' reach",
                !exec.GetSkillTargets(elara, "double-slice").Tiles.Contains(foe.GridPosition)
                && !await exec.ExecuteSkillAction(elara, "double-slice", foe.GridPosition) && elara.Actions.TotalActionsRemaining == 3);
            foe.GridPosition = new V(4, 3); session.ReconcileOccupancy();
            var rolls = new List<CombatRoll>();
            void Log(CombatLogEntry entry)
            { if (CombatRoll.Parse(entry.Message) is { } roll) rolls.Add(roll); }
            CombatLog.OnLogEntry += Log;
            try
            {
                DiceRoller.EnqueueD20(20); DiceRoller.EnqueueD20(20);
                Check("Double Slice executes through the player adapter", await exec.ExecuteSkillAction(elara, "double-slice", foe.GridPosition));
            }
            finally { CombatLog.OnLogEntry -= Log; }
            Check("Double Slice spends two actions and advances MAP twice", elara.Actions.TotalActionsRemaining == 1
                && elara.Combat.AttacksMadeThisTurn == 2);
            Check("both Double Slice strikes resolve and damage the target", DoubleSliceAction.GetLastDoubleSlice(elara.UniqueId) is { BothHit: true }
                && foe.Health.CurrentHP < 1000 && rolls.Count == 2);
            Check("both strikes use their original attack bonus", rolls.Count == 2
                && rolls[0].Total - rolls[0].Die == WeaponAttackCalculator.CalculateAttackBonus(elara, elara.Equipment.MainHandWeapon)
                && rolls[1].Total - rolls[1].Die == WeaponAttackCalculator.CalculateAttackBonus(elara, elara.Equipment.OffHandWeapon));
            var after = exec.GetSkillEntries(elara).Single(e => e.ActionId == "double-slice");
            Check("spent actions disable the shortcut without removing its priority", !after.Castable
                && after.SignaturePriority == before.SignaturePriority && after.UnavailableReason.Length > 0);
        }
        finally { session.Teardown(); }

        var medic = PresetCharacters.BuildFenwick(4);
        var patient = PresetCharacters.BuildPlayer(4);
        session = Session(medic, PresetCharacters.BuildRecruit(2, teamId: 2), patient);
        try
        {
            var exec = session.PlayerActions;
            Check("Battle Medicine appears once and is promoted when earned", exec.GetSkillEntries(medic).Count(e => e.ActionId == "battle-medicine") == 1
                && exec.GetSkillEntries(medic).Single(e => e.ActionId == "battle-medicine").SignaturePriority > 0);
            Check("Treat Condition excludes healthy allies", !exec.GetSkillTargets(medic, "treat-condition").Tiles.Contains(patient.GridPosition));
            patient.Conditions.AddCondition(ConditionDatabase.Instance.GetCondition(Condition.Sickened), value: 2);
            Check("Treat Condition offers an adjacent affected ally", exec.GetSkillTargets(medic, "treat-condition").Tiles.Contains(patient.GridPosition));
            DiceRoller.EnqueueD20(20);
            Check("Treat Condition executes and removes the condition", await exec.ExecuteSkillAction(medic, "treat-condition", patient.GridPosition)
                && !patient.Conditions.HasCondition(Condition.Sickened) && medic.Actions.TotalActionsRemaining == 1);
            Check("unearned Double Slice cannot execute", !await exec.ExecuteSkillAction(medic, "double-slice", new V(4, 3)));
        }
        finally { session.Teardown(); }

        var tharr = PresetCharacters.BuildTharr(4);
        session = Session(tharr, PresetCharacters.BuildRecruit(2, teamId: 2));
        try
        {
            Check("Marshal Stance is promoted when earned", session.PlayerActions.GetSkillEntries(tharr)
                .Single(e => e.ActionId == "inspiring-marshal-stance").SignaturePriority > 0);
            DiceRoller.EnqueueD20(20);
            Check("Marshal Stance enters through the player adapter", await session.PlayerActions.ExecuteSelfSkill(tharr, "inspiring-marshal-stance")
                && StanceRules.IsInStance(tharr, "inspiring-marshal-stance") && tharr.Actions.TotalActionsRemaining == 2);
            Check("Marshal Stance reports active state", session.PlayerActions.GetSkillEntries(tharr)
                .Single(e => e.ActionId == "inspiring-marshal-stance").BadgeText == "Active");
        }
        finally { session.Teardown(); }
    }

    private static CombatSession Session(PF2eCharacter hero, PF2eCharacter foe, PF2eCharacter? ally = null)
    {
        var setup = new CombatSetup { GridWidth = 12, GridHeight = 10, RngSeed = 11 };
        setup.Party.Add((hero, new V(3, 3))); setup.Enemies.Add((foe, new V(4, 3)));
        if (ally != null) setup.Party.Add((ally, new V(3, 4)));
        var session = new CombatSession(); session.Setup(setup);
        CombatantRegistry.Instance.Register(hero); CombatantRegistry.Instance.Register(foe);
        if (ally != null) CombatantRegistry.Instance.Register(ally);
        hero.Actions.RefillActions();
        session.SetPresenter(_ => Task.CompletedTask);
        return session;
    }
}
