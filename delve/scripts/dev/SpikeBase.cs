using Godot;

namespace Delve.Dev;

/// <summary>
/// Shared harness for the headless dev spikes: the [PASS]/[FAIL] check counter and the final
/// "SPIKE RESULT" banner that gates the process exit code (the line CI/tooling greps for).
/// One Check signature — (label, ok) — replaces the per-spike copies and retires the two
/// argument-order variants that had drifted.
/// </summary>
public abstract partial class SpikeBase : Node
{
    private int _checks;
    private int _failures;

    /// <summary>Failures recorded so far (checks plus <see cref="Fail"/> calls).</summary>
    protected int Failures => _failures;

    /// <summary>Record one check: prints "[PASS]/[FAIL] label" and counts a failure on false.</summary>
    protected void Check(string label, bool ok)
    {
        _checks++;
        if (!ok) _failures++;
        GD.Print($"  [{(ok ? "PASS" : "FAIL")}] {label}");
    }

    /// <summary>Record a failure discovered outside a check (e.g. an unhandled exception path).</summary>
    protected void Fail() => _failures++;

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
}
