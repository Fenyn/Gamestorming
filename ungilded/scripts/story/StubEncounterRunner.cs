using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;

namespace Ungilded.Story;

/// <summary>Stand-in runner: logs each call and wins every encounter at once.</summary>
public sealed class StubEncounterRunner : IEncounterRunner
{
    /// <summary>Every call in order, as "prepare 1", "run 1", "release 1".</summary>
    public List<string> Calls { get; } = new();

    /// <summary>Fires with each entry as it is added to <see cref="Calls"/>.</summary>
    public event System.Action<string>? Called;

    public Task Prepare(int index)
    {
        Record($"prepare {index}");
        return Task.CompletedTask;
    }

    public Task<EncounterOutcome> Run(int index)
    {
        Record($"run {index}");
        return Task.FromResult(EncounterOutcome.Victory);
    }

    public void Release(int index) => Record($"release {index}");

    public void Skip(int index) => Record($"skip {index}");

    private void Record(string call)
    {
        Calls.Add(call);
        GD.Print($"[StubEncounterRunner] {call}");
        Called?.Invoke(call);
    }
}
