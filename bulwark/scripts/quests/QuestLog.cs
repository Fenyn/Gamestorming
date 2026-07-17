using System;
using System.Collections.Generic;
using System.Linq;

using Bulwark.Save;
namespace Bulwark.Quests;

/// <summary>
/// How a quest objective is completed. <see cref="Label"/> (default) and <see cref="InventoryGain"/>
/// are the pre-existing kinds — advanced imperatively by GameState's hand-wired tutorial handlers.
/// The rest are the data-driven fabric (design/tutorial_quests.md): they advance through the
/// generic choke points on <see cref="QuestLog"/> so adding a quest touches data only.
/// </summary>
public enum QuestObjectiveKind
{
    /// <summary>A plain marker objective, completed by an explicit CompleteObjective call.</summary>
    Label,

    /// <summary>Advanced by inventory gains of <see cref="QuestObjective.TrackingItemId"/> (legacy path;
    /// GameState drives the shipped tutorial quests through it directly).</summary>
    InventoryGain,

    /// <summary>Counter keyed by an event id (<see cref="QuestObjective.Key"/>), advanced by
    /// <see cref="QuestLog.RecordEvent"/> toward <see cref="QuestObjective.TargetCount"/>.</summary>
    EventCount,

    /// <summary>Completed by the FIRST occurrence of an event id (<see cref="QuestObjective.Key"/>).</summary>
    EventOnce,

    /// <summary>Completed when a story flag (<see cref="QuestObjective.Key"/>) resolves true through
    /// the host's flag resolver (real flags + derived families).</summary>
    Flag,

    /// <summary>Completed by delivering items from a named set (<see cref="QuestObjective.Key"/>) via
    /// <see cref="QuestLog.RecordDelivery"/> (the Give-Fenwick-3-crops interaction).</summary>
    Deliver,
}

/// <summary>
/// One quest definition. <paramref name="StartWhen"/> distinguishes the two families: null =
/// hand-wired (the four shipped tutorial quests, started/completed by GameState's explicit switch);
/// non-null = DATA-DRIVEN (the arc quests) — auto-started when every <paramref name="StartWhen"/>
/// flag resolves true and auto-completed when every non-<see cref="QuestObjective.Optional"/>
/// objective is done. Flags are resolved through the host (real + derived, incl.
/// <c>quest_&lt;id&gt;_complete</c>), so chain conditions ("quest 5 when 1 AND 2 complete") are pure data.
/// </summary>
public sealed record QuestDefinition(string Id, string Title, QuestObjective[] Objectives, string[]? StartWhen = null);

/// <summary>
/// One quest objective. Positional shape (Description, TrackingItemId, TargetCount) is preserved for
/// the shipped tutorial quests; the arc quests use the static factories which set <see cref="Kind"/>
/// / <see cref="Key"/> / <see cref="Optional"/>. An <see cref="Optional"/> objective displays and
/// ticks but never gates its quest's auto-completion (guidance steps like "Speak with Arkus").
/// </summary>
public sealed record QuestObjective(
    string Description,
    string? TrackingItemId = null,
    int TargetCount = 1,
    QuestObjectiveKind Kind = QuestObjectiveKind.Label,
    string? Key = null,
    bool Optional = false)
{
    /// <summary>Count objective driven by an event key (e.g. combat_victory ×2, item_sold ×3).</summary>
    public static QuestObjective CountEvent(string description, string eventKey, int count, bool optional = false)
        => new(description, TargetCount: count, Kind: QuestObjectiveKind.EventCount, Key: eventKey, Optional: optional);

    /// <summary>One-shot objective completed by the first occurrence of an event key.</summary>
    public static QuestObjective OnceEvent(string description, string eventKey, bool optional = false)
        => new(description, Kind: QuestObjectiveKind.EventOnce, Key: eventKey, Optional: optional);

    /// <summary>Objective completed when a story flag (real or derived) resolves true.</summary>
    public static QuestObjective OnFlag(string description, string flagId, bool optional = false)
        => new(description, Kind: QuestObjectiveKind.Flag, Key: flagId, Optional: optional);

    /// <summary>Deliver-and-consume objective, advanced by <see cref="QuestLog.RecordDelivery"/>.</summary>
    public static QuestObjective Deliver(string description, string setKey, int count)
        => new(description, TargetCount: count, Kind: QuestObjectiveKind.Deliver, Key: setKey);
}

public sealed class QuestState
{
    public string QuestId { get; }
    public bool Completed { get; internal set; }
    public int[] ObjectiveProgress { get; }

    public QuestState(string questId, int objectiveCount)
    {
        QuestId = questId;
        ObjectiveProgress = new int[objectiveCount];
    }
}

public sealed class QuestLog
{
    private readonly Dictionary<string, QuestDefinition> _definitions = new();
    private readonly Dictionary<string, QuestState> _active = new();
    private readonly Dictionary<string, QuestState> _completed = new();

    public event Action<string>? QuestStarted;
    public event Action<string>? QuestCompleted;
    public event Action<string, int>? ObjectiveProgressed;

