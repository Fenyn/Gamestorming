using System;
using System.Collections.Generic;
using System.Linq;
using Bulwark.Data;
using PF2e.Data;
using PF2e.Import;

namespace Bulwark.Cozy;

/// <summary>
/// The smithy's FORGE loop (the buy/sell-for-gold economy lives on <see cref="StoreSystem"/> now):
/// apply fundamental weapon runes and buy catalog weapons for the live squad. Plain C# and
/// unit-testable, constructed only when the squad exists (the PF2e content is loaded) — GameState
/// keeps thin forwarders that null-guard on it, the <see cref="TreatWoundsSystem"/> precedent.
///
/// Both purchase paths validate reagent/metal presence BEFORE spending gold so a short-material reject
/// leaves gold and inventory untouched, apply the change in place on the member's live equipment, and
/// raise <see cref="Changed"/> (GameState re-exposes it as SmithyChanged and records the smithy_craft
/// quest event through the story director). The smithy tier ceiling is read live via the injected
/// provider (the <see cref="OutpostEffects.SmithyTier"/> aggregate); the shop widens as it rises.
/// <see cref="BuildView"/> produces the engine-free <see cref="SmithyView"/> the future screen consumes.
/// </summary>
public sealed class SmithySystem
{
    private readonly SquadRoster _squad;
    private readonly Wallet _wallet;
    private readonly Inventory _inventory;
    private readonly Func<SmithyTier> _smithyTier;

    /// <summary>Raised after a rune is applied or a weapon is bought — GameState re-exposes it as SmithyChanged.</summary>
    public event Action? Changed;

    /// <param name="squad">The live roster runes/weapons are applied to.</param>
    /// <param name="wallet">The gold purse spends (and defensive refunds) go through directly.</param>
    /// <param name="inventory">Party inventory the rune reagent / weapon metal is consumed from.</param>
    /// <param name="smithyTier">Live smithy-ceiling provider (the OutpostEffects aggregate).</param>
    public SmithySystem(SquadRoster squad, Wallet wallet, Inventory inventory, Func<SmithyTier> smithyTier)
    {
        _squad = squad ?? throw new ArgumentNullException(nameof(squad));
        _wallet = wallet ?? throw new ArgumentNullException(nameof(wallet));
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _smithyTier = smithyTier ?? throw new ArgumentNullException(nameof(smithyTier));
    }

    // ===================== Commands =====================

    /// <summary>
    /// Apply a fundamental rune to a member's main-hand weapon. Refinement 3: runes are a MAGICAL
    /// enchantment, so the cost is gold + N magical reagent (arcane_essence), NOT metal. Validates the
    /// rune is applicable (member exists, holds a weapon, rune not maxed), the smithy tier unlocks it,
    /// gold covers the cost, AND the inventory holds the reagent — all BEFORE consuming anything, so an
    /// insufficient-gold / short-reagent / inapplicable request consumes NOTHING. On success spends the
    /// gold, consumes the reagent, applies the rune in place (flows straight into strike math), and
    /// raises <see cref="Changed"/>.
    /// </summary>
    public bool ApplyWeaponRune(string memberId, RuneKind kind)
    {
        if (!_squad.CanApplyRune(memberId, kind))
            return false;
        // Phase-4 smithy gate: rune must be unlocked at the outpost's smithy tier. Fundamental runes
        // require Base (always unlocked → baseline unchanged); higher rune tiers gate here later.
        if (!SmithyAccess.RuneUnlocked(kind, _smithyTier()))
            return false;

        // Refinement 3: reagent presence is validated BEFORE any gold is spent so a short-reagent
        // reject leaves gold and inventory untouched.
        string reagentId = RunePrices.ReagentItemId;
        int reagentCost = RunePrices.ReagentCostOf(kind);
        if (reagentCost > 0 && !_inventory.Has(reagentId, reagentCost))
            return false;

        int cost = RunePrices.CostOf(kind);
        if (!_wallet.TrySpendGold(cost))
            return false;
        if (reagentCost > 0)
            _inventory.RemoveItem(reagentId, reagentCost); // validated present above

        if (!_squad.ApplyWeaponRune(memberId, kind))
        {
            _wallet.EarnGold(cost); // defensive refund — CanApplyRune already vetted this
            if (reagentCost > 0)
                _inventory.AddItem(reagentId, reagentCost); // and un-consume the reagent
            return false;
        }

        Changed?.Invoke();
        return true;
    }

