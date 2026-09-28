using System.Linq;
using Delve.Dungeon;
using Delve.Run;
using Delve.Run.Events;
using PF2e.Conditions;
using PF2e.Core;
using PF2e.Data;
using RunState = Delve.Run.RunState;

namespace Delve.Dev;

/// <summary>The station-room effects: each applies as its preview says and never spends ward it should not.</summary>
public partial class RunEventSpike
{
    private void CheckRoomEffects()
    {
        var quiet = new[] { RoomPurpose.Checkpoint, RoomPurpose.Barracks, RoomPurpose.MessHall, RoomPurpose.Kitchen,
            RoomPurpose.Cistern, RoomPurpose.Stores, RoomPurpose.Workshop, RoomPurpose.Maintenance, RoomPurpose.Shrine };
        bool scenes = true;
        foreach (var purpose in quiet)
            foreach (var history in System.Enum.GetValues<StationHistory>())
            {
                var options = StationScenes.For(purpose, history);
                var leave = options[^1].Success.Effects.Single();
                scenes &= options.Count >= 2 && leave.Kind == EventEffectKind.WardDelta && leave.Value == StationScenes.LeaveWard
                    && options.Take(options.Count - 1).All(o => o.Check == null || o.CriticalSuccess != null);
            }
        Check("every quiet room offers its own scene plus Leave (Ward +5), in all three histories", scenes);
        Check("history changes rules: flooded cistern dives, ward-failure workshop gains a conduit, evacuated shrine is haunted",
            StationScenes.For(RoomPurpose.Cistern, StationHistory.Flooded)[0].Check?.Skill == Skill.Athletics
            && StationScenes.For(RoomPurpose.Workshop, StationHistory.WardFailure).Count == 3
            && StationScenes.For(RoomPurpose.Shrine, StationHistory.Evacuated)[0].Check?.Dc == StationScenes.HazardDc);

        var run = NewRun();
        var ward = run.Wardstone;
        while (ward.Ward > 40) ward.BurnShortRest();
        int start = ward.Ward;
        Apply(run, EventEffectKind.WardDelta, 15);
        Check($"a ward gain raises the stone ({start} → {ward.Ward})", ward.Ward == start + 15);
        while (ward.Ward > ward.Rules.ShortRestBurn) ward.BurnShortRest();
        Apply(run, EventEffectKind.WardDelta, -30);
        Check($"a ward loss from a room never puts the stone out (ward {ward.Ward})", ward.Ward >= 1);

        var hurt = run.Party.Members[1];
        hurt.Health.SetCurrentHP(1);
        Apply(run, EventEffectKind.HealingPotion, 1);
        Check("a found potion is banked, not drunk on the spot", run.Potions == 1 && hurt.Health.CurrentHP == 1);
        var potion = HealingPotions.ForLevel(run.Party.Level);
        HealingPotions.Drink(run);
        Check($"a banked potion of the party's level ({potion.Name}) goes to the most wounded ({hurt.Name} HP {hurt.Health.CurrentHP})",
            hurt.Health.CurrentHP >= 1 + potion.Dice + potion.Bonus && run.Potions == 0);

        var caster = run.Party.Living().First(m => m.Spellcasting is { MaxFocusPoints: > 0 });
        caster.Spellcasting!.ConsumeFocusPoint();
        int focus = caster.Spellcasting.CurrentFocusPoints;
        Apply(run, EventEffectKind.PartyRefocus, 1);
        Check("a shrine prayer refocuses every caster", caster.Spellcasting.CurrentFocusPoints == focus + 1);

        var owner = run.Party.Living().First(m => m.Equipment?.Shield?.EquippedShield != null);
        owner.Equipment!.Shield.SetCurrentShieldHP(1);
        var smith = run.Party.Members[0];
        int rank = (int)PF2e.Utilities.SkillCalculator.GetProficiency(smith, Skill.Crafting) / 2;
        Apply(run, EventEffectKind.RepairShields, 1, smith);
        Check($"a bench repair follows Player Core Repair (5 + 5 per rank: shield 1 → {owner.Equipment.Shield.CurrentShieldHP})",
            owner.Equipment.Shield.CurrentShieldHP == System.Math.Min(owner.Equipment.Shield.MaxShieldHP, 1 + 5 + 5 * rank));

        int shieldHp = owner.Equipment.Shield.CurrentShieldHP;
        Apply(run, EventEffectKind.RepairShields, -1, smith);
        int gouge = shieldHp - owner.Equipment.Shield.CurrentShieldHP;
        int hardness = owner.Equipment.Shield.EquippedShield!.Hardness;
        Check($"a critically failed Repair deals 2d6 less Hardness {hardness} to the shield ({gouge})",
            gouge >= 0 && gouge <= 12 - hardness || owner.Equipment.Shield.CurrentShieldHP == 0);

        int gold = run.Gold;
        Apply(run, EventEffectKind.CacheGold, 0);
        Check($"cache gold follows the treasure-by-level curve ({run.Gold - gold} at level {run.Party.Level})",
            run.Gold - gold == TreasureByLevel.Scale(EventRewards.CacheGoldAtLevelOne, run.Party.Level)
            && TreasureByLevel.Scale(25, 10) == 1250);
        Check("item Repair keeps the shield's own DC at any party level",
            DungeonEncounters.AtLevel(new EventDefinition { Id = "w", Title = "w", Body = "",
                Options = StationScenes.For(RoomPurpose.Workshop, StationHistory.Flooded) }, 10).Options[0].Check!.Dc == StationScenes.ShieldRepairDc);

        var victim = run.Party.Members[2];
        victim.Health.SetCurrentHP(2);
        Apply(run, EventEffectKind.HazardDamage, 50, victim);
        Check("hazard damage never drops a member below 1 HP", victim.Health.CurrentHP == 1);

        int wardBeforeRest = ward.Ward;
        int blocks = run.Clock.ShortRestsToday;
        int banked = run.FreeRests;
        Apply(run, EventEffectKind.FreeRest, 0);
        Check("a room's free rest is banked, not spent on the spot", run.FreeRests == banked + 1
            && ward.Ward == wardBeforeRest && run.Clock.ShortRestsToday == blocks);

        var rested = NewRun();
        rested.FreeRests = 1;
        int full = rested.Wardstone.Ward;
        var plan = ShortRest.Suggest(rested.Party);
        var onFree = ShortRest.PerformSchedule(rested, plan, new RecoveryRules(), useFree: true);
        Check("a rest paid with a banked free rest spends the rest, not ward",
            onFree.Performed && rested.FreeRests == 0 && rested.Wardstone.Ward == full);
        var onWard = ShortRest.PerformSchedule(rested, plan, new RecoveryRules(), useFree: true);
        Check("with nothing banked the same rest pays ward",
            onWard.Performed && rested.Wardstone.Ward == full - rested.Wardstone.Rules.ShortRestBurn);
        rested.Potions = 1;
        rested.Party.Members[1].Health.SetCurrentHP(1);
        string? drank = HealingPotions.Drink(rested);
        Check($"a banked potion goes to the most wounded ('{drank}')", drank != null && rested.Potions == 0
            && rested.Party.Members[1].Health.CurrentHP > 1);
        var healthy = NewRun();
        healthy.Potions = 1;
        Check("no one drinks when nobody is hurt", HealingPotions.Drink(healthy) == null && healthy.Potions == 1);
    }

    private static void Apply(RunState run, EventEffectKind kind, int value, PF2eCharacter? actor = null)
    {
        var definition = new EventDefinition
        {
            Id = "spike-effect",
            Title = "Spike",
            Body = "",
            Options = new[] { new EventOption { Label = "Apply", Success = new EventOutcome("", new[] { new EventEffect(kind, value) }) } },
        };
        EventResolver.Resolve(run, definition, 0, actor ?? run.Party.Members[0]);
    }
}
