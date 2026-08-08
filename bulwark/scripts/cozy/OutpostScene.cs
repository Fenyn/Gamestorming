using System;
using System.Collections.Generic;
using System.Text;
using Bulwark.Autoload;
using Bulwark.Data;
using Bulwark.Data.Dialogues;
using Bulwark.Territory;
using Godot;
using CharacterRegistry = Bulwark.Data.Characters.Characters;

namespace Bulwark.Cozy;

/// <summary>
/// Thin Node3D adapter for the outpost world scene (<c>scenes/outpost/outpost.tscn</c>). Holds no
/// game logic: it only exposes typed accessors so the avatar / farming systems can query the
/// greybox — the ground body, spawn/farm markers, pre-placed building instances, and the territory
/// gate trigger. The user authors the actual 3D blockout in the editor (every building, prop and
/// bedroll is its own scene instanced here, swappable one at a time); this script never mutates
/// world state. Player/HUD/squad-panel hosting is inherited from <see cref="CozyWorldScene"/>.
///
/// NODE CONTRACT (all optional — every lookup is null-safe so the scene still runs standalone):
///  • <c>%Ground</c> — StaticBody3D floor (physics layer 1 "Terrain") + the perimeter wall colliders.
///  • <c>%PlayerSpawn</c> / <c>%FarmArea</c> / <c>%Villager_&lt;id&gt;</c> / <c>%Spot_*</c> — Marker3D.
///  • <c>%GateTrigger</c> / <c>%Bedroll</c> — Area3D.
///  • building instances — <c>scenes/buildings/&lt;id&gt;.tscn</c> placed directly as children and
///    adopted by <see cref="BuildingLoader"/> through their SceneFilePath (never by node name).
///
/// GRID: one cell is ONE METRE. Cell (x, y) covers world X ∈ [x, x+1), Z ∈ [y, y+1).
/// </summary>
public partial class OutpostScene : CozyWorldScene
{
    /// <summary>The territory the gate leads to (M3: the single Tier-1 forest).</summary>
    [Export] public string GateTerritoryId { get; set; } = "verdant_fringe";

    /// <summary>Size (in CELLS) of the base, always-unlocked farm plot centred on <c>%FarmArea</c>.
    /// This rectangle is farm zone 0 — the soil the player can work from day one.</summary>
    [Export] public Vector2I FarmSizeCells { get; set; } = new(8, 8);

    /// <summary>Cells of extra farmland each higher farm ZONE adds around the base rectangle
    /// (design/Refinement 2: farm upgrades expand the tillable AREA, they don't grant plot count).</summary>
    [Export] public int FarmZoneRingCells { get; set; } = 2;

    /// <summary>Highest authored farm zone — soil beyond this ring is not farmland at all.</summary>
    [Export] public int FarmMaxZone { get; set; } = 2;

    /// <summary>Proximity radius (m) for the villager TALK/gift interactions (~1.5 cells).</summary>
    private const float VillagerTalkRadius = 1.5f;

    private StaticBody3D? _ground;
    private Marker3D? _playerSpawn;
    private Marker3D? _farmArea;
    private Area3D? _gateTrigger;
    private Area3D? _bedroll;

    // Farm renderer instanced by this scene (pooled per-cell greybox soil/crop meshes).
    private FarmRenderer? _farmRenderer;

    // Phase-2 build loop: adopts the pre-placed building instances (or instances them at their
    // %Building_<id> markers) and refreshes their staged visual on BuildingChanged.
    private BuildingLoader? _buildingLoader;

    // Phase-3 static cast: spawns an NPC node for each PRESENT villager at its %Villager_<id> marker
    // and refreshes on VillagerArrived.
    private VillagerLoader? _villagerLoader;
    private TransitionSign? _gateSign;
    private bool _playerAtGate;  // player currently inside the gate trigger (interact travels)

    // Level-ups announced by the sleep command, held until the wake toast consumes them.
    private IReadOnlyList<SquadLevelUpView>? _pendingLevelUps;

