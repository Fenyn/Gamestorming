# Palworld work-assignment call-path map

Build target: Palworld 1.0 (Steam), UE 5.1.
Header source: `localcc/PalworldModdingKit` @ `62fad41` (post-1.0, 2026-07-11). Declarations only —
runtime behavior below marked ✅ verified / ⏳ pending in-game verification.

## Tooling installed
- UE4SS Okaetsu fork, `experimental-palworld` release, asset uploaded 2026-07-09 (1.0-compatible,
  commit c2ac246). Installed at `E:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64`
  (`dwmapi.dll` + `ue4ss\`), zDev variant. GUI console enabled by default in this bundle.
- Probe mod `PrioProbe` (source of truth: `../probe/PrioProbe/`, installed copy in `ue4ss\Mods\`),
  enabled in both `mods.txt` and `mods.json`.

## Assignment path (server side)
- `UPalBaseCampWorkerDirector` — per-basecamp roster manager. Holds `RequiredAssignWorks` queue,
  `WaitingWorkerIndividualIds : TArray<FPalInstanceID>`, `WorkerTasks`, state machine.
- Jobs are `UPalWorkBase` objects (abstract; `OverrideWorkType : EPalWorkType`, assign/unassign/start/end delegates).
- ⏳ `UPalBaseCampWorkerDirector::OnRequiredAssignWork_ServerInternal(UPalWorkBase*, const FPalWorkAssignRequirementParameter&)` — job-needs-worker intake.
- ⏳ `UPalWorkBase::IsExistAssignableSlot(const UPalIndividualCharacterHandle*, bool bByFixedAssign)` — per-pal/per-job eligibility gate. **Primary priority-injection candidate.**
- ⏳ `UPalBaseCampWorkerDirector::OnNotifiedUnassignWork_ServerInternal(UPalWorkBase*, const FPalInstanceID&)` — unassign path.
- Suitability reads: `UPalIndividualCharacterParameter::HasWorkSuitability / HasWorkSuitabilityRank / GetWorkSuitabilityRank`.
- Live per-pal state: `UPalCharacterParameterComponent` → `GetWork()`, `GetWorkAssign()`, `IsAssignedToAnyWork()`.

## Fallback lever (if hooks fail)
Vanilla per-pal toggle storage: `FPalWorkSuitabilityPreferenceInfo { TArray<EPalWorkSuitability> OffWorkSuitabilityList; bool bAllowBaseCampBattle; }`
on `FPalIndividualCharacterSaveParameter` (in save data, per pal). Change delegate:
`OnUpdateWorkSuitabilityOptionDelegate(const FPalWorkSuitabilityPreferenceInfo&)` on `UPalIndividualCharacterParameter`.
A supervisor tick driving the off-list per pal from the priority table replicates priorities coarsely.

## Pal identity
`FPalInstanceID { FGuid PlayerUId; FGuid InstanceId; FString DebugName; }` via
`UPalIndividualCharacterHandle::GetIndividualID()`. JSON key: `PlayerUId_InstanceId`.

**⚠ InstanceId is NOT stable (verified live 2026-07-17, dedicated server):** Palworld
re-instances base pals — the same pal returned with a new InstanceId after a server
restart (SamuraiDog `...AD1DCFA9...` → `...C33911CE...`, same nickname + suitabilities),
and a mid-session re-instance was also observed (PinkCat auto-configured under two keys
2s apart). PlayerUId was all-zero for base workers. Anything keyed by palKey silently
orphans on re-instance. Mitigation (1.1.0): ANCHOR FINGERPRINT — the engine stores
`anchor = CharacterID|Talent_HP/Talent_Shot/Talent_Defense/Gender` per entry (all
persisted SaveParameter fields, immutable IVs; refreshed while live in case a future
patch changes them) and ADOPTS orphaned configs onto re-instanced pals by exact-unique
anchor match (sweep + click-time fast-path); superseded duplicates are dropped.
Identical bred twins (same species+IVs+gender) are never guessed — re-click those.

Probe findings 2026-07-17 (anchor selection):
- Names seen in configs were NOT nicknames: displayName falls back to `CharacterID`,
  the INTERNAL species id (Cattiva=PinkCat, Pupperai=SamuraiDog, Gumoss=PlantSlime,
  Pengullet=Penguin). NickName was empty on all probed base pals.
- `SaveParameter.ItemContainerId.ID` is an all-zero guid on most pals (lazily
  allocated) — unusable as an anchor. `EquipItemContainerId` and `Talent_Melee` are
  marked Transient in the header (unsaved) — never fingerprint on them.

## Work types (EPalWorkSuitability, 13 usable)
EmitFlame (Kindling), Watering, Seeding, GenerateElectricity, Handcraft, Collection, Deforest,
Mining, OilExtraction, ProductMedicine, Cool, Transport, MonsterFarm. (Plus None/Anyone/MAX sentinels.)

## UI layer (verified via reflection dump, session 4)
Pure Blueprint, under `/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/WorkSuitabilityPreference/`:
- `WBP_WorkSuitabilityPreferenceMenu_C` — the screen. Props: `WBP_PalCommonScrollList_PalList`,
  `NowDisplayingCharacterHandle`, delegates `OnChangedSuitabilitySetting`/`OnChangedBattleModeSetting`.
- `WBP_WorlSuitabilityPreference_PalList_C` (game's own typo) — one row per pal. Props:
  `bindedSlot : SoftObject → UPalIndividualCharacterSlot` (the pal!), `SuitabilityCheckBoxMap : Map`,
  `Text_Pal_name`, `Text_CurrentTask`. Funcs: `OnUpdateWorkSuitabilityOption_Binded`,
  `SetupCheckBox`, `SetFixedAssignMode`.
- `WBP_WorkSuitabilityPreference_CheckBox_0_C` — one cell per work type. Props:
  `BindedSuitability : Enum` (the work type), `IsBattleSettingMode : Bool` (battle cell, skip),
  `PalCheckBox`, `Image_None`, `WBP_PalInvisibleButton_0`. Funcs: `GetBindedSuitability`,
  `SetCheckedState`, `SetEnableClick`. 26 live instances with a 2-pal base (13 × pal row).
- Cell click → vanilla `RequestChangeWorkSuitability_ToServer` RPC (verified) — so the ENGINE owns
  cycle logic; client UI mod (PalPriorityUI) is display-only (injected TextBlock number overlays,
  500ms poll while menu open). Display data source since 1.1.0: server→client sync over
  `Notify_RequestClient_int32` (primary; works on dedicated servers), with the local
  priorities.lua read kept as a same-machine bootstrap/fallback.

## Write routing (1.1.0, multi-guild correctness)
The supervisor's off-list writes execute the toggle RPC on a PLAYER's server-side
component — and the game may scope authority per guild, so the caller must be a player
who manages that pal. Design: each config entry persists `owner = <PlayerUId hex>` (the
player whose attested click created/last cycled it — captured for free inside hook B).
A runtime registry maps owner → live component (learned from mod traffic, plus a
periodic controller scan — `APalPlayerController:GetPlayerUId()` + `.Transmitter.BaseCamp`
— so shaping resumes when the owner merely connects). Writes route through the pal's
own manager's component; owner offline → that pal's shaping defers quietly (never send
through a possibly-unauthorized component, never spam a boot-time playerless dud).
Legacy owner-less entries fall back to the old campComp path, metered by the
convergence guard (3 tries → 120s backoff), until a click upgrades them.

## Sync wire protocol (1.1.0, server → modded clients)
Channel: `comp:Notify_RequestClient_int32({0-guid}, FName(msg), 1)` on each modded player's own
component. The server learns which components are modded from incoming `PrioMod_*` messages
(client pings every 60s while the work screen is open; server replies to a ping with full state).
Messages (parse by splitting on `|` — the palkey itself contains a `-`):
- `PrioSync|<palkey>|<13 chars>` — work types 1..13 in order; `0`-`5` = explicit priority
  (`0` renders X/never), `-` = no entry (pal lacks the suitability → cell stays blank).
- `PrioDrop|<palkey>` — pal released/unconfigured; client forgets it.
Note: every unique FName string interns permanently in UE's name table. Bounded by clicks per
session (one string per config change + full-state replies) — accepted deliberately.
- Enumeration note: container `GetSlots()` by-value return fails in UE4SS — use the `SlotArray`
  property (fixed in engine v0.1.1). BP classes need the `_C` suffix for FindAllOf.

## Force-job feature (REMOVED 2026-07-14)
Built and working (interact-bracket targeting via APalMapObject:OnInteractBegin/End, native
fixed-assign pinning, per-item completion via OnFinishWorkInServer + RemainProductNum), then
dropped by decision. Force-era sources archived in ../attic/. The WORKTYPE_TO_SUIT station
work-type map stayed in the engine (it fixes the pending tracker, not force). Discovery facts
below remain valid if the feature is ever revived.

## Original design notes (historical)
Goal: player looks at a workstation's active job, presses a key → job is FORCED: filled to its
slot capacity with the most capable pals, held at top priority until completed.
- Server: forced set keyed by work GUID. Per forced job:
  1. Enumerate the work's assign slots (`GetWorkAssignInfo` → entries → `WorkAssign:IsAssigned()`;
     out-param pattern UNVERIFIED — fallback: pin one pal, log once).
  2. Candidate pals: base pals with the work's suitability, config prio ≥1 or unconfigured
     (prio 0 = user said never — force respects it).
  3. Rank candidates: `GetWorkSuitabilityRankWithCharacterRank(type)` desc; tiebreak: pals doing
     lower-priority work first (cheapest to steal).
  4. Pin top N into free slots via native `RequestFixedAssignWorkInBaseCamp_ToServer(BaseCampId,
     WorkId, IndividualId)` (BaseCampIdBelongTo property on the work gives the camp id).
  5. Hold the work's type at max bar for pinned pals; release everything when the work object
     dies/completes (GUID vanishes from live works).
- Client: hook the station-info widget's bind (widget names from probe v4 F7 dump — pending),
  overlay FORCE prompt/FORCED state, send work GUID via 4× Request_Server_int32 + commit.

## CRASH SUSPECT REMOVED (2026-07-17, pre-1.1.0-release)
Nexus users reported repeated crashes minutes into play once ADVANCED PRODUCTION
BENCHES were built. Prime suspect: `UPalWorkBase::GetWorkAssignInfo(TArray<FPalWorkAssignInfo>&)`
— the engine's deepest getWorkType fallback, runtime-UNVERIFIED, never once succeeded
(always a caught error on our build), and its out-param marshals object-bearing structs —
the same native-AV family as the bindedSlot SoftObjectProperty crash below (pcall cannot
catch those). Station jobs from advanced benches are exactly the classes that reached it.
REMOVED from the engine 1.1.0; unknown job classes now just log once (grow WORKTYPE_TO_SUIT
from those logs). Do not reintroduce this call without an in-game probe proving it safe.

## HARD-WON CRASH RULE #2 (session 6)
READING a SoftObjectProperty from Lua (`row.bindedSlot`) crashes natively inside UE4SS
(`push_softobjectproperty` → `FString::operator=` AV) — the crash is in the property read itself,
so alive()/pcall are useless. Never read soft-object properties on this build. Workaround: hook a
BLUEPRINT function that receives the object as a parameter (BP functions always execute through the
hookable layer) — e.g. the row's `BindFromSlot(slot)` — and capture the mapping at call time.
Cells' Outer is the GameInstance (dynamic CreateWidget), NOT their row — associate cells to rows
top-down via the row's `HorizontalBox_CheckBox` children, never by Outer-walking.

## HARD-WON CRASH RULE (from live AV crash, session 5)
UE4SS returns a **wrapper object, not nil** for null UObject properties, and **pcall cannot catch
the native access violation** from calling any method on a null/stale wrapper (crash: AV reading
0x10 in LuaUObject member invoker, via ExecuteInGameThread queue). Empty pal-list rows / screens
mid-teardown / GC'd cached widgets all produce these. Rule: before ANY member call on ANY received
object, require `obj:IsValid() == true` (the `alive()` helper in both mods; IsValid itself is safe
on stale wrappers). Never trust `~= nil`, never cache UObject refs across ticks without
revalidating, skip `Default__` CDOs from FindAllOf results.

## RPC surface (UPalNetworkBaseCampComponent — verified in headers, key discovery)
Reached via `APalPlayerController.Transmitter` (`APalNetworkTransmitter`) → `.BaseCamp`, or
`UPalUtility::GetNetworkTransmitter(WorldContext)`. RPCs execute via ProcessEvent → hookable AND callable:
- `RequestChangeWorkSuitability_ToServer(FPalInstanceID, EPalWorkSuitability, bool bOn)` — vanilla toggle write path (drives OffWorkSuitabilityList, replicated + persisted)
- `RequestFixedAssignWorkInBaseCamp_ToServer(BaseCampId, WorkId, IndividualId)` — 1.0 pin-to-station
- `RequestUnassignWorkInBaseCamp_ToServer(BaseCampId, WorkId, IndividualId)` — kick pal off job
- `Request_Server_int32(FGuid BaseCampId, FName FunctionName, int32 Value)` (+ _void/_bool/_FVector/_FPalNetArchive variants) — generic named RPC; candidate custom client→server transport (replaces chat-command plan)
- `Notify_RequestClient_int32(FGuid, FName, int32)` (+ _void/_bool/_FVector/_FPalNetArchive variants; all Client+Reliable) — the exact server→client mirror of Request_Server_*. Header-verified 2026-07-17 (PalworldModdingKit). Called on the server-side instance of a player's component it delivers to that player only; on listen server / single-player it executes locally through ProcessEvent, so the client hook fires in-process. ✅ runtime-verified 2026-07-17 on a live dedicated server: client hook received PrioSync payloads pushed from the server (custom FName, no side effects observed).
- `Notify_Multicast_*` family also exists (NetMulticast+Reliable) — deliberately NOT used: multicast would deliver to unmodded clients, whose native handling of an unknown FName is unverified.
- Client-side UI model: `UPalUIWorkSuitabilitySettingModel::RequestChangeWorkSuitability(...)` — what the toggle widget calls; hook = click interception.

## In-game verification log
Session 1 (v1 probe) — 2026-07-14:
- [x] Game boots with UE4SS console, no crash
- [x] All three targets HOOK OK (registered as native hooks)
- [x] OnRequiredAssignWork fires constantly (Transport spam ~every 1-4s; also PalWorkProgress, DeforestFoliage, CollectResource classes seen). OnNotifiedUnassignWork fires.
- [x] **IsExistAssignableSlot NEVER fires** — called directly from native C++, bypasses reflection.
      → Direct-hook injection dead; supervisor-via-RPCs is THE mechanism.
Session 2 (v2 probe) — 2026-07-14:
- [x] RequestChangeWorkSuitability_ToServer fires on vanilla toggle, params readable.
      Enum values confirmed by observation: work=5 Handcraft, work=8 Mining, work=12 Transport
      (matches header order: None=0, EmitFlame=1, Watering=2, Seeding=3, GenerateElectricity=4,
      Handcraft=5, Collection=6, Deforest=7, Mining=8, OilExtraction=9, ProductMedicine=10,
      Cool=11, Transport=12, MonsterFarm=13).
- [x] **UI model RequestChangeWorkSuitability NEVER fires** — screen doesn't route through
      UPalUIWorkSuitabilitySettingModel (or calls it natively). Click interception must target
      the WBP checkbox widget's own BP handler instead.
- [x] F6: Lua CAN call RequestChangeWorkSuitability_ToServer — table→struct params work,
      UI visibly flips back. **Write lever proven end-to-end.**
- [x] F6: Request_Server_int32 with custom FName ("PrioMod_Test", 42) round-trips to hook.
      **Custom client→server transport proven** (single-player at least; re-verify on dedicated server).
- DISCOVERY COMPLETE 2026-07-14. All engine mechanisms verified.
- [x] F7 widget names — **the revamp targets**:
      - Screen: `/Game/Pal/Blueprint/UI/UserInterface/IngameMenu/WorkSuitabilityPreference/WBP_WorkSuitabilityPreferenceMenu`
      - Inner panel: `/Game/Pal/Blueprint/UI/WorkSuitabilityPreference/WBP_WorkSuitabilityPreference`
      - Toggle cell: `.../IngameMenu/WorkSuitabilityPreference/WBP_WorkSuitabilityPreference_CheckBox_0`
      - Pal list: `.../IngameMenu/WorkSuitabilityPreference/WBP_WorlSuitabilityPreference_PalList` (game's own typo)
      - Also useful: WBP_PalStatus, WBP_MainMenu_Pal_WorkIcon, WBP_IngameMenu_Monitoring_WorkButton/WorkInfo
- Note: probe's GUID printf sign-extends negative int32s (FFFFFFFF prefix) — mask with & 0xFFFFFFFF in the engine.

## Mechanism (settled by session 1)
Server-side supervisor reacting to OnRequiredAssignWork/Unassign events + periodic tick:
- Priority 0 → RequestChangeWorkSuitability(pal, type, off) (vanilla off-list, persisted)
- Priorities 1-5 → shape each pal's allowed set to its highest-priority types that have pending
  work (off-list writes), escalate with Unassign/FixedAssign RPCs for hard reassignment.
