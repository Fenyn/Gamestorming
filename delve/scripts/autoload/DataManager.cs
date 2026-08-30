using System;
using Godot;
using Delve.Data;
using PF2e;
using PF2e.Core;
using PF2e.Data;

namespace Delve.Autoload;

/// <summary>
/// Autoload adapter for PF2e content loading. Thin per CLAUDE.md: the actual loading logic
/// lives in <see cref="PackLoader"/> (plain C#). This Node wires PF2e diagnostics + combat log
/// to Godot's console and exposes loaded state to the rest of the game.
/// </summary>
public partial class DataManager : Node
{
    /// <summary>ProjectSettings key that holds the OS-absolute PF2e pack root (not res://).
    /// project.godot registers it; change the machine's path there, never in code.</summary>
    public const string PackPathSetting = "delve/pf2e_pack_path";

    /// <summary>Path used when the setting is missing (a project.godot that predates the entry).</summary>
    public const string DefaultPackPath = "F:/dev/Pf2e.Core/Data/pf2e-source/packs/pf2e";

    /// <summary>The one autoload instance. Set in <see cref="_Ready"/>, cleared on tree exit.
    /// Every consumer reads this instead of resolving "/root/DataManager" by string.</summary>
    public static DataManager Instance { get; private set; } = null!;

    private PackLoader? _loader;

    /// <summary>Engine log sinks as they were before <see cref="WireLogging"/> ran. Restored on exit
    /// so a host that outlives this autoload does not keep calling into a freed Node.</summary>
    private Action<string>? _priorInfo;
    private Action<string>? _priorWarn;
    private Action<string>? _priorError;
    private bool _loggingWired;

    public bool IsLoaded => _loader?.IsLoaded ?? false;

    public int ConditionCount => _loader?.ConditionCount ?? 0;
    public int SpellCount => _loader?.SpellCount ?? 0;
    public int EquipmentCount => _loader?.EquipmentCount ?? 0;
    public int CreatureCount => _loader?.CreatureCount ?? 0;

    public override void _Ready()
    {
        Instance = this;
        WireLogging();

        string packPath = ResolvePackPath();
        if (!DirAccess.DirExistsAbsolute(packPath))
        {
            GD.PushError(
                $"[DataManager] PF2e pack folder not found: '{packPath}'. "
                + $"Set '{PackPathSetting}' in project.godot to this machine's Pf2e.Core data path.");
            return;
        }

        _loader = new PackLoader(packPath);
        _loader.LoadAll(msg => GD.Print($"[DataManager] {msg}"));
        FeatLookup.Index(packPath);

        GD.Print(
            $"[DataManager] Ready — {ConditionCount} conditions, {SpellCount} spells, "
            + $"{EquipmentCount} equipment, {CreatureCount} creatures, "
            + $"{FeatLookup.IndexedCount} feat entries indexed");
    }

    public override void _ExitTree()
    {
        RestoreLogging();
        if (Instance == this) Instance = null!;
    }

    /// <summary>The configured pack root as an OS-absolute path. A res:// or user:// value is
    /// globalized, so both a packaged path and a raw drive path work.</summary>
    private static string ResolvePackPath()
    {
        var setting = ProjectSettings.GetSetting(PackPathSetting, DefaultPackPath);
        string path = setting.AsString();
        if (string.IsNullOrWhiteSpace(path)) path = DefaultPackPath;
        return ProjectSettings.GlobalizePath(path);
    }

    /// <summary>Find an imported creature definition by display name (case-insensitive).</summary>
    public EnemyDefinition? FindCreature(string creatureName) => _loader?.FindCreature(creatureName);

    /// <summary>Load a single creature JSON directly by pack subfolder + file slug.</summary>
    public EnemyDefinition LoadCreatureFile(string packSubfolder, string slug)
        => _loader!.LoadCreatureFile(packSubfolder, slug);

    /// <summary>
    /// Resolve a data-driven creature ref: display-name lookup first, direct pack-file load as the
    /// fallback. Null (with an error log) when the content is unavailable — the single home for
    /// the idiom every consumer used to hand-roll.
    ///
    /// Also stamps the pack SLUG onto the resolved definition's CreatureId. Foundry's own
    /// <c>_id</c> is an opaque 16-character hash, which is useless as a save key; the slug
    /// ("goblin-warrior") is the readable species identity a future monster journal would key on.
    /// Stamping it here — the single funnel every
    /// creature resolution passes through — is what carries it into
    /// <c>CreatureStatBlock.CreatureId</c> and <c>ICharacter.Id</c> via CreatureFactory.
    /// </summary>
    public EnemyDefinition? ResolveCreature(CreatureRef @ref)
    {
        try
        {
            var def = FindCreature(@ref.DisplayName) ?? LoadCreatureFile(@ref.Pack, @ref.Slug);
            if (def != null)
                def.CreatureId = @ref.Slug;
            return def;
        }
        catch (System.Exception e)
        {
            GD.PushError($"[DataManager] Could not resolve creature '{@ref.DisplayName}': {e.Message}");
            return null;
        }
    }

    /// <summary>Route the engine's diagnostics to Godot's console, keeping the previous sinks so
    /// <see cref="RestoreLogging"/> can put them back.</summary>
    private void WireLogging()
    {
        if (_loggingWired) return;
        _loggingWired = true;

        _priorInfo = Log.OnInfo;
        _priorWarn = Log.OnWarn;
        _priorError = Log.OnError;

        Log.OnInfo = msg => GD.Print($"[PF2e] {msg}");
        Log.OnWarn = msg => GD.PushWarning($"[PF2e WARN] {msg}");
        Log.OnError = msg => GD.PushError($"[PF2e ERROR] {msg}");
    }

    private void RestoreLogging()
    {
        if (!_loggingWired) return;
        _loggingWired = false;

        Log.OnInfo = _priorInfo;
        Log.OnWarn = _priorWarn;
        Log.OnError = _priorError;
    }
}
