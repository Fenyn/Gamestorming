using Godot;
using PF2e.MapGen;
using Ungilded.Look;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>A faint mist rising off the board's channels and off its sludge: one emitter over the
/// tiles of each kind, its count scaled to their area, in its own colour (cool over water, a
/// fainter murk over sludge).</summary>
public static class ChannelMist
{
    /// <summary>Mist puffs per tile of channel or sludge.</summary>
    private const float PuffsPerTile = 0.6f;

    public static void Place(Node3D parent, DressingContext context, PackedScene scene, Color water, Color sludge)
    {
        foreach (var role in new[] { TileRole.Water, TileRole.DifficultTerrain })
        {
            var board = context.Board;
            int x0 = int.MaxValue, y0 = int.MaxValue, x1 = int.MinValue, y1 = int.MinValue, count = 0;
            for (int y = 0; y < board.Height; y++)
                for (int x = 0; x < board.Width; x++)
                {
                    if (board.GetTile(x, y) != role) continue;
                    x0 = Mathf.Min(x0, x); y0 = Mathf.Min(y0, y); x1 = Mathf.Max(x1, x); y1 = Mathf.Max(y1, y);
                    count++;
                }
            if (count == 0 || scene.Instantiate() is not GpuParticles3D mist) continue;
            int m = context.Skirt.Margin;
            float floor = context.SkirtHeights.CenterY(new PF2eVec(x0 + m, y0 + m));
            mist.Name = $"ChannelMist_{role}";
            mist.Position = new Vector3((x0 + x1 + 1) * 0.5f, floor + 0.1f, (y0 + y1 + 1) * 0.5f);
            mist.Amount = Mathf.Max(4, Mathf.RoundToInt(count * PuffsPerTile));
            if (mist.ProcessMaterial is ParticleProcessMaterial process)
            {
                process.EmissionBoxExtents = new Vector3((x1 - x0 + 1) * 0.5f, process.EmissionBoxExtents.Y, (y1 - y0 + 1) * 0.5f);
                process.Color = role == TileRole.Water ? water : sludge;
            }
            parent.AddChild(mist);
        }
    }
}
