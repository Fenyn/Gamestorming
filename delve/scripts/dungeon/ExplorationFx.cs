using System.Collections.Generic;
using Delve.Fx;
using Delve.UI;
using Godot;

namespace Delve.Dungeon;

/// <summary>
/// Effects and sound slots for exploration beats. The director calls one method per beat; this node
/// decides what plays. Sound slots are AudioStreamPlayers with no stream until audio is chosen, so
/// wiring and timing are already in place.
/// </summary>
public partial class ExplorationFx : Node3D
{
    [Export] public PackedScene? DustRing { get; set; }
    [Export] public PackedScene? Sparkles { get; set; }

    /// <summary>Looping effects on each purpose's signature prop.</summary>
    [Export] public PackedScene? CampFire { get; set; }
    [Export] public PackedScene? HearthSmoke { get; set; }
    [Export] public PackedScene? BenchSparks { get; set; }
    [Export] public PackedScene? ShrineRays { get; set; }
    [Export] public PackedScene? EnginePortal { get; set; }

    /// <summary>Scale of the looping signature effects against the pack's authored size.</summary>
    [Export] public float SignatureScale { get; set; } = 0.6f;

    /// <summary>Which prop in which room carries a looping effect: one signature per purpose.</summary>
    private (RoomPurpose Purpose, string Prop, PackedScene? Scene)[] Signatures => new[]
    {
        (RoomPurpose.Refuge, "camp", CampFire),
        (RoomPurpose.Kitchen, "hearth", HearthSmoke),
        (RoomPurpose.Workshop, "tool_bench", BenchSparks),
        (RoomPurpose.Shrine, "shrine", ShrineRays),
        (RoomPurpose.WardChamber, "ward_engine", EnginePortal),
        (RoomPurpose.WardChamber, "beacon", EnginePortal),
    };

    /// <summary>Places the room's signature effect on top of its signature prop. Returns the number placed.</summary>
    public int Dress(Node3D room, RoomPurpose purpose, IReadOnlyList<RoomProp> props)
    {
        int placed = 0;
        foreach (var (signature, kind, scene) in Signatures)
        {
            if (signature != purpose) continue;
            foreach (var prop in props)
            {
                if (prop.Kind != kind) continue;
                if (!Instant)
                {
                    var effect = EffectBurst.Ambient(scene, room, new Vector3(prop.X, prop.Height, prop.Y), SignatureScale);
                    // The ward engine glows in the one ward teal, never a second cyan.
                    if (purpose == RoomPurpose.WardChamber) EffectBurst.Tint(effect, UiColors.Ward);
                }
                placed++;
                Dressed++;
                break;
            }
        }
        return placed;
    }

    /// <summary>Scale of the dust ring at the doorway the party arrives through.</summary>
    [Export] public float ArrivalDustScale { get; set; } = 0.5f;

    /// <summary>Scale of the dust a landing door shutter throws up.</summary>
    [Export] public float ShutterDustScale { get; set; } = 0.4f;

    /// <summary>Sparkles rise from every lamp of a cleared room, this far above it.</summary>
    [Export] public float SparkleLift { get; set; } = 1.2f;

    [Export] public float SparkleScale { get; set; } = 1.2f;
    [Export] public int SparkleAmount { get; set; } = 32;
    [Export] public float SparkleExplosiveness { get; set; } = 0.7f;

    [Export] public AudioStreamPlayer RoomEnterSound { get; set; } = null!;
    [Export] public AudioStreamPlayer ShutterSound { get; set; } = null!;
    [Export] public AudioStreamPlayer WardSound { get; set; } = null!;
    [Export] public AudioStreamPlayer ClearedSound { get; set; } = null!;
    [Export] public AudioStreamPlayer RestSound { get; set; } = null!;
    [Export] public AudioStreamPlayer DescendSound { get; set; } = null!;

    /// <summary>Skips every effect; sound slots still count, for spikes.</summary>
    public bool Instant { get; set; }

    /// <summary>Number of beats played, for spikes.</summary>
    public int Played { get; private set; }

    /// <summary>Signature effects placed since the node entered the tree, for spikes.</summary>
    public int Dressed { get; private set; }

    public void RoomArrived(Node3D room, Vector3 entryDoorway)
    {
        Beat(RoomEnterSound);
        if (!Instant) EffectBurst.Play(DustRing, room, entryDoorway, ArrivalDustScale);
    }

    /// <summary>Dust at each doorway once the shutters land, <paramref name="landsAfter"/> seconds on.</summary>
    public void ShuttersOpened(Node3D room, IReadOnlyList<Vector3> doorways, double landsAfter)
    {
        if (Instant) { Beat(ShutterSound); return; }
        GetTree().CreateTimer(landsAfter).Timeout += () =>
        {
            if (!IsInstanceValid(room) || !room.IsInsideTree()) return;
            Beat(ShutterSound);
            foreach (var doorway in doorways) EffectBurst.Play(DustRing, room, doorway, ShutterDustScale);
        };
    }

    public void RoomCleared(Node3D room, IReadOnlyList<Vector3> lamps)
    {
        Beat(ClearedSound);
        if (Instant) return;
        foreach (var lamp in lamps)
            EffectBurst.Tint(EffectBurst.Play(Sparkles, room, lamp + Vector3.Up * SparkleLift, SparkleScale, SparkleAmount, SparkleExplosiveness),
                UiColors.Accent);
    }

    public void WardChanged() => Beat(WardSound);
    public void Rested() => Beat(RestSound);
    public void Descended() => Beat(DescendSound);

    private void Beat(AudioStreamPlayer slot)
    {
        Played++;
        if (slot.Stream != null && !Instant) slot.Play();
    }
}
