using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using PF2e.Conditions;
using PF2e.Data;
using PF2e.Import;

namespace Delve.Data;

/// <summary>
/// Plain C# adapter over Pf2e.Core's data importers. Owns all pack-loading logic so the
/// DataManager autoload can stay a thin Node adapter (see CLAUDE.md engineering standards).
///
/// Mirrors the autobattler's proven pattern: GameDataLoader.LoadAll (conditions + spells +
/// equipment) followed by CreatureImporter.ImportAll for the monster packs.
/// No Godot dependency — diagnostics are surfaced through the optional <c>log</c> callback.
/// </summary>
public sealed class PackLoader
{
    private static readonly string[] CreaturePacks =
    {
        "pathfinder-monster-core",
        "pathfinder-bestiary",
    };

    private readonly List<EnemyDefinition> _creatures = new();

    public PackLoader(string dataRoot)
    {
        DataRoot = dataRoot;
    }

    /// <summary>OS-absolute data root (e.g. F:\dev\Pf2e.Core\Data\pf2e-source\packs\pf2e).</summary>
    public string DataRoot { get; }

    public bool IsLoaded { get; private set; }

    public IReadOnlyList<EnemyDefinition> Creatures => _creatures;

    public int ConditionCount { get; private set; }
    public int SpellCount { get; private set; }
    public int EquipmentCount { get; private set; }
    public int CreatureCount => _creatures.Count;

    /// <summary>
    /// Load every pack under <see cref="DataRoot"/>. Safe to call once at startup.
    /// </summary>
    public void LoadAll(Action<string>? log = null)
    {
        if (!Directory.Exists(DataRoot))
        {
            log?.Invoke($"PackLoader: data root does not exist: {DataRoot}");
            return;
        }

        log?.Invoke($"PackLoader: loading packs from {DataRoot}");
        GameDataLoader.LoadAll(DataRoot);

        ConditionCount = ConditionDatabase.Instance?.Conditions.Count ?? 0;
        SpellCount = GameDataLoader.Spells.Count;
        EquipmentCount = GameDataLoader.Equipment.Count;

        // Import creatures file-by-file so a single malformed JSON (e.g. a null splashDamage.value
        // that the engine's ImportAll would rethrow) can't abort the whole catalog.
        _creatures.Clear();
        int skipped = 0;
        foreach (var pack in CreaturePacks)
        {
            var dir = Path.Combine(DataRoot, pack);
            if (!Directory.Exists(dir))
                continue;

            foreach (var file in Directory.EnumerateFiles(dir, "*.json"))
            {
                try
                {
                    var def = CreatureImporter.Import(file);
                    if (def != null)
                        _creatures.Add(def);
                }
                catch (Exception ex)
                {
                    skipped++;
                    log?.Invoke($"PackLoader: skipped {Path.GetFileName(file)} ({ex.GetType().Name}: {ex.Message})");
                }
            }
        }
        if (skipped > 0)
            log?.Invoke($"PackLoader: skipped {skipped} malformed creature file(s)");

        IsLoaded = true;
        log?.Invoke(
            $"PackLoader: loaded {ConditionCount} conditions, {SpellCount} spells, "
            + $"{EquipmentCount} equipment, {CreatureCount} creatures");
    }

    /// <summary>Find an imported creature definition by display name (case-insensitive).</summary>
    public EnemyDefinition? FindCreature(string creatureName)
    {
        return _creatures.FirstOrDefault(
            c => string.Equals(c.CreatureName, creatureName, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>Load a single creature JSON directly by pack subfolder + file slug.</summary>
    public EnemyDefinition LoadCreatureFile(string packSubfolder, string slug)
    {
        var path = Path.Combine(DataRoot, packSubfolder, slug + ".json");
        return GameDataLoader.LoadCreature(path);
    }
}
