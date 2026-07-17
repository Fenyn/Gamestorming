using Bulwark.Data;
using Godot;

namespace Bulwark.Dev;

/// <summary>
/// Headless, CI-able gate over <see cref="DataValidation.RunAll"/>: runs every cross-registry
/// referential-integrity check and FAILS (exit 1) if any violation is reported. The individual
/// <c>GD.PushError("[DataValidation] ...")</c> lines name each broken reference; this spike collapses
/// them into a single PASS/FAIL so `--headless ... res://scenes/dev/validation_spike.tscn` gates a
/// build. Needs no PF2e packs — the checks read the static Bulwark content registries + Godot resource
/// APIs directly.
/// </summary>
public partial class ValidationSpike : SpikeBase
{
    public override void _Ready()
    {
        GD.Print("==================== VALIDATION SPIKE ====================");

        int violations = DataValidation.RunAll();
        Check("DataValidation reports zero violations", violations == 0);
        if (violations > 0)
            GD.PushError($"[ValidationSpike] {violations} content-validation violation(s) — see the [DataValidation] errors above.");

        FinishAndQuit("ValidationSpike");
    }
}