    /// <summary>
    /// Buy a catalog weapon and equip it to a member. Refinement 3: metal drives higher-tier EQUIPMENT —
    /// base entries stay gold-only, while higher-tier entries (SmithyTier &gt; Base) also cost METAL
    /// ingots (copper_ingot). Validates the weapon is on the available shelf, resolves the real pack
    /// definition, and checks gold AND the metal material BEFORE spending — a rejected buy (locked /
    /// unaffordable / short on metal) consumes NOTHING. On success spends the gold, consumes the metal,
    /// re-equips the member (preserving their other live state), and raises <see cref="Changed"/>.
    /// </summary>
    public bool BuyWeapon(string memberId, string weaponSlug)
    {
        if (_squad.FindMember(memberId) == null)
            return false;
        // Phase-4 smithy gate: only weapons unlocked at the outpost's smithy tier are purchasable
        // (base tier always available → baseline unchanged; higher tiers open as the smithy upgrades).
        if (!WeaponCatalog.TryGetAvailable(weaponSlug, out var entry, _smithyTier()))
            return false;

        var def = GameDataLoader.FindEquipment(weaponSlug)?.ToWeaponDefinition();
        if (def == null)
            return false;

        // Refinement 3: metal presence validated BEFORE spending gold so a short-metal reject is clean.
        if (entry.MetalCost > 0 && !_inventory.Has(entry.MetalItemId, entry.MetalCost))
            return false;
        if (!_wallet.TrySpendGold(entry.Price))
            return false;
        if (entry.MetalCost > 0)
            _inventory.RemoveItem(entry.MetalItemId, entry.MetalCost); // validated present above

        if (!_squad.BuyWeapon(memberId, def, weaponSlug))
        {
            _wallet.EarnGold(entry.Price); // defensive refund
            if (entry.MetalCost > 0)
                _inventory.AddItem(entry.MetalItemId, entry.MetalCost);
            return false;
        }

        Changed?.Invoke();
        return true;
    }

    // ===================== View-model =====================

    /// <summary>Build the smithy view-model: current gold, the per-member rune-upgrade options with
    /// costs, and the weapons available to buy at the current smithy tier. View-model shaped per
    /// CLAUDE.md — no engine types leak (weapon names are plain strings, <see cref="RuneKind"/> is a
    /// bulwark enum).</summary>
    public SmithyView BuildView()
    {
        int gold = _wallet.Gold;
        var members = new List<SmithyMemberView>();
        foreach (var m in _squad.Members)
        {
            var weapon = m.Equipment?.MainHandWeapon;
            int potency = weapon?.PotencyBonus ?? 0;
            bool hasStriking = weapon != null && weapon.Striking >= StrikingRuneLevel.Striking;

            string reagentId = RunePrices.ReagentItemId;
            int potencyReagent = RunePrices.ReagentCostOf(RuneKind.Potency);
            int strikingReagent = RunePrices.ReagentCostOf(RuneKind.Striking);
            var runeOptions = new List<SmithyRuneOption>
            {
                new()
                {
                    Kind = RuneKind.Potency,
                    Label = $"Potency +{Math.Min(potency + 1, RunePrices.MaxPotency)}",
                    Cost = RunePrices.Potency,
                    ReagentItemId = reagentId,
                    ReagentCost = potencyReagent,
                    Available = _squad.CanApplyRune(m.Id, RuneKind.Potency),
                    CanAfford = gold >= RunePrices.Potency && _inventory.Has(reagentId, potencyReagent),
                },
                new()
                {
                    Kind = RuneKind.Striking,
                    Label = "Striking",
                    Cost = RunePrices.Striking,
                    ReagentItemId = reagentId,
                    ReagentCost = strikingReagent,
                    Available = _squad.CanApplyRune(m.Id, RuneKind.Striking),
                    CanAfford = gold >= RunePrices.Striking && _inventory.Has(reagentId, strikingReagent),
                },
            };

            members.Add(new SmithyMemberView
            {
                MemberId = m.Id,
                Name = m.Name,
                WeaponName = weapon?.ItemName ?? "Unarmed",
                PotencyBonus = potency,
                HasStriking = hasStriking,
                RuneUpgrades = runeOptions,
            });
        }

        var weapons = WeaponCatalog.Available(_smithyTier())
            .Select(e => new SmithyWeaponOption
            {
                WeaponSlug = e.WeaponSlug,
                DisplayName = e.DisplayName,
                Price = e.Price,
                MetalItemId = e.MetalItemId,
                MetalCost = e.MetalCost,
                CanAfford = gold >= e.Price && (e.MetalCost <= 0 || _inventory.Has(e.MetalItemId, e.MetalCost)),
            })
            .ToList();

        return new SmithyView { Gold = gold, Members = members, Weapons = weapons };
    }
}
