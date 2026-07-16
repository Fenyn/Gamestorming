using System;
using System.Collections.Generic;
using System.Linq;

namespace Bulwark.Cozy;

public sealed record QuestDefinition(string Id, string Title, QuestObjective[] Objectives);
public sealed record QuestObjective(string Description, string? TrackingItemId = null, int TargetCount = 1);

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
