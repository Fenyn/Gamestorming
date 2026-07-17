using Bulwark.Data.Characters;

namespace Bulwark.Dialogue;

/// <summary>
/// Presentation-time text resolution for dialogue lines, applied at the single point where the
/// <see cref="DialogueRunner"/> pushes a line to the box (design/dialogue.md: the player speaker
/// uses the chosen name from CharacterProfile). Plain C#, no Godot dependency — testable.
///
/// Two concerns, both keyed off the runtime-chosen player name:
/// <list type="bullet">
///   <item><see cref="Format"/> substitutes inline tokens in line text. The table is deliberately
///   minimal — only <c>{player_name}</c> is used today; the mechanism extends trivially by adding
///   another <c>Replace</c> when a second token earns its place.</item>
///   <item><see cref="ResolveSpeaker"/> maps a speaker id to the display name shown on the box's
///   name label — "player" resolves to the chosen name, other ids to the character profile's
///   display name, and unknown ids fall back to the raw id (safe default).</item>
/// </list>
/// The raw speaker id still travels alongside the resolved name so the box can keep loading portraits
/// by id.
/// </summary>
public static class DialogueText
{
    /// <summary>The speaker id whose display name is the player's runtime-chosen name.</summary>
    private const string PlayerSpeakerId = PlayerCharacter.CharacterId; // "player"

    /// <summary>Inline token for the player's chosen name.</summary>
    private const string PlayerNameToken = "{player_name}";

    /// <summary>
    /// Substitute inline tokens in a dialogue line. Minimal token table: <c>{player_name}</c> only.
    /// A null/empty or token-free string is returned unchanged.
    /// </summary>
    public static string Format(string? text, string? playerName)
    {
        if (string.IsNullOrEmpty(text) || text!.IndexOf('{') < 0)
            return text ?? "";
        return text.Replace(PlayerNameToken, ResolvePlayerName(playerName));
    }

    /// <summary>
    /// Resolve a speaker id to the display name for the dialogue box label. "player" → the chosen
    /// name; any other known character id → its <see cref="CharacterProfile.DefaultName"/>; an
    /// unknown id falls back to the raw id.
    /// </summary>
    public static string ResolveSpeaker(string? speakerId, string? playerName)
    {
        if (string.IsNullOrEmpty(speakerId))
            return "";
        if (speakerId == PlayerSpeakerId)
            return ResolvePlayerName(playerName);
        if (Characters.TryGet(speakerId!, out var profile))
            return profile.DefaultName;
        return speakerId!;
    }

    /// <summary>The chosen name, or the player profile's default when no name has been set yet.</summary>
    private static string ResolvePlayerName(string? playerName)
        => string.IsNullOrEmpty(playerName) ? PlayerCharacter.Profile.DefaultName : playerName!;
}
