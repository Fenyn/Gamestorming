using Godot;
using Bulwark.Data;
using PF2e;
using PF2e.Core;
using PF2e.Data;

namespace Bulwark.Autoload;

/// <summary>
/// Autoload adapter for PF2e content loading. Thin per CLAUDE.md: the actual loading logic
/// lives in <see cref="PackLoader"/> (plain C#). This Node wires PF2e diagnostics + combat log
/// to Godot's console and exposes loaded state to the rest of the game.
/// </summary>
public partial class DataManager : Node
{
    /// <summary>OS-absolute PF2e data root (not res://). See CLAUDE.md.</summary>
    public const string Pf2eDataPath = "F:/dev/Pf2e.Core/Data/pf2e-source/packs/pf2e";

    private PackLoader _loader = null!;

    public bool IsLoaded => _loader?.IsLoaded ?? false;

    public int ConditionCount => _loader?.ConditionCount ?? 0;
    public int SpellCount => _loader?.SpellCount ?? 0;
    public int EquipmentCount => _loader?.EquipmentCount ?? 0;
    public int CreatureCount => _loader?.CreatureCount ?? 0;

    public override void _Ready()
    {
        WireLogging();

        _loader = new PackLoader(Pf2eDataPath);
        _loader.LoadAll(msg => GD.Print($"[DataManager] {msg}"));

        GD.Print(
            $"[DataManager] Ready — {ConditionCount} conditions, {SpellCount} spells, "
            + $"{EquipmentCount} equipment, {CreatureCount} creatures");

        // Fail-fast content validation: cross-registry referential integrity, loud in dev, absent in
        // release. Violations surface as GD.PushError lines (see DataValidation).
        if (OS.IsDebugBuild())
            DataValidation.RunAll();
    }

    /// <summary>Find an imported creature definition by display name (case-insensitive).</summary>
    public EnemyDefinition? FindCreature(string creatureName) => _loader?.FindCreature(creatureName);

    /// <summary>Load a single creature JSON directly by pack subfolder + file slug.</summary>
    public EnemyDefinition LoadCreatureFile(string packSubfolder, string slug)
        => _loader.LoadCreatureFile(packSubfolder, slug);

    /// <summary>
    /// Resolve a data-driven creature ref: display-name lookup first, direct pack-file load as the
    /// fallback. Null (with an error log) when the content is unavailable — the single home for
    /// the idiom every consumer used to hand-roll.
    /// </summary>
    public EnemyDefinition? ResolveCreature(CreatureRef @ref)
    {
        try
        {
            return FindCreature(@ref.DisplayName) ?? LoadCreatureFile(@ref.Pack, @ref.Slug);
        }
        catch (System.Exception e)
        {
            GD.PushError($"[DataManager] Could not resolve creature '{@ref.DisplayName}': {e.Message}");
            return null;
        }
    }

    private static void WireLogging()
    {
        Log.OnInfo = msg => GD.Print($"[PF2e] {msg}");
        Log.OnWarn = msg => GD.PushWarning($"[PF2e WARN] {msg}");
        Log.OnError = msg => GD.PushError($"[PF2e ERROR] {msg}");
    }
}
