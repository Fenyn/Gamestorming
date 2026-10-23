using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using PF2e.MapGen;
using Ungilded.Content;
using Ungilded.Data;
using Ungilded.Look;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>
/// Sewer props for one board. Each prop has an architectural reason and a rule that places it:
/// torches beside passage mouths and along long unbroken walls, drain grates where water drains,
/// puddles where water comes from, slime beside the sludge, bones gathered in corners and niches,
/// rubble fallen against walls (<see cref="Placed"/> lists each with its rule). Also the drain pipes
/// pouring into the sludge and onto the floor, the Encounter 4 sigil on the far wall behind its
/// anchor, the marks an authored halo asks for (outfall pipes, a skeleton), arches and outflow over
/// the culverts, stone kerbs along the channels and drips over the puddles. Ties between equal
/// candidates hash off the layout seed, so a board always dresses the same way. Floor props stay
/// off spawn anchors (<see cref="BoardAnchors"/>); the board itself only gets flat decals, so
/// nothing stands on a tile a unit may take.
///
/// Wall props hang on any full-height wall face that looks onto the board or the halo floor near
/// it. While the camera cuts a wall down (<see cref="TerrainCutaway"/>), the props on it hide.
/// The placed sigil and the tiles under wet decals stay readable for cutscene staging.
/// </summary>
public partial class SewerDressing : LookDressing
{
    [Export] public PackedScene? TorchScene { get; set; }
    [Export] public PackedScene? SludgePipeScene { get; set; }
    [Export] public PackedScene? WaterPipeScene { get; set; }
    [Export] public PackedScene? SigilScene { get; set; }
    [Export] public PackedScene? DripsScene { get; set; }

    /// <summary>Puddle laid at the foot of each water pipe.</summary>
    [Export] public DecorSprite? PipePuddle { get; set; }

    /// <summary>Skeleton slumped against a wall at a "skeleton" mark; its size is its width.</summary>
    [Export] public DecorSprite? SlumpedSkeleton { get; set; }

    /// <summary>Degrees from upright the skeleton leans back against its wall.</summary>
    [Export(PropertyHint.Range, "0,80,1")] public float SkeletonLean { get; set; } = 30f;

    /// <summary>Floor tiles this many rings around a skeleton mark get no clutter.</summary>
    [Export] public int SkeletonClearance { get; set; } = 1;

    /// <summary>Wall faces looking onto floor this many rings out still carry props.</summary>
    [Export] public int FaceRings { get; set; } = 2;

    /// <summary>A face must rise this far above its floor to carry props, metres. Keeps them off
    /// the low pillars.</summary>
    [Export] public float MinFaceHeight { get; set; } = 1.5f;

    /// <summary>Walls shorter than this many tiles get no water pipe.</summary>
    [Export] public int WaterPipeMinWall { get; set; } = 8;

    /// <summary>Anchor whose far wall carries the sigil; boards without it get none.</summary>
    [Export] public string SigilAnchor { get; set; } = "";

    /// <summary>Sigil centre height above the floor, metres.</summary>
    [Export] public float SigilHeight { get; set; } = 1.05f;

    /// <summary>Gap between a wall prop and its wall, metres, so it never z-fights the bricks.</summary>
    [Export] public float WallInset { get; set; } = 0.03f;

    /// <summary>Height the drips fall from, metres above the floor.</summary>
    [Export] public float DripHeight { get; set; } = 4f;

    /// <summary>Wall props, grates and the sigil keep this far apart, metres.</summary>
    [Export] public float WallPropGap { get; set; } = 1.5f;

    /// <summary>Slime stain down the wall behind every pipe; its size is its width.</summary>
    [Export] public DecorSprite? PipeStain { get; set; }

    /// <summary>Mist rising off the channels and the sludge on the board, and its colour over each.</summary>
    [Export] public PackedScene? ChannelMistScene { get; set; }
    [Export] public Color WaterMistColor { get; set; } = new(0.55f, 0.66f, 0.6f, 0.09f);
    [Export] public Color SludgeMistColor { get; set; } = new(0.42f, 0.4f, 0.22f, 0.05f);

