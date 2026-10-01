using System.Threading.Tasks;
using Godot;

namespace Delve.Dev;

public partial class HubMockSpike
{
    /// <summary>The merged hub storyboard (hub_merged.md): overview, walk, line-up, step in.</summary>
    private async Task RunStoryboard()
    {
        // (a) Overview: Aldric and Elara already wait at the gate; Tharr is hovered on his log.
        Pose("player", Slots[0], Walk.Stand, Facing.South);
        Pose("elara", Slots[1], Walk.Stand, Facing.South);
        Orbit(new Vector3(-1.0f, 0, -1.4f), 35f, 34.7f);
        await Shot("hub2_a_overview");

        // (c) Walk: Tharr rises and heads up to slot 3; Fenwick comes from the table to slot 4.
        Pose("tharr", Vector3.Zero.Lerp(Slots[2], 0.55f) + new Vector3(-1.4f, 0, 1.2f), Walk.Stride, Facing.North);
        Pose("fenwick", new Vector3(5.4f, 0, -4.2f).Lerp(Slots[3], 0.6f), Walk.Stride, Facing.West);
        Orbit(new Vector3(-1.2f, 0, -2.2f), 32f, 27.8f);
        await Shot("hub2_c_walk");

        // (d) Line-up: all four at the gate facing out, lanterns lit.
        Pose("tharr", Slots[2], Walk.Stand, Facing.South);
        Pose("fenwick", Slots[3], Walk.Stand, Facing.South);
        foreach (var lantern in _lanterns) lantern.LightEnergy = 1.2f;
        Orbit(new Vector3(-2.46f, 0, -6.78f), 30f, 23.1f);
        await Shot("hub2_d_lineup");

        // (e) Step in: the four turn to the gate and walk in pairs.
        string[] four = { "player", "elara", "tharr", "fenwick" };
        for (int i = 0; i < 4; i++)
            Pose(four[i], Slots[i].Lerp(Gate, i < 2 ? 0.7f : 0.35f), Walk.Stride, Facing.North);
        await Shot("hub2_e_step_in");
    }
}
