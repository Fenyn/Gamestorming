using System;
using System.Collections.Generic;
using System.Text.Json;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Presets;
using Godot;
using PF2e.Core;
using PF2e.Data;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for banked level-up application on sleep (WP: level-up milestone). Drives
/// REAL GameState nodes on a clean save slot (the user's slot0.json is backed up and restored):
///  (1) bank 1300 XP on the veteran → sleep → exactly one level applied (2→3), 1000 XP consumed,
///      max HP grew by class HP + Con (10+2), full HP after the rest, event reported 2→3;
///  (2) save mid-progression → reload into a fresh GameState → the veteran REBUILDS at level 3,
///      live state (HP dent) and banked XP intact, exact snapshot round-trip;
///  (3) bank 3000 XP on everyone → sleep → all reach the L5 cap; the Scholar's L5 blend trade is
///      live (rank-3 max = 4) with the school slot enforced, the Medic's font grew to 5 slots at
///      rank 3, and the veteran's XP above the cap stays banked;
///  (4) EQUIVALENCE: each member leveled in place matches a fresh PresetCharacters L5 build on
///      level, ability scores, max HP, skill proficiencies, granted feature set, per-rank max
///      slots, focus, font, and prepared loadout — the core invariant of the level-up seam;
///  (5) a further sleep at the cap changes nothing and emits no level-up event.
/// Prints [PASS]/[FAIL] per check and a final SPIKE RESULT line.
/// </summary>
public partial class SleepLevelUpSpike : Node
{
    private const string SavePath = "user://save/slot0.json";

    private int _failures;
    private int _checks;
    private bool _slot0Existed;
    private string? _slot0Backup;

    public override void _Ready()
    {
        GD.Print("==================== SLEEP LEVEL-UP SPIKE ====================");

        var data = GetNode<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            GD.PushError("[SleepLevelUpSpike] DataManager not loaded — aborting.");
            GD.Print("SPIKE RESULT: FAIL");
            GetTree().Quit(1);
            return;
        }

        BackupSlot0();
        try
        {
            RunScenario();
        }
        catch (Exception e)
        {
            GD.PushError($"[SleepLevelUpSpike] Unhandled exception: {e}");
            _failures++;
        }
        finally
        {
            RestoreSlot0();
        }

