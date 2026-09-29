using System.Collections.Generic;
using Delve.Data;
using Godot;

namespace Delve.UI;

/// <summary>
/// Portrait art for any combatant, cut from the art the board already draws: a hero's Mana Seed
/// stand frame (<see cref="HeroPortraits"/>) or an enemy's first idle frame. Timeline tiles and unit
/// cards want a face, so an upright enemy frame is cropped to the square at its top; a wide one
/// (a wolf, a beetle) keeps its whole body. Cached per hero id and per sprite folder.
/// </summary>
public static class UnitPortraits
{
    private static readonly Dictionary<string, Texture2D?> IdleFrames = new();
    private static readonly Dictionary<string, Texture2D?> Faces = new();

    /// <summary>Portrait for a hero id or an enemy sprite folder; null when the art is missing.</summary>
    public static Texture2D? For(string heroId, string spriteFolder) =>
        heroId.Length > 0 ? HeroPortraits.Face(heroId) : spriteFolder.Length > 0 ? EnemyFace(spriteFolder) : null;

    /// <summary>The enemy's first idle frame, uncropped, as the bestiary page draws it.</summary>
    public static Texture2D? EnemyIdleFrame(string folder)
    {
        if (IdleFrames.TryGetValue(folder, out var cached)) return cached;
        var sprite = ResourceLoader.Load<EnemySpriteDefinition>(EnemySpriteMap.DefinitionPath(folder));
        var frames = sprite?.Frames;
        var texture = frames != null && frames.HasAnimation(sprite!.IdleAnimation) && frames.GetFrameCount(sprite.IdleAnimation) > 0
            ? frames.GetFrameTexture(sprite.IdleAnimation, 0) : null;
        IdleFrames[folder] = texture;
        return texture;
    }

    private static Texture2D? EnemyFace(string folder)
    {
        if (Faces.TryGetValue(folder, out var cached)) return cached;
        var frame = EnemyIdleFrame(folder);
        Texture2D? face = frame;
        if (frame?.GetImage() is { } image)
        {
            if (image.IsCompressed()) image.Decompress();
            var used = image.GetUsedRect();
            if (used.Size.X > 0 && used.Size.Y >= used.Size.X)
                used = used with { Size = new Vector2I(used.Size.X, used.Size.X) };
            // A frame may itself be a region of a sheet, so crop its pixels rather than nesting atlases.
            if (used.Size.X > 0) face = ImageTexture.CreateFromImage(image.GetRegion(used));
        }
        Faces[folder] = face;
        return face;
    }
}
