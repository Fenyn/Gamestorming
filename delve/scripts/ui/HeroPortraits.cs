using System.Collections.Generic;
using Delve.Data;
using Godot;

namespace Delve.UI;

/// <summary>
/// Card-sized portraits cut from the heroes' Mana Seed movement pages. The portrait is the
/// south-facing stand frame (row <see cref="ManaSeedSheet.RowSouth"/>, column 0) cropped to the
/// figure — the same frame the board draws while a hero idles, so a card and its token show the
/// same character in the same pose.
///
/// One <see cref="AtlasTexture"/> per hero id, cached: the party strip and the roster card both ask
/// for the same portrait, and neither should re-read the page.
/// </summary>
public static class HeroPortraits
{
    private static readonly Dictionary<string, Texture2D?> Cache = new();

    /// <summary>Portrait for a hero id, or null when its sheet is missing.</summary>
    public static Texture2D? For(string characterId)
    {
        if (Cache.TryGetValue(characterId, out var cached)) return cached;

        string path = ManaSeedSheet.SheetPath(HeroSpriteMap.FolderFor(characterId), ManaSeedSheet.WalkPage);
        var page = ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;
        Texture2D? portrait = page == null ? null : new AtlasTexture
        {
            Atlas = page,
            Region = new Rect2(
                ManaSeedSheet.PortraitX,
                ManaSeedSheet.RowSouth * ManaSeedSheet.CellPx + ManaSeedSheet.PortraitY,
                ManaSeedSheet.PortraitWidth, ManaSeedSheet.PortraitHeight),
        };

        Cache[characterId] = portrait;
        return portrait;
    }
}
