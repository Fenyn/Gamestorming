using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Bulwark.Autoload;
using Bulwark.Cozy;
using Bulwark.Data;
using Bulwark.Data.Characters;
using Bulwark.UI;
using Godot;
using CharacterRegistry = Bulwark.Data.Characters.Characters;

namespace Bulwark.Dev;

/// <summary>
/// Headless regression for the FRIENDSHIP / HEART system (design/friendship.md). Proves the logic
/// with SPIKE-LOCAL SYNTHETIC friendship profiles (injected profile source + presence predicate —
/// never added to the shipped registries) plus the real shipped content (tharr) for the end-to-end
/// GameState wiring. Sections:
///  (A) Points/hearts math: 250/heart, cap 10 (2,500), floor at 0; every preference tier's delta
///      (loved/liked/neutral/disliked/hated; item id beats category); gift consumes the item.
///  (B) Weekly gift cadence: 2/character/week, the 3rd rejected (nothing consumed), resets on the
///      7-day week boundary.
///  (C) Birthday multiplier (×8) on the character's birthday only.
///  (D) Talk: +12 once/character/day; same-day repeat is a no-op; resets the next day.
///  (E) Rejections: player not befriendable; un-arrived (absent) character; unknown/uncarried item.
///  (F) Threshold + unlock seams: each heart rung fires exactly once (in order, never re-fires
///      after a points dip); earned perk effects land in OutpostEffects via the friendship source
///      (StorePriceDiscount reaches Trading Post pricing, InfirmaryHealing sums ADDITIVELY with a
///      building source) and a category unlock becomes IsCategoryUnlocked.
///  (G) Building-restore award: commissioning/upgrading a character's associated building grants
///      the chunk to that character only (FriendshipAwards).
///  (H) Save/restore: exact serialized round-trip of points/counters/fired thresholds; same-day
///      counters survive, a later-week restore clears cadence but keeps points; null DTO (pre-v8
///      save) restores to zero friendship; restore never re-fires thresholds.
///  (I) Real GameState end-to-end: player rejected, tharr talk/gift/view, full save/load round-trip.
///  (J) Friendship panel UI smoke: scene instances, renders a view, raises GiftRequested.
/// The user's slot0.json is backed up and restored around the run.
/// </summary>
public partial class FriendshipSpike : SpikeBase
{
    private const string SavePath = "user://save/slot0.json";

    private bool _slot0Existed;
    private string? _slot0Backup;

    // ── Spike-local synthetic cast (never touches the shipped registries) ──
    private readonly Dictionary<string, FriendshipProfile> _profiles = new();
    private readonly HashSet<string> _present = new();

    private FriendshipProfile ProfileOf(string id)
        => _profiles.TryGetValue(id, out var p) ? p : new FriendshipProfile { CharacterId = id };

    private FriendshipSystem NewSystem(Inventory inventory, DayClock clock)
        => new(inventory, clock, _present.Contains, ProfileOf);

    public override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print("==================== FRIENDSHIP SPIKE ====================");

        var data = GetNodeOrNull<DataManager>("/root/DataManager");
        if (data == null || !data.IsLoaded)
        {
            AbortFail("[FriendshipSpike] DataManager not loaded — aborting.");
            return;
        }

        BackupSlot0();
        try
        {
            RunPointsAndTiers();     // (A)
            RunWeeklyCadence();      // (B)
            RunBirthday();           // (C)
            RunTalk();               // (D)
            RunRejections();         // (E)
            RunThresholdSeams();     // (F)
            RunBuildingAwards();     // (G)
            RunSaveRoundTrip();      // (H)
            RunGameStateEndToEnd();  // (I)
            await RunPanelSmoke();   // (J)
        }
        catch (Exception e)
        {
            GD.PushError($"[FriendshipSpike] Unhandled exception: {e}");
            Fail();
        }
        finally
        {
            RestoreSlot0();
        }