    public void Register(QuestDefinition def) => _definitions[def.Id] = def;

    public void RegisterAll(IEnumerable<QuestDefinition> defs)
    {
        foreach (var d in defs) _definitions[d.Id] = d;
    }

    public void StartQuest(string questId)
    {
        if (_active.ContainsKey(questId) || _completed.ContainsKey(questId))
            return;
        if (!_definitions.TryGetValue(questId, out var def))
            return;
        var state = new QuestState(questId, def.Objectives.Length);
        _active[questId] = state;
        QuestStarted?.Invoke(questId);
    }

    public void UpdateProgress(string questId, int objectiveIndex, int amount)
    {
        if (!_active.TryGetValue(questId, out var state))
            return;
        if (objectiveIndex < 0 || objectiveIndex >= state.ObjectiveProgress.Length)
            return;
        if (!_definitions.TryGetValue(questId, out var def))
            return;
        int target = def.Objectives[objectiveIndex].TargetCount;
        int before = state.ObjectiveProgress[objectiveIndex];
        state.ObjectiveProgress[objectiveIndex] = Math.Min(before + amount, target);
        if (state.ObjectiveProgress[objectiveIndex] != before)
            ObjectiveProgressed?.Invoke(questId, objectiveIndex);
    }

    public void CompleteObjective(string questId, int objectiveIndex)
    {
        if (!_active.TryGetValue(questId, out var state))
            return;
        if (objectiveIndex < 0 || objectiveIndex >= state.ObjectiveProgress.Length)
            return;
        if (!_definitions.TryGetValue(questId, out var def))
            return;
        int target = def.Objectives[objectiveIndex].TargetCount;
        if (state.ObjectiveProgress[objectiveIndex] < target)
        {
            state.ObjectiveProgress[objectiveIndex] = target;
            ObjectiveProgressed?.Invoke(questId, objectiveIndex);
        }
    }

    public void CompleteQuest(string questId)
    {
        if (!_active.TryGetValue(questId, out var state))
            return;
        state.Completed = true;
        _active.Remove(questId);
        _completed[questId] = state;
        QuestCompleted?.Invoke(questId);
    }

    public IReadOnlyList<QuestState> ActiveQuests => _active.Values.ToList();
    public IReadOnlyList<QuestState> CompletedQuests => _completed.Values.ToList();
    public bool IsActive(string questId) => _active.ContainsKey(questId);
    public bool IsCompleted(string questId) => _completed.ContainsKey(questId);

    // ===================== Data-driven fabric (design/tutorial_quests.md) =====================

    /// <summary>
    /// Start/complete every DATA-DRIVEN quest (definition with a non-null <see cref="QuestDefinition.StartWhen"/>)
    /// whose conditions currently hold, resolving flags through <paramref name="hasFlag"/> (real +
    /// derived, incl. <c>quest_&lt;id&gt;_complete</c>). Loops to a fixed point so a completion that flips a
    /// derived flag cascades into the next quest's start within the same call. Flag-kind objectives
    /// tick here; hand-wired quests (StartWhen null) are never touched. Idempotent.
    /// </summary>
    public void EvaluateConditions(Func<string, bool> hasFlag)
    {
        bool changed = true;
        while (changed)
        {
            changed = false;

            // (1) Auto-start data-driven quests whose start flags all hold.
            foreach (var def in _definitions.Values)
            {
                if (def.StartWhen == null || _active.ContainsKey(def.Id) || _completed.ContainsKey(def.Id))
                    continue;
                if (AllFlags(def.StartWhen, hasFlag))
                {
                    StartQuest(def.Id);
                    changed = true;
                }
            }

            // (2) Tick flag-kind objectives + auto-complete data-driven quests whose required
            //     (non-optional) objectives are all done.
            foreach (var state in _active.Values.ToList())
            {
                if (!_definitions.TryGetValue(state.QuestId, out var def) || def.StartWhen == null)
                    continue;

                for (int i = 0; i < def.Objectives.Length; i++)
                {
                    var obj = def.Objectives[i];
                    if (obj.Kind == QuestObjectiveKind.Flag && obj.Key != null
                        && state.ObjectiveProgress[i] < obj.TargetCount && hasFlag(obj.Key))
                    {
                        CompleteObjective(state.QuestId, i);
                        changed = true;
                    }
                }

                if (RequiredObjectivesComplete(def, state))
                {
                    CompleteQuest(state.QuestId);
                    changed = true;
                }
            }
        }
    }

    /// <summary>
    /// Choke point for event-driven objectives: advance every active quest's <see cref="QuestObjectiveKind.EventCount"/>
    /// counter (by <paramref name="amount"/>) and complete every <see cref="QuestObjectiveKind.EventOnce"/>
    /// objective matching <paramref name="eventKey"/>, then re-evaluate start/complete conditions.
    /// </summary>
    public void RecordEvent(string eventKey, int amount, Func<string, bool> hasFlag)
    {
        foreach (var state in _active.Values.ToList())
        {
            if (!_definitions.TryGetValue(state.QuestId, out var def))
                continue;
            for (int i = 0; i < def.Objectives.Length; i++)
            {
                var obj = def.Objectives[i];
                if (obj.Key != eventKey)
                    continue;
                if (obj.Kind == QuestObjectiveKind.EventCount)
                    UpdateProgress(state.QuestId, i, amount);
                else if (obj.Kind == QuestObjectiveKind.EventOnce)
                    CompleteObjective(state.QuestId, i);
            }
        }
        EvaluateConditions(hasFlag);
    }