    /// <summary>Culvert arch: spring and crown height above the run, metres, and halo rings roofed.</summary>
    [Export] public float ArchSpring { get; set; } = 0.8f;
    [Export] public float ArchCrown { get; set; } = 1.5f;
    [Export] public int ArchDepth { get; set; } = 2;
    [Export] public int ArchSegmentsPerTile { get; set; } = 8;

    /// <summary>Streaks drifting out of each culvert mouth, and their colour over water and sludge.</summary>
    [Export] public PackedScene? FlowScene { get; set; }
    [Export] public Color WaterFlowColor { get; set; } = new(0.5f, 0.62f, 0.6f, 0.35f);
    [Export] public Color SludgeFlowColor { get; set; } = new(0.34f, 0.36f, 0.18f, 0.45f);

    /// <summary>Streaks ride this far above the run's surface, metres.</summary>
    [Export] public float FlowLift { get; set; } = 0.015f;

    /// <summary>Channel kerb width and height, metres, its brightness against the wall tint, and
    /// how many halo rings out it runs.</summary>
    [Export] public float KerbWidth { get; set; } = 0.12f;
    [Export] public float KerbHeight { get; set; } = 0.07f;
    [Export] public float KerbShade { get; set; } = 1.25f;
    [Export] public int KerbRings { get; set; } = 4;

    /// <summary>An opening that runs at least this many tiles off the board is a passage; a
    /// shallower one is a niche, a bay or an apse.</summary>
    [Export] public int PassageDepth { get; set; } = 3;

    private const int SaltPipe = 0x51A5;

    private Node3D? _props;
    private readonly DressLedger _ledger = new();
    private readonly HashSet<Vector2I> _wet = new();
    private readonly List<Node3D> _torches = new();

    /// <summary>The state one <see cref="Dress"/> call shares between its rules.</summary>
    private sealed record Pass(DressingContext Context, List<WallFace> Faces, WallProps Props, List<Vector3> Taken,
        HashSet<PF2eVec> Reserved, Func<float, float> Shade)
    {
        public int Margin => Context.Skirt.Margin;
        public MapLayout Layout => Context.Skirt.Layout;
        public Vector2I Board(Vector2I skirt) => skirt - new Vector2I(Margin, Margin);
        public Vector2I Board(PF2eVec skirt) => new(skirt.x - Margin, skirt.y - Margin);
        public int Ring(Vector2I skirt) => SewerSites.Ring(Context.Skirt, skirt);
        public float FloorShade(Vector2I skirt) => Shade(Mathf.Max(0f, Ring(skirt) - 0.5f));
        public float FloorY(Vector2I skirt) => Context.SkirtHeights.CenterY(new PF2eVec(skirt.X, skirt.Y));
    }

    /// <summary>The sigil placed for this board, or null.</summary>
    public SewerSigil? Sigil { get; private set; }

    /// <summary>The slumped skeleton placed for this board, or null.</summary>
    public Sprite3D? Skeleton { get; private set; }

    /// <summary>Board tiles (halo included) under a wet decal: a puddle or slime.</summary>
    public IReadOnlyCollection<Vector2I> WetTiles => _wet;

    /// <summary>The wall torches placed for this board.</summary>
    public IReadOnlyList<Node3D> Torches => _torches;

    /// <summary>Every torch, grate and floor decal placed for this board, with the rule that placed it.</summary>
    public IReadOnlyList<DressPlacement> Placed => _ledger.Placed;

    /// <summary>The openings in this board's outline, in skirt coordinates.</summary>
    public IReadOnlyList<SewerOpening> Openings { get; private set; } = Array.Empty<SewerOpening>();

    /// <summary>The chamber walls torches may hang on, in skirt coordinates.</summary>
    public IReadOnlyList<WallRun> WallRuns { get; private set; } = Array.Empty<WallRun>();

