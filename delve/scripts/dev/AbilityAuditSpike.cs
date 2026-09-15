using System.Linq;
using System.Threading.Tasks;
using Delve.Autoload;
using Delve.Combat;
using Delve.Run;
using Godot;

namespace Delve.Dev;

/// <summary>Read-only inventory of granted actions and their combat UI adapters.</summary>
public partial class AbilityAuditSpike : SpikeBase
{
    [Export] public PackedScene BarScene { get; set; } = null!;
    [Export] public Theme BarTheme { get; set; } = null!;
    protected override async Task RunSpikeAsync(DataManager data)
    {
        foreach (var definition in CharacterCatalog.All)
            foreach (int level in new[] { 2, 4, 10 })
            {
                var character = definition.Builder(level);
                var actions = character.Features?.GetAllGrantedActions();
                Check($"{character.Name} L{level}: all earned abilities have UI adapters", actions != null && actions.All(a =>
                    SkillActionCatalog.IdForGrantedAction(a.ActionName) != null
                    || SkillActionCatalog.Basic.Any(b => b.Factory().ActionName == a.ActionName)));
                GD.Print($"[AbilityAudit] {character.Name} L{level}: " + string.Join("; ",
                    actions?.Select(a => $"{a.ActionName} => {SkillActionCatalog.IdForGrantedAction(a.ActionName)
                        ?? SkillActionCatalog.Basic.FirstOrDefault(b => b.Factory().ActionName == a.ActionName)?.Id
                        ?? "MISSING"}")
                    ?? System.Array.Empty<string>()));
            }
        foreach (var definition in CharacterCatalog.All)
        {
            var character = definition.Builder(1);
            Delve.Presets.PresetCharacters.LevelUpInPlace(character, 10);
            Check($"{character.Name}: live level-up preserves ability coverage", character.Features.GetAllGrantedActions().All(a =>
                SkillActionCatalog.IdForGrantedAction(a.ActionName) != null
                || SkillActionCatalog.Basic.Any(b => b.Factory().ActionName == a.ActionName)));
        }
        await CheckCombatAdapters();
        await CheckSignatureUi();
    }
}
