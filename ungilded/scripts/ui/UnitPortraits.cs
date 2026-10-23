using System.Collections.Generic;
using Ungilded.Data;
using Godot;

namespace Ungilded.UI;

/// <summary>
/// Portrait art for any combatant, cut from the art the board already draws: a hero's stand frame
/// (<see cref="HeroPortraits"/>) or an authored sprite's first idle frame. Timeline tiles and unit
/// cards want a face, so an upright frame is cropped to its <c>FaceRect</c> or the square at its
/// top; a wide one (a wolf, a beetle) keeps its whole body. Cached per hero id and per sprite folder.
/// </summary>
public static class UnitPortraits
{
    private static readonly Dictionary<string, Texture2D?> IdleFrames = new();
    private static readonly Dictionary<string, Texture2D?> Faces = new();
    private static readonly Dictionary<string, Texture2D?> Figures = new();

    /// <summary>Portrait for a hero id or an enemy sprite folder; null when the art is missing.</summary>
    public static Texture2D? For(string heroId, string spriteFolder) =>
        heroId.Length > 0 ? HeroPortraits.Face(heroId) : spriteFolder.Length > 0 ? SpriteFace(spriteFolder) : null;

    /// <summary>The enemy's first idle frame, uncropped, as the bestiary page draws it.</summary>
    public static Texture2D? EnemyIdleFrame(string folder)
    {
        if (IdleFrames.TryGetValue(folder, out var cached)) return cached;
        var sprite = EnemySpriteMap.Definition(folder);
        var frames = sprite?.Frames;
        var texture = frames != null && frames.HasAnimation(sprite!.IdleAnimation) && frames.GetFrameCount(sprite.IdleAnimation) > 0
            ? frames.GetFrameTexture(sprite.IdleAnimation, 0) : null;
        IdleFrames[folder] = texture;
        return texture;
    }

    /// <summary>Face crop of an authored sprite folder: the definition's <c>FaceRect</c>, else the
    /// square at the top of the figure.</summary>
    public static Texture2D? SpriteFace(string folder)
    {
        if (Faces.TryGetValue(folder, out var cached)) return cached;
        var rect = EnemySpriteMap.Definition(folder)?.FaceRect ?? default;
        var face = Crop(EnemyIdleFrame(folder), rect, squareTop: true);
        Faces[folder] = face;
        return face;
    }

    /// <summary>Whole-figure crop of an authored sprite folder: the definition's <c>PortraitRect</c>,
    /// else the figure's opaque bounds.</summary>
    public static Texture2D? FigurePortrait(string folder)
    {
        if (Figures.TryGetValue(folder, out var cached)) return cached;
        var rect = EnemySpriteMap.Definition(folder)?.PortraitRect ?? default;
        var figure = Crop(EnemyIdleFrame(folder), rect, squareTop: false);
        Figures[folder] = figure;
        return figure;
    }

    private static Texture2D? Crop(Texture2D? frame, Rect2I rect, bool squareTop)
    {
        if (frame?.GetImage() is not { } image) return frame;
        if (image.IsCompressed()) image.Decompress();
        if (rect.Size.X <= 0 || rect.Size.Y <= 0)
        {
            rect = image.GetUsedRect();
            if (squareTop && rect.Size.X > 0 && rect.Size.Y >= rect.Size.X)
                rect = rect with { Size = new Vector2I(rect.Size.X, rect.Size.X) };
        }
        // A frame may itself be a region of a sheet, so crop its pixels rather than nesting atlases.
        return rect.Size.X > 0 ? ImageTexture.CreateFromImage(image.GetRegion(rect)) : frame;
    }
}
