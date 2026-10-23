using System.Collections.Generic;
using Godot;

namespace Ungilded.Combat;

/// <summary>
/// The normal page drawn beside a sprite frame: <c>idle_3.png</c> has <c>idle_3_n.png</c> in the
/// same folder (tools/art/sprite_normals.py writes them). Each page loads once and is held, as
/// <see cref="Ungilded.Data.EnemySpriteMap.Definition"/> holds its definitions.
/// </summary>
public static class SpriteNormalPages
{
    public const string Suffix = "_n";

    private static readonly Dictionary<string, Texture2D?> Pages = new();

    /// <summary>The normal page of <paramref name="colour"/>, or null when the frame has none.</summary>
    public static Texture2D? For(Texture2D? colour)
    {
        string source = colour?.ResourcePath ?? "";
        if (source.Length == 0) return null;
        if (Pages.TryGetValue(source, out var cached)) return cached;
        string path = PathFor(source);
        var page = ResourceLoader.Exists(path) ? ResourceLoader.Load<Texture2D>(path) : null;
        Pages[source] = page;
        return page;
    }

    public static string PathFor(string colourPath) =>
        colourPath.GetBaseName() + Suffix + "." + colourPath.GetExtension();
}
