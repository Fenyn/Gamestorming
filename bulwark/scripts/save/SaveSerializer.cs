using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace Bulwark.Save;

/// <summary>
/// Pure JSON (de)serialization of <see cref="SaveData"/>. Takes/returns a DTO and a string — no
/// file paths, no Godot types in the public surface (per M2 spec, only the GameState adapter
/// touches the filesystem) — the sole exception is a GD.PushError log line on a malformed save,
/// since the caller has no exception object of its own to report. Enums are written as strings so
/// save files survive enum reordering.
/// </summary>
public static class SaveSerializer
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() },
    };

    public static string Serialize(SaveData data) => JsonSerializer.Serialize(data, Options);

    /// <summary>
    /// Parse a save JSON string. Returns null both for the literal JSON "null" (System.Text.Json's
    /// own contract) AND for any malformed, truncated, or otherwise unparseable input that would
    /// normally throw — a corrupt save file must degrade to "no save", never crash the caller.
    /// Logs the exception message via GD.PushError so a bad save is diagnosable without attaching
    /// a debugger.
    /// </summary>
    public static SaveData? Deserialize(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<SaveData>(json, Options);
        }
        catch (Exception ex)
        {
            GD.PushError($"[SaveSerializer] Save file could not be parsed: {ex.Message}");
            return null;
        }
    }
}
