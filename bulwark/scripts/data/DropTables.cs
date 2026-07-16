using System;
using System.Collections.Generic;

namespace Bulwark.Data;

/// <summary>One weighted item line of a <see cref="DropTable"/>: which item, and the quantity band
/// rolled when this entry is picked. Min == Max makes the entry deterministic.</summary>
public sealed class DropEntry
{
    public required string ItemId { get; init; }
    public int MinQty { get; init; } = 1;
    public int MaxQty { get; init; } = 1;

    /// <summary>Relative weight in the table's single weighted pick.</summary>
    public int Weight { get; init; } = 1;
}

/// <summary>
/// A weighted loot table: a single weighted item pick (from <see cref="Entries"/>) plus a coin
/// (gold) band, rolled once per defeated creature that references it. Coin min == max makes the
/// gold deterministic (the Phase-1 forest tables are built that way so the economy spike can force
/// exact results without an RNG seam). Data-only per CLAUDE.md.
/// </summary>
public sealed class DropTable
{
    public required string Id { get; init; }

    /// <summary>Weighted item candidates; empty = coin only.</summary>
    public IReadOnlyList<DropEntry> Entries { get; init; } = Array.Empty<DropEntry>();

    public int CoinMin { get; init; }
    public int CoinMax { get; init; }
}

/// <summary>
/// Static registry of loot tables, keyed by <see cref="CreatureRef.DropTableId"/>.
///
/// Full bestiary set (design/economy/materials.md, "Combat drops" + biome creature sections): every
/// one of the fifteen creature families across the three biomes gets three tables —
/// <c>&lt;family&gt;_drops</c> (common encounters), <c>&lt;family&gt;_elite_drops</c>, and
/// <c>&lt;family&gt;_boss_drops</c>. Common tables roll a WIDENED 1-3 quantity band on the family's
/// common part (genre parity — a single kill returns 1 to 3 units, not a flat 1), plus a family's
/// second common part where the catalog names one (Goblins' goblin_scrap; every Sunken Reach
/// family's shared marsh_leech secondary). Elite/boss tables are a separate weighted pick between
/// the family's trophy (heavily weighted, 1-1 qty for elites, 2-3 for bosses — the materials.md
/// "guarantee" language, approximated as a dominant-weight favorite since DropTable/LootRoller only
/// support a single weighted pick per roll, not a guaranteed-plus-bonus roll) and a bonus,
/// higher-quantity haul of the common part. Coin bands scale with the biome's difficulty band per
/// materials.md: easy (Verdant Fringe) common 3-6 / elite 12-18 / boss 25-35, moderate (Elderwood)
/// common 6-10 / elite 18-26 / boss 35-50, dangerous (Sunken Reach) common 8-15 / elite 24-34 /
/// boss 45-65 — the elite/boss bands are a content-pass judgment call (materials.md only specifies
/// the common band); they scale up consistently per tier. Additions are data-only.
/// </summary>
public static class DropTables
{
    // ================= The Verdant Fringe (easy: common 3-6, elite 12-18, boss 25-35) =================

    // --- Goblins (goblin_fang + goblin_scrap common; goblin_totem trophy) ---
    public static readonly DropTable GoblinDrops = new()
    {
        Id = "goblin_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "goblin_fang", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "goblin_scrap", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 3, CoinMax = 6,
    };
    public static readonly DropTable GoblinEliteDrops = new()
    {
        Id = "goblin_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "goblin_totem", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "goblin_fang", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 12, CoinMax = 18,
    };
    public static readonly DropTable GoblinBossDrops = new()
    {
        Id = "goblin_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "goblin_totem", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "goblin_fang", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 25, CoinMax = 35,
    };

    // --- Rats (rat_pelt common; nest_matriarch_tail trophy) ---
    public static readonly DropTable RatDrops = new()
    {
        Id = "rat_drops",
        Entries = new[] { new DropEntry { ItemId = "rat_pelt", MinQty = 1, MaxQty = 3 } },
        CoinMin = 3, CoinMax = 6,
    };
    public static readonly DropTable RatEliteDrops = new()
    {
        Id = "rat_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "nest_matriarch_tail", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "rat_pelt", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 12, CoinMax = 18,
    };
    public static readonly DropTable RatBossDrops = new()
    {
        Id = "rat_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "nest_matriarch_tail", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "rat_pelt", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 25, CoinMax = 35,
    };

    // --- Brigands (deserter_badge common; deserter_signet trophy) ---
    public static readonly DropTable BrigandDrops = new()
    {
        Id = "brigand_drops",
        Entries = new[] { new DropEntry { ItemId = "deserter_badge", MinQty = 1, MaxQty = 3 } },
        CoinMin = 3, CoinMax = 6,
    };
    public static readonly DropTable BrigandEliteDrops = new()
    {
        Id = "brigand_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "deserter_signet", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "deserter_badge", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 12, CoinMax = 18,
    };
    public static readonly DropTable BrigandBossDrops = new()
    {
        Id = "brigand_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "deserter_signet", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "deserter_badge", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 25, CoinMax = 35,
    };

