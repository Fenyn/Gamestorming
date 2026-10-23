using System;
using System.Collections.Generic;
using Ungilded.Data;
using Ungilded.Look;
using Godot;
using PF2e.MapGen.Biomes;

namespace Ungilded.Terrain;

/// <summary>The pieces of <see cref="TerrainStage"/> around the terrain itself: the look, the
/// backdrop, the wall cutaway, the tree fader and the placeholder floor.</summary>
public partial class TerrainStage
{
    /// <summary>Switch this stage's lighting setup on or off. A host that borrows another scene's
    /// ground (a dungeon-hosted fight) turns it off so the other scene's look applies.</summary>
    public void SetLookActive(bool active) => _look?.SetActive(active);

    /// <summary>Instance the biome's lighting setup, reusing the current one when the biome maps to
    /// the same scene, and fit its fog to the board.</summary>
    private void ApplyLook(string? biomeId, int width, int height)
    {
        var source = biomeId != null && Looks.TryGetValue(biomeId, out var scene) ? scene : DefaultLook;
        if (source != _lookSource)
        {
            _look?.SetActive(false);
            _look?.QueueFree();
            _look = source?.Instantiate<LookScene>();
            _lookSource = source;
            if (_look != null) AddChild(_look);
        }
        _look?.SetActive(true);
        _look?.FitBoard(width, height);
        // Board tile (0, 0) sits on the world origin; the halo shading starts past the far edge.
        RenderingServer.GlobalShaderParameterSet(LookScene.BoardRectGlobal, new Vector4(0f, 0f, width, height));
    }

    private TreeFader AddFader()
    {
        var fader = new TreeFader { Name = "TreeFader" };
        AddChild(fader);
        return fader;
    }

    /// <summary>Switch the wall cutaway on for this build: stone caps on the stubs, the biome's
    /// ground colour under the masonry that drops away.</summary>
    private void ApplyCutaway(CutawayMap map, Vector2 origin, MapThemeDefinition theme, BackdropThemeDefinition backdrop)
    {
        if (_cutaway == null)
        {
            _cutaway = new TerrainCutaway { Name = "Cutaway" };
            AddChild(_cutaway);
        }
        _cutaway.Configure(map, origin, theme.HeightScale,
            MapMaterials.StoneTrim(theme, "cutaway_cap", backdrop.CutawayCapShade, always: false),
            MapMaterials.Build(backdrop.GroundPlaneColor, "cutaway_void"),
            MapMaterials.Wall(theme, backdrop.Skirt.WallSurface));
    }

    /// <summary>
    /// Dress the space around the board with far scenery. Reuses one backdrop node so a rebuild
    /// never stacks backdrops.
    /// </summary>
    private void ApplyBackdrop(string? biomeId, int width, int height)
    {
        if (_backdrop == null)
        {
            _backdrop = new Backdrop { Name = BackdropName };
            AddChild(_backdrop);
        }
        _backdrop.Apply(biomeId, Skirt, _skirtHeights, width, height, OutskirtsMistShader,
            _look == null ? null : ring => _look.HaloShade(ring));
    }

    /// <summary>
    /// How far a tree or vault wall rises in the halo: the biome's own <c>WallHeight</c>, so the
    /// synthesized trees match the board's. An id the map-gen registry does not carry is a content
    /// bug — say so and fall back rather than lose the scene.
    /// </summary>
    private static int WallHeightFor(string biomeId)
    {
        try
        {
            return MapGenRegistry.GetBiome(biomeId).WallHeight;
        }
        catch (Exception e) when (e is KeyNotFoundException or ArgumentException)
        {
            GD.PushWarning(
                $"[TerrainStage] No map-gen biome '{biomeId}'; halo walls use {FallbackWallHeightUnits} units.");
            return FallbackWallHeightUnits;
        }
    }

    /// <summary>
    /// Size, place and show the placeholder floor for a flat board; hide it once real terrain is up.
    /// The floor mesh is sized from the board bounds so every dimension renders correctly — grid tile
    /// (x, y) spans world x..x+1 / y..y+1, so a WxH plane sits at the board centre. The checker shader
    /// works in world space and follows automatically.
    /// </summary>
    private void ApplyFloor(int width, int height)
    {
        if (_floor == null) return;

        if (Layout != null)
        {
            _floor.Visible = false;
            return;
        }

        if (_floor.Mesh is PlaneMesh floorPlane)
            floorPlane.Size = new Vector2(width, height);
        _floor.Position = GridSpace.BoardCenter(width, height);
        _floor.Visible = true;
    }
}