    /// <summary>Advance a <see cref="QuestObjectiveKind.Deliver"/> objective keyed <paramref name="setKey"/>
    /// (the host validated + consumed the items), then re-evaluate conditions.</summary>
    public void RecordDelivery(string setKey, int amount, Func<string, bool> hasFlag)
    {
        foreach (var state in _active.Values.ToList())
        {
            if (!_definitions.TryGetValue(state.QuestId, out var def))
                continue;
            for (int i = 0; i < def.Objectives.Length; i++)
                if (def.Objectives[i].Kind == QuestObjectiveKind.Deliver && def.Objectives[i].Key == setKey)
                    UpdateProgress(state.QuestId, i, amount);
        }
        EvaluateConditions(hasFlag);
    }

    /// <summary>Query: an active quest's Deliver objective for <paramref name="setKey"/> — its
    /// (questId, required count) or null. The host reads the count to validate the hand-off.</summary>
    public (string QuestId, int Need)? FindDeliverObjective(string setKey)
    {
        foreach (var state in _active.Values)
        {
            if (!_definitions.TryGetValue(state.QuestId, out var def))
                continue;
            for (int i = 0; i < def.Objectives.Length; i++)
            {
                var obj = def.Objectives[i];
                if (obj.Kind == QuestObjectiveKind.Deliver && obj.Key == setKey
                    && state.ObjectiveProgress[i] < obj.TargetCount)
                    return (state.QuestId, obj.TargetCount - state.ObjectiveProgress[i]);
            }
        }
        return null;
    }

    private static bool AllFlags(string[] flags, Func<string, bool> hasFlag)
    {
        foreach (var f in flags)
            if (!hasFlag(f))
                return false;
        return true;
    }

    private static bool RequiredObjectivesComplete(QuestDefinition def, QuestState state)
    {
        for (int i = 0; i < def.Objectives.Length; i++)
            if (!def.Objectives[i].Optional && state.ObjectiveProgress[i] < def.Objectives[i].TargetCount)
                return false;
        return true;
    }

    public QuestView GetView()
    {
        var active = new List<QuestEntryView>();
        foreach (var s in _active.Values)
        {
            if (!_definitions.TryGetValue(s.QuestId, out var def)) continue;
            var objs = new List<QuestObjectiveView>();
            for (int i = 0; i < def.Objectives.Length; i++)
            {
                objs.Add(new QuestObjectiveView(
                    def.Objectives[i].Description,
                    s.ObjectiveProgress[i],
                    def.Objectives[i].TargetCount,
                    s.ObjectiveProgress[i] >= def.Objectives[i].TargetCount));
            }
            active.Add(new QuestEntryView(def.Id, def.Title, objs, false));
        }
        var completed = new List<QuestEntryView>();
        foreach (var s in _completed.Values)
        {
            if (!_definitions.TryGetValue(s.QuestId, out var def)) continue;
            var objs = new List<QuestObjectiveView>();
            for (int i = 0; i < def.Objectives.Length; i++)
            {
                objs.Add(new QuestObjectiveView(
                    def.Objectives[i].Description,
                    def.Objectives[i].TargetCount,
                    def.Objectives[i].TargetCount,
                    true));
            }
            completed.Add(new QuestEntryView(def.Id, def.Title, objs, true));
        }
        return new QuestView(active, completed);
    }

    public List<QuestDto> Capture()
    {
        var list = new List<QuestDto>();
        foreach (var s in _active.Values)
            list.Add(new QuestDto { QuestId = s.QuestId, Completed = false, ObjectiveProgress = s.ObjectiveProgress.ToArray() });
        foreach (var s in _completed.Values)
            list.Add(new QuestDto { QuestId = s.QuestId, Completed = true, ObjectiveProgress = s.ObjectiveProgress.ToArray() });
        return list;
    }

    public void Restore(List<QuestDto>? dtos)
    {
        _active.Clear();
        _completed.Clear();
        if (dtos == null) return;
        foreach (var dto in dtos)
        {
            if (!_definitions.TryGetValue(dto.QuestId, out var def)) continue;
            var state = new QuestState(dto.QuestId, def.Objectives.Length);
            for (int i = 0; i < Math.Min(dto.ObjectiveProgress.Length, state.ObjectiveProgress.Length); i++)
                state.ObjectiveProgress[i] = dto.ObjectiveProgress[i];
            state.Completed = dto.Completed;
            if (dto.Completed)
                _completed[dto.QuestId] = state;
            else
                _active[dto.QuestId] = state;
        }
    }
}