    public override void _Ready()
    {
        _ground = GetNodeOrNull<StaticBody3D>("%Ground");
        _playerSpawn = GetNodeOrNull<Marker3D>("%PlayerSpawn");
        _farmArea = GetNodeOrNull<Marker3D>("%FarmArea");
        _gateTrigger = GetNodeOrNull<Area3D>("%GateTrigger");
        _bedroll = GetNodeOrNull<Area3D>("%Bedroll");

        SpawnFarmRenderer();
        SpawnPlayer();
        SpawnHud();
        SpawnSquadPanel();
        SpawnBuildPanel();
        SpawnInventoryPanel();
        SpawnSmithyPanel();
        SpawnCraftingPanel();
        SpawnTradingPostPanel();
        SpawnFriendshipPanel();
        SpawnQuestPanel();
        SpawnCalendarPanel();
        SpawnDialogueBox();
        SpawnDaySummaryPanel();
        SpawnPauseMenu();
        SpawnPartySelectPanel();
        SpawnGateSign();
        WireGate();
        SpawnBuildings();
        SpawnVillagers();
        WireStateEvents();
        if (PartySelectPanel != null)
            PartySelectPanel.TravelConfirmed += OnGatePartyConfirmed;
        RefreshHudAll();
        ShowArrivalToasts();
        TryPlayIntroScene2();
        // Arrival-triggered story cutscenes (design/tutorial_quests.md): Arkus found on the first
        // return after the wolf kill, then Arkus wakes once the Trading Post is up. Both set their
        // real flag even when the (later-authored) cutscene JSON is missing.
        TryPlayArkusFound();
        TryPlayArkusWake();
    }

    // ------------------------------------------------------------------ Instancing

    private void SpawnFarmRenderer()
    {
        _farmRenderer = new FarmRenderer { Name = "FarmRenderer" };
        AddChild(_farmRenderer);
        _farmRenderer.Bind(this);
    }

    /// <summary>Drive every building (ruined Stage0 for not-yet-commissioned ones too) with the
    /// correct stage/scaffold/overlays for its current tier, construction, season/day, and story
    /// flags (design/building_visuals.md). Instances pre-placed in this scene are ADOPTED by their
    /// scene path; anything missing falls back to a <c>%Building_&lt;id&gt;</c> marker. Null-safe:
    /// missing instances/markers/scenes are skipped (the build state still works, art arrives
    /// later). Refreshed per building on BuildingChanged, and for every building on
    /// DayStarted/StoryFlagChanged (season/window/flag boundaries).</summary>
    private void SpawnBuildings()
    {
        _buildingLoader = new BuildingLoader(
            this,
            id => GameState.Instance?.GetBuildingTier(id) ?? 0,
            id => GameState.Instance?.Building.IsUnderConstruction(id) ?? false,
            () => GameState.Instance is { } gs ? (gs.Clock.Season, gs.Clock.Day) : (Season.Spring, 1),
            // GameState.HasFlagForConditions (not the plain HasStoryFlag) so visual rules can also
            // gate on the derived <id>_built / <id>_commissioned / building_under_construction flags
            // (design/building_visuals.md; the lodging-repair payoff on the tavern's tier-1 override).
            id => GameState.Instance?.HasFlagForConditions(id) ?? false);
        _buildingLoader.PlaceAll();
    }

    /// <summary>Instance an NPC entity for every PRESENT villager at its <c>%Villager_&lt;id&gt;</c>
    /// marker: the always-present starting party (Tharr, Elara, Fenwick) from day one, plus any arrived
    /// villager. Null-safe: missing markers are skipped. Refreshed per villager on VillagerArrived.</summary>
    private void SpawnVillagers()
    {
        _villagerLoader = new VillagerLoader(
            this,
            id => GameState.Instance?.IsVillagerArrived(id) ?? false,
            residents: CharacterRegistry.StartingResidents(),
            // Wander is suppressed while any dialogue/modal is open (covers cutscenes, since the
            // dialogue box that stages them opens as a modal too), during a hand-off, or for whichever
            // villager is currently the interact-adjacent talk target.
            isWanderSuppressed: id => IsTransitioning || AnyModalOpen || id == GetNearbyVillagerId(),
            // Daily schedules (design/schedules): NPCs spawn on their current slot's anchor and re-anchor
            // (walk) as the clock crosses slot times (see OnScheduleTick wiring below).
            currentMinuteOfDay: () => GameState.Instance?.Clock.MinuteOfDay ?? DayClock.DayStartMinute);
        _villagerLoader.PlaceArrived();
    }

    protected override Vector3 GetPlayerSpawnPosition() => PlayerSpawnPosition;

    protected override void ConfigurePlayer(PlayerController player)
    {
        player.Setup(this, _bedroll);
        player.SleepRequested += OnSleepRequested;
        player.ActionRejected += ShowRejectionToast;
    }

