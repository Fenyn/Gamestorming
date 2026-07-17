using System.Collections.Generic;

namespace Bulwark.Quests;

public sealed record QuestView(
    IReadOnlyList<QuestEntryView> Active,
    IReadOnlyList<QuestEntryView> Completed);

public sealed record QuestEntryView(
    string QuestId,
    string Title,
    IReadOnlyList<QuestObjectiveView> Objectives,
    bool Completed);

public sealed record QuestObjectiveView(
    string Description,
    int Progress,
    int Target,
    bool Done);
