using System;
using System.Collections.Generic;
using Bulwark.Data;
using Bulwark.Data.Characters;

namespace Bulwark.Cozy;

/// <summary>
/// The Stardew-style FRIENDSHIP / HEART system (design/friendship.md — decisions locked). Plain C#
/// and unit-testable: per-character POINTS are the storage unit, HEARTS the display unit
/// (<see cref="PointsPerHeart"/> points per heart, capped at <see cref="MaxHearts"/>). NO DECAY —
/// friendship only ever grows; negative gift reactions can dent points but the total floors at 0
/// and once-fired heart thresholds stay earned forever.
///
/// Earning: <see cref="GiveGift"/> (per-character preference tiers, weekly cadence limit, birthday
/// multiplier; consumes the physical item from the party inventory), <see cref="Talk"/> (small bump
/// once per character per day), and <see cref="AddFriendship"/> (quest/help awards — e.g. restoring
/// a character's associated building, see <see cref="FriendshipAwards"/>).
///
/// Unlock seams: every whole heart NEWLY reached fires <see cref="HeartThresholdReached"/> exactly
/// once (tracked in the fired set, which persists). <see cref="ActiveEffects"/> derives the earned
/// heart-perk effects (domain perks + CategoryUnlock recipe/item unlocks) from the fired set for the
/// <see cref="OutpostEffects"/> aggregator — an additional effect source beside buildings. Heart-
/// EVENT ids on unlock entries are a Phase-4 hook the future dialogue system consumes; nothing here
/// plays content.
///
/// Recruitment is NOT gated by friendship, and adventuring together earns nothing (locked design).
/// The profile source and presence predicate are injectable so spikes prove the logic with
/// synthetic characters; GameState wires the shipped <see cref="Friendships"/> registry and
/// "starting PC or arrived villager" presence.
/// </summary>
public sealed class FriendshipSystem
{
    // ── Tunables (design-doc proposals; placeholder values, easy to retune) ──
    public const int PointsPerHeart = 250;
    public const int MaxHearts = 10;
    public const int MaxPoints = PointsPerHeart * MaxHearts; // 2,500

    public const int LovedPoints = 80;
    public const int LikedPoints = 45;
    public const int NeutralPoints = 20;
    public const int DislikedPoints = -20;
    public const int HatedPoints = -40;

    /// <summary>Birthday gifts multiply the tier's points (Stardew-parity ×8; TUNABLE placeholder).</summary>
    public const int BirthdayMultiplier = 8;

    /// <summary>Points for the first conversation with a character each day.</summary>
    public const int TalkPoints = 12;

    /// <summary>Gift cadence: gifts accepted per character per week (weeks run 7 days from day 1).</summary>
    public const int MaxGiftsPerWeek = 2;

    private readonly Inventory _inventory;
    private readonly DayClock _clock;
    private readonly Func<string, bool> _isPresent;
    private readonly Func<string, FriendshipProfile> _profiles;

    private readonly Dictionary<string, int> _points = new();
    private readonly Dictionary<string, int> _giftsThisWeek = new();
    private readonly HashSet<string> _talkedToday = new();
    private readonly Dictionary<string, int> _firedHearts = new(); // charId → highest heart fired
    private readonly HashSet<string> _romanced = new();            // Phase-4 romance placeholder

    private int _talkedDayOrdinal;
    private int _giftWeekIndex;

    /// <summary>Raised after a character's friendship points changed, with the character id.</summary>
    public event Action<string>? FriendshipChanged;

    /// <summary>Raised ONCE per (character, heart) the first time that heart level is reached —
    /// the hook heart events, domain perks, and recipe unlocks hang off. Never re-fires (no decay).</summary>
    public event Action<string, int>? HeartThresholdReached;

    /// <summary>Raised after a successful gift (charId, itemId, points delta) — HUD toast seam.</summary>
    public event Action<string, string, int>? GiftGiven;