    /// <summary>Signpost at the %GateTrigger position. Visual only: the proximity hint rides the
    /// gate trigger's own entered/exited signals.</summary>
    private void SpawnGateSign()
        => _gateSign = SpawnTransitionSign("GateSign", $"To {GateDestinationName}", _gateTrigger, trackPlayer: false);

    private void WireGate()
    {
        _gateTrigger?.Connect(Area3D.SignalName.BodyEntered, Callable.From<Node3D>(OnGateBodyEntered));
        _gateTrigger?.Connect(Area3D.SignalName.BodyExited, Callable.From<Node3D>(OnGateBodyExited));
    }

    protected override void WireExtraStateEvents(GameState gs, EventSubscriptions subs)
    {
        subs.Add(() => gs.DayStarted += RefreshHudTime, () => gs.DayStarted -= RefreshHudTime);
        subs.Add(() => gs.SquadLeveledUp += OnSquadLeveledUp, () => gs.SquadLeveledUp -= OnSquadLeveledUp);
        subs.Add(() => gs.BuildingChanged += OnBuildingPlaced, () => gs.BuildingChanged -= OnBuildingPlaced);
        subs.Add(() => gs.VillagerArrived += OnVillagerArrived, () => gs.VillagerArrived -= OnVillagerArrived);
        // Daily-schedule re-anchor: on each game-minute (and the dawn rollover) push the current slot to
        // each placed NPC, which walks it there when the slot flips.
        subs.Add(() => gs.MinuteChanged += OnScheduleTick, () => gs.MinuteChanged -= OnScheduleTick);
        subs.Add(() => gs.DayStarted += OnScheduleTick, () => gs.DayStarted -= OnScheduleTick);
        subs.Add(() => gs.DayStarted += RefreshBuildingVisuals, () => gs.DayStarted -= RefreshBuildingVisuals);
        subs.Add(() => gs.StoryFlagChanged += OnStoryFlagChangedForVisuals, () => gs.StoryFlagChanged -= OnStoryFlagChangedForVisuals);
        // Arkus wakes on the day-start where the outpost catches the conditions (found + Trading Post
        // up). Deferred so any day-summary modal for the same rollover opens first.
        subs.Add(() => gs.DayStarted += OnDayStartedArkusWake, () => gs.DayStarted -= OnDayStartedArkusWake);

        // World-rules seam: farm commands validate through THIS scene's map truth while it hosts the
        // farm — the paired undo unbinds it on teardown so a freed scene is never queried.
        subs.Add(() => gs.BindFarmWorld(IsTillable), () => gs.BindFarmWorld(null));
    }

    /// <summary>A building was commissioned or upgraded: (re)place its world visual at its marker and
    /// select the stage for the new tier. The panel refresh is handled by the base class.</summary>
    private void OnBuildingPlaced(string buildingId) => _buildingLoader?.Refresh(buildingId);

    /// <summary>Calendar boundary (new day): re-evaluate every commissioned building's visual —
    /// season overlays and event windows can flip without any building's own tier/construction
    /// state changing.</summary>
    private void RefreshBuildingVisuals() => _buildingLoader?.RefreshAll();

    /// <summary>A story flag was set: re-evaluate every commissioned building's visual — flag-driven
    /// overlays and stage overrides can change independent of tier/construction.</summary>
    private void OnStoryFlagChangedForVisuals(string flagId) => _buildingLoader?.RefreshAll();

    /// <summary>A villager arrived: spawn its NPC node at its marker (idempotent).</summary>
    private void OnVillagerArrived(string villagerId) => _villagerLoader?.Refresh(villagerId);

    /// <summary>Clock advanced (a game-minute, or the dawn rollover): re-anchor placed NPCs to their
    /// current schedule slot. Cheap — the loader skips NPCs whose slot has not changed.</summary>
    private void OnScheduleTick()
        => _villagerLoader?.ApplySchedules(GameState.Instance?.Clock.MinuteOfDay ?? DayClock.DayStartMinute);

    // ------------------------------------------------------------------ Interactions

    private void OnSquadLeveledUp(IReadOnlyList<SquadLevelUpView> levelUps)
        => _pendingLevelUps = levelUps;

    private void OnSleepRequested()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;