    // --- Bramble Slicks (sap_gland common; amber_core trophy) ---
    public static readonly DropTable BrambleSlickDrops = new()
    {
        Id = "bramble_slick_drops",
        Entries = new[] { new DropEntry { ItemId = "sap_gland", MinQty = 1, MaxQty = 3 } },
        CoinMin = 3, CoinMax = 6,
    };
    public static readonly DropTable BrambleSlickEliteDrops = new()
    {
        Id = "bramble_slick_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "amber_core", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "sap_gland", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 12, CoinMax = 18,
    };
    public static readonly DropTable BrambleSlickBossDrops = new()
    {
        Id = "bramble_slick_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "amber_core", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "sap_gland", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 25, CoinMax = 35,
    };

    // --- Hedge Folk (fey_charm common; hollow_crown trophy) ---
    public static readonly DropTable HedgeFolkDrops = new()
    {
        Id = "hedge_folk_drops",
        Entries = new[] { new DropEntry { ItemId = "fey_charm", MinQty = 1, MaxQty = 3 } },
        CoinMin = 3, CoinMax = 6,
    };
    public static readonly DropTable HedgeFolkEliteDrops = new()
    {
        Id = "hedge_folk_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "hollow_crown", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "fey_charm", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 12, CoinMax = 18,
    };
    public static readonly DropTable HedgeFolkBossDrops = new()
    {
        Id = "hedge_folk_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "hollow_crown", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "fey_charm", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 25, CoinMax = 35,
    };

    // ================= The Elderwood (moderate: common 6-10, elite 18-26, boss 35-50) =================

    // --- Beasts (beast_hide common; alpha_pelt trophy) ---
    public static readonly DropTable BeastDrops = new()
    {
        Id = "beast_drops",
        Entries = new[] { new DropEntry { ItemId = "beast_hide", MinQty = 1, MaxQty = 3 } },
        CoinMin = 6, CoinMax = 10,
    };
    public static readonly DropTable BeastEliteDrops = new()
    {
        Id = "beast_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "alpha_pelt", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "beast_hide", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 18, CoinMax = 26,
    };
    public static readonly DropTable BeastBossDrops = new()
    {
        Id = "beast_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "alpha_pelt", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "beast_hide", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 35, CoinMax = 50,
    };

    // --- Root Wardens (warden_bark common; heartwood_shard trophy) ---
    public static readonly DropTable RootWardenDrops = new()
    {
        Id = "root_warden_drops",
        Entries = new[] { new DropEntry { ItemId = "warden_bark", MinQty = 1, MaxQty = 3 } },
        CoinMin = 6, CoinMax = 10,
    };
    public static readonly DropTable RootWardenEliteDrops = new()
    {
        Id = "root_warden_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "heartwood_shard", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "warden_bark", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 18, CoinMax = 26,
    };
    public static readonly DropTable RootWardenBossDrops = new()
    {
        Id = "root_warden_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "heartwood_shard", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "warden_bark", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 35, CoinMax = 50,
    };

    // --- Canopy Spiders (spider_silk common; silkqueen_fang trophy) ---
    public static readonly DropTable CanopySpiderDrops = new()
    {
        Id = "canopy_spider_drops",
        Entries = new[] { new DropEntry { ItemId = "spider_silk", MinQty = 1, MaxQty = 3 } },
        CoinMin = 6, CoinMax = 10,
    };
    public static readonly DropTable CanopySpiderEliteDrops = new()
    {
        Id = "canopy_spider_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "silkqueen_fang", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "spider_silk", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 18, CoinMax = 26,
    };
    public static readonly DropTable CanopySpiderBossDrops = new()
    {
        Id = "canopy_spider_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "silkqueen_fang", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "spider_silk", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 35, CoinMax = 50,
    };

    // --- Thornbacks (thornback_hide common; grovefather_knuckle trophy) ---
    public static readonly DropTable ThornbackDrops = new()
    {
        Id = "thornback_drops",
        Entries = new[] { new DropEntry { ItemId = "thornback_hide", MinQty = 1, MaxQty = 3 } },
        CoinMin = 6, CoinMax = 10,
    };
    public static readonly DropTable ThornbackEliteDrops = new()
    {
        Id = "thornback_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "grovefather_knuckle", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "thornback_hide", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 18, CoinMax = 26,
    };
    public static readonly DropTable ThornbackBossDrops = new()
    {
        Id = "thornback_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "grovefather_knuckle", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "thornback_hide", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 35, CoinMax = 50,
    };

    // ============ The Sunken Reach (dangerous: common 8-15, elite 24-34, boss 45-65) ============
    // Every family's common table also carries a secondary, weighted marsh_leech entry — the
    // "any Sunken Reach encounter, secondary drop" universal part named in materials.md.