    /// <param name="inventory">Party inventory gifts are consumed from.</param>
    /// <param name="clock">Calendar source (birthdays, daily/weekly counter rollovers).</param>
    /// <param name="isPresent">Whether a character is at the outpost (starting PC or arrived villager).</param>
    /// <param name="profiles">Profile source; defaults to the shipped <see cref="Friendships"/> registry.</param>
    public FriendshipSystem(Inventory inventory, DayClock clock, Func<string, bool> isPresent,
        Func<string, FriendshipProfile>? profiles = null)
    {
        _inventory = inventory ?? throw new ArgumentNullException(nameof(inventory));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
        _isPresent = isPresent ?? throw new ArgumentNullException(nameof(isPresent));
        _profiles = profiles ?? Friendships.Get;
        _talkedDayOrdinal = CurrentDayOrdinal;
        _giftWeekIndex = CurrentWeekIndex;
    }

    // ===================== Queries =====================

    /// <summary>Friendship points for a character (0 when never met).</summary>
    public int PointsOf(string charId) => _points.TryGetValue(charId, out var p) ? p : 0;

    /// <summary>Whole hearts for a character (points / 250, capped at 10).</summary>
    public int HeartsOf(string charId) => Math.Min(PointsOf(charId) / PointsPerHeart, MaxHearts);

    /// <summary>Gifts accepted for a character in the current week.</summary>
    public int GiftsGivenThisWeek(string charId)
    {
        SyncCalendar();
        return _giftsThisWeek.TryGetValue(charId, out var n) ? n : 0;
    }

    /// <summary>Whether the daily talk bump has already been earned for a character today.</summary>
    public bool TalkedToday(string charId)
    {
        SyncCalendar();
        return _talkedToday.Contains(charId);
    }

    /// <summary>Highest heart threshold that has fired for a character (0 = none yet).</summary>
    public int HighestFiredHeart(string charId) => _firedHearts.TryGetValue(charId, out var h) ? h : 0;

    // ===================== Commands =====================

    /// <summary>
    /// Give one unit of a carried item to a present character. Validates the character is
    /// befriendable and present, the item is defined and carried, and the weekly gift cadence
    /// (<see cref="MaxGiftsPerWeek"/>) is not exhausted — a rejected gift consumes NOTHING. On
    /// success consumes the item, applies the profile's preference-tier points (birthday gifts
    /// multiply by <see cref="BirthdayMultiplier"/>; the total floors at 0 on a bad gift), counts
    /// the cadence, and raises <see cref="GiftGiven"/> + <see cref="FriendshipChanged"/> (plus any
    /// newly crossed <see cref="HeartThresholdReached"/>).
    /// </summary>
    public bool GiveGift(string charId, string itemId)
    {
        SyncCalendar();
        var profile = _profiles(charId);
        if (profile == null || !profile.Befriendable || !_isPresent(charId))
            return false;
        if (!Items.IsDefined(itemId) || !_inventory.Has(itemId))
            return false;
        if ((_giftsThisWeek.TryGetValue(charId, out var given) ? given : 0) >= MaxGiftsPerWeek)
            return false;
        if (!_inventory.RemoveItem(itemId, 1))
            return false;

        _giftsThisWeek[charId] = given + 1;

        int delta = PointsFor(profile.TierOf(itemId));
        if (profile.IsBirthday(_clock.Season, _clock.Day))
            delta *= BirthdayMultiplier;

        ApplyDelta(charId, delta);
        GiftGiven?.Invoke(charId, itemId, delta);
        return true;
    }

    /// <summary>
    /// First conversation of the day with a present, befriendable character grants
    /// <see cref="TalkPoints"/>; repeats the same day are a no-op (false). Resets on day rollover.
    /// </summary>
    public bool Talk(string charId)
    {
        SyncCalendar();
        var profile = _profiles(charId);
        if (profile == null || !profile.Befriendable || !_isPresent(charId))
            return false;
        if (!_talkedToday.Add(charId))
            return false;

        ApplyDelta(charId, TalkPoints);
        return true;
    }

