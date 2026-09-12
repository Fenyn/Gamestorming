using System.Linq;
using Delve.Terrain;
using Godot;
using PF2e.Grid;
using PF2e.MapGen;

namespace Delve.Dev;

public partial class TerrainSkirtRenderSpike
{
    private void CheckTextureTransitions()
    {
        var layout = new MapLayout();
        layout.Initialize(2, 1);
        layout.Seed = 42;
        layout.SetTile(0, 0, TileRole.Ground);
        layout.SetTile(1, 0, TileRole.Ground);
        var surfaces = new[] { SurfaceType.Dirt, SurfaceType.Grass };
        using var source = Image.CreateEmpty(96, 48, false, Image.Format.Rgba8);
        source.Fill(Colors.Red);
        source.FillRect(new Rect2I(48, 0, 48, 48), Colors.Green);
        using var joined = (Image)source.Duplicate();
        GroundTextureTransitions.Blend(joined, layout, surfaces, 48);
        Check("continuous ground blends using the neighbor's palette",
            joined.GetPixel(47, 24) == Colors.Green && joined.GetPixel(24, 24) == Colors.Red);
        using var repeated = (Image)source.Duplicate();
        GroundTextureTransitions.Blend(repeated, layout, surfaces, 48);
        Check("texture transition is deterministic", joined.GetData().SequenceEqual(repeated.GetData()));
        layout.SetCornerHeights(0, 0, TileCornerHeights.Flat(8));
        using var cliff = (Image)source.Duplicate();
        GroundTextureTransitions.Blend(cliff, layout, surfaces, 48);
        Check("grass cannot bleed from the cliff foot onto its raised top",
            cliff.GetData().SequenceEqual(source.GetData()));
        layout.SetCornerHeights(0, 0, TileCornerHeights.Flat(0));
        surfaces[0] = SurfaceType.Wood;
        using var deck = (Image)source.Duplicate();
        GroundTextureTransitions.Blend(deck, layout, surfaces, 48);
        Check("wood edges keep their authored finish", deck.GetData().SequenceEqual(source.GetData()));
    }
}