    // --- Mudclaws (mudclaw_hide common; reaver_tooth trophy) ---
    public static readonly DropTable MudclawDrops = new()
    {
        Id = "mudclaw_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "mudclaw_hide", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable MudclawEliteDrops = new()
    {
        Id = "mudclaw_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "reaver_tooth", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "mudclaw_hide", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable MudclawBossDrops = new()
    {
        Id = "mudclaw_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "reaver_tooth", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "mudclaw_hide", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    // --- Marsh Serpents (serpent_scale common; venom_sac trophy) ---
    public static readonly DropTable MarshSerpentDrops = new()
    {
        Id = "marsh_serpent_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "serpent_scale", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable MarshSerpentEliteDrops = new()
    {
        Id = "marsh_serpent_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "venom_sac", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "serpent_scale", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable MarshSerpentBossDrops = new()
    {
        Id = "marsh_serpent_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "venom_sac", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "serpent_scale", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    // --- Bog Fungus (spore_pod common; fungal_core trophy) ---
    public static readonly DropTable BogFungusDrops = new()
    {
        Id = "bog_fungus_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "spore_pod", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable BogFungusEliteDrops = new()
    {
        Id = "bog_fungus_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "fungal_core", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "spore_pod", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable BogFungusBossDrops = new()
    {
        Id = "bog_fungus_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "fungal_core", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "spore_pod", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    // --- The Drowned (drowned_bone common; hollow_locket trophy) ---
    public static readonly DropTable DrownedDrops = new()
    {
        Id = "drowned_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "drowned_bone", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable DrownedEliteDrops = new()
    {
        Id = "drowned_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "hollow_locket", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "drowned_bone", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable DrownedBossDrops = new()
    {
        Id = "drowned_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "hollow_locket", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "drowned_bone", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    // --- Swamp Drakes (swamp_drake_scale common; sovereign_hide trophy) ---
    public static readonly DropTable SwampDrakeDrops = new()
    {
        Id = "swamp_drake_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "swamp_drake_scale", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable SwampDrakeEliteDrops = new()
    {
        Id = "swamp_drake_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "sovereign_hide", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "swamp_drake_scale", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable SwampDrakeBossDrops = new()
    {
        Id = "swamp_drake_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "sovereign_hide", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "swamp_drake_scale", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    // --- Marsh Wisps (wisp_ember common; drowning_lantern trophy) ---
    public static readonly DropTable MarshWispDrops = new()
    {
        Id = "marsh_wisp_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "wisp_ember", MinQty = 1, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "marsh_leech", MinQty = 1, MaxQty = 3, Weight = 1 },
        },
        CoinMin = 8, CoinMax = 15,
    };
    public static readonly DropTable MarshWispEliteDrops = new()
    {
        Id = "marsh_wisp_elite_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "drowning_lantern", MinQty = 1, MaxQty = 1, Weight = 3 },
            new DropEntry { ItemId = "wisp_ember", MinQty = 4, MaxQty = 6, Weight = 1 },
        },
        CoinMin = 24, CoinMax = 34,
    };
    public static readonly DropTable MarshWispBossDrops = new()
    {
        Id = "marsh_wisp_boss_drops",
        Entries = new[]
        {
            new DropEntry { ItemId = "drowning_lantern", MinQty = 2, MaxQty = 3, Weight = 3 },
            new DropEntry { ItemId = "wisp_ember", MinQty = 6, MaxQty = 9, Weight = 1 },
        },
        CoinMin = 45, CoinMax = 65,
    };

    private static readonly DefinitionRegistry<DropTable> Registry = new(d => d.Id,
        GoblinDrops, GoblinEliteDrops, GoblinBossDrops,
        RatDrops, RatEliteDrops, RatBossDrops,
        BrigandDrops, BrigandEliteDrops, BrigandBossDrops,
        BrambleSlickDrops, BrambleSlickEliteDrops, BrambleSlickBossDrops,
        HedgeFolkDrops, HedgeFolkEliteDrops, HedgeFolkBossDrops,
        BeastDrops, BeastEliteDrops, BeastBossDrops,
        RootWardenDrops, RootWardenEliteDrops, RootWardenBossDrops,
        CanopySpiderDrops, CanopySpiderEliteDrops, CanopySpiderBossDrops,
        ThornbackDrops, ThornbackEliteDrops, ThornbackBossDrops,
        MudclawDrops, MudclawEliteDrops, MudclawBossDrops,
        MarshSerpentDrops, MarshSerpentEliteDrops, MarshSerpentBossDrops,
        BogFungusDrops, BogFungusEliteDrops, BogFungusBossDrops,
        DrownedDrops, DrownedEliteDrops, DrownedBossDrops,
        SwampDrakeDrops, SwampDrakeEliteDrops, SwampDrakeBossDrops,
        MarshWispDrops, MarshWispEliteDrops, MarshWispBossDrops);

    public static IReadOnlyCollection<DropTable> All => Registry.All;

    public static bool IsDefined(string id) => Registry.IsDefined(id);

    public static DropTable Get(string id) => Registry.Get(id);

    public static bool TryGet(string id, out DropTable def) => Registry.TryGet(id, out def);
}