        FinishAndQuit("FriendshipSpike");
    }

    // ─────────────────────────── (A) Points / hearts / preference tiers ───────────────────────────

    private void RunPointsAndTiers()
    {
        GD.Print("-------------------- (A) Points, hearts, preference tiers --------------------");

        _profiles.Clear();
        _present.Clear();
        _profiles["c_loved"] = new FriendshipProfile
        {
            CharacterId = "c_loved",
            LovedItems = new[] { "wood" },
            // Item-id precedence check: the id listing must beat the category listing.
            HatedCategories = new[] { ItemCategory.Resource },
        };
        _profiles["c_liked"] = new FriendshipProfile
        {
            CharacterId = "c_liked", LikedCategories = new[] { ItemCategory.Resource },
        };
        _profiles["c_neutral"] = new FriendshipProfile { CharacterId = "c_neutral" };
        _profiles["c_disliked"] = new FriendshipProfile
        {
            CharacterId = "c_disliked", DislikedItems = new[] { "wood" },
        };
        _profiles["c_hated"] = new FriendshipProfile
        {
            CharacterId = "c_hated", HatedItems = new[] { "wood" },
        };
        foreach (var id in _profiles.Keys)
            _present.Add(id);

        var inv = new Inventory();
        var clock = new DayClock();
        var fs = NewSystem(inv, clock);

        inv.AddItem("wood", 20);

        Check("(A) loved gift = +80 (item id beats hated category)",
            fs.GiveGift("c_loved", "wood") && fs.PointsOf("c_loved") == 80);
        Check("(A) gift consumed the item (20 → 19)", inv.Count("wood") == 19);
        Check("(A) liked-category gift = +45", fs.GiveGift("c_liked", "wood") && fs.PointsOf("c_liked") == 45);
        Check("(A) neutral (unlisted) gift = +20", fs.GiveGift("c_neutral", "wood") && fs.PointsOf("c_neutral") == 20);

        fs.AddFriendship("c_disliked", 100, "seed");
        Check("(A) disliked gift = −20 (100 → 80)",
            fs.GiveGift("c_disliked", "wood") && fs.PointsOf("c_disliked") == 80);

        fs.AddFriendship("c_hated", 30, "seed");
        Check("(A) hated gift floors at 0 (30 − 40 → 0, never negative)",
            fs.GiveGift("c_hated", "wood") && fs.PointsOf("c_hated") == 0);

        // Hearts math: 250/heart, capped at 10 / 2,500.
        Check("(A) 249 points = 0 hearts", HeartsAt(249) == 0);
        Check("(A) 250 points = 1 heart", HeartsAt(250) == 1);
        Check("(A) 2,499 points = 9 hearts", HeartsAt(2499) == 9);
        Check("(A) points cap at 2,500 = 10 hearts", HeartsAt(999_999) == 10);
    }

    /// <summary>Hearts a fresh character shows after a single quest award of <paramref name="points"/>.</summary>
    private int HeartsAt(int points)
    {
        var fs = NewSystem(new Inventory(), new DayClock());
        _profiles["c_math"] = new FriendshipProfile { CharacterId = "c_math" };
        _present.Add("c_math");
        fs.AddFriendship("c_math", points, "math");
        Check($"(A) points clamp ({points} in)", fs.PointsOf("c_math") == Math.Min(points, FriendshipSystem.MaxPoints));
        return fs.HeartsOf("c_math");
    }

    // ─────────────────────────── (B) Weekly gift cadence ───────────────────────────

    private void RunWeeklyCadence()
    {
        GD.Print("-------------------- (B) Weekly gift cadence (2/char/week) --------------------");

        _profiles["c_cad"] = new FriendshipProfile { CharacterId = "c_cad", LovedItems = new[] { "wood" } };
        _present.Add("c_cad");

        var inv = new Inventory();
        var clock = new DayClock(); // Spring 1, Year 1 → day ordinal 1, week 0
        var fs = NewSystem(inv, clock);
        inv.AddItem("wood", 10);

        Check("(B) 1st gift of the week accepted", fs.GiveGift("c_cad", "wood"));
        Check("(B) 2nd gift of the week accepted", fs.GiveGift("c_cad", "wood") && fs.GiftsGivenThisWeek("c_cad") == 2);

        int before = fs.PointsOf("c_cad");
        Check("(B) 3rd gift the same week REJECTED (no points, nothing consumed)",
            !fs.GiveGift("c_cad", "wood") && fs.PointsOf("c_cad") == before && inv.Count("wood") == 8);

        // Day 7 is still week 0 (weeks run 7 days from day 1); day 8 starts week 1.
        clock.RestoreState(DayClock.DayStartMinute, day: 7, Season.Spring, year: 1);
        Check("(B) day 7 is still the same week — gift still rejected", !fs.GiveGift("c_cad", "wood"));

        clock.RestoreState(DayClock.DayStartMinute, day: 8, Season.Spring, year: 1);
        Check("(B) week rollover (day 8) resets the cadence — gift accepted",
            fs.GiftsGivenThisWeek("c_cad") == 0 && fs.GiveGift("c_cad", "wood"));
    }

    // ─────────────────────────── (C) Birthday multiplier ───────────────────────────

    private void RunBirthday()
    {
        GD.Print("-------------------- (C) Birthday multiplier (×8) --------------------");

        _profiles["c_bday"] = new FriendshipProfile
        {
            CharacterId = "c_bday",
            LovedItems = new[] { "wood" },
            BirthdaySeason = Season.Summer,
            BirthdayDay = 5,
        };
        _present.Add("c_bday");

        var inv = new Inventory();
        var clock = new DayClock();
        var fs = NewSystem(inv, clock);
        inv.AddItem("wood", 10);

        Check("(C) non-birthday loved gift = +80", fs.GiveGift("c_bday", "wood") && fs.PointsOf("c_bday") == 80);

        clock.RestoreState(DayClock.DayStartMinute, day: 5, Season.Summer, year: 1);
        Check("(C) birthday loved gift = +640 (80 × 8)",
            fs.GiveGift("c_bday", "wood") && fs.PointsOf("c_bday") == 80 + 640);
    }

    // ─────────────────────────── (D) Talk once per day ───────────────────────────

    private void RunTalk()
    {
        GD.Print("-------------------- (D) Talk: +12 once/character/day --------------------");

        _profiles["c_talk"] = new FriendshipProfile { CharacterId = "c_talk" };
        _present.Add("c_talk");

        var clock = new DayClock();
        var fs = NewSystem(new Inventory(), clock);

        Check("(D) first talk of the day = +12", fs.Talk("c_talk") && fs.PointsOf("c_talk") == 12);
        Check("(D) second talk the same day is a no-op",
            !fs.Talk("c_talk") && fs.PointsOf("c_talk") == 12 && fs.TalkedToday("c_talk"));

        clock.RestoreState(DayClock.DayStartMinute, day: 2, Season.Spring, year: 1);
        fs.OnDayStarted();
        Check("(D) next day resets — talk grants +12 again",
            !fs.TalkedToday("c_talk") && fs.Talk("c_talk") && fs.PointsOf("c_talk") == 24);
    }

    // ─────────────────────────── (E) Rejections ───────────────────────────

    private void RunRejections()
    {
        GD.Print("-------------------- (E) Rejections (player / absent / bad item) --------------------");

        // The SHIPPED registry: player not befriendable, tharr is, unknowns default befriendable.
        Check("(E) shipped Friendships: player NOT befriendable", !Friendships.Get("player").Befriendable);
        Check("(E) shipped Friendships: tharr befriendable", Friendships.Get("tharr").Befriendable);
        Check("(E) unknown character defaults befriendable (townsfolk rule)",
            Friendships.Get("someone_new").Befriendable);

        _profiles["player"] = Friendships.Get("player"); // route the real player profile through the stub
        _profiles["c_absent"] = new FriendshipProfile { CharacterId = "c_absent" };
        _present.Add("player"); // present but not befriendable
        // c_absent deliberately NOT present (un-arrived villager).

        var inv = new Inventory();
        var fs = NewSystem(inv, new DayClock());
        inv.AddItem("wood", 5);

        Check("(E) gift to the PLAYER rejected (not befriendable)", !fs.GiveGift("player", "wood"));
        Check("(E) talk to the PLAYER rejected", !fs.Talk("player"));
        Check("(E) award to the PLAYER rejected", !fs.AddFriendship("player", 100, "test"));
        Check("(E) gift to an UN-ARRIVED character rejected", !fs.GiveGift("c_absent", "wood"));
        Check("(E) talk to an un-arrived character rejected", !fs.Talk("c_absent"));
        Check("(E) unknown item id rejected (present character)", !fs.GiveGift("c_talk", "no_such_item"));
        Check("(E) uncarried item rejected (present character)", !fs.GiveGift("c_talk", "stone"));
        Check("(E) nothing consumed by the rejections", inv.Count("wood") == 5);
    }

    // ─────────────────────────── (F) Thresholds + unlock seams ───────────────────────────

    private void RunThresholdSeams()
    {
        GD.Print("-------------------- (F) Heart thresholds + perk/unlock seams --------------------");

        _profiles["c_perk"] = new FriendshipProfile
        {
            CharacterId = "c_perk",
            Unlocks = new HeartUnlock[]
            {
                new()
                {
                    Heart = 1, EventId = "perk_h1",
                    Effect = new BuildingEffect { Type = BuildingEffectType.StorePriceDiscount, Magnitude = 25 },
                },
                new() { Heart = 2, UnlockCategoryId = "spike_bond_recipes" },
                new()
                {
                    Heart = 3,
                    Effect = new BuildingEffect { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 2 },
                },
            },
        };
        _present.Add("c_perk");

        var inv = new Inventory();
        var fs = NewSystem(inv, new DayClock());

        // A synthetic BUILDING source beside the friendship source — the additive proof.
        var buildingEffects = new List<BuildingEffect>();
        var effects = new OutpostEffects(() => buildingEffects);
        fs.HeartThresholdReached += (_, _) => effects.Recompute();
        effects.AddSource(fs.ActiveEffects);

        var fired = new List<(string Id, int Heart)>();
        fs.HeartThresholdReached += (id, heart) => fired.Add((id, heart));

        Check("(F) baseline: no discount, nothing unlocked, healing 0",
            effects.StorePriceDiscountPercent == 0
            && !effects.IsCategoryUnlocked("spike_bond_recipes")
            && effects.InfirmaryHealingBonus == 0);

        fs.AddFriendship("c_perk", 249, "quest");
        Check("(F) below the rung: nothing fires", fired.Count == 0);

        fs.AddFriendship("c_perk", 1, "quest"); // 250 → heart 1
        Check("(F) heart 1 fires once", fired.Count == 1 && fired[0] == ("c_perk", 1));
        Check("(F) heart-1 perk landed: StorePriceDiscount 25 in OutpostEffects",
            effects.StorePriceDiscountPercent == 25);

        // The discount reaches Trading Post pricing (turnip_seed: 6g → 4g at 25%).
        var wallet = new Wallet();
        wallet.EarnGold(4);
        var store = new StoreSystem(inv, wallet, _ => { }, () => SmithyTier.Base,
            () => effects.StorePriceDiscountPercent);
        var offer = store.BuildView().Offers.FirstOrDefault(o => o.ItemId == "turnip_seed");
        Check("(F) Trading Post offer shows the discounted price (6g → 4g)", offer != null && offer.Price == 4);
        Check("(F) Buy charges the discounted price (4 gold buys it exactly)",
            store.Buy("turnip_seed") && wallet.Gold == 0);

        // A points DIP below the rung never revokes and never re-fires on the climb back.
        fs.AddFriendship("c_perk", -100, "setback"); // 250 → 150 (below heart 1)
        Check("(F) points dip keeps the perk (fired set drives effects)",
            fs.HeartsOf("c_perk") == 0 && effects.StorePriceDiscountPercent == 25);
        fs.AddFriendship("c_perk", 100, "quest"); // back to 250
        Check("(F) climb back over the rung does NOT re-fire", fired.Count == 1);

        // A multi-heart jump fires each crossed rung once, in order; unlock seams land per rung.
        fs.AddFriendship("c_perk", 500, "quest"); // 250 → 750 → hearts 3: fires 2 then 3
        Check("(F) jump fires hearts 2 and 3 once each, in order",
            fired.Count == 3 && fired[1] == ("c_perk", 2) && fired[2] == ("c_perk", 3));
        Check("(F) heart-2 category unlock: IsCategoryUnlocked(\"spike_bond_recipes\")",
            effects.IsCategoryUnlocked("spike_bond_recipes"));
        Check("(F) heart-3 perk: InfirmaryHealing 2 from friendship alone", effects.InfirmaryHealingBonus == 2);

        // Additive with a building source: infirmary tier adds on top of the friendship perk.
        buildingEffects.Add(new BuildingEffect { Type = BuildingEffectType.InfirmaryHealing, Magnitude = 1 });
        effects.Recompute();
        Check("(F) friendship + building InfirmaryHealing sum ADDITIVELY (2 + 1 = 3)",
            effects.InfirmaryHealingBonus == 3);
    }

    // ─────────────────────────── (G) Building-restore award ───────────────────────────

    private void RunBuildingAwards()
    {
        GD.Print("-------------------- (G) Building-restore friendship award --------------------");

        _profiles["c_builder"] = new FriendshipProfile { CharacterId = "c_builder" };
        _profiles["c_other"] = new FriendshipProfile { CharacterId = "c_other" };
        _present.Add("c_builder");
        _present.Add("c_other");

        var cast = new List<CharacterProfile>
        {
            new()
            {
                Id = "c_builder", DefaultName = "Builder", ClassName = "Fighter", AncestryName = "Human",
                Kind = CharacterKind.Townsfolk, AssociatedBuildingId = "smithy",
            },
            new()
            {
                Id = "c_other", DefaultName = "Other", ClassName = "Rogue", AncestryName = "Elf",
                Kind = CharacterKind.Townsfolk, AssociatedBuildingId = "infirmary",
            },
        };

        var fs = NewSystem(new Inventory(), new DayClock());

        FriendshipAwards.OnBuildingAdvanced("smithy", isCommission: true, cast, fs);
        Check("(G) commission awards +240 to the ASSOCIATED character",
            fs.PointsOf("c_builder") == FriendshipAwards.CommissionAward);
        Check("(G) unrelated character gets nothing", fs.PointsOf("c_other") == 0);

        FriendshipAwards.OnBuildingAdvanced("smithy", isCommission: false, cast, fs);
        Check("(G) upgrade awards +120 more to the same character",
            fs.PointsOf("c_builder") == FriendshipAwards.CommissionAward + FriendshipAwards.UpgradeAward);
    }

    // ─────────────────────────── (H) Save / restore round-trip ───────────────────────────

    private void RunSaveRoundTrip()
    {
        GD.Print("-------------------- (H) Save/restore round-trip --------------------");

        _profiles["c_save"] = new FriendshipProfile { CharacterId = "c_save", LovedItems = new[] { "wood" } };
        _present.Add("c_save");

        var inv = new Inventory();
        var clock = new DayClock();
        var fs = NewSystem(inv, clock);
        inv.AddItem("wood", 5);

        fs.AddFriendship("c_save", 600, "quest"); // hearts 2 → fired 1, 2
        fs.GiveGift("c_save", "wood");            // +80, cadence 1
        fs.Talk("c_save");                        // +12, talked today
        int points = fs.PointsOf("c_save");

        var dto = fs.Capture();
        var fs2 = NewSystem(new Inventory(), clock);
        var refired = new List<int>();
        fs2.HeartThresholdReached += (_, h) => refired.Add(h);
        fs2.Restore(dto);

        Check("(H) points round-trip", fs2.PointsOf("c_save") == points && points == 692);
        Check("(H) same-day talked flag round-trips", fs2.TalkedToday("c_save"));
        Check("(H) same-week gift counter round-trips", fs2.GiftsGivenThisWeek("c_save") == 1);
        Check("(H) fired thresholds round-trip (highest = 2)", fs2.HighestFiredHeart("c_save") == 2);
        Check("(H) restore fires NO threshold events", refired.Count == 0);
        Check("(H) EXACT serialized round-trip",
            JsonSerializer.Serialize(dto) == JsonSerializer.Serialize(fs2.Capture()));

        // A restore against a LATER week/day clears the windowed counters but keeps points/fired.
        var laterClock = new DayClock();
        laterClock.RestoreState(DayClock.DayStartMinute, day: 9, Season.Spring, year: 1);
        var fs3 = NewSystem(new Inventory(), laterClock);
        fs3.Restore(dto);
        Check("(H) later-week restore clears cadence + talked, keeps points/fired",
            fs3.GiftsGivenThisWeek("c_save") == 0 && !fs3.TalkedToday("c_save")
            && fs3.PointsOf("c_save") == points && fs3.HighestFiredHeart("c_save") == 2);

        // Version tolerance: a pre-v8 save (no friendship section) restores to zero friendship.
        fs3.Restore(null);
        Check("(H) null DTO (pre-v8 save) restores to zero friendship",
            fs3.PointsOf("c_save") == 0 && fs3.HighestFiredHeart("c_save") == 0
            && fs3.GiftsGivenThisWeek("c_save") == 0);
    }

    // ─────────────────────────── (I) GameState end-to-end ───────────────────────────

    private void RunGameStateEndToEnd()
    {
        GD.Print("-------------------- (I) GameState end-to-end (shipped content: tharr) --------------------");

        ClearSlot0();
        var gs = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs);

        gs.AddItem("stone", 5); // tharr LIKES stone (+45); starter seed already granted 10 more

        Check("(I) GiveGift to the PLAYER rejected (not befriendable)", !gs.GiveGift("player", "stone"));
        Check("(I) TalkTo the player rejected", !gs.TalkTo("player"));
        Check("(I) gift to an unknown/absent character rejected", !gs.GiveGift("nobody_here", "stone"));

        Check("(I) TalkTo(tharr) works (starting PC = present)", gs.TalkTo("tharr"));
        Check("(I) repeat talk the same day is a no-op", !gs.TalkTo("tharr"));

        int stoneBefore = gs.Inventory.Count("stone");
        var changed = new List<string>();
        gs.FriendshipChanged += changed.Add;
        Check("(I) GiveGift(tharr, stone) accepted", gs.GiveGift("tharr", "stone"));
        Check("(I) the gift consumed one stone", gs.Inventory.Count("stone") == stoneBefore - 1);
        Check("(I) FriendshipChanged fired for tharr", changed.Contains("tharr"));

        var view = gs.GetFriendshipView();
        var tharr = view.Characters.Find(c => c.CharacterId == "tharr");
        Check("(I) view lists tharr (talked, 1 gift, 57 pts = 12 + 45)",
            tharr != null && tharr.Points == 57 && tharr.TalkedToday && tharr.GiftsGivenThisWeek == 1
            && tharr.Hearts == 0 && tharr.MaxHearts == 10);
        Check("(I) view does NOT list the player", view.Characters.Find(c => c.CharacterId == "player") == null);
        Check("(I) view carries gift options from the carried stacks",
            view.GiftableItems.Exists(g => g.ItemId == "stone"));

        // Full save/load round-trip through the real save file.
        gs.SaveGame();
        var gs2 = new GameState { RealSecondsPerGameMinute = 0 };
        AddChild(gs2);
        var tharr2 = gs2.GetFriendshipView().Characters.Find(c => c.CharacterId == "tharr");
        Check("(I) reload restores tharr's points/counters (57 pts, talked, 1 gift)",
            tharr2 != null && tharr2.Points == 57 && tharr2.TalkedToday && tharr2.GiftsGivenThisWeek == 1);
        Check("(I) baseline store price untouched at 0 hearts (turnip_seed 6g)",
            gs2.GetTradingPostView().Offers.FirstOrDefault(o => o.ItemId == "turnip_seed")?.Price == 6);
    }

    // ─────────────────────────── (J) Friendship panel UI smoke ───────────────────────────

    private async Task RunPanelSmoke()
    {
        GD.Print("-------------------- (J) friendship_panel UI smoke --------------------");

        Check("(J) input map defines toggle_friendship_panel", InputMap.HasAction("toggle_friendship_panel"));

        var packed = GD.Load<PackedScene>("res://scenes/ui/friendship_panel.tscn");
        if (packed == null)
        {
            Check("(J) friendship_panel.tscn loads", false);
            return;
        }
        var panel = packed.Instantiate<FriendshipPanel>();
        AddChild(panel);
        await Frames(2);
        Check("(J) friendship_panel instantiates and enters the tree", true);
        Check("(J) %Body resolves", panel.GetNodeOrNull("%Body") != null);

        var view = new FriendshipView();
        view.Characters.Add(new FriendshipCharacterView
        {
            CharacterId = "tharr", DisplayName = "Tharr", Points = 730, Hearts = 2, MaxHearts = 10,
            GiftsGivenThisWeek = 1, GiftsPerWeek = 2, TalkedToday = true, IsBirthdayToday = true,
        });
        view.Characters.Add(new FriendshipCharacterView
        {
            CharacterId = "elara", DisplayName = "Elara", Points = 0, Hearts = 0, MaxHearts = 10,
            GiftsPerWeek = 2, Romanceable = true,
        });
        view.GiftableItems.Add(new GiftOptionView { ItemId = "stone", DisplayName = "Stone", Count = 4 });

        panel.Visible = true;
        panel.Render(view, nearbyCharacterId: "tharr");
        await Frames(2);

        Check("(J) renders the character name", HasLabelContaining(panel, "Tharr"));
        Check("(J) renders 2/10 heart pips", HasLabelContaining(panel, "♥♥♡♡♡♡♡♡♡♡"));
        Check("(J) renders the birthday marker", HasLabelContaining(panel, "Birthday today!"));
        Check("(J) renders talked/gift indicators", HasLabelContaining(panel, "Gifts this week: 1/2")
            && HasLabelContaining(panel, "Talked today"));
        Check("(J) renders the romanceable tag on Elara's row", HasLabelContaining(panel, "Romanceable"));
        Check("(J) nearby character gets the gift flow", HasLabelContaining(panel, "Give Tharr a gift:"));

        int gifts = 0;
        string? giftChar = null, giftItem = null;
        panel.GiftRequested += (cid, iid) => { gifts++; giftChar = cid; giftItem = iid; };
        FindButton(panel, "Give")?.EmitSignal(BaseButton.SignalName.Pressed);
        Check("(J) Give raises GiftRequested(tharr, stone)", gifts == 1 && giftChar == "tharr" && giftItem == "stone");

        panel.Render(view, nearbyCharacterId: null);
        await Frames(1);
        Check("(J) no nearby villager → gift hint instead of Give buttons",
            FindButton(panel, "Give") == null && HasLabelContaining(panel, "Stand beside a villager"));

        bool lastOpen = true;
        panel.Toggled += open => lastOpen = open;
        panel.Close();
        Check("(J) Close hides and raises Toggled(false)", !panel.Visible && lastOpen == false);

        panel.QueueFree();
        await Frames(1);
    }

    // ─────────────────────────── helpers ───────────────────────────

    private static Button? FindButton(Node root, string text)
    {
        if (root is Button b && b.Text == text)
            return b;
        foreach (Node c in root.GetChildren())
            if (FindButton(c, text) is { } found)
                return found;
        return null;
    }

    private static bool HasLabelContaining(Node root, string substr)
    {
        if (root is Label l && l.Text.Contains(substr))
            return true;
        foreach (Node c in root.GetChildren())
            if (HasLabelContaining(c, substr))
                return true;
        return false;
    }

    private async Task Frames(int count)
    {
        for (int i = 0; i < count; i++)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
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
        GD.Print("[FriendshipSpike] slot0.json backed up and cleared for the test run.");
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
            GD.Print("[FriendshipSpike] slot0.json restored.");
        }
        else if (!_slot0Existed && Godot.FileAccess.FileExists(SavePath))
        {
            DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(SavePath));
            GD.Print("[FriendshipSpike] test slot0.json removed (no prior save existed).");
        }
    }
}