    /// <summary>
    /// Quest/help award seam: grant (or, for authored setbacks, dent — floored at 0) friendship
    /// points outside the gift/talk economy. Requires only that the character is befriendable —
    /// awards may land for a character who has not arrived yet (e.g. restoring their building
    /// before they show up). <paramref name="reason"/> is a debug/telemetry tag, not game state.
    /// </summary>
    public bool AddFriendship(string charId, int points, string reason)
    {
        var profile = _profiles(charId);
        if (profile == null || !profile.Befriendable || points == 0)
            return false;
        ApplyDelta(charId, points);
        return true;
    }

    /// <summary>Called by GameState on day start — rolls the daily (and, on a 7-day boundary,
    /// weekly) counters. Counters also self-reconcile lazily, so a restored clock stays correct.</summary>
    public void OnDayStarted() => SyncCalendar();

    // ===================== Unlock seams =====================

    /// <summary>
    /// The friendship EFFECT SOURCE for <see cref="OutpostEffects"/>: every earned heart-unlock's
    /// domain-perk effect, plus a CategoryUnlock effect per earned recipe/item unlock id. Derived
    /// from the FIRED set (not current hearts), so a points dent never revokes an earned perk.
    /// Empty until a threshold with a perk/unlock entry fires — the shipped baseline.
    /// </summary>
    public IEnumerable<BuildingEffect> ActiveEffects()
    {
        foreach (var (charId, fired) in _firedHearts)
        {
            var profile = _profiles(charId);
            if (profile == null)
                continue;
            foreach (var unlock in profile.Unlocks)
            {
                if (unlock.Heart > fired)
                    continue;
                if (unlock.Effect != null)
                    yield return unlock.Effect;
                if (!string.IsNullOrEmpty(unlock.UnlockCategoryId))
                    yield return new BuildingEffect
                    {
                        Type = BuildingEffectType.CategoryUnlock,
                        Detail = unlock.UnlockCategoryId,
                    };
            }
        }
    }

    // ===================== View-model =====================

    /// <summary>
    /// Build the passive friendship-panel view over the given character candidates (GameState feeds
    /// the shipped cast): one row per befriendable, PRESENT character, plus the carried gift options.
    /// </summary>
    public FriendshipView BuildView(IEnumerable<(string Id, string Name)> candidates)
    {
        SyncCalendar();
        var view = new FriendshipView();

        foreach (var (id, name) in candidates)
        {
            var profile = _profiles(id);
            if (profile == null || !profile.Befriendable || !_isPresent(id))
                continue;

            view.Characters.Add(new FriendshipCharacterView
            {
                CharacterId = id,
                DisplayName = name,
                Points = PointsOf(id),
                Hearts = HeartsOf(id),
                MaxHearts = MaxHearts,
                GiftsGivenThisWeek = _giftsThisWeek.TryGetValue(id, out var g) ? g : 0,
                GiftsPerWeek = MaxGiftsPerWeek,
                TalkedToday = _talkedToday.Contains(id),
                IsBirthdayToday = profile.IsBirthday(_clock.Season, _clock.Day),
                Romanceable = profile.Romanceable,
            });
        }
        view.Characters.Sort((a, b) => string.CompareOrdinal(a.DisplayName, b.DisplayName));

        foreach (var (itemId, qty) in _inventory.Stacks)
        {
            if (qty <= 0 || !Items.TryGet(itemId, out var def))
                continue;
            view.GiftableItems.Add(new GiftOptionView { ItemId = itemId, DisplayName = def.DisplayName, Count = qty });
        }
        view.GiftableItems.Sort((a, b) => string.CompareOrdinal(a.DisplayName, b.DisplayName));

        return view;
    }

    // ===================== Save / restore =====================

    /// <summary>Snapshot all friendship state for the save file.</summary>
    public FriendshipDto Capture() => new()
    {
        Points = new Dictionary<string, int>(_points),
        GiftsThisWeek = new Dictionary<string, int>(_giftsThisWeek),
        GiftWeekIndex = _giftWeekIndex,
        TalkedToday = new List<string>(_talkedToday),
        TalkedDayOrdinal = _talkedDayOrdinal,
        FiredHearts = new Dictionary<string, int>(_firedHearts),
        Romanced = new List<string>(_romanced),
    };