    public override void Clear()
    {
        Sigil = null;
        Skeleton = null;
        _wet.Clear();
        _torches.Clear();
        _torchNotes.Clear();
        _ledger.Clear();
        Openings = Array.Empty<SewerOpening>();
        WallRuns = Array.Empty<WallRun>();
        if (_props == null) return;
        RemoveChild(_props);
        _props.QueueFree();
        _props = null;
    }

    public override void Dress(DressingContext context, Func<float, float> haloShade)
    {
        Clear();
        var skirt = context.Skirt;
        int margin = skirt.Margin;

        _props = new Node3D { Name = "SewerProps" };
        AddChild(_props);

        var anchors = BoardAnchors.For(context.Board);
        var reserved = new HashSet<PF2eVec>(anchors.Values.Select(a => new PF2eVec(a.x + margin, a.y + margin)));
        foreach (var mark in skirt.Plan?.Marks.Where(m => m.Kind == SewerBoard.SkeletonMark) ?? Enumerable.Empty<HaloMark>())
            for (int dy = -SkeletonClearance; dy <= SkeletonClearance; dy++)
                for (int dx = -SkeletonClearance; dx <= SkeletonClearance; dx++)
                    reserved.Add(new PF2eVec(mark.X + margin + dx, mark.Y + margin + dy));
        var faces = WallFaces.Chamber(skirt, context.SkirtHeights, FaceRings, MinFaceHeight);
        if (faces.Count == 0) return;
        var pass = new Pass(context, faces, new WallProps(_props, context.Cutaway, WallInset), new List<Vector3>(), reserved, haloShade);
        var culverts = CulvertSpans.Find(context).ToList();
        Openings = SewerSites.Openings(skirt, PassageDepth);
        WallRuns = SewerWalls.Runs(faces.Where(f => f.OpenRing <= TorchRings));

        var sigil = PlaceSigil(pass, anchors);
        Skeleton = SewerMarks.Place(pass.Props, _props, context, faces,
            new SewerMarkArt(WaterPipeScene, PipePuddle, WallGrate, SlumpedSkeleton, FloorGrate, PipeStain, SkeletonLean),
            pass.Taken, haloShade, _ledger);
        CulvertArches.Place(_props, context, new ArchShape(ArchSpring, ArchCrown, ArchDepth, ArchSegmentsPerTile));
        if (FlowScene != null) CulvertFlows.Place(_props, context, FlowScene, WaterFlowColor, SludgeFlowColor, FlowLift);
        if (ChannelMistScene != null) ChannelMist.Place(_props, context, ChannelMistScene, WaterMistColor, SludgeMistColor);
        ChannelKerbs.Place(_props, context, MapMaterials.StoneTrim(MapThemes.Sewer, "channel_kerb", KerbShade, always: true),
            new KerbShape(KerbWidth, KerbHeight), KerbRings);
        PlacePipes(pass);
        PlaceGrates(pass);
        PlaceTorches(pass, sigil);
        PlaceChannelEndGrates(pass);
        PlaceFloor(pass, culverts);
        foreach (var p in _ledger.OfKind(DressKind.Puddle, DressKind.Slime)) _wet.Add(p.Tile);
        PlaceDrips(pass);
    }

    // ─────────────────────────── wall props ───────────────────────────

    private WallFace? PlaceSigil(Pass pass, IReadOnlyDictionary<string, PF2eVec> anchors)
    {
        if (SigilScene == null || SigilAnchor.Length == 0 || !anchors.TryGetValue(SigilAnchor, out var anchor)) return null;
        int margin = pass.Margin;
        int row = anchor.y + margin;
        // The far wall is the low-x side, where the party faces its enemies.
        var face = pass.Faces.Where(f => f.Normal == new Vector2I(1, 0) && f.Open.y == row && f.Wall.x < anchor.x + margin)
            .OrderByDescending(f => f.Wall.x).FirstOrDefault();
        if (face == default) return null;
        var at = face.Foot(margin) + Vector3.Up * SigilHeight + WallProps.Out(face) * WallInset;
        Sigil = pass.Props.AddScene(SigilScene, face, at, pass.Shade(face.OpenRing)) as SewerSigil;
        pass.Taken.Add(at);
        return face;
    }

