using System.Linq;
using Godot;
using Ungilded.Fx;

namespace Ungilded.Dev;

/// <summary>
/// The Treat Wounds heal effect, recorded through the effect watch (PrologueRunSpike.FxWatch.cs). After
/// Encounter 2 the Friend treats the Player: the check wants one <see cref="TreatWounds"/> on the
/// Player's token, in the Fx group, with the tall set showing and the low set hidden, its light moved
/// toward the Friend by the effect's <see cref="TreatWounds.LightTowardHealer"/>, freed after its
/// Lifetime of game time. Rendered, the first one is saved at <see cref="HealShotSeconds"/> (the strip
/// wrapped) and <see cref="HealLateShotSeconds"/> (the knot and the sparkles), at full viewport size.
/// </summary>
public partial class PrologueRunSpike
{
    [Export] public float HealShotSeconds { get; set; } = 0.5f;
    [Export] public float HealLateShotSeconds { get; set; } = 0.9f;

    /// <summary>Slack on the light's offset toward the healer, in metres.</summary>
    [Export] public float HealLightTolerance { get; set; } = 0.05f;

    /// <summary>Least cosine between the light's offset and the direction to the healer.</summary>
    [Export] public float HealLightAlignment { get; set; } = 0.95f;

    private sealed class WrapRecord : FxRecord
    {
        public WrapRecord(TreatWounds node, int encounter) : base(node, encounter)
        {
            UseLowSet = node.UseLowSet;
            Toward = node.LightTowardHealer;
        }

        public bool UseLowSet { get; }
        public float Toward { get; }
        public float BodyScale { get; set; }
        public bool TallShown { get; set; }
        public bool LowHidden { get; set; }
        public float LightOffset { get; set; }
        public float LightAlignment { get; set; }
    }

    private readonly System.Collections.Generic.List<WrapRecord> _wraps = new();

    /// <summary>Healed battle events presented after an encounter's result: a heal the Treat Wounds
    /// beat presented itself and a journal flush played again would show here.</summary>
    private readonly System.Collections.Generic.List<string> _healsAfterResult = new();

    private void WatchLateHeals(int index)
    {
        var session = _runner.Scene!.Session!;
        bool decided = false;
        session.EncounterFinished += _ => decided = true;
        session.EventPresented += evt =>
        {
            if (decided && evt.Type == PF2e.Core.BattleEventType.Healed) _healsAfterResult.Add($"E{index} {evt.Target?.Name}");
        };
    }

    private void NoteTreatWounds(TreatWounds wrap)
    {
        var record = Track(new WrapRecord(wrap, _runner.CurrentEncounter)
        {
            BodyScale = wrap.GetNode<Node3D>("%Body").Scale.X,
            TallShown = wrap.GetNode<Node3D>("%Tall").Visible,
            LowHidden = !wrap.GetNode<Node3D>("%Low").Visible,
        });
        _wraps.Add(record);

        if (FxToken(record.Unit) is { } patient && FxToken(_runner.Friend) is { } medic)
        {
            var offset = wrap.GetNode<Node3D>("%Light").GlobalPosition - wrap.GlobalPosition;
            var flat = new Vector3(offset.X, 0f, offset.Z);
            var toMedic = medic.GlobalPosition - patient.GlobalPosition;
            toMedic.Y = 0f;
            record.LightOffset = flat.Length();
            record.LightAlignment = flat.LengthSquared() > 0f && toMedic.LengthSquared() > 0f
                ? flat.Normalized().Dot(toMedic.Normalized()) : 0f;
        }

        if (_wraps.Count == 1 && !Headless)
            _ = CaptureAfterSpawn(record, "Treat Wounds",
                ("treat_wounds.png", HealShotSeconds), ("treat_wounds_late.png", HealLateShotSeconds));
    }

    private void CheckTreatWounds()
    {
        foreach (var w in _wraps)
            GD.Print($"[PrologueRun] treat wounds E{w.Encounter} on {w.Unit?.Name ?? "?"} fx group {w.InFxGroup} "
                + $"feet gap {w.FeetGap:0.000} low set {w.UseLowSet} tall shown {w.TallShown} low hidden {w.LowHidden} "
                + $"body scale {w.BodyScale:0.000} light offset {w.LightOffset:0.00} m, cos {w.LightAlignment:0.00} toward the Friend, {w.Timing}");

        var repeated = _wraps.GroupBy(w => (w.Encounter, w.Unit?.Name)).Where(g => g.Count() > 1).Select(g => $"E{g.Key.Encounter} {g.Key.Name} x{g.Count()}");
        Check($"each heal played once: one heal effect per hero per Treat Wounds, no Healed event after a result ({string.Join(", ", repeated.Concat(_healsAfterResult))})",
            !repeated.Any() && _healsAfterResult.Count == 0);

        var onPlayer = _wraps.Where(w => w.Unit == _runner.Player && w.Encounter == 2).ToArray();
        Check($"Treat Wounds after E2 spawned one heal effect on the Player ({onPlayer.Length} of {_wraps.Count})",
            onPlayer.Length == 1);
        if (onPlayer.Length == 0) return;
        var heal = onPlayer[0];
        Check("the heal effect joined the Fx group at the Player's feet", heal.InFxGroup && heal.FeetGap <= FxFeetTolerance);
        Check("the heal effect plays the tall set with the low set hidden", heal.TallShown && heal.LowHidden && !heal.UseLowSet);
        Check($"the heal light moved {heal.Toward:0.0} m toward the Friend ({heal.LightOffset:0.00} m, cos {heal.LightAlignment:0.00})",
            Mathf.Abs(heal.LightOffset - heal.Toward) <= HealLightTolerance && heal.LightAlignment >= HealLightAlignment);
        Check($"the heal effect freed itself after its Lifetime of game time ({heal.Lived:0.00} s)",
            heal.Freed && heal.LivedItsLifetime(FxLifetimeSlack));
    }
}