    /// <summary>
    /// Overwrite all friendship state from a save. Version-tolerant: null (a pre-v8 save) clears to
    /// zero friendship. SILENT — no change or threshold events fire (fired thresholds restore as
    /// already-fired, so nothing re-triggers); the caller recomputes the effect aggregator after.
    /// Counters reconcile against the (already restored) clock, so a stale day/week resets cleanly.
    /// </summary>
    public void Restore(FriendshipDto? dto)
    {
        _points.Clear();
        _giftsThisWeek.Clear();
        _talkedToday.Clear();
        _firedHearts.Clear();
        _romanced.Clear();
        _talkedDayOrdinal = CurrentDayOrdinal;
        _giftWeekIndex = CurrentWeekIndex;
        if (dto == null)
            return;

        if (dto.Points != null)
            foreach (var (id, pts) in dto.Points)
                if (!string.IsNullOrEmpty(id) && pts > 0)
                    _points[id] = Math.Clamp(pts, 0, MaxPoints);

        if (dto.FiredHearts != null)
            foreach (var (id, heart) in dto.FiredHearts)
                if (!string.IsNullOrEmpty(id) && heart > 0)
                    _firedHearts[id] = Math.Min(heart, MaxHearts);

        if (dto.Romanced != null)
            foreach (var id in dto.Romanced)
                if (!string.IsNullOrEmpty(id))
                    _romanced.Add(id);

        // Daily/weekly counters restore only while still within their saved day/week window.
        if (dto.TalkedDayOrdinal == _talkedDayOrdinal && dto.TalkedToday != null)
            foreach (var id in dto.TalkedToday)
                if (!string.IsNullOrEmpty(id))
                    _talkedToday.Add(id);

        if (dto.GiftWeekIndex == _giftWeekIndex && dto.GiftsThisWeek != null)
            foreach (var (id, n) in dto.GiftsThisWeek)
                if (!string.IsNullOrEmpty(id) && n > 0)
                    _giftsThisWeek[id] = n;
    }

    // ===================== Internals =====================

    private int CurrentDayOrdinal => ArrivalTrigger.Ordinal(_clock.Year, _clock.Season, _clock.Day);

    /// <summary>Weeks run every 7 days from day 1 (ordinal 1..7 = week 0, 8..14 = week 1, ...).</summary>
    private int CurrentWeekIndex => (CurrentDayOrdinal - 1) / 7;

    private static int PointsFor(GiftTier tier) => tier switch
    {
        GiftTier.Loved => LovedPoints,
        GiftTier.Liked => LikedPoints,
        GiftTier.Disliked => DislikedPoints,
        GiftTier.Hated => HatedPoints,
        _ => NeutralPoints,
    };

    /// <summary>Reconcile the daily/weekly counters with the calendar (lazy + on DayStarted).</summary>
    private void SyncCalendar()
    {
        int ordinal = CurrentDayOrdinal;
        if (ordinal != _talkedDayOrdinal)
        {
            _talkedToday.Clear();
            _talkedDayOrdinal = ordinal;
        }
        int week = CurrentWeekIndex;
        if (week != _giftWeekIndex)
        {
            _giftsThisWeek.Clear();
            _giftWeekIndex = week;
        }
    }

    /// <summary>Apply a points delta (floored at 0, capped at max), announce the change, and fire
    /// any newly crossed heart thresholds exactly once each (in ascending order).</summary>
    private void ApplyDelta(string charId, int delta)
    {
        int before = PointsOf(charId);
        int after = Math.Clamp(before + delta, 0, MaxPoints);
        _points[charId] = after;
        FriendshipChanged?.Invoke(charId);

        int hearts = HeartsOf(charId);
        int fired = HighestFiredHeart(charId);
        while (fired < hearts)
        {
            fired++;
            _firedHearts[charId] = fired;
            HeartThresholdReached?.Invoke(charId, fired);
        }
    }
}