    private void PlacePipes(Pass pass)
    {
        int margin = pass.Margin;
        var layout = pass.Layout;
        var faces = pass.Faces;

        // One sludge pipe at the middle of each stretch of wall the sludge runs along.
        if (SludgePipeScene != null)
        {
            foreach (var run in StraightRuns(faces.Where(f => layout.GetTile(f.Open.x, f.Open.y) == TileRole.DifficultTerrain)))
            {
                var face = run[run.Count / 2];
                var at = face.Foot(margin) + WallProps.Out(face) * WallInset;
                if (Crowded(at, pass.Taken)) continue;
                pass.Props.AddScene(SludgePipeScene, face, at, pass.Shade(face.OpenRing));
                pass.Props.AddStain(PipeStain, face, margin, pass.Shade(face.OpenRing));
                pass.Taken.Add(at);
            }
        }

        // One water pipe on each long far wall (the two the opening camera faces), over board floor.
        if (WaterPipeScene == null) return;
        foreach (var normal in new[] { new Vector2I(1, 0), new Vector2I(0, 1) })
        {
            var wall = faces.Where(f => f.Normal == normal && f.OpenRing == 0).OrderBy(SewerWalls.Along).ToList();
            if (wall.Count < WaterPipeMinWall) continue;
            var candidates = wall.Skip(2).Take(wall.Count - 4)
                .Where(f => layout.GetTile(f.Open.x, f.Open.y) == TileRole.Ground && !pass.Reserved.Contains(f.Open))
                .ToList();
            if (candidates.Count == 0) continue;
            int pick = (int)(MapHash.Hash01(normal.X, normal.Y, layout.Seed + SaltPipe) * candidates.Count) % candidates.Count;
            var face = candidates[pick];
            var at = face.Foot(margin) + WallProps.Out(face) * WallInset;
            if (Crowded(at, pass.Taken)) continue;
            pass.Props.AddScene(WaterPipeScene, face, at, pass.Shade(face.OpenRing));
            pass.Props.AddStain(PipeStain, face, margin, pass.Shade(face.OpenRing));
            pass.Taken.Add(at);
            if (PipePuddle != null)
            {
                var spot = face.Foot(margin) + WallProps.Out(face) * SewerMarks.PuddleOut;
                FloorClutter.AddDecal(_props!, PipePuddle, spot, 0, pass.Shade(face.OpenRing));
                var tile = pass.Board(face.Open);
                _ledger.Add(new DressPlacement(DressKind.Puddle, tile, tile, new Vector2(spot.X, spot.Z), OutfallReason));
            }
            pass.Reserved.Add(face.Open);
        }
    }

    private bool Crowded(Vector3 at, List<Vector3> taken)
        => taken.Any(t => new Vector2(t.X - at.X, t.Z - at.Z).Length() < WallPropGap);

    /// <summary>Faces split into straight runs: same normal, same wall line, consecutive tiles.</summary>
    private static List<List<WallFace>> StraightRuns(IEnumerable<WallFace> faces)
    {
        var runs = new List<List<WallFace>>();
        foreach (var group in faces.GroupBy(f => (f.Normal, SewerWalls.Line(f))))
        {
            List<WallFace>? run = null;
            int last = int.MinValue;
            foreach (var face in group.OrderBy(SewerWalls.Along))
            {
                if (run == null || SewerWalls.Along(face) != last + 1)
                {
                    run = new List<WallFace>();
                    runs.Add(run);
                }
                run.Add(face);
                last = SewerWalls.Along(face);
            }
        }
        return runs;
    }
}
