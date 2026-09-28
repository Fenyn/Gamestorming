namespace Delve.Data;

/// <summary>Foundry-style creature slug: the species key shared by the sprite map and the journal.</summary>
public static class CreatureSlug
{
    /// <summary>Lowercase, runs of non-alphanumerics collapsed to single hyphens, the factory's
    /// Elite/Weak name prefix dropped.</summary>
    public static string Normalize(string? name)
    {
        if (string.IsNullOrEmpty(name)) return "";
        var sb = new System.Text.StringBuilder(name.Length);
        bool pendingHyphen = false;
        foreach (char c in name.ToLowerInvariant())
        {
            if (char.IsLetterOrDigit(c))
            {
                if (pendingHyphen && sb.Length > 0) sb.Append('-');
                pendingHyphen = false;
                sb.Append(c);
            }
            else
            {
                pendingHyphen = true;
            }
        }
        string slug = sb.ToString();
        if (slug.StartsWith("elite-")) return slug["elite-".Length..];
        if (slug.StartsWith("weak-")) return slug["weak-".Length..];
        return slug;
    }
}
