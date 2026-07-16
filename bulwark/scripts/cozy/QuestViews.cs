using System.Collections.Generic;

namespace Bulwark.Cozy;

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

public sealed class QuestDto
{
    public string QuestId { get; set; } = "";
    public bool Completed { get; set; }
    public int[] ObjectiveProgress { get; set; } = System.Array.Empty<int>();
}
