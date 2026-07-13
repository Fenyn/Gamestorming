using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Godot;
using PF2e.Actions;
using PF2e.Data;
using BuildingEffectType = Bulwark.Data.BuildingEffectType;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the Phase-4 BUILDING-EFFECT APPLICATION FRAMEWORK. Proves the aggregator +
/// hook pattern with SPIKE-LOCAL SYNTHETIC effects/buildings (constructed here, NEVER added to the
/// shipped <see cref="Buildings"/> registry) plus real shipped buildings for the end-to-end wiring —
/// so no specific upgrade content is baked in. Sections:
///  (A) OutpostEffects aggregation over a synthetic source: baseline defaults with an empty source;
///      commissioning/upgrading a synthetic building recomputes sums (FarmPlots/InfirmaryHealing),
///      flags (WateringAutomation/Greenhouse), the SmithyTier ceiling (max), and the CategoryUnlock
///      set — and EffectsChanged (Changed) fires on every recompute.
///  (B) Smithy tier GATE via SmithyAccess with synthetic catalog entries: base always unlocked, a
///      higher-tier entry unlocks only at/above its tier; fundamental runes unlocked at Base.
///  (C) Real GameState wiring + save/load: BASELINE (no buildings) → every query at its default and a
///      base weapon purchase works; commissioning a shipped Infirmary raises InfirmaryHealingBonus and
///      fires EffectsChanged; upgrading the shipped Smithy raises the SmithyTier ceiling; the derived
///      state round-trips a save/load (recomputed from restored building state).
///  (D) Infirmary healing bonus is ADDITIVE in the Treat Wounds path (bounded proof: baseline heals
///      below the bonus, a large bonus heals at/above it).
///  (E) Farm capability queries flip with the aggregator (auto-water / greenhouse / plot allowance),
///      and the applied rules change behaviour (off-season plant, overnight auto-grow).
///  (F) Spell-access grant seam: grants a spell to the Scholar's known list (no engine edit) and the
///      granted spell enters the prepared list via the engine (OnSpellsChanged fires); CategoryUnlock
///      membership query.
/// The user's slot0.json is backed up and restored around the run.
/// </summary>
public partial class EffectsSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    // ── Spike-local synthetic building: a mutable tier + cumulative per-tier effects (NOT shipped) ──
    private sealed class SyntheticBuilding
    {
        public required string Id;
        public required List<BuildingEffect>[] TierEffects; // index 0 = tier 1
        public int Tier; // 0 = not commissioned

        public IEnumerable<BuildingEffect> Active()
        {
            for (int t = 1; t <= Tier && t <= TierEffects.Length; t++)
                foreach (var e in TierEffects[t - 1])
                    yield return e;
        }
    }

    public override void _Ready()
    {
        GD.Print("==================== EFFECTS SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[EffectsSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunAggregator();        // (A)
            RunSmithyGate();        // (B)
            RunGameStateWiring();   // (C)
            RunInfirmaryHealing();  // (D)
            RunFarmCapabilities();  // (E)
            RunSpellAndCategory();  // (F)
        }
        catch (Exception e)
        {
            GD.PushError($"[EffectsSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("EffectsSpike");
    }

    // ─────────────────────────── (A) Aggregator over a synthetic source ───────────────────────────

    private void RunAggregator()
    {
        GD.Print("-------------------- (A) OutpostEffects aggregation (synthetic source) --------------------");

        var farm = new SyntheticBuilding
        {
            Id = "syn_farm",
            TierEffects = new[]
            {
                new List<BuildingEffect>
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 2 },
                    new() { Type = BuildingEffectType.WateringAutomation },
                },
                new List<BuildingEffect>
                {
                    new() { Type = BuildingEffectType.FarmPlots, Magnitude = 3 },
                    new() { Type = BuildingEffectType.Greenhouse },
                },
            },
        };
        var smithy = new SyntheticBuilding
        {
            Id = "syn_smithy",
            TierEffects = new[]
            {
                new List<BuildingEffect> { new() { Type = BuildingEffectType.SmithyTier, Magnitude = 0 } },
                new List<BuildingEffect> { new() { Type = BuildingEffectType.SmithyTier, Magnitude = 1 } },
                new List<BuildingEffect> { new() { Type = BuildingEffectType.SmithyTier, Magnitude = 2 } },
            },
        };
        var infirmary = new SyntheticBuilding
        {
            Id = "syn_infirmary",
            TierEffects = new[]
            {
                new List<BuildingEffect> { new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 5 } },
                new List<BuildingEffect> { new() { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 5 } },
            },
        };
        var lab = new SyntheticBuilding
        {
            Id = "syn_lab",
            TierEffects = new[]
            {
                new List<BuildingEffect> { new() { Type = BuildingEffectType.CategoryUnlock, Detail = "alchemy" } },
                new List<BuildingEffect> { new() { Type = BuildingEffectType.CategoryUnlock, Detail = "poisons" } },
            },
        };
        var all = new[] { farm, smithy, infirmary, lab };

        var effects = new OutpostEffects(() => all.SelectMany(b => b.Active()));
        int changes = 0;
        effects.Changed += () => changes++;

        // Baseline: empty source (nothing commissioned) → every query at its ungated default.
        Check("(A) baseline TillableAreaLevel 0", effects.TillableAreaLevel == 0);
        Check("(A) baseline AutoWatering false", !effects.AutoWatering);
        Check("(A) baseline Greenhouse false", !effects.Greenhouse);
        Check("(A) baseline SmithyTier Base", effects.SmithyTier == SmithyTier.Base);
        Check("(A) baseline InfirmaryHealingBonus 0", effects.InfirmaryHealingBonus == 0);
        Check("(A) baseline no categories", effects.UnlockedCategories.Count == 0);

        // Commission the synthetic smithy (tier 1 = SmithyTier 0 = Base) → recompute fires, tier still Base.
        smithy.Tier = 1;
        effects.Recompute();
        Check("(A) recompute fired Changed", changes == 1);
        Check("(A) smithy tier1 present, ceiling still Base (mag 0)",
            effects.Has(BuildingEffectType.SmithyTier) && effects.SmithyTier == SmithyTier.Base);

        // Upgrade the synthetic smithy → the ceiling climbs the ladder (MAX magnitude, not a sum).
        smithy.Tier = 2; effects.Recompute();
        Check("(A) smithy tier2 → ceiling Improved", effects.SmithyTier == SmithyTier.Improved);
        smithy.Tier = 3; effects.Recompute();
        Check("(A) smithy tier3 → ceiling Advanced", effects.SmithyTier == SmithyTier.Advanced);

        // Farm: sums accumulate across tiers; flags turn on.
        farm.Tier = 1; effects.Recompute();
        Check("(A) farm tier1 → TillableAreaLevel 2, AutoWatering on, Greenhouse off",
            effects.TillableAreaLevel == 2 && effects.AutoWatering && !effects.Greenhouse);
        farm.Tier = 2; effects.Recompute();
        Check("(A) farm tier2 → TillableAreaLevel cumulative 5, Greenhouse on",
            effects.TillableAreaLevel == 5 && effects.Greenhouse);

        // Infirmary: additive sum.
        infirmary.Tier = 1; effects.Recompute();
        Check("(A) infirmary tier1 → healing bonus 5", effects.InfirmaryHealingBonus == 5);
        infirmary.Tier = 2; effects.Recompute();
        Check("(A) infirmary tier2 → healing bonus cumulative 10", effects.InfirmaryHealingBonus == 10);

        // CategoryUnlock: id set grows.
        lab.Tier = 1; effects.Recompute();
        Check("(A) lab tier1 → alchemy unlocked, poisons not",
            effects.IsCategoryUnlocked("alchemy") && !effects.IsCategoryUnlocked("poisons"));
        lab.Tier = 2; effects.Recompute();
        Check("(A) lab tier2 → both categories unlocked (set of 2)",
            effects.IsCategoryUnlocked("alchemy") && effects.IsCategoryUnlocked("poisons")
            && effects.UnlockedCategories.Count == 2);

        Check("(A) Changed fired once per recompute (9 recomputes)", changes == 9);
    }

    // ─────────────────────────── (B) Smithy tier gate (synthetic entries) ───────────────────────────

    private void RunSmithyGate()
    {
        GD.Print("-------------------- (B) Smithy tier gate (SmithyAccess, synthetic entries) --------------------");

        var baseEntry = new WeaponCatalogEntry { WeaponSlug = "syn-base", DisplayName = "Syn Base", Price = 1, Tier = SmithyTier.Base };
        var advEntry = new WeaponCatalogEntry { WeaponSlug = "syn-adv", DisplayName = "Syn Adv", Price = 1, Tier = SmithyTier.Advanced };
        var entries = new[] { baseEntry, advEntry };

        Check("(B) base weapon unlocked at Base (baseline always works)", SmithyAccess.WeaponUnlocked(baseEntry, SmithyTier.Base));
        Check("(B) advanced weapon LOCKED at Base", !SmithyAccess.WeaponUnlocked(advEntry, SmithyTier.Base));
        Check("(B) advanced weapon still locked at Improved", !SmithyAccess.WeaponUnlocked(advEntry, SmithyTier.Improved));
        Check("(B) advanced weapon unlocks at Advanced", SmithyAccess.WeaponUnlocked(advEntry, SmithyTier.Advanced));

        Check("(B) UnlockedWeapons(Base) yields only the base entry",
            SmithyAccess.UnlockedWeapons(entries, SmithyTier.Base).SequenceEqual(new[] { baseEntry }));
        Check("(B) UnlockedWeapons(Advanced) yields both",
            SmithyAccess.UnlockedWeapons(entries, SmithyTier.Advanced).Count() == 2);

        Check("(B) fundamental Potency rune unlocked at Base", SmithyAccess.RuneUnlocked(RuneKind.Potency, SmithyTier.Base));
        Check("(B) fundamental Striking rune unlocked at Base", SmithyAccess.RuneUnlocked(RuneKind.Striking, SmithyTier.Base));
    }

    // ─────────────────────────── (C) Real GameState wiring + save/load ───────────────────────────

    private void RunGameStateWiring()
    {
        GD.Print("-------------------- (C) GameState baseline + shipped-building recompute + save/load --------------------");
        ClearSlot0();

        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        // BASELINE: no buildings commissioned → every capability query at its ungated default.
        Check("(C) baseline SmithyTier Base", gs.SmithyTier == SmithyTier.Base);
        Check("(C) baseline InfirmaryHealingBonus 0", gs.InfirmaryHealingBonus == 0);
        Check("(C) baseline farm auto-water/greenhouse off", !gs.FarmAutoWater && !gs.FarmGreenhouse);
        Check("(C) baseline no categories unlocked", gs.UnlockedCategories.Count == 0);

        // Base weapon purchase works at baseline (base tier always available).
        gs.EarnGold(1000);
        Check("(C) baseline base weapon purchase succeeds", gs.BuyWeapon(SquadRoster.PlayerId, "dagger"));

        int effectEvents = 0;
        gs.EffectsChanged += () => effectEvents++;

        // Commission the shipped Infirmary (wood5 + herb8) → tier1 InfirmaryHealing mag 1.
        gs.AddItem("herb", 10);
        gs.AddItem("wood", 10);
        Check("(C) commission shipped infirmary", gs.CommissionBuilding("infirmary"));
        Check("(C) infirmary raised InfirmaryHealingBonus to 1", gs.InfirmaryHealingBonus == 1);
        Check("(C) commissioning fired EffectsChanged", effectEvents >= 1);

        // Commission + upgrade the shipped Smithy → SmithyTier ceiling Base → Improved.
        gs.AddItem("wood", 10);
        gs.AddItem("stone", 30);
        Check("(C) commission shipped smithy", gs.CommissionBuilding("smithy"));
        Check("(C) smithy tier1 → ceiling still Base", gs.SmithyTier == SmithyTier.Base);
        gs.AddItem("goblin_fang", 6);
        gs.AddItem("rat_pelt", 5);
        Check("(C) contribute smithy tier2 stone", gs.ContributeBundle("smithy", "stone", 8));
        Check("(C) contribute smithy tier2 goblin_fang", gs.ContributeBundle("smithy", "goblin_fang", 6));
        Check("(C) contribute smithy tier2 rat_pelt", gs.ContributeBundle("smithy", "rat_pelt", 5));
        Check("(C) upgrade shipped smithy to tier2", gs.UpgradeBuilding("smithy"));
        Check("(C) smithy tier2 → ceiling Improved", gs.SmithyTier == SmithyTier.Improved);

        gs.SaveGame();

        // Fresh GameState reloads: the DERIVED effect state must recompute from restored building tiers.
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        Check("(C) reload recomputed InfirmaryHealingBonus (1)", gs2.InfirmaryHealingBonus == 1);
        Check("(C) reload recomputed SmithyTier ceiling (Improved)", gs2.SmithyTier == SmithyTier.Improved);

        // A pristine GameState (fresh slot) recomputes back to baseline defaults.
        ClearSlot0();
        var gs3 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs3);
        Check("(C) fresh slot → baseline SmithyTier Base + 0 heal (byte-identical defaults)",
            gs3.SmithyTier == SmithyTier.Base && gs3.InfirmaryHealingBonus == 0);

        gs.QueueFree();
        gs2.QueueFree();
        gs3.QueueFree();
    }

    // ─────────────────────────── (D) Infirmary healing is additive ───────────────────────────

    private void RunInfirmaryHealing()
    {
        GD.Print("-------------------- (D) InfirmaryHealing additive in Treat Wounds --------------------");

        int h0 = HealWithBonus(0);
        int hK = HealWithBonus(100);

        Check("(D) a baseline Treat Wounds heal occurred and is below the bonus (0 < h0 < 100)",
            h0 > 0 && h0 < 100);
        Check("(D) a +100 infirmary bonus heals at/above 100 (bonus applied additively)",
            hK >= 100);
        Check("(D) bonus heal strictly exceeds the baseline heal", hK > h0);
    }

    /// <summary>Run Treat Wounds under a fixed infirmary bonus until one positive heal lands; return
    /// the applied heal reported by the result view (base + bonus, pre-clamp). -1 if none in 40 tries.</summary>
    private static int HealWithBonus(int bonus)
    {
        for (int attempt = 0; attempt < 40; attempt++)
        {
            var squad = SquadRoster.BuildNew(2);
            var clock = new DayClock();

            // Find a member who can attempt a Treat Wounds DC (Medicine-trained).
            string? healerId = null;
            var probe = new TreatWoundsSystem(squad, clock);
            foreach (var m in squad.Members)
                if (probe.GetAvailableDCs(m.Id).Length > 0) { healerId = m.Id; break; }
            if (healerId == null)
                return -1;

            var target = squad.FindMember(healerId)!;
            target.Health!.SetCurrentHP(1); // large dent so a heal isn't clamped away

            var sys = new TreatWoundsSystem(squad, clock, () => bonus);
            TreatWoundsResultView? view = null;
            sys.Resolved += v => view = v;

            int dc = sys.GetAvailableDCs(healerId)[0];
            if (sys.TreatWounds(healerId, healerId, dc) && view is { HealingOrDamage: > 0 })
                return view.HealingOrDamage;
        }
        return -1;
    }

    // ─────────────────────────── (E) Farm capability queries + applied rules ───────────────────────────

    private void RunFarmCapabilities()
    {
        GD.Print("-------------------- (E) Farm capability queries + applied rules --------------------");

        // Baseline farm (no capabilities provider) reproduces today's behaviour.
        var invBase = new Inventory();
        invBase.AddItem("turnip_seed", 4);
        var seasonBase = Season.Spring;
        var farmBase = new FarmSystem(invBase, () => seasonBase);
        Check("(E) baseline auto-water/greenhouse off, tillable-area level 0",
            !farmBase.AutoWaterEnabled && !farmBase.GreenhouseEnabled && farmBase.TillableAreaLevel == 0);

        // A crop that grows in Spring but NOT Summer, to exercise the season gate + greenhouse.
        string cropId = Crops.All.FirstOrDefault(c =>
            c.Seasons.Contains(Season.Spring) && !c.Seasons.Contains(Season.Summer))?.Id
            ?? Crops.All.First().Id;
        var seedId = Crops.Get(cropId).SeedItemId;

        // ---- Capability-driven farm: flip the aggregator's farm caps behind the provider. ----
        var caps = FarmCapabilities.Baseline;
        var inv = new Inventory();
        inv.AddItem(seedId, 10);
        var season = Season.Summer; // out of season for the chosen crop
        var farm = new FarmSystem(inv, () => season);
        farm.SetCapabilities(() => caps);
        var tile = new Vector2I(0, 0);

        // Baseline: cannot plant out of season.
        farm.TillPlot(tile);
        Check("(E) baseline: out-of-season plant rejected", !farm.PlantCrop(tile, cropId));

        // Greenhouse capability flips on → the query flips and the out-of-season plant is now allowed.
        caps = new FarmCapabilities { Greenhouse = true };
        Check("(E) greenhouse query flips true", farm.GreenhouseEnabled);
        Check("(E) greenhouse: out-of-season plant now allowed", farm.PlantCrop(tile, cropId));

        // Auto-water capability: an UNWATERED planted plot still advances growth overnight.
        caps = new FarmCapabilities { Greenhouse = true, AutoWater = true, TillableAreaLevel = 4 };
        Check("(E) auto-water + tillable-area-level queries flip",
            farm.AutoWaterEnabled && farm.TillableAreaLevel == 4);
        var plotBefore = farm.GetPlot(tile)!;
        int grownBefore = plotBefore.DaysGrown;
        Check("(E) plot not watered by hand", !plotBefore.WateredToday);
        farm.OnDayEnded();
        Check("(E) auto-water advanced growth without a manual water",
            farm.GetPlot(tile)!.DaysGrown == grownBefore + 1);

        RunFarmZoneGate();
    }

    // ─────────────────────────── (E2) Tillable-AREA zone gate (Refinement 2) ───────────────────────────

    /// <summary>
    /// Proves the farm tillable-AREA expansion gate (the rule OutpostScene.IsTillable adds): a farmable
    /// tile is tillable only when its ZONE ≤ the outpost's tillable-area LEVEL. Base zone (0) always
    /// tills; a higher-zone tile is locked until the level unlocks it; a tile with no authored zone data
    /// defaults to base (0) so behaviour is byte-identical until the user authors zone tiers. Driven
    /// through a real FarmSystem via an injected tillable predicate = farmable ∧ zone-gate (the exact
    /// composition the scene uses), flipping the area level to unlock a higher zone.
    /// </summary>
    private void RunFarmZoneGate()
    {
        GD.Print("-------------------- (E2) Tillable-AREA zone gate (Refinement 2) --------------------");

        // Pure rule: base zone always in; higher zone gated on level; default (no data) = base.
        Check("(E2) base zone (0) tillable at level 0", FarmZones.IsWithinTillableArea(0, 0));
        Check("(E2) zone 1 LOCKED at level 0", !FarmZones.IsWithinTillableArea(1, 0));
        Check("(E2) zone 1 unlocks at level 1", FarmZones.IsWithinTillableArea(1, 1));
        Check("(E2) zone 2 still locked at level 1", !FarmZones.IsWithinTillableArea(2, 1));
        Check("(E2) no-zone-data default (base 0) tillable at level 0",
            FarmZones.IsWithinTillableArea(FarmZones.BaseZone, 0));

        // IsTillable-style gate through a real FarmSystem: base tile (zone 0) + a higher tile (zone 1).
        var baseTile = new Vector2I(0, 0);
        var zone1Tile = new Vector2I(1, 0);
        int ZoneOf(Vector2I c) => c == zone1Tile ? 1 : 0; // authored zone map; everything else = base

        int areaLevel = 0;
        var zinv = new Inventory();
        var zfarm = new FarmSystem(zinv, () => Season.Spring);
        // The scene composes: farmable(map) ∧ within-unlocked-area(zone, level). Here every tile is
        // farmable; the zone gate is what varies.
        zfarm.SetTillable(c => FarmZones.IsWithinTillableArea(ZoneOf(c), areaLevel));

        Check("(E2) level 0: base-zone tile tills", zfarm.TillPlot(baseTile));
        Check("(E2) level 0: zone-1 tile NOT tillable (outside unlocked area)", !zfarm.TillPlot(zone1Tile));

        areaLevel = 1; // a farm upgrade expands the tillable area to include zone 1
        Check("(E2) level 1: zone-1 tile now tills (area expanded)", zfarm.TillPlot(zone1Tile));
    }

    // ─────────────────────────── (F) Spell-access seam + CategoryUnlock membership ───────────────────────────

    private void RunSpellAndCategory()
    {
        GD.Print("-------------------- (F) Spell-access grant seam + CategoryUnlock membership --------------------");

        var squad = SquadRoster.BuildNew(2); // BuildScholar registers the preset spells into SpellDatabase
        var scholar = squad.FindMember(SquadRoster.ScholarId);
        Check("(F) scholar is a spellcaster", scholar?.Spellcasting != null);
        if (scholar?.Spellcasting == null)
            return;

        // A preset spell the arcane Scholar does NOT know (Heal is Divine) — the grant target.
        const string grantId = PresetSpells.HealId;
        Check("(F) scholar does not know the spell before the grant", !SpellAccessSeam.KnowsSpell(scholar, grantId));

        Check("(F) grant seam adds the spell to the known list", SpellAccessSeam.GrantSpell(scholar, grantId));
        Check("(F) scholar now knows it (KnowsSpell)", SpellAccessSeam.KnowsSpell(scholar, grantId));
        Check("(F) re-granting an already-known spell is rejected", !SpellAccessSeam.GrantSpell(scholar, grantId));

        var granted = SpellDatabase.Instance?.GetById(grantId);
        Check("(F) granted spell resolves from SpellDatabase", granted?.Spell != null);
        if (granted?.Spell != null)
        {
            int rank = granted.Spell.SpellLevel;
            Check("(F) granted spell now appears in the caster's available list for its rank",
                scholar.Spellcasting.GetAvailableSpellsForRank(rank).Contains(granted));

            // OnSpellsChanged proof: swap the granted spell into the prepared list for an existing
            // same-rank preparation — a pure engine call that fires the event (no engine edit).
            var existing = scholar.Spellcasting.LeveledSpells.FirstOrDefault(s =>
                s?.Spell != null && !s.Spell.IsFocusSpell && s.Spell.SpellLevel == rank && s != granted);
            if (existing != null)
            {
                bool fired = false;
                Action handler = () => fired = true;
                scholar.Spellcasting.OnSpellsChanged += handler;
                bool swapped = scholar.Spellcasting.SwapPreparedSpell(existing, granted);
                scholar.Spellcasting.OnSpellsChanged -= handler;
                Check("(F) granted spell prepared via engine swap (OnSpellsChanged fired)",
                    swapped && fired && scholar.Spellcasting.HasPreparedSpell(granted));
            }
            else
            {
                GD.Print("  [INFO] no same-rank preparation to swap; grant proven via KnowsSpell only.");
            }
        }

        // CategoryUnlock membership: a generic queryable set (proven synthetic in (A)); confirm the
        // OutpostEffects membership API answers a non-member as false and a member as true.
        var lab = new List<BuildingEffect> { new() { Type = BuildingEffectType.CategoryUnlock, Detail = "tonics" } };
        var effects = new OutpostEffects(() => lab);
        Check("(F) CategoryUnlock membership: unlocked id true", effects.IsCategoryUnlocked("tonics"));
        Check("(F) CategoryUnlock membership: unknown id false", !effects.IsCategoryUnlocked("nope"));
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
        GD.Print("[EffectsSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[EffectsSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[EffectsSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
