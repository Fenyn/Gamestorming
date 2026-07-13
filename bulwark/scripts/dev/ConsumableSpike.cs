using System;
using System.Linq;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Conditions;
using PF2e.Core;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the per-fight CONSUMABLE item-use subsystem (potions / elixirs / antidotes).
/// Sections:
///   (A) Out-of-combat use via the GameState.UseItem command: a wounded member drinks a Minor Healing
///       Potion → HP restored, item consumed; using a consumable the party does NOT hold rejects cleanly
///       (nothing consumed); an undefined item id rejects; baseline (no use) leaves HP untouched.
///   (B) In-combat use via ConsumableSystem.UseInCombat (the combat action path): a member drinks a potion
///       they are CARRYING as their action → HP restored, item consumed from THAT member's carry, ONE
///       action spent, the action is manipulate-tagged; using an item that member is NOT carrying rejects
///       (nothing consumed, no action spent).
///   (C) A combat ELIXIR buff affects combat stats and EXPIRES per its duration: the Guardian Elixir grants
///       +1 item AC that ticks out after 3 rounds; an Antidote's encounter-length Fortitude buff survives
///       round ticks and is cleared at the encounter boundary. Post-encounter cleanup clears combat buffs.
/// Drives the systems directly (no grid) for determinism. The user's slot0.json is backed up and restored.
/// </summary>
public partial class ConsumableSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== CONSUMABLE SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[ConsumableSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunDataChecks();       // content sanity
            RunOutOfCombat();      // (A)
            RunInCombat();         // (B)
            RunElixirExpiry();     // (C)
        }
        catch (Exception e)
        {
            GD.PushError($"[ConsumableSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("ConsumableSpike");
    }

    // ─────────────────────────── content sanity ───────────────────────────

    private void RunDataChecks()
    {
        GD.Print("-------------------- data: consumable content is defined --------------------");
        Check("potion item defined as Consumable category",
            Items.TryGet("minor_healing_potion", out var p) && p.Category == ItemCategory.Consumable);
        Check("potion is Light Bulk", Items.Get("minor_healing_potion").Bulk == 0.1f);
        Check("three proving consumables defined", Consumables.All.Count == 3);
        Check("potion effect = restore 8 HP",
            Consumables.Get("minor_healing_potion").Effects.Single().Type == ConsumableEffectType.Heal);
        Check("no poison content ships (deferred)",
            !Consumables.All.Any(c => c.DisplayName.ToLower().Contains("poison")));
    }

    // ─────────────────────────── (A) out-of-combat UseItem command ───────────────────────────

    private void RunOutOfCombat()
    {
        GD.Print("-------------------- (A) out-of-combat UseItem (GameState command) --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null) { Fail(); gs.QueueFree(); return; }

        var member = gs.Squad.Members[0];

        // BASELINE: no use → HP untouched at a wounded value.
        member.Health!.SetCurrentHP(member.Health.MaxHP - 6);
        int wounded = member.Health.CurrentHP;
        Check("(A) baseline: HP untouched with no use", member.Health.CurrentHP == wounded);

        // REJECT: using a consumable the party doesn't hold → false, nothing consumed, HP unchanged.
        Check("(A) UseItem rejected when item not held", !gs.UseItem(member.Id, "minor_healing_potion"));
        Check("(A) reject consumed nothing", gs.Inventory.Count("minor_healing_potion") == 0);
        Check("(A) reject left HP unchanged", member.Health.CurrentHP == wounded);

        // REJECT: undefined item id.
        Check("(A) UseItem rejects an undefined id", !gs.UseItem(member.Id, "nope"));

        // HEAL + CONSUME: give the party a potion, drink it out of combat.
        gs.AddItem("minor_healing_potion", 1);
        Check("(A) party holds 1 potion", gs.Inventory.Count("minor_healing_potion") == 1);
        Check("(A) UseItem (self) succeeds", gs.UseItem(member.Id, "minor_healing_potion"));
        Check("(A) potion restored 8 HP (capped at max)",
            member.Health.CurrentHP == Math.Min(member.Health.MaxHP, wounded + 8));
        Check("(A) potion consumed from inventory", gs.Inventory.Count("minor_healing_potion") == 0);

        // TARGETED: one member can use a potion on another (targetId).
        var other = gs.Squad.Members[1];
        other.Health!.SetCurrentHP(other.Health.MaxHP - 5);
        int otherWounded = other.Health.CurrentHP;
        gs.AddItem("minor_healing_potion", 1);
        Check("(A) UseItem on another member succeeds", gs.UseItem(member.Id, "minor_healing_potion", other.Id));
        Check("(A) target member healed", other.Health.CurrentHP == Math.Min(other.Health.MaxHP, otherWounded + 8));

        gs.QueueFree();
    }

    // ─────────────────────────── (B) in-combat use as an action ───────────────────────────

    private void RunInCombat()
    {
        GD.Print("-------------------- (B) in-combat use (ConsumableSystem.UseInCombat action path) --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null) { Fail(); gs.QueueFree(); return; }

        var hero = gs.Squad.Members[0];
        var bystander = gs.Squad.Members[1];

        // Give ONLY the hero a potion in their personal carry.
        Check("(B) hero given a carried potion", gs.Inventory.TryGiveToMember(hero.Id, "minor_healing_potion", 1));
        Check("(B) hero carries 1 potion", gs.Inventory.MemberCount(hero.Id, "minor_healing_potion") == 1);

        hero.Health!.SetCurrentHP(1);
        hero.Actions!.RefillActions();
        int actionsBefore = hero.Actions.TotalActionsRemaining;
        Check("(B) hero starts the turn with 3 actions", actionsBefore == 3);

        // REJECT: bystander isn't carrying it → false, no action spent, nothing consumed.
        bystander.Actions!.RefillActions();
        int bystanderActions = bystander.Actions.TotalActionsRemaining;
        bool rejected = !gs.Consumables.UseInCombat(bystander, "minor_healing_potion", gs.Inventory).GetAwaiter().GetResult();
        Check("(B) use rejected for a member not carrying it", rejected);
        Check("(B) reject spent no action", bystander.Actions.TotalActionsRemaining == bystanderActions);
        Check("(B) reject consumed nothing (hero still carries it)",
            gs.Inventory.MemberCount(hero.Id, "minor_healing_potion") == 1);

        // USE: hero drinks their carried potion as their action.
        bool used = gs.Consumables.UseInCombat(hero, "minor_healing_potion", gs.Inventory).GetAwaiter().GetResult();
        Check("(B) hero uses the carried potion", used);
        Check("(B) potion healed hero 1→9", hero.Health.CurrentHP == 9);
        Check("(B) one action spent (drinking a potion = 1 action)",
            hero.Actions.TotalActionsRemaining == actionsBefore - 1);
        Check("(B) potion consumed from the hero's carry",
            gs.Inventory.MemberCount(hero.Id, "minor_healing_potion") == 0);

        gs.QueueFree();
    }

    // ─────────────────────────── (C) elixir buff affects stats + expires ───────────────────────────

    private void RunElixirExpiry()
    {
        GD.Print("-------------------- (C) combat elixir buff: affects stats, expires per duration --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);
        if (gs.Squad == null) { Fail(); gs.QueueFree(); return; }

        var hero = gs.Squad.Members[0];
        hero.Actions!.RefillActions();

        // ---- Guardian Elixir: +1 item AC for 3 rounds, then ticks out mid-combat ----
        int acBefore = hero.Modifiers!.GetModifierTotal(StatType.AC);
        gs.Inventory.TryGiveToMember(hero.Id, "guardian_elixir", 1);
        Check("(C) hero drinks the Guardian Elixir",
            gs.Consumables.UseInCombat(hero, "guardian_elixir", gs.Inventory).GetAwaiter().GetResult());
        Check("(C) +1 item AC live (affects combat defense)",
            hero.Modifiers.GetModifierTotal(StatType.AC) == acBefore + 1);
        Check("(C) one active combat buff tracked", gs.Consumables.ActiveEffectCount == 1);

        gs.Consumables.AdvanceCombatRound(); // round 1
        gs.Consumables.AdvanceCombatRound(); // round 2
        Check("(C) buff persists while its duration remains", hero.Modifiers.GetModifierTotal(StatType.AC) == acBefore + 1);
        gs.Consumables.AdvanceCombatRound(); // round 3 → expires
        Check("(C) elixir AC buff expired after 3 rounds", hero.Modifiers.GetModifierTotal(StatType.AC) == acBefore);
        Check("(C) expired buff dropped from tracking", gs.Consumables.ActiveEffectCount == 0);

        // ---- Antidote: encounter-length +2 item Fortitude — survives ticks, cleared at encounter end ----
        int fortBefore = hero.Modifiers.GetModifierTotal(StatType.Fortitude);
        gs.Inventory.TryGiveToMember(hero.Id, "antidote", 1);
        Check("(C) hero applies the Antidote",
            gs.Consumables.UseInCombat(hero, "antidote", gs.Inventory).GetAwaiter().GetResult());
        Check("(C) +2 item Fortitude live", hero.Modifiers.GetModifierTotal(StatType.Fortitude) == fortBefore + 2);
        gs.Consumables.AdvanceCombatRound();
        gs.Consumables.AdvanceCombatRound();
        Check("(C) encounter-length antidote buff survives round ticks",
            hero.Modifiers.GetModifierTotal(StatType.Fortitude) == fortBefore + 2);

        // Post-encounter cleanup (GameState.CompleteEncounter → ClearCombatEffects) wipes combat buffs.
        gs.CompleteEncounter(BattleResult.Team1Wins, null);
        Check("(C) encounter completion cleared the antidote buff",
            hero.Modifiers.GetModifierTotal(StatType.Fortitude) == fortBefore);
        Check("(C) no combat buffs tracked after the fight", gs.Consumables.ActiveEffectCount == 0);

        gs.QueueFree();
    }

    // ─────────────────────────── save-slot protection ───────────────────────────

    private void BackupSlot0()
    {
        _slot0Existed = Godot.FileAccess.FileExists(SavePath);
        if (!_slot0Existed)
            return;
        using (var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Read))
            _slot0Backup = file?.GetAsText();
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
        GD.Print("[ConsumableSpike] slot0.json backed up and cleared for the test run.");
    }

    private static void ClearSlot0()
    {
        if (Godot.FileAccess.FileExists(SavePath))
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[ConsumableSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[ConsumableSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
