# Palworld work-assignment call-path map

Build target: Palworld 1.0 (Steam), UE 5.1.
Header source: `localcc/PalworldModdingKit` @ `62fad41` (post-1.0, 2026-07-11). Declarations only —
runtime behavior below marked ✅ verified / ⏳ pending in-game verification.

## Tooling installed
- UE4SS Okaetsu fork, `experimental-palworld` release, asset uploaded 2026-07-09 (1.0-compatible,
  commit c2ac246). Installed at `E:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Binaries\Win64`
  (`dwmapi.dll` + `ue4ss\`), zDev variant. GUI console enabled by default in this bundle.
- Probe mods live in `../probe/`, installed alongside PalPriority in `ue4ss\Mods\`. The original
  `PrioProbe` (widget discovery for the removed force-job feature) was deleted 2026-07-26 — it was
  spent, and its findings are transcribed into the session log at the bottom of this file. The
  live probes are `TransportLoadProbe` (load, director state, work anatomy) and `WorkTypeProbe`
  (enum reflection + per-station job records).

> **Reading this section:** entries are HEADER declarations unless marked. Many were never used
> and several were never even read at runtime, so "it is listed here" is not evidence it works.
> Anything tagged **[UNUSED]** has zero references in `unified-mod/PalPriority/Scripts/`; anything
> tagged **[UNPROBED]** has never been touched from Lua on this build.

## Assignment path (server side)
- `UPalBaseCampWorkerDirector` — per-basecamp roster manager. Holds `RequiredAssignWorks` queue,
  `WaitingWorkerIndividualIds : TArray<FPalInstanceID>`, `WorkerTasks`, state machine.
  **[UNUSED] [UNPROBED] — see "Director & work internals" below for what each one is worth.**
  Header verification (2026-07-26) demoted `RequiredAssignWorks` to a LENGTH: its element struct
  has zero reflected members, so the count is an exact per-camp queue depth and nothing more. The
  readable demand data lives elsewhere — `UPalWorkBase`'s occupancy chain and
  `UPalWorkProgressManager`'s define map. `WaitingWorkerIndividualIds` is the one that survived
  intact: fully-reflected `FPalInstanceID` entries, i.e. the idle trigger. `WorkerTasks` is
  scheduled base chores, not worker state. `probe/TransportLoadProbe` **F5** is the runtime gate
  for all of it; until that dump exists, treat every one of them as unverified from Lua.
- Jobs are `UPalWorkBase` objects (abstract; `OverrideWorkType : EPalWorkType`, assign/unassign/start/end delegates).
- ✅ `UPalBaseCampWorkerDirector::OnRequiredAssignWork_ServerInternal(UPalWorkBase*, const FPalWorkAssignRequirementParameter&)` — job-needs-worker intake. Fires constantly (pulse, every 1-4s per unfilled job). `Context` is the director, which is how the engine learns camps without scanning.
- ❌ `UPalWorkBase::IsExistAssignableSlot(...)` — **DEAD END, verified session 1:** called directly from native C++, never reaches the reflection layer, so it cannot be hooked. Inline assignment veto is impossible; the off-list supervisor is the mechanism.
- ✅ `UPalBaseCampWorkerDirector::OnNotifiedUnassignWork_ServerInternal(UPalWorkBase*, const FPalInstanceID&)` — unassign path. Used for camp discovery only (1.2.0).
- Suitability reads: `UPalIndividualCharacterParameter::HasWorkSuitability` (used), plus
  `HasWorkSuitabilityRank` / `GetWorkSuitabilityRank` **[UNUSED]**. The function the allocator
  actually depends on is `GetWorkSuitabilityRankWithCharacterRank(t)` — it keys the candidate sort
  (`engine.lua`) and was missing from this list entirely.
- `UPalIndividualCharacterParameter::GetCurrentWorkSuitability()` — used, and today the only idle
  signal the engine has (nil/0 ⇒ not working).
- Live per-pal state: `UPalCharacterParameterComponent` → `GetWork()`, `GetWorkAssign()`,
  `IsAssignedToAnyWork()`. **[UNUSED] [UNPROBED]** — a whole route never taken. F6 in
  `TransportLoadProbe` now tries all three next to `GetCurrentWorkSuitability` on the same pals, to
  calibrate which one to trust for the idle trigger.

## Fallback lever (if hooks fail) — **[UNUSED]**, a design that was never taken
Vanilla per-pal toggle storage: `FPalWorkSuitabilityPreferenceInfo { TArray<EPalWorkSuitability> OffWorkSuitabilityList; bool bAllowBaseCampBattle; }`
on `FPalIndividualCharacterSaveParameter` (in save data, per pal). Change delegate:
`OnUpdateWorkSuitabilityOptionDelegate(const FPalWorkSuitabilityPreferenceInfo&)` on `UPalIndividualCharacterParameter`.
A supervisor tick driving the off-list per pal from the priority table replicates priorities coarsely.

## Pal identity
`FPalInstanceID { FGuid PlayerUId; FGuid InstanceId; FString DebugName; }` via
`UPalIndividualCharacterHandle::GetIndividualID()`. The mod's key ("palKey", `shared.lua:78-80`)
is `guidStr(PlayerUId) .. "-" .. guidStr(InstanceId)` — a Lua table key joined by a **hyphen**, not
JSON and not an underscore. It contains a `-`, which is why the sync protocol below splits on `|`.

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

## Work-type resolution — SETTLED 2026-07-25 (WorkTypeProbe)
UEnum reflection worked: `EPalWorkType` (0-47) and `EPalWorkSuitability` (0-15, `Anyone`=14) were
read straight from the game. `WORKTYPE_TO_SUIT` is now annotated with the real enum names and every
pre-existing entry checked out — the map was correct, just unverified.

Three things the dump settled:
1. **`OverrideWorkType` is authoritative when non-zero; 0 means "no override, use the class."**
   One class carries several work types: `PalWorkTransportItemInBaseCamp` was observed with 11
   (TransportDisposable), 16 (TransportItemInBaseCamp), 17 (CollectResourcePickable), 7
   (TransportFood) and 0. The old order checked `CLASS_TYPE_MAP` first, so **every
   CollectResourcePickable job was mis-labelled Transport** and hidden from pals set to Collection.
   Resolution order is now OverrideWorkType → class map → `STATION_SUIT[AssignDefineDataId]`.
   ⏳ The one inference to watch: 17 → Collection(6) rather than Transport(12).
2. **Only SOME stations report 0.** `Workbench_0` carries 12 (ConvertItem) and always resolved
   fine. `CampFire_0` and `BuildWork_0` report 0 and were invisible — `CampFire_0` → EmitFlame is
   the root cause of the "Sootseer never leaves the ranch for a cold campfire" report.
   Note the `_0` suffixes are what the PROBE printed; `STATION_SUIT` is keyed on the **stripped**
   ids `CampFire` / `BuildWork`, because `resolveWorkType` removes a trailing `_%d+` before the
   lookup. Keying on the raw id (as 1.2 did) matched only a player's FIRST campfire and left every
   later one invisible.
   Campfire also shows `RequiredWorkAmount = 0` with `AutoWorkSelfAmountBySec = 6`: continuous
   work that never completes, which is why preemption (not finish-the-job) is the right default.
3. **`FPalWorkAssignRequirementParameter` exposes no suitability field** under any plausible name —
   there is nothing to read there, so the three-step order above is the whole story.

Still unobserved, so still potentially invisible: furnace/smelting, mill, farm plot, ranch, cooler,
medicine bench, power generator, lab. Each resolves IF its job sets OverrideWorkType (most enum
values are mapped); watch the log's `unmapped work class ... assignId=X` lines and add any that
appear to `STATION_SUIT`.

## Camp scoping — VERIFIED 2026-07-25
`dir.BaseCampId` reads fine off hook A's `Context` (`57AAE6B949DFA7F153907B9EF040538F`), and matches
`work.BaseCampIdBelongTo` on the same job. Per-camp demand is sound.

## Object lookup cost — SETTLED 2026-07-25
`FindAllOf` walks the entire UObject array: ~29ms measured live, i.e. two dropped frames. Nothing
may call it on a schedule.

Two dictionaries answer every recurring question instead, both fed by events:
- **camps** (`engine.lua`) — `campId -> director`, registered from hooks A/A2, plus a sweep.
  ⚠ **Corrected 2026-07-26.** This used to read "`discoverCamps` is therefore a cold-start fallback
  that runs only while the registry is EMPTY", and 1.3 implemented exactly that. It is wrong, and
  it was a regression against 1.2's unconditional 60s rescan. Hook A fires only for **unfilled**
  work, so a base that is fully staffed never pulses, never registers, and — once any *other* camp
  has populated the registry — is never scanned for again. Its pals are never reconciled, so a pal
  fenced there before a restart stays fenced indefinitely. That is the second half of the sweep's
  own stated purpose ("how a pal fenced before a restart gets un-fenced when its base has nothing
  pending") silently deleted. The sweep now also runs when a CONFIGURED pal is missing from
  `liveSeen`, which is the cheap proxy for "someone is unaccounted for" and keeps the ~29ms walk off
  the common path. `findPalByKey`'s boot-time scan still registers what it finds.
- **players** (`registry.lua`) — `uidHex -> { ctrl, comp }` plus `compFullName -> uidHex`. Replaced
  four independent walks (role gate, both engine owner lookups, interface own-component resolve),
  each of which cached successes only and so re-walked on every miss.

`registry.lua` rules: a walk happens only on a caller MISS, never on a timer; ≤1 walk per 2s however
many callers miss together; each question backs off independently (5s → 120s; the local-player
question is capped at 30s); `R.note(compName)` from a hook re-arms that question instantly; a walk
that sees the player set change clears every backoff.

Local player vs dedicated server: `UKismetSystemLibrary::IsDedicatedServer` (static CDO call, same
shape as the interface's KismetTextLibrary use) answers it outright when callable. When it is not,
the walk itself discriminates — controllers present but none local means this process serves players
it is not one of.

## Per-tick cost rules — SETTLED 2026-07-26
Three rules, each of which was a real recurring spike before it was written down:

1. **One deferrable camp enumeration per tick.** `reconcileCamp` splits its reasons into *must*
   (demand moved, a pal is mid-convergence, the user clicked) and *may* (the 30s verify, the 60s
   liveness sweep). Only *may* is budgeted. A four-base save used to land all four verifies in the
   same frame.
2. **Stalled ≠ pending.** `applyPlan` returns `(converged, stalled)`. Stalled means nothing was sent
   and nothing will be until something external changes — managing player offline, every toggle in
   `SEND_BACKOFF_SECONDS` hold. `cs.pending` is set from actively-retrying pals only; a stalled camp
   drops to the budgeted path instead of enumerating its whole roster every tick for 120s.
3. **No closures in hot pcalls.** `pcall(f, arg)` allocates nothing, `pcall(function() ... end)`
   allocates per call. `S.alive` alone runs thousands of times per enumeration burst. The named
   helpers in shared.lua (`_isValid`, `_toString`, `_fullName`, `_className`) and engine.lua
   (`_workId`, `_palKeyOf`) exist for this and nothing else — the protected call still wraps the
   member lookup as well as the call, so crash semantics are identical.

4. **Nothing may scale with the pending-work QUEUE.** See the runaway-queue section below. The
   queue is unbounded, so any per-job cost is an unbounded per-tick cost on the game thread.

Interface half, while the work screen is open (500ms poll × ~13 cells per visible row):
`IsBattleSettingMode` and `BindedSuitability` are fixed for the life of a binding and are cached in
`cellFacts`, dropped by `invalidateCells()` like every other per-cell cache. The vanilla-checkbox
hide is stamped with `visGen`, which bumps on rebind (the only thing that can re-show it) and on a
5s safety timer, instead of re-asserting on every cell every tick.

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
  cycle logic. Display data source since 1.1.0: server→client sync over
  `Notify_RequestClient_int32` (primary; works on dedicated servers), with the local
  priorities.lua read kept as a same-machine bootstrap/fallback.
  ⚠ Two corrections to what this bullet used to say. (a) There is no separate `PalPriorityUI` mod
  since 1.3.0 — the interface is `ui.lua` inside the one package, and `main.lua` refuses to boot if
  the old mod is still installed. (b) The interface is **not** display-only: it originates
  `PrioMod_Dir` and `PrioMod_Ping` over `Request_Server_int32`, hides the vanilla checkboxes, and
  injects TextBlocks. "Display-only" described a design that predates click attestation.

## Write routing (1.1.0, multi-guild correctness)
The supervisor's off-list writes execute the toggle RPC on a PLAYER's server-side
component — and the game may scope authority per guild, so the caller must be a player
who manages that pal. Design: each config entry persists `owner = <PlayerUId hex>` (the
player whose attested click created/last cycled it — captured for free inside hook B).
A runtime registry maps owner → live component (learned from mod traffic, plus an
ON-DEMAND controller walk — `APalPlayerController:GetPlayerUId()` + `.Transmitter.BaseCamp`
— so shaping resumes when the owner merely connects). That walk is **not periodic**: it happens
only on a caller miss, never on a timer, exactly as the registry contract above states. This
sentence used to say "periodic controller scan", contradicting both that contract and
`registry.lua`. Writes route through the pal's
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
- `PrioReset` — clear everything before a full-state batch. The server sends it ahead of every
  full push (`engine.lua`) and the interface handles it (`ui.lua`). It was missing from this list;
  a reimplementation from these notes alone would have dropped it and left stale rows on screen.
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

**Caveat added 2026-07-26 — the attribution is probably WRONG.** The evidence above says the call
"never once succeeded (always a caught error on our build)". A *caught Lua* error means UE4SS
refused the call at the marshalling layer, before native code ran — so it cannot have produced a
native AV. The proven crash cause on this build is the SoftObjectProperty rule below. Practical
conclusion is unchanged (the call does not work, do not use it), but "it crashes" is not the
reason, and it should not be treated as evidence that assign-slot enumeration is inherently
unsafe. If slot counts are ever needed, probe a different route rather than assuming this one
poisoned the whole area.

## Runaway haul queue — the 1.3 transport bug (2026-07-26)
Reported symptom: a lategame station producing several items/sec makes transport pals "come to a
halt and behave oddly", with almost nothing hauled.

**The trigger is production rate crossing HAULING CAPACITY, not items/sec on its own.** Below that
line the unfilled-haul queue sits at ~0 and nothing is wrong. Above it the queue grows linearly and
never settles — simulated at 3 items/s with 11 haulers: ~980 tracked jobs after 10 minutes, ~2900
after 30, no steady state. Three costs scaled with that queue, all on the game thread, which is
where pal AI runs — so the backlog starved the pals that would have cleared it (a feedback loop,
hence "explodes"):

1. `jobs` grew without bound, one entry per pending work object, each retaining a UObject wrapper.
2. `pruneJobs` full-scanned it every tick with a pcall'd native `IsValid()` per entry.
3. Hook A re-pulses every 1-4s per unfilled job, so the handler ran at roughly queue/2.5 per
   second — ~390/s at 10 minutes, ~1170/s at 30 — each paying `workKey()`'s native `GetWorkId`
   plus a 32-char `string.format` allocation.

**Guards added (engine.lua):** `DEMAND_CAP` bounds the jobs table; at the cap a pulse only stamps a
saturation timestamp and `pruneJobs` holds the count there instead of draining a queue it stopped
enumerating. `PULSE_BUDGET` bounds the hook, checked before any game access at all, so surplus
pulses cost one `os.time()` and two integer ops. Simulated at 8 items/s: 7753 tracked jobs → 18,
and per-second mod work down ~8.7×, flat over time instead of growing.

⚠ **"`DEMAND_CAP` bounds the jobs table" was only true for jobs with a RESOLVABLE type** (fixed
2026-07-26). The cap test sat inside `if t then`, and unresolvable work contributes no demand at
all (`bumpDemand` no-ops on a nil type), so the count the cap reads could never rise for it — the
one category with no ceiling whatsoever, each entry holding a UObject wrapper and costing a native
`alive()` in every prune sweep. Unmapped stations are reachable in ordinary play, so this was the
guard's live hole. There is now a separate `unresolved[campId]` counter capped the same way.

`DEMAND_CAP` is behaviour-preserving *for a single plan* because the allocator can never hand out
more claims for one type than there are pals in the camp. Verified by running the real
`planner.lua`: demand 16 and demand 999 produce byte-identical allocations for a 12-pal roster.
(An earlier draft of this paragraph claimed the sweep covered "16, 32, 40, 100 and 5000"; the
engine's own comment records the two-value version, and the two write-ups cannot both be the
experiment that was run. Treat the two-value claim as the real one.)

⚠ Behaviour-preserving *per plan* is not the same as behaviour-preserving. `isSaturated` requires
`d[t] >= DEMAND_CAP`, so the cap is precisely what pins a flooded count at 32 and what makes the
held set drain in a single prune once saturation lifts. It changes the **timing and shape** of
demand transitions, and demand timing is what drives fencing.

**Two things this section used to defend as "NOT bugs". Both defences rest on a premise that does
not hold, re-examined 2026-07-26 against the live idle-transporter reports:**

- *The whole roster gets dragooned onto transport when the queue is huge.* The argument was that
  `remaining[t] = queue` is self-tuning, so it only takes the whole roster when the whole roster is
  genuinely needed — and a fixed ceiling really is harmful (at 4 items/s a base needs ~10.7
  haulers; any ceiling ≤ 8 turns a backlog of 10 into 1805). The ceiling conclusion stands. The
  self-tuning claim does not: **queue length is a biased estimator of need.** There is no
  fill signal, so a job a pal already picked up keeps counting as unfilled for `JOB_FRESH_SECONDS`,
  and the pal working it is *also* claimed (for free, costing no slot) — the same job inflating the
  count twice. In a base where hauls turn over faster than 6s the count is permanently high, so
  more pals are fenced to Transport-only than there are hauls, and the surplus have every other
  work type disabled and nothing to do. That is the reported idle, and it is caused by the estimate,
  not by the roster size.
- *`demandMask` discards counts while allocation is count-sensitive.* The rate-limiting rationale
  is real: a ±1 wobble re-masking a pal every second means ~60 work-cancelling toggles a minute.
  But the wobble is an artefact of **sampling** — capped counts, a 120/s global pulse budget, and
  6s decay — not of the base. Read the director's queue directly and the count stops wobbling, at
  which point presence-only detection is no longer buying anything and is instead the reason a
  second priority-1 job waits up to `VERIFY_SECONDS` for a pal. Do not tighten this while the
  estimator is still the source (that unleashes the toggle storm, and stacking hysteresis on top is
  what produced 15-25s of idle pals — see `JOB_FRESH_SECONDS`). Tighten it *with* the source change,
  plus a per-pal re-mask dwell.

Also settled: `ceil(queue / itemsPerTrip)` as a crew-sizing rule is strictly *worse* than raw queue
length (holds a larger backlog for the same crew), so per-pal carry capacity does not belong in the
demand→claims conversion. Capacity still matters for *which* pals get picked, and that is already
implemented — the candidate sort is keyed on `GetWorkSuitabilityRankWithCharacterRank`.

Unmeasured in-game: the queue depths and hook rates above are simulated. `probe/TransportLoadProbe/`
measures them live.

## Idle transporters + starved priorities — root cause (2026-07-26)

Two reports: transport pals standing idle in high-throughput hauling bases, and low-priority work
being done while high-priority work sits unfilled. **One root cause.** The mod never asks the game
what work is pending; it reconstructs a guess from hook A through four lossy stages (global
120/s pulse budget, 6s decay with **no fill signal**, cap-plus-saturation-hold, presence-only
change detection). Over-count fences more pals onto Transport-only than there are hauls and the
surplus have everything else disabled — the idle. Under-count makes high-priority work invisible,
so nothing is disabled and vanilla picks by proximity — the starvation.

Three further idle causes are independent of demand and were fixed the same day:
- camp discovery regression (see the camps bullet above);
- `refreshManaged` deleted a pal's priority from disk on a single failed `HasWorkSuitability` read
  out of thirteen — only a *total* read failure was guarded;
- the unmodded-toggle release path discarded `readOffMask`'s ok flag. A failed read reads as
  "nothing is off", so no re-enable was ever sent, and the config was dropped anyway — leaving the
  pal wearing its fence with nothing left to remove it.

Also fixed: the send backoff suppressed ENABLE writes as well as DISABLE (a retry limiter causing
the idle it was meant to prevent) and survived plan changes; `workKey` fell back to `tostring(w)`,
which varies per wrapper, so the same job was counted repeatedly.

**`CYCLE_MODE` is gone, not fixed.** Its `false` branch — documented as "binary semantics" — could
never assign `step`, so every toggle fell through to the release path and un-configured the pal.
There was no binary behaviour to preserve.

**Suitability 9 (OilExtraction) has no mapping at all.** No `EPalWorkType` value maps to it and no
`STATION_SUIT` entry produces it, so oil-rig work is invisible to the tracker and an oil priority
set in the UI is silently inert. F8 in `TransportLoadProbe` is how to capture the missing value.

The redesign these lead to — an idle pal asks a base-wide overseer, which decides from whole-colony
state and answers with an off-list mask — is gated on the F5 director probe above.

## Director & work internals — header/source verification (2026-07-26)

Tags: **HEADER-VERIFIED** = three independent sources agree (PalworldModdingKit headers @
`62fad41`, byte-identical to current main; a Dumper-7 SDK dump; the game's own `.usmap` reflection
mappings). **SOURCE-VERIFIED** = read in the UE4SS source at `c838a8a`, the exact commit the
Okaetsu Palworld release builds — that fork carries zero source changes against upstream, the
release ships only a `MemberVariableLayout.ini`. **COMMUNITY-VERIFIED** = a shipping mod does it
live on this build. **RUNTIME-UNVERIFIED** = still needs the F5 session.

### What the director actually exposes — HEADER-VERIFIED

All three are UPROPERTY, Transient, NOT replicated, server-only.

| Field on `UPalBaseCampWorkerDirector` | Verdict |
| --- | --- |
| `RequiredAssignWorks : TArray<FPalBaseCampWorkAssignRequest>` | **Length only, permanently.** The element struct has **zero reflected members** — 0x30 of padding in the SDK dump, `propCount=0` in the usmap. `GetArrayNum()` extracts 100% of the information the array carries. |
| `WaitingWorkerIndividualIds : TArray<FPalInstanceID>` | **The idle trigger.** `FPalInstanceID` is fully reflected (`PlayerUId : FGuid`, `InstanceId : FGuid`, `DebugName : FString`) and the array holds structs by value, not object pointers — so entries yield the engine's palKey directly. |
| `WorkerTasks` | **Not a work queue.** `UPalBaseCampWorkerTaskBase` is near-empty and its task-type enum is `{Undefined, IgnitionTorchAtNight}`: scheduled base chores (lighting torches at night), not per-worker state. |

The director's replication list covers only `CharacterContainer` and `CurrentBattleType`, so those
two arrays read **empty on a client**. The engine only runs with authority, so this costs nothing —
but a probe run on the wrong machine reports zeros, and that is the wrong machine, not a failure.

`RequiredAssignWorks` drain semantics (drains-on-assign vs holds-until-complete) are
**UNRESOLVED** — every cpp body in the kit is an empty stub. Structural hints (the request-struct
vocabulary, no OnAssign handler on the director, the tick divisor
`UPalGameSetting.BaseCampWorkerDirectorTickForAssignWorkByCount`) weakly favour drains-on-assign.
Moot for the mod either way: the elements are unreadable.

### Per-slot occupancy — HEADER-VERIFIED, and it replaces `GetWorkAssignInfo`

The banned out-param getter was never the only route to slot occupancy. All of the following is
UPROPERTY and Replicated on `UPalWorkBase`:
- `AssignLocations : TArray<FPalWorkAssignLocalLocation>` — the slots themselves.
- `AssignRepInfoArray : FPalFastWorkAssignRepInfoArray` (an `FFastArraySerializer`) →
  `.Items : TArray<FPalWorkAssignRepInfo>`, each element carrying `LocationIndex : int32` and
  `WorkAssign : UPalWorkAssign*`.
- `UPalWorkAssign` exposes `HandleId`, `AssignedIndividualId : FPalInstanceID`,
  `State : EPalWorkWorkerState {None, Reserve, Working, Leave}`, `bFixed`, and
  `WorkingState : EPalWorkWorkerWorkingState {Wait, ApproachTo, Working, WaitForWorkable}`.

That is a real fill signal — the thing the demand estimator has never had.

Also on `UPalWorkBase`, all UPROPERTY + Replicated: `AssignDefineDataId : FName`,
`OverrideWorkType`, `BaseCampIdBelongTo : FGuid`, and the work GUID as a private-but-reflected
property named **`ID`**. There is **no property named `WorkId`** — `GetWorkId()` / `GetId()` are
BlueprintPure UFUNCTIONs wrapping `ID`. `RequiredWorkAmount` and `AutoWorkSelfAmountBySec` live on
the subclass `UPalWorkProgress`, both UPROPERTY + Replicated.

### `UPalWorkProgressManager` — the game's own tables — HEADER-VERIFIED

A `UPalWorldSubsystem` holding three plain Transient UPROPERTY TMaps:
- `WorkMap_InServer : TMap<FGuid, UPalWorkBase*>` — the game's registry of every live work.
- `WorkAssignDefineMap : TMap<FName, FPalWorkAssignDefineData>` — keyed by `AssignDefineDataId`;
  the row carries `WorkSuitability`, `WorkType`, `WorkerMaxNum`, `WorkSuitabilityRank`. **This is
  the game's own station→suitability table.** It would fix the OilExtraction hole generically
  instead of by hand-maintained map, and `WorkerMaxNum` is a real slot count.
- `WorkTypeAssignPriorityMap : TMap<EPalWorkType, int32>`.

### Character-side idle signals — HEADER-VERIFIED
`IsAssignedToAnyWork()`, `GetWorkAssign()`, `GetWork()` and `GetWorkId()` are
BlueprintCallable+BlueprintPure on **`UPalCharacterParameterComponent`** — an ActorComponent, NOT
the `UPalIndividualCharacterParameter` a container slot hands out. F6 tries them on the individual
parameter, so "not callable here" in that dump is the EXPECTED result, not a dead end; the right
object is the character's parameter component. `GetCurrentWorkSuitability()` is on
`UPalIndividualCharacterParameter` (what the engine reads today), with static
`UPalUtility.GetCurrentWorkSuitability(Character)` as the fallback.

### Dead ends, crossed off — HEADER-VERIFIED
- **OilExtraction (suitability 9) has no `EPalWorkType`** in any header. The mapping is
  data-driven through `WorkAssignDefineMap`, which is the generic fix; hand-mapping via
  `STATION_SUIT` stays the fallback.
- The 18 `PalOilrig*` classes are raid/combat content, unrelated to base oil work.
- `EPalWorkType.DedicatedWork01-10` appear nowhere in the source tree except their own declaration.
- Classes that DO NOT EXIST (stop looking for them): `UPalWorkAssignManager`,
  `PalWorkProgressInfo`, `PalWorkerDirector`, `BP_PalBaseCampWorkerDirector`.

### How Lua may touch any of it — SOURCE-VERIFIED (UE4SS @ `c838a8a`)

- **A TArray property read returns a LAZY wrapper** with no element access. `#arr` and
  `arr:GetArrayNum()` both compile to a bare `FScriptArray::Num()` read — the cheapest and safest
  operations available, and the offsets they depend on (`FArrayProperty::Inner`,
  `FProperty::ElementSize`, `Offset_Internal`) are among the 39 sections explicitly corrected by
  the shipped Palworld `MemberVariableLayout.ini`.
- **`TArray:ForEach` carries an author-acknowledged crash bug**, unfixed since v2.5.2 (2023) and
  present in this build. The TODO sits at the element-push site: *"Fix crash that occurs here. It
  appears that the Lua stack is getting corrupted somehow, or lua_object is getting GC'd by Lua.
  It seems to only affect large arrays"*. Separately, ForEach snapshots the data pointer and the
  element count ONCE before the loop and runs Lua between elements, so an array the game
  reallocates or shrinks mid-iteration leaves it walking a dangling pointer — and the director's
  queue is exactly that kind of array. Elements arrive as `RemoteUnrealParam` (needs `:get()`),
  and `IsValid()` is *deliberately deleted* on that type, so ForEach elements cannot be
  validity-checked at all. Early termination does work: a callback returning `true` breaks the
  loop (merged Oct 2025, in this build).
- **An out-of-range `arr[i]` READ MUTATES the game's array.** Read and write share one
  implementation that calls `AddZeroed` for any out-of-range index, so an out-of-bounds *read*
  grows the live array with zeroed elements. Every index loop must be bounded by a
  `GetArrayNum()` captured *immediately* before it. `arr[i]` returns structs as `UScriptStruct`
  userdata directly (no `:get()`) and reads through to live struct memory; a missing field raises
  a **catchable** Lua error.
- **The Lua-side index base (0- or 1-based) is undocumented upstream** — RUNTIME-UNVERIFIED, and
  it must be measured before any index loop may run, precisely because of the growth hazard above.
  `TransportLoadProbe` F5 measures it on a non-empty array (where index 0 is in range under a
  0-based build and below the range under a 1-based one, so it cannot reach `AddZeroed`) and gates
  every walk on the result.
- **pcall is genuinely protective for the non-AV class**: unsupported property types and missing
  fields raise catchable Lua errors via `luaL_error` inside a protected call. Only real memory
  faults are uncatchable.
- **TMap access is the biggest open question.** `push_mapproperty` exists and is defensive
  (validates its pushers up front, skips invalid indices) and no crash issue has ever been filed
  against it — but the Lua-side TMap API surface (key lookup? iteration?) is undocumented.
  RUNTIME-UNVERIFIED; F5 tries both against `WorkAssignDefineMap` and `WorkMap_InServer` and
  reports which operations work.
- **FString reads are the documented weak point** on layout-modified engines (open issue #1250).
  That is why the probe reads `FPalInstanceID.PlayerUId` / `InstanceId` and never `DebugName`.
- **The SoftObjectProperty rule is ours, not upstream's** — zero upstream issues mention it. Best
  inference: the soft-object pusher is the only one that copies a UE value struct *by value*
  against a hardcoded layout, and `FSoftObjectPtr` / `FSoftObjectPath` are NOT among the types
  `MemberVariableLayout.ini` can correct. The rule stands (crash rule #2 below).
- **`UnregisterHook(UFunctionName, PreId, PostId)`**: unregistering from inside a firing callback
  is officially sanctioned (the docs example does exactly that). Removal is *deferred* — an atomic
  flag is set and the actual removal happens after the callback completes, behind a recursive
  mutex. Caveat: open issue **#1351**, filed 2026-07-23 against this exact commit, reports a
  background-thread AV inside `UnregisterHook`. Unresolved.
- **Concurrency hazard, open issue #1345** (filed after this build's commit — the fix is NOT in
  it): `main_lua`, `hook_lua` and `async_lua` are coroutines off ONE `lua_State`, sharing one GC,
  with no lock. Async-thread Lua racing hook-thread Lua is a real hazard. Mitigation: do game
  reads inside `ExecuteInGameThread`, which is already what the engine and the probe's periodic
  sampler do.
- COMMUNITY-VERIFIED that this class is live and readable from Lua on this build:
  **PalJobsPreferred** (July 2026) hooks
  `PalBaseCampWorkerDirector:OnRequiredAssignWork_ServerInternal`, reads director properties
  (`CharacterHandleList`) and calls `w:GetWorkType()` from Lua; **EnhancedBaseLogistics** hooks
  `PalBaseCampManager:OnRegisteredNewWork_ServerInternal`.
- COMMUNITY lead, not our mechanism: `UPalGameSetting.WorkTypeAssignPriorityOrder :
  TArray<FPalWorkTypeSet>` is the game's global work-priority tier list, and Nexus mod 3964
  rewrites it wholesale. Global, not per-pal.

### Consequences for the 1.3 redesign
- `RequiredAssignWorks` is **demoted to a length**. It still gives the exact per-camp queue depth,
  and it still retires the pulse-derived estimate of *how much* is pending — for one
  `FScriptArray::Num()` read, no walk, no per-job cost — but it can never say what KIND of work is
  queued. Anything that needs a type breakdown must come from elsewhere.
- Demand architecture: hook A discovers works → the engine retains the work refs it already sees →
  the **occupancy chain** says how many slots each work has and who is in them → the **define
  map** says which suitability and how many workers a station wants, with hand-maintained
  `WORKTYPE_TO_SUIT` / `STATION_SUIT` as the fallback if TMap access does not work from Lua. That
  combination is what finally gives demand a FILL SIGNAL, which is the bias the current estimator
  has no way to correct for.
- `WaitingWorkerIndividualIds` is **the idle trigger** — a server-side list of pals waiting for
  work, whose entries yield palKeys directly, replacing the per-pal poll.
- All of it is runtime-gated on the revised **F5** in `probe/TransportLoadProbe`: index base, idle
  list palKeys, occupancy chain, TMap access. Nothing here ships before that dump exists.

## UnregisterHook — available on this build (2026-07-26)
`main.lua` used to justify always-registered hooks with "UE4SS has no reliable unhook". That is
**false for this build**: `UnregisterHook(UFunctionName, PreId, PostId)` is documented in the
shipped `ue4ss/Mods/shared/Types.lua` and used in production by `ConsoleEnablerMod`. It looked
unavailable because PalPriority wrapped `RegisterHook` in a closure that discarded the two ids it
returns. Hook A's ids are now captured. The gate-check design is kept because it is simpler and a
failed re-register would silently stop the engine — not because detaching is impossible. Whether
detaching the hot hook mid-session is *safe* is the open question; `probe/TransportLoadProbe/` F7
tests it, using its own pulse counter as the evidence.

## HARD-WON CRASH RULE #2 (session 6)
READING a SoftObjectProperty from Lua (`row.bindedSlot`) crashes natively inside UE4SS
(`push_softobjectproperty` → `FString::operator=` AV) — the crash is in the property read itself,
so alive()/pcall are useless. Never read soft-object properties on this build. Workaround: hook a
BLUEPRINT function that receives the object as a parameter (BP functions always execute through the
hookable layer) — e.g. the row's `BindFromSlot(slot)` — and capture the mapping at call time.
Cells' Outer is the GameInstance (dynamic CreateWidget), NOT their row.

**Corrected 2026-07-26 — this section used to prescribe the wrong fix.** It said to associate cells
to rows "top-down via the row's `HorizontalBox_CheckBox` children, never by Outer-walking". Both
halves are wrong, and `ui.lua:190-207` records the live result: the row's `HorizontalBox_CheckBox`
has **0 children at runtime** (the game re-parents cells after construction), so the prescribed
route is the dead end. What works, and what ships, is the cell's **Slate** parent —
`cell:GetParent()` returns the panel it actually renders in, which *does* live inside the row's
widget tree, so `GetParent()` followed by a bounded `GetOuter()` walk reaches the row. The
"never Outer-walk" rule applies only to walking Outer *from the cell itself*.

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
- `RequestFixedAssignWorkInBaseCamp_ToServer(BaseCampId, WorkId, IndividualId)` — 1.0 pin-to-station.
  **[UNUSED]** in the shipped mod; the removed force-job feature in `../attic/` is the only code
  that ever called it. Deliberately out of scope — see the Mechanism section.
- `RequestUnassignWorkInBaseCamp_ToServer(BaseCampId, WorkId, IndividualId)` — kick pal off job.
  **[UNUSED]**, same story.
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
  work (off-list writes).

⚠ This bullet used to end "…escalate with Unassign/FixedAssign RPCs for hard reassignment."
**That was never built.** Neither `RequestUnassignWorkInBaseCamp_ToServer` nor
`RequestFixedAssignWorkInBaseCamp_ToServer` appears anywhere in the shipped scripts — off-list
shaping is the only write path the mod has ever had. Per-job pinning stays deliberately out of
scope: it would make the mod own each pal's work lifecycle forever, and a missed completion signal
strands the pal. `probe/TransportLoadProbe` F9 reports whether the RPCs are reachable without
sending anything.
