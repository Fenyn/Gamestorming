using System.Text.Json;
using System.Text.Json.Serialization;

namespace Bulwark.Cozy;

/// <summary>
/// Pure JSON (de)serialization of <see cref="SaveData"/>. Takes/returns a DTO and a string — no
/// file paths, no Godot types (per M2 spec, only the GameState adapter touches the filesystem).
/// Enums are written as strings so save files survive enum reordering.
/// </summary>
public static class SaveSerializer
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    public static string Serialize(SaveData data) => JsonSerializer.Serialize(data, Options);

    public static SaveData? Deserialize(string json) => JsonSerializer.Deserialize<SaveData>(json, Options);
}
