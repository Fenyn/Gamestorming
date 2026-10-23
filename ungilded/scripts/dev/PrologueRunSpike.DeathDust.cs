using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using Ungilded.Combat;
using Ungilded.Fx;

namespace Ungilded.Dev;

/// <summary>
/// The creature death effect, recorded through the effect watch (PrologueRunSpike.FxWatch.cs). Every
/// <see cref="DeathDust"/> must stand at a creature's feet in the Fx group with the creature's erosion,
/// at least one band playing and the stand-in hidden. When its sweep has run the creature's body must
/// be fully eroded (death_progress 1) and hidden, and the effect frees itself after its Lifetime. No
/// hero disintegrates, Encounter 3's five rats send one each, and no node of the removed death poof is
/// ever added. Rendered, the first death of Encounter 1 is saved at <see cref="DeathShotSeconds"/> and
/// <see cref="DeathLateShotSeconds"/>, at full viewport size.
/// </summary>
public partial class PrologueRunSpike
{
    [Export] public float DeathShotSeconds { get; set; } = 0.3f;
    [Export] public float DeathLateShotSeconds { get; set; } = 0.8f;

    /// <summary>Game seconds past the end of the sweep at which the body is read.</summary>
    [Export] public float ErosionReadSlack { get; set; } = 0.05f;

    /// <summary>Encounter 3's rats, each of which must send one death dust.</summary>
    [Export] public int Encounter3Rats { get; set; } = 5;

    /// <summary>Root name of the death effect this one replaced.</summary>
    private const string RemovedDeathEffect = "DeathPoof";

    private int _removedDeathEffects;

    private sealed class DustRecord : FxRecord
    {
        public DustRecord(DeathDust node, int encounter) : base(node, encounter)
        {
            Sweep = node.SweepSeconds;
            HasErosion = node.Erosion != null;
        }

        public float Sweep { get; }
        public bool HasErosion { get; }
        public int Bands { get; set; }
        public int Particles { get; set; }
        public bool PreviewHidden { get; set; }
        public bool OnHero { get; set; }
        public float ProgressAtEnd { get; set; } = -1f;
        public bool BodyHiddenAtEnd { get; set; }

        /// <summary>The body read again <see cref="ErosionLateSeconds"/> after the sweep.</summary>
        public float ProgressLate { get; set; } = -1f;
        public bool BodyHiddenLate { get; set; }

        /// <summary>Longest frame delta between the spawn and the first read, game seconds.</summary>
        public double LongestDelta { get; set; }
    }

    /// <summary>Game seconds after the sweep at which the body is read a second time.</summary>
    [Export] public float ErosionLateSeconds { get; set; } = 0.5f;

    private readonly List<DustRecord> _dusts = new();

    private void NoteDeathDust(DeathDust dust)
    {
        var record = Track(new DustRecord(dust, _runner.CurrentEncounter)
        {
            PreviewHidden = !dust.GetNode<Node3D>("%Preview").Visible,
        });
        foreach (string name in DeathDust.BandNames)
        {
            var band = dust.GetNode<GpuParticles3D>(name);
            if (!band.Visible || !band.Emitting) continue;
            record.Bands++;
            record.Particles += band.Amount;
        }
        record.OnHero = record.Unit?.CreatureStats == null;
        _dusts.Add(record);
        _ = ReadErosion(record, FxToken(record.Unit));

        if (record.Encounter == 1 && _dusts.Count(d => d.Encounter == 1) == 1 && !Headless)
            _ = CaptureAfterSpawn(record, "the first Encounter 1 death",
                ("death_dust.png", DeathShotSeconds), ("death_dust_late.png", DeathLateShotSeconds));
    }

    /// <summary>Read the creature's body once its sweep has run, and again later. The first read waits
    /// the longest frame of the window on top: in one run the token missed a 137 ms frame (a capture
    /// frame at the end of Encounter 2) that the dust and this clock counted, so its erosion ended that
    /// much later.</summary>
    private async Task ReadErosion(DustRecord record, UnitVisual3D? token)
    {
        while (_gameClock - record.SpawnedAt < record.Sweep + ErosionReadSlack + record.LongestDelta)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
            record.LongestDelta = System.Math.Max(record.LongestDelta, GetProcessDeltaTime());
        }
        if (token == null || !IsInstanceValid(token)) return;
        record.ProgressAtEnd = token.DeathProgress;
        record.BodyHiddenAtEnd = !token.BodyShown;
        while (_gameClock - record.SpawnedAt < record.Sweep + ErosionLateSeconds)
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        if (!IsInstanceValid(token)) return;
        record.ProgressLate = token.DeathProgress;
        record.BodyHiddenLate = !token.BodyShown;
    }

    private void CheckDeathDust()
    {
        foreach (var d in _dusts)
            GD.Print($"[PrologueRun] death dust E{d.Encounter} on {d.Unit?.Name ?? "?"} fx group {d.InFxGroup} "
                + $"feet gap {d.FeetGap:0.000} bands {d.Bands} particles {d.Particles} preview hidden {d.PreviewHidden} "
                + $"erosion {d.ProgressAtEnd:0.000} body hidden {d.BodyHiddenAtEnd} after the {d.Sweep:0.00} s sweep, "
                + $"{d.ProgressLate:0.000} hidden {d.BodyHiddenLate} {ErosionLateSeconds:0.0} s later, "
                + $"longest frame {d.LongestDelta * 1000:0} ms, {d.Timing}");

        var e1 = _dusts.Where(d => d.Encounter == 1).ToArray();
        int e3 = _dusts.Count(d => d.Encounter == 3);
        Check($"E1: the first rat death spawned a death dust on the rat ({e1.Length} in E1)",
            e1.Length >= 1 && e1[0].Unit is { CreatureStats: not null });
        Check($"E3: each of the {Encounter3Rats} rats sent one death dust ({e3})", e3 == Encounter3Rats);
        CheckWith("no hero disintegrated", _dusts.All(d => !d.OnHero), Units(_dusts.Where(d => d.OnHero)));
        CheckWith("every death dust joined the Fx group at its creature's feet",
            _dusts.All(DustOnToken), Units(_dusts.Where(d => !DustOnToken(d))));
        CheckWith("every death dust carried the creature's erosion, played a band and hid its stand-in",
            _dusts.All(DustPlays), Units(_dusts.Where(d => !DustPlays(d))));
        CheckWith("every eroding body reached death_progress 1 and hid by the end of its sweep (plus its longest "
            + $"frame) and was still gone {ErosionLateSeconds:0.0} s later",
            _dusts.All(BodyGone), Units(_dusts.Where(d => !BodyGone(d))));
        CheckWith($"every death dust freed itself after its Lifetime of game time, within {FxLifetimeSlack:0.0} s",
            _dusts.All(d => d.Freed && d.LivedItsLifetime(FxLifetimeSlack)),
            Units(_dusts.Where(d => !d.Freed || !d.LivedItsLifetime(FxLifetimeSlack))));
        Check($"no {RemovedDeathEffect} node was added ({_removedDeathEffects})", _removedDeathEffects == 0);
    }

    private bool DustOnToken(DustRecord d) => d.InFxGroup && d.FeetGap <= FxFeetTolerance;

    private static bool DustPlays(DustRecord d) => d.HasErosion && d.Bands > 0 && d.PreviewHidden;

    private static bool BodyGone(DustRecord d)
        => d.ProgressAtEnd >= 0.999f && d.BodyHiddenAtEnd && d.ProgressLate >= 0.999f && d.BodyHiddenLate;
}
