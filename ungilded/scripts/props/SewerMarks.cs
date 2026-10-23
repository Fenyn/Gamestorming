using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using Ungilded.Content;
using Ungilded.Look;
using Ungilded.Terrain;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Props;

/// <summary>The art the dressing marks of an authored halo call for. <paramref name="SkeletonLean"/>
/// is how far, in degrees from upright, the skeleton leans back against its wall.</summary>
public sealed record SewerMarkArt(PackedScene? Outfall, DecorSprite? Puddle, DecorSprite? Grate, DecorSprite? Skeleton,
    DecorSprite? FloorGrate, DecorSprite? Stain, float SkeletonLean);

/// <summary>
/// Places the dressing marks of an authored halo (<see cref="Ungilded.Terrain.HaloPlan.Marks"/>):
/// an outfall pipe with a puddle under it, or a drain grate, on the face of a marked wall tile; a
/// slumped skeleton leaned against the wall beside a marked floor tile, on the wall the opening
/// camera faces; a drain grate in a marked floor tile. Every puddle and grate goes in the ledger.
/// </summary>
public static class SewerMarks
{
    /// <summary>A grate's foot sits this far above the floor, metres.</summary>
    private const float GrateLift = 0.03f;

    /// <summary>A pipe's puddle lies this far out from the wall, metres.</summary>
    public const float PuddleOut = 0.4f;

    /// <summary>Returns the skeleton sprite, or null when the halo marks none.</summary>
    public static Sprite3D? Place(WallProps props, Node3D parent, DressingContext context, List<WallFace> faces,
        SewerMarkArt art, List<Vector3> taken, Func<float, float> haloShade, DressLedger ledger)
    {
        var plan = context.Skirt.Plan;
        if (plan == null) return null;
        int margin = context.Skirt.Margin;
        Sprite3D? skeleton = null;
        foreach (var mark in plan.Marks)
        {
            var tile = new PF2eVec(mark.X + margin, mark.Y + margin);
            if (mark.Kind == SewerBoard.SkeletonMark)
            {
                var wall = faces.Where(f => f.Open == tile).OrderByDescending(f => f.Normal.X + f.Normal.Y).FirstOrDefault();
                if (wall != default && art.Skeleton != null)
                    skeleton = Lean(parent, art.Skeleton, wall, margin, art.SkeletonLean, props.Inset, haloShade(wall.OpenRing));
                continue;
            }
            if (mark.Kind == SewerBoard.FloorGrateMark)
            {
                if (art.FloorGrate == null) continue;
                var centre = new Vector3(mark.X + 0.5f, context.SkirtHeights.CenterY(tile), mark.Y + 0.5f);
                int ring = WallFaces.Ring(tile.x, tile.y, margin, context.Board.Width, context.Board.Height);
                FloorClutter.AddDecal(parent, art.FloorGrate, centre, 0, haloShade(Math.Max(0f, ring - 0.5f)));
                taken.Add(centre);
                var at = new Vector2I(mark.X, mark.Y);
                ledger.Add(new DressPlacement(DressKind.FloorGrate, at, at, new Vector2(centre.X, centre.Z), "mark"));
                continue;
            }

            var face = faces.Where(f => f.Wall == tile).OrderBy(f => f.OpenRing).FirstOrDefault();
            if (face == default) continue;
            float shade = haloShade(face.OpenRing);
            var foot = face.Foot(margin);
            var open = new Vector2I(face.Open.x - margin, face.Open.y - margin);
            if (mark.Kind == SewerBoard.OutfallMark && art.Outfall != null)
            {
                props.AddScene(art.Outfall, face, foot + WallProps.Out(face) * props.Inset, shade);
                props.AddStain(art.Stain, face, margin, shade);
                if (art.Puddle != null)
                {
                    var spot = foot + WallProps.Out(face) * PuddleOut;
                    FloorClutter.AddDecal(parent, art.Puddle, spot, 0, shade);
                    ledger.Add(new DressPlacement(DressKind.Puddle, open, open, new Vector2(spot.X, spot.Z), SewerDressing.OutfallReason));
                }
                taken.Add(foot);
            }
            else if (mark.Kind == SewerBoard.GrateMark && art.Grate != null)
            {
                HangGrate(props, art.Grate, face, margin, shade);
                taken.Add(foot);
                ledger.Add(new DressPlacement(DressKind.WallGrate, open, new Vector2I(mark.X, mark.Y), new Vector2(foot.X, foot.Z), "mark"));
            }
        }
        return skeleton;
    }

    /// <summary>A drain grate at the foot of the face, level with the floor or water before it.</summary>
    public static void HangGrate(WallProps props, DecorSprite grate, WallFace face, int margin, float shade)
        => props.AddSprite("WallGrate", grate, face, margin, GrateLift, 0f, shade, onWall: true);

    /// <summary>A flat pixel quad leaned back <paramref name="lean"/> degrees against the face: its
    /// bottom edge on the floor, its top edge <paramref name="inset"/> off the wall.
    /// <see cref="DecorSprite.Size"/> is its width.</summary>
    private static Sprite3D? Lean(Node3D parent, DecorSprite def, WallFace face, int margin, float lean, float inset, float shade)
    {
        if (def.Texture == null) return null;
        var sprite = new Sprite3D
        {
            Name = $"SlumpedSkeleton_{face.Wall.x}_{face.Wall.y}",
            Texture = def.Texture,
            PixelSize = def.Size / def.Texture.GetWidth(),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            Modulate = new Color(shade, shade, shade),
        };
        PixelSprite.Configure(sprite);
        sprite.Shaded = true;
        float tilt = Mathf.DegToRad(lean);
        float half = def.Size * def.Texture.GetHeight() / def.Texture.GetWidth() * 0.5f;
        // Turning about local X by -tilt tips the top toward the wall (local -Z).
        var basis = face.Facing * new Basis(Vector3.Right, -tilt);
        var centre = face.Foot(margin) + Vector3.Up * (half * Mathf.Cos(tilt))
            + WallProps.Out(face) * (inset + half * Mathf.Sin(tilt));
        sprite.Transform = new Transform3D(basis, centre);
        parent.AddChild(sprite);
        return sprite;
    }
}
