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
  500ms poll while menu open, reads engine's priorities.lua).
- Enumeration note: container `GetSlots()` by-value return fails in UE4SS — use the `SlotArray`
  property (fixed in engine v0.1.1). BP classes need the `_C` suffix for FindAllOf.

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