        // Sleep is unlocked by repairing the lodging (design/tutorial.md — "sleep unlocked by lodging
        // repair"): before the walls and roof hold there is nowhere safe to bed down. A friendly toast
        // points the player back at Tharr's task. The gate lives here (the bedroll interaction), NOT in
        // GameState.Sleep(), so spike/F6 paths that drive Sleep() directly keep working.
        if (!gs.HasStoryFlag("lodging_repaired"))
        {
            Hud?.ShowToast("No safe place to sleep yet — patch up the lodging with Tharr first.", 3f);
            return;
        }

        if (Hud != null)
            Hud.PlaySleepTransition(gs.Sleep, () => BuildWakeText(gs));
        else
            gs.Sleep();
    }

    /// <summary>Wake toast: date line plus one line per overnight level-up (consumed here).</summary>
    private string BuildWakeText(GameState gs)
    {
        string text = $"You wake — {gs.Clock.DateString()}";
        if (_pendingLevelUps != null)
        {
            foreach (var lu in _pendingLevelUps)
                text += $"\n{lu.MemberName} reached level {lu.ToLevel}!";
            _pendingLevelUps = null;
        }
        return text;
    }

    /// <summary>Destination display name for gate affordance text ("the Verdant Fringe").</summary>
    private string GateDestinationName
        => Territories.TryGet(GateTerritoryId, out var def) ? def.DisplayName : GateTerritoryId;

    /// <summary>Gate trigger reached: flash the travel hint (once per approach — the trigger's own
    /// entered/exited boundary is the hysteresis) and arm the interact-to-travel flow.</summary>
    private void OnGateBodyEntered(Node3D body)
    {
        if (body is not PlayerController || IsTransitioning)
            return;

        _playerAtGate = true;
        Hud?.ShowToast(
            $"Press E / LMB — travel to {GateDestinationName} ({TerritorySystem.TravelMinutes} min)",
            2.5f);
    }

    private void OnGateBodyExited(Node3D body)
    {
        if (body is PlayerController)
            _playerAtGate = false;
    }

    /// <summary>
    /// Interact press: at the gate, open the party-select panel (defaulting to the full party — the
    /// player deselects anyone to leave behind), then travel on confirm via
    /// <see cref="OnGatePartyConfirmed"/>. F6/spike fallback (no panel spawned) marches the full squad
    /// directly. Away from the gate, an interact BESIDE a villager NPC talks to them (the friendship
    /// daily-talk bump).
    /// </summary>
    protected override void OnInteractRequested(ToolKind tool)
    {
        var gs = GameState.Instance;
        if (gs == null || IsTransitioning)
            return;

        if (_playerAtGate)
        {
            if (PartySelectPanel != null)
            {
                PartySelectPanel.Open(gs.GetPartySelectView(GateTerritoryId));
                return;
            }

            // Fallback: no panel (standalone F6) — march with the full living squad.
            if (!gs.TravelToTerritory(GateTerritoryId))
            {
                Hud?.ShowToast("Cannot travel right now.", 1.5f);
                return;
            }
            string territoryId = GateTerritoryId;
            BeginHandOff(
                $"The squad marches for {GateDestinationName}.",
                () => SceneRouter.Instance?.GoToTerritory(territoryId));
            return;
        }

        TryTalkToVillager(gs);
    }

    /// <summary>The gate party-select confirmed with the chosen companions (0-3): travel with that
    /// explicit selection and hand off to the territory.</summary>
    private void OnGatePartyConfirmed(IReadOnlyList<string> companionIds)
    {
        var gs = GameState.Instance;
        if (gs == null || IsTransitioning)
            return;

        if (!gs.TravelToTerritory(GateTerritoryId, companionIds))
        {
            Hud?.ShowToast("Cannot travel right now.", 1.5f);
            return;
        }

        string territoryId = GateTerritoryId;
        BeginHandOff(
            $"The squad marches for {GateDestinationName}.",
            () => SceneRouter.Instance?.GoToTerritory(territoryId));
    }

    /// <summary>The placed villager NPC beside the player, for the friendship panel's gift flow.</summary>
    protected override string? GetNearbyVillagerId()
        => Player == null ? null : _villagerLoader?.NearestVillagerId(Player.GlobalPosition, VillagerTalkRadius);

    /// <summary>Floating "E — …" HUD prompt: mirrors <see cref="OnInteractRequested"/>'s exact
    /// proximity checks (the gate-trigger flag, the bedroll cell math, the villager talk radius) so
    /// the hint never promises an action interact wouldn't actually take.</summary>
    protected override string? GetInteractionHint()
    {
        if (Player == null)
            return null;
        if (_playerAtGate)
            return "Travel";
        if (IsNearBedroll())
            return "Sleep";
        if (GetNearbyVillagerId() != null)
            return "Talk";
        return null;
    }

    /// <summary>Same cell math as <see cref="PlayerController.TrySleepAtBedroll"/> (standing on or
    /// facing the bedroll cell) — read-only mirror the hint needs, without duplicating the private
    /// bedroll cell cached on the controller.</summary>
    private bool IsNearBedroll()
    {
        if (_bedroll == null || Player == null)
            return false;
        Vector2I self = WorldToCell(Player.GlobalPosition);
        Vector2I bedrollCell = WorldToCell(_bedroll.GlobalPosition);
        return self == bedrollCell || self + Player.FacingDirection == bedrollCell;
    }

    /// <summary>
    /// TALK: interact beside a placed villager NPC. First tries the dialogue system's talk pool
    /// (if a talk pool exists for the character with a passing entry, play it in the dialogue box).
    /// Falls back to the old Personality toast if no talk pool is loaded.
    /// </summary>
    private void TryTalkToVillager(GameState gs)
    {
        string? charId = GetNearbyVillagerId();
        if (charId == null)
            return;

        // Tutorial hand-offs that happen by TALKING to the NPC (design/tutorial.md Step 4 + Fenwick's
        // Table). Both are attempted BEFORE the talk line is chosen so a successful hand-off has already
        // mutated state by the time the talk pool is queried:
        //  • Tharr + repair_lodging active: handing him 15 wood / 10 stone repairs the lodging. On
        //    success lodging_repaired flips and the scripted Day-1 close takes over (below). Short on
        //    materials => RepairLodging cleanly no-ops and his "fifteen timber, ten stone" ask plays.
        //  • Fenwick + a live "give 3 fresh crops" deliver objective: DeliverQuestItems consumes the
        //    crops and ticks Fenwick's Table. It self-validates (right quest active AND crops in the
        //    pack), so it only fires at the intended moment and no-ops otherwise.
        bool lodgingJustRepaired = false;
        if (charId == "tharr" && gs.IsQuestActive("repair_lodging"))
        {
            lodgingJustRepaired = gs.RepairLodging();
        }
        else if (charId == "fenwick" && gs.DeliverQuestItems(Bulwark.Data.Quests.FreshCropsSet))
        {
            Hud?.ShowToast("You hand Fenwick three fresh crops for the pot.", 3f);
        }

        bool bumped = gs.TalkTo(charId);

        // Scripted Day-1 close (design/tutorial.md): repairing the lodging ends the first day — play the
        // hearth cutscene, then auto-sleep to Day 2. Takes over the screen from the normal talk line.
        if (lodgingJustRepaired)
        {
            PlayScriptedDayOneClose(gs);
            return;
        }

        // Day-2 planning-table tour (design/tutorial_quests.md quest 2): the first talk to Tharr after
        // first_rest, before the table has been shown, plays the staged ruins tour (camera pans to the
        // Farmhouse/Tavern/Trading Post building instances) INSTEAD of the talk pool. HasSeenDialogue
        // guards the once-only replay — planning_table_shown itself is set later, by opening the build
        // panel for the first time (CozyWorldScene.OnBuildPanelToggled), not by this tour finishing, so
        // a player who keeps talking to Tharr before ever opening the panel doesn't get the tour again.
        if (charId == "tharr" && gs.HasStoryFlag("first_rest") && !gs.HasStoryFlag("planning_table_shown")
            && !gs.HasSeenDialogue("tharr_day2_tour")
            && TryPlayStoryCutscene(gs, "tharr_day2_tour"))
        {
            return;
        }

        // Try the dialogue system's talk pool first. Play the whole entry (not just its lines) so
        // any entry-level effects (e.g. latching a story flag on first talk) and choices apply.
        if (gs.DialogueDb != null && gs.DialogueDb.HasTalkPool(charId))
        {
            var entry = gs.DialogueDb.GetTalkEntry(charId, gs.BuildConditionContext());
            if (entry != null && entry.Lines.Count > 0)
            {
                PlayTalkEntry(entry);
                return;
            }
        }

        // Fallback: the old Personality toast
        string name = charId;
        string? line = null;
        if (CharacterRegistry.TryGet(charId, out var profile))
        {
            name = profile.DefaultName;
            line = profile.Personality;
        }
        else if (_villagerLoader != null)
        {
            foreach (var v in Villagers.All)
                if (v.Id == charId)
                {
                    name = v.DisplayName;
                    break;
                }
        }

        string text = line != null ? $"{name}: \"{line}\"" : $"You chat with {name} for a while.";
        if (bumped)
            text += "\n(+12 friendship)";
        Hud?.ShowToast(text, 3f);
    }

    /// <summary>If this is the first arrival at the outpost after the road intro (intro_scene_1 set
    /// but intro_complete not yet set), play the Scene 2 dialogue sequence.</summary>
    private void TryPlayIntroScene2()
    {
        var gs = GameState.Instance;
        if (gs == null || DialogueBox == null)
            return;
        if (!gs.HasStoryFlag("intro_scene_1") || gs.HasStoryFlag("intro_complete"))
            return;

        var db = gs.DialogueDb;
        if (db == null || !db.TryGetSequence("intro_scene_2", out var seq) || seq.Steps == null)
            return;

        // Stage the arrival cutscene against the resident NPC instances the villager loader spawned:
        // the director hides the actors this script stages (Tharr, via scene_2's `enter` step), then
        // reveals + walks each in on its enter step.
        PrepareCutsceneStaging(seq.Steps);

        PlayDialogueSteps(seq.Steps, "intro_scene_2", seq.Once);
    }

    /// <summary>
    /// Play a staged story cutscene sequence by id if the (later-authored) JSON exists. Returns true
    /// when it started playing; false when the sequence is missing, so callers can degrade gracefully
    /// (still set their flag / advance the day). Mirrors <see cref="TryPlayIntroScene2"/>'s staging.
    /// </summary>
    private bool TryPlayStoryCutscene(GameState gs, string dialogueId)
    {
        var db = gs.DialogueDb;
        if (DialogueBox == null || db == null || !db.TryGetSequence(dialogueId, out var seq) || seq.Steps == null)
            return false;

        PrepareCutsceneStaging(seq.Steps);
        return PlayDialogueSteps(seq.Steps, dialogueId, seq.Once);
    }

    /// <summary>
    /// Scripted Day-1 close (design/tutorial.md): play the <c>day1_close</c> hearth cutscene, then
    /// auto-sleep into Day 2 (reusing the sleep/day-advance path, which sets first_rest and lifts the
    /// tutorial time freeze). The dialogue JSON is authored later — if it is missing, still advance the
    /// day directly with a warning, so the tutorial never stalls.
    /// </summary>
    private void PlayScriptedDayOneClose(GameState gs)
    {
        if (TryPlayStoryCutscene(gs, "day1_close"))
        {
            Action? onEnded = null;
            onEnded = () =>
            {
                gs.DialogueEnded -= onEnded;
                gs.Sleep();
            };
            gs.DialogueEnded += onEnded;
            return;
        }

        GD.PushWarning("[OutpostScene] day1_close cutscene missing — advancing the day directly.");
        gs.Sleep();
    }

    /// <summary>
    /// Arkus found on the first return to the outpost after the wolf kill (dire_wolf_slain &amp;&amp; not yet
    /// found): play the <c>arkus_found</c> cutscene (if authored) and latch <c>arkus_found</c>, which
    /// places Arkus as an unconscious resident. The flag is set even when the cutscene JSON is missing.
    /// </summary>
    private void TryPlayArkusFound()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;
        if (!gs.HasStoryFlag("dire_wolf_slain") || gs.HasStoryFlag("arkus_found"))
            return;

        TryPlayStoryCutscene(gs, "arkus_found");
        gs.SetStoryFlag("arkus_found");
    }

    /// <summary>
    /// Arkus wakes once he has been found AND the Trading Post is up (arkus_found &amp;&amp; trading_post_built
    /// &amp;&amp; not yet awake): play the <c>arkus_wake</c> cutscene (if authored) and latch <c>arkus_awake</c>,
    /// which opens the Smithy + Infirmary and starts The Smith and the Sickbed. Flag set regardless of
    /// the cutscene JSON's existence.
    /// </summary>
    private void TryPlayArkusWake()
    {
        var gs = GameState.Instance;
        if (gs == null)
            return;
        if (!gs.HasStoryFlag("arkus_found") || gs.HasStoryFlag("arkus_awake")
            || !gs.HasFlagForConditions("trading_post_built"))
            return;

        TryPlayStoryCutscene(gs, "arkus_wake");
        gs.SetStoryFlag("arkus_awake");
    }

    /// <summary>
    /// Resolve a dialogue actor id to the villager NPC the loader placed, or null when that villager
    /// isn't present (or there is no loader, e.g. an F6/spike run). The cutscene director stages against
    /// <see cref="Node3D"/> actors, which is exactly what the villager loader places.
    /// </summary>
    private Node3D? FindCutsceneActor(string id) => _villagerLoader?.GetPlaced(id);

    /// <summary>Hand the director the actor lookup for a staged sequence, so each <c>enter</c> step
    /// reveals the real resident NPC instance. An id the loader never placed resolves to null and that
    /// step degrades to the director's log-and-continue.</summary>
    private void PrepareCutsceneStaging(List<DialogueStep> steps)
        => Director?.PrepareStaging(steps, FindCutsceneActor);

    /// <summary>Day-start Arkus-wake check, deferred so a same-rollover day-summary modal opens first.</summary>
    private void OnDayStartedArkusWake() => Callable.From(TryPlayArkusWake).CallDeferred();

    /// <summary>One-shot arrival messages: return-travel notice and/or the defeat wake summary.</summary>
    private void ShowArrivalToasts()
    {
        var gs = GameState.Instance;
        if (gs == null || Hud == null)
            return;

        var defeat = gs.ConsumeDefeatSummary();
        if (defeat != null)
        {
            var sb = new StringBuilder("Defeated... you wake at the outpost — ");
            sb.Append(gs.Clock.DateString());
            if (defeat.Losses.Count == 0)
            {
                sb.Append("\nThe stores survived intact.");
            }
            else
            {
                sb.Append("\nLost: ");
                for (int i = 0; i < defeat.Losses.Count; i++)
                {
                    if (i > 0) sb.Append(", ");
                    sb.Append($"{defeat.Losses[i].ItemName} x{defeat.Losses[i].Lost}");
                }
            }
            Hud.ShowToast(sb.ToString(), 4.5f);
            return;
        }

        string? travel = gs.Territory.ConsumeTravelToast();
        if (travel != null)
            Hud.ShowToast(travel);
    }

    // --- Blockout accessors ---

    /// <summary>The authored floor + perimeter body (physics layer 1 "Terrain").</summary>
    public StaticBody3D? Ground => _ground;

    public Marker3D? PlayerSpawn => _playerSpawn;
    public Marker3D? FarmArea => _farmArea;
    public Area3D? GateTrigger => _gateTrigger;
    public Area3D? Bedroll => _bedroll;

    /// <summary>World-space player spawn point (falls back to origin if the marker is missing).</summary>
    public Vector3 PlayerSpawnPosition => _playerSpawn?.GlobalPosition ?? Vector3.Zero;

    // --- Farming query API (for the farm system) ---

    /// <summary>Grid cell containing a world-space point (one cell = one metre on the XZ plane).</summary>
    public Vector2I WorldToCell(Vector3 world)
        => new(Mathf.FloorToInt(world.X), Mathf.FloorToInt(world.Z));

    /// <summary>Centre world-space point (on the ground plane) of a grid cell.</summary>
    public Vector3 CellToWorld(Vector2I cell)
        => new(cell.X + 0.5f, 0f, cell.Y + 0.5f);

    /// <summary>The base (zone-0) farm rectangle in cells, centred on <c>%FarmArea</c>. Empty
    /// (a degenerate rect at the origin) when the marker is missing — nothing is farmable then.</summary>
    private Rect2I BaseFarmRect()
    {
        if (_farmArea == null)
            return new Rect2I(0, 0, 0, 0);

        Vector2I centre = WorldToCell(_farmArea.GlobalPosition);
        Vector2I size = new(Mathf.Max(FarmSizeCells.X, 0), Mathf.Max(FarmSizeCells.Y, 0));
        return new Rect2I(centre - size / 2, size);
    }

    /// <summary>
    /// The farm ZONE of a cell, or -1 when the cell is not farmland at all. Zone 0 is the base
    /// rectangle; each further <see cref="FarmZoneRingCells"/>-wide ring around it is the next zone,
    /// up to <see cref="FarmMaxZone"/>, feeding the <see cref="FarmZones"/> unlock rule.
    /// </summary>
    private int FarmZoneOf(Vector2I cell)
    {
        Rect2I rect = BaseFarmRect();
        if (rect.Size.X <= 0 || rect.Size.Y <= 0)
            return -1;

        int dx = Math.Max(rect.Position.X - cell.X, cell.X - (rect.Position.X + rect.Size.X - 1));
        int dy = Math.Max(rect.Position.Y - cell.Y, cell.Y - (rect.Position.Y + rect.Size.Y - 1));
        int outside = Math.Max(Math.Max(dx, dy), 0);
        if (outside == 0)
            return FarmZones.BaseZone;

        int ring = Math.Max(FarmZoneRingCells, 1);
        int zone = (outside + ring - 1) / ring;
        return zone <= FarmMaxZone ? zone : -1;
    }

    /// <summary>True if <paramref name="cell"/> is farm soil (inside the farm region, any zone).</summary>
    public bool IsFarmable(Vector2I cell) => FarmZoneOf(cell) >= 0;

    /// <summary>
    /// Stardew rule: a cell can be tilled only when the world says so — farm soil, nothing standing
    /// on it (a trigger, a sign, a building footprint), AND (Refinement 2) the cell is within the
    /// currently UNLOCKED tillable area (its farm zone ≤ the outpost's tillable-area level). This is
    /// the predicate the scene injects into the farm system (GameState.BindFarmWorld); the highlight
    /// and the command share it, so an actionable highlight always matches a command that succeeds.
    /// </summary>
    public bool IsTillable(Vector2I cell)
    {
        int zone = FarmZoneOf(cell);
        if (zone < 0)
            return false;
        int level = GameState.Instance?.FarmTillableAreaLevel ?? 0;
        return FarmZones.IsWithinTillableArea(zone, level) && !IsCellOccupied(cell);
    }

    /// <summary>
    /// Occupancy is scene knowledge: functional world objects (triggers, signs, building footprints)
    /// claim their cell even when the soil under them is farm soil. Scanned live — tilling happens on
    /// interact presses, and a live scan tracks runtime-spawned children.
    /// </summary>
    private bool IsCellOccupied(Vector2I cell)
    {
        if (_gateTrigger != null && WorldToCell(_gateTrigger.GlobalPosition) == cell)
            return true;
        if (_bedroll != null && WorldToCell(_bedroll.GlobalPosition) == cell)
            return true;

        foreach (Node child in GetChildren())
        {
            switch (child)
            {
                case TransitionSign sign when WorldToCell(sign.GlobalPosition) == cell:
                    return true;
                case BuildingInstance building when FootprintCoversCell(building, cell):
                    return true;
            }
        }
        return false;
    }

    /// <summary>True when a placed building's <c>%Footprint</c> box covers the cell centre. Boxes are
    /// the only footprint shape the greybox scenes use; anything else is ignored (the building still
    /// blocks physically, it just doesn't veto tilling).</summary>
    private bool FootprintCoversCell(BuildingInstance building, Vector2I cell)
    {
        var footprint = building.GetNodeOrNull<StaticBody3D>("%Footprint");
        if (footprint == null)
            return false;

        Vector3 centre = CellToWorld(cell);
        foreach (Node child in footprint.GetChildren())
        {
            if (child is not CollisionShape3D { Disabled: false } shape || shape.Shape is not BoxShape3D box)
                continue;

            Vector3 local = shape.GlobalTransform.AffineInverse() * centre;
            Vector3 half = box.Size * 0.5f;
            if (Mathf.Abs(local.X) <= half.X && Mathf.Abs(local.Z) <= half.Z)
                return true;
        }
        return false;
    }

    /// <summary>Every farm-soil cell (the tillable region the player may work, across all zones).</summary>
    public IEnumerable<Vector2I> FarmableCells()
    {
        Rect2I rect = BaseFarmRect();
        if (rect.Size.X <= 0 || rect.Size.Y <= 0)
            yield break;

        int margin = Math.Max(FarmZoneRingCells, 1) * Math.Max(FarmMaxZone, 0);
        for (int x = rect.Position.X - margin; x < rect.Position.X + rect.Size.X + margin; x++)
            for (int y = rect.Position.Y - margin; y < rect.Position.Y + rect.Size.Y + margin; y++)
            {
                var cell = new Vector2I(x, y);
                if (IsFarmable(cell))
                    yield return cell;
            }
    }
}