        GD.Print("---------------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"[SleepLevelUpSpike] checks: {_checks}, failures: {_failures}");
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    private void RunScenario()
    {
        // Fresh GameState on the clean slot: pristine L2 squad.
        var gs1 = new GameState();
        AddChild(gs1);
        var squad = gs1.Squad;
        Check("(0) GameState built a squad of 4", squad != null && squad.Members.Count == 4);
        if (squad == null)
            return;

        var levelUpEvents = new List<SquadLevelUpView>();
        gs1.SquadLeveledUp += ups => levelUpEvents.AddRange(ups);

        // ── (1) Single level-up: 1300 XP → level 3, remainder 300 banked ──
        GD.Print("-------------------- (1) Single level-up on sleep --------------------");
        var vet = squad.FindMember(SquadRoster.VeteranId)!;
        int vetMaxBefore = vet.Health!.MaxHP;

        squad.AddXp(SquadRoster.VeteranId, 1300);
        Check("(1) 1300 XP banked pre-sleep", squad.GetXp(SquadRoster.VeteranId) == 1300);

        gs1.Sleep();

        Check("(1) veteran is level 3 after sleep", vet.Stats!.Level == 3);
        Check("(1) 1000 XP consumed, 300 remainder banked", squad.GetXp(SquadRoster.VeteranId) == 300);
        // Fighter 10 class HP + Con 14 (+2) = 12 per level; no ability boost between L2 and L3.
        Check($"(1) max HP grew by 12 (class 10 + Con 2): {vetMaxBefore} -> {vet.Health.MaxHP}",
            vet.Health.MaxHP == vetMaxBefore + 12);
        Check("(1) full HP after the rest (FullHeal to the NEW max)", vet.Health.IsFullHealth);
        Check("(1) other members untouched at level 2",
            squad.FindMember(SquadRoster.ScoutId)!.Stats!.Level == 2
            && squad.FindMember(SquadRoster.MedicId)!.Stats!.Level == 2
            && squad.FindMember(SquadRoster.ScholarId)!.Stats!.Level == 2);
        Check("(1) SquadLeveledUp event reported veteran 2 -> 3",
            levelUpEvents.Count == 1
            && levelUpEvents[0].MemberId == SquadRoster.VeteranId
            && levelUpEvents[0].FromLevel == 2 && levelUpEvents[0].ToLevel == 3);

        // ── (2) Save mid-progression → reload → level 3 rebuilt + live state + XP intact ──
        GD.Print("-------------------- (2) Save / load mid-progression --------------------");
        vet.Health.SetCurrentHP(vet.Health.MaxHP - 7); // live-state dent to survive the reload
        gs1.SaveGame();

        var gs2 = new GameState();
        AddChild(gs2); // _Ready: builds fresh presets, then LoadGame rebuilds at saved levels
        var squad2 = gs2.Squad!;
        Check("(2) reloaded GameState built a squad", squad2 != null && squad2.Members.Count == 4);

        string snapLive = JsonSerializer.Serialize(squad.CaptureMembers());
        string snapLoaded = JsonSerializer.Serialize(squad2!.CaptureMembers());
        Check("(2) EXACT squad round-trip (serialized snapshots identical)", snapLive == snapLoaded);

        var vet2 = squad2.FindMember(SquadRoster.VeteranId)!;
        Check("(2) veteran REBUILT at level 3", vet2.Stats!.Level == 3);
        Check("(2) live HP dent restored on top of the level-3 rebuild",
            vet2.Health!.CurrentHP == vet2.Health.MaxHP - 7);
        Check("(2) banked 300 XP intact", squad2.GetXp(SquadRoster.VeteranId) == 300);
        Check("(2) scholar still rebuilt at level 2",
            squad2.FindMember(SquadRoster.ScholarId)!.Stats!.Level == 2);

        // ── (3) Multi-level to the cap (on the RELOADED state — proves post-load leveling) ──
        GD.Print("-------------------- (3) Multi-level to the L5 cap --------------------");
        var levelUpEvents2 = new List<SquadLevelUpView>();
        gs2.SquadLeveledUp += ups => levelUpEvents2.AddRange(ups);

        foreach (var id in new[]
        {
            SquadRoster.VeteranId, SquadRoster.ScoutId, SquadRoster.MedicId, SquadRoster.ScholarId,
        })
            squad2.AddXp(id, 3000);

        gs2.Sleep();

        var scout2 = squad2.FindMember(SquadRoster.ScoutId)!;
        var medic2 = squad2.FindMember(SquadRoster.MedicId)!;
        var scholar2 = squad2.FindMember(SquadRoster.ScholarId)!;
        Check("(3) all four members at the level-5 cap",
            vet2.Stats.Level == 5 && scout2.Stats!.Level == 5
            && medic2.Stats!.Level == 5 && scholar2.Stats!.Level == 5);
        // Veteran had 300 + 3000 = 3300 and only two levels (4, 5) to the cap: 1300 stays banked.
        Check("(3) XP above the cap stays banked (veteran 3300 - 2000 = 1300)",
            squad2.GetXp(SquadRoster.VeteranId) == 1300);
        Check("(3) exactly consumed for the others (3000 = three levels)",
            squad2.GetXp(SquadRoster.ScoutId) == 0 && squad2.GetXp(SquadRoster.ScholarId) == 0);
        Check("(3) event reported veteran 3 -> 5 and scholar 2 -> 5",
            levelUpEvents2.Count == 4
            && levelUpEvents2.Exists(v => v.MemberId == SquadRoster.VeteranId && v.FromLevel == 3 && v.ToLevel == 5)
            && levelUpEvents2.Exists(v => v.MemberId == SquadRoster.ScholarId && v.FromLevel == 2 && v.ToLevel == 5));

        // Scholar: L5 Spell Blending trade live on top of the school slots, Fireballs prepared.
        var casting = scholar2.Spellcasting!;
        Check("(3) scholar blend trade active", casting.ActiveBlendTrades.Count == 1);
        Check($"(3) scholar rank-3 max == 4 (2 base + 1 blended + 1 school), got {casting.GetMaxSlots(3)}",
            casting.GetMaxSlots(3) == 4);
        Check("(3) scholar rank-1 max == 2 (3 base - 2 blended + 1 school)", casting.GetMaxSlots(1) == 2);
        Check("(3) school bonus slot flagged at rank 3", casting.GetSchoolBonusSlots(3) == 1);
        Check("(3) 4 Fireballs prepared at rank 3 (curriculum fills the school slot)",
            CountPrepared(scholar2, PresetSpells.FireballId) == 4);
        // School slot enforced at the new layout: rank 1 has 1 unrestricted + 1 school slot, so
        // two NON-curriculum preparations must be rejected (validation fails before mutating).
        var fear = PresetSpells.Get(PresetSpells.FearId)!;
        Check("(3) school slot REJECTS a second non-curriculum rank-1 preparation",
            !casting.PrepareSpells(new List<PF2e.Actions.SpellAction> { fear, fear }));

        // Medic: divine font grew per the level table (4 at L1-4 → 5 at L5) at the new rank 3.
        var font = medic2.Spellcasting!.DivineFont!;
        Check($"(3) medic font = 5/5 at rank 3, got {font.CurrentSlots}/{font.MaxSlots} r{font.FontRank}",
            font.MaxSlots == 5 && font.CurrentSlots == 5 && font.FontRank == 3);

        Check("(3) everyone at full HP after the rest",
            vet2.Health.IsFullHealth && scout2.Health!.IsFullHealth
            && medic2.Health!.IsFullHealth && scholar2.Health!.IsFullHealth);

        // ── (4) Equivalence: leveled-in-place == fresh L5 build ──
        GD.Print("-------------------- (4) Equivalence vs fresh L5 builds --------------------");
        CheckEquivalence("veteran", vet2, PresetCharacters.BuildVeteran(5));
        CheckEquivalence("scout", scout2, PresetCharacters.BuildScout(5));
        CheckEquivalence("medic", medic2, PresetCharacters.BuildMedic(5));
        CheckEquivalence("scholar", scholar2, PresetCharacters.BuildScholar(5));

        // ── (5) Sleeping again at the cap changes nothing ──
        GD.Print("-------------------- (5) Sleep at the cap --------------------");
        int eventsBefore = levelUpEvents2.Count;
        gs2.Sleep();
        Check("(5) veteran still level 5 with 1300 XP banked",
            vet2.Stats.Level == 5 && squad2.GetXp(SquadRoster.VeteranId) == 1300);
        Check("(5) no level-up event emitted at the cap", levelUpEvents2.Count == eventsBefore);
    }

    // ─────────────────────────── Equivalence ───────────────────────────

    /// <summary>
    /// The core invariant: a member leveled 2→5 in place must be mechanically identical to one
    /// built fresh at 5 — level, ability scores, max HP, every skill proficiency, the granted
    /// feature set, per-rank max spell slots, focus pool, divine font, and prepared loadout.
    /// </summary>
    private void CheckEquivalence(string label, PF2eCharacter leveled, PF2eCharacter fresh)
    {
        Check($"(4) {label}: level equal ({fresh.Stats!.Level})",
            leveled.Stats!.Level == fresh.Stats.Level);

        bool scoresEqual = true;
        foreach (AbilityScore ability in Enum.GetValues(typeof(AbilityScore)))
            scoresEqual &= leveled.Stats.GetAbilityScore(ability) == fresh.Stats.GetAbilityScore(ability);
        Check($"(4) {label}: ability scores equal (L5 boosts auto-assigned identically)", scoresEqual);

        Check($"(4) {label}: max HP equal ({fresh.Health!.MaxHP})",
            leveled.Health!.MaxHP == fresh.Health.MaxHP);

        bool skillsEqual = true;
        int trainedPlus = 0;
        foreach (Skill skill in Enum.GetValues(typeof(Skill)))
        {
            var a = leveled.Skills!.GetProficiency(skill);
            var b = fresh.Skills!.GetProficiency(skill);
            skillsEqual &= a == b;
            if (a > ProficiencyLevel.Untrained) trainedPlus++;
        }
        Check($"(4) {label}: every skill proficiency equal ({trainedPlus} trained+)", skillsEqual);

        string featuresLeveled = FeatureSet(leveled);
        string featuresFresh = FeatureSet(fresh);
        Check($"(4) {label}: granted feature set equal ({fresh.Features!.ActiveFeatures.Count} features)",
            featuresLeveled == featuresFresh);
        if (featuresLeveled != featuresFresh)
            GD.Print($"  [info] leveled: {featuresLeveled}\n  [info] fresh:   {featuresFresh}");

        var castingA = leveled.Spellcasting;
        var castingB = fresh.Spellcasting;
        Check($"(4) {label}: spellcasting presence equal", (castingA == null) == (castingB == null));
        if (castingA == null || castingB == null)
            return;

        bool slotsEqual = true;
        for (int rank = 1; rank <= 10; rank++)
            slotsEqual &= castingA.GetMaxSlots(rank) == castingB.GetMaxSlots(rank);
        Check($"(4) {label}: per-rank max slots equal", slotsEqual);

        Check($"(4) {label}: focus pool equal ({castingB.MaxFocusPoints})",
            castingA.MaxFocusPoints == castingB.MaxFocusPoints);

        var fontA = castingA.DivineFont;
        var fontB = castingB.DivineFont;
        Check($"(4) {label}: divine font equal",
            (fontA == null) == (fontB == null)
            && (fontA == null || (fontA.MaxSlots == fontB!.MaxSlots && fontA.FontRank == fontB.FontRank)));

        Check($"(4) {label}: prepared loadout equal", LoadoutSet(castingA) == LoadoutSet(castingB));
    }

    /// <summary>Sorted granted-feature id list (order-independent set comparison).</summary>
    private static string FeatureSet(PF2eCharacter character)
    {
        var ids = new List<string>();
        foreach (var f in character.Features!.ActiveFeatures)
            ids.Add(f.FeatureId ?? f.DisplayName ?? "?");
        ids.Sort(StringComparer.Ordinal);
        return string.Join(",", ids);
    }

    /// <summary>Sorted rank:spell-id list of the non-focus prepared spells.</summary>
    private static string LoadoutSet(PF2e.CharacterComponents.Spellcasting casting)
    {
        var ids = new List<string>();
        foreach (var s in casting.LeveledSpells)
            if (s?.Spell != null && !s.Spell.IsFocusSpell)
                ids.Add($"{s.Spell.SpellLevel}:{s.SpellId ?? s.ActionName}");
        ids.Sort(StringComparer.Ordinal);
        return string.Join(",", ids);
    }

    private static int CountPrepared(ICharacter caster, string spellId)
    {
        int count = 0;
        foreach (var s in caster.Spellcasting!.LeveledSpells)
            if (s?.SpellId == spellId)
                count++;
        return count;
    }

    private void Check(string label, bool ok)
    {
        _checks++;
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
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
        GD.Print("[SleepLevelUpSpike] slot0.json backed up and cleared for the test run.");
    }

    private void RestoreSlot0()
    {
        if (_slot0Existed && _slot0Backup != null)
        {
            using var file = Godot.FileAccess.Open(SavePath, Godot.FileAccess.ModeFlags.Write);
            file?.StoreString(_slot0Backup);
            GD.Print("[SleepLevelUpSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[SleepLevelUpSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
