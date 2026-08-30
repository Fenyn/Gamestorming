using System;
using System.Threading.Tasks;
using Delve.Autoload;
using Godot;
using PF2e.Core;
using PF2e.Events;

namespace Delve.Dev;

/// <summary>
/// Shared harness for the headless dev spikes. <see cref="_Ready"/> is the template method every
/// spike runs through: banner, DataManager resolution, the spike body, then the "SPIKE RESULT"
/// banner that gates the process exit code (the line CI/tooling greps for). A spike only writes
/// <see cref="RunSpikeAsync"/>.
///
/// The try/catch around the body is load-bearing: an exception thrown inside a fire-and-forget
/// async void run used to leave the process alive with no result line at all, which reads as a
/// hang. Now it prints FAIL and exits 1.
/// </summary>
public abstract partial class SpikeBase : Node
{
    private int _checks;
    private int _failures;

    /// <summary>Failures recorded so far (checks plus <see cref="Fail"/> calls).</summary>
    protected int Failures => _failures;

    /// <summary>Banner printed before the spike body. Override for a custom title.</summary>
    protected virtual string Banner => $"==================== {GetType().Name} ====================";

    /// <summary>Tag on the counts line. Defaults to the spike class name.</summary>
    protected virtual string Tag => GetType().Name;

    /// <summary>The spike body. The harness owns the banner, the DataManager check, error
    /// handling and the exit; this only runs checks.</summary>
    protected abstract Task RunSpikeAsync(DataManager data);

    public sealed override void _Ready() => _ = RunAsync();

    private async Task RunAsync()
    {
        GD.Print(Banner);

        var data = DataManager.Instance;
        if (data == null || !data.IsLoaded)
        {
            AbortFail($"[{Tag}] DataManager not loaded — aborting.");
            return;
        }

        try
        {
            await RunSpikeAsync(data);
        }
        catch (Exception e)
        {
            GD.PushError($"[{Tag}] Unhandled exception: {e}");
            Fail();
        }

        FinishAndQuit(Tag);
    }

    /// <summary>Record one check: prints "[PASS]/[FAIL] label" and counts a failure on false.</summary>
    protected void Check(string label, bool ok)
    {
        _checks++;
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
    }

    /// <summary>Record a failure discovered outside a check (e.g. an unhandled exception path).</summary>
    protected void Fail() => _failures++;

    /// <summary>
    /// Install the pass-through damage-reaction handler for the duration of a spike.
    /// StrikeResolver / SpellCastAction throw when damage delivery finds no handler, and three
    /// spikes each carried their own copy of this two-line install/remove pair.
    /// </summary>
    protected static IDisposable UsePassthroughReactions()
    {
        ReactionEvents.DamageReactionHandler handler =
            (src, tgt, result, applyDamage) => { applyDamage(); return Task.CompletedTask; };
        ReactionEvents.OnDamageReactionCheck += handler;
        return new Scope(() => ReactionEvents.OnDamageReactionCheck -= handler);
    }

    /// <summary>Print the counts + result banner and quit with the gating exit code.</summary>
    protected void FinishAndQuit(string tag)
    {
        GD.Print("---------------------------------------------------------");
        bool pass = _failures == 0;
        GD.Print($"[{tag}] checks: {_checks}, failures: {_failures}");
        GD.Print($"SPIKE RESULT: {(pass ? "PASS" : "FAIL")}");
        GetTree().Quit(pass ? 0 : 1);
    }

    /// <summary>Hard abort (missing content, broken precondition): error log, FAIL banner, exit 1.</summary>
    protected void AbortFail(string message)
    {
        GD.PushError(message);
        GD.Print("SPIKE RESULT: FAIL");
        GetTree().Quit(1);
    }

    /// <summary>Run an action when the scope is disposed.</summary>
    private sealed class Scope : IDisposable
    {
        private Action? _onDispose;
        public Scope(Action onDispose) => _onDispose = onDispose;
        public void Dispose() { _onDispose?.Invoke(); _onDispose = null; }
    }
}
