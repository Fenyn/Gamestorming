using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.Presets;
using Delve.Run;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatShotSpike
{
    private async Task CaptureSignatures(CombatScene scene)
    {
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var panel = scene.GetNode<ActiveCharacterPanel>("%ActiveCharacter");
        scene.GetNode<CombatLogPanel>("%CombatLog").SetExpanded(false);
        var dice = scene.GetNode<DiceRollPanel>("%DiceRoll");
        foreach (var character in new[] { PresetCharacters.BuildElara(2), CharacterCatalog.Find("sera")!.Builder(2) })
        {
            var entries = character.Features.GetAllGrantedActions().Select(action =>
            {
                var definition = SkillActionCatalog.Get(SkillActionCatalog.IdForGrantedAction(action.ActionName)!);
                return new SkillEntryView { ActionId = definition!.Id, Name = action.ActionName,
                    ActionCost = action.ActionCostCount, Castable = true, IsCharacterAbility = true,
                    SignaturePriority = definition.SignaturePriority, Description = action.Description };
            }).ToArray();
            bar.Render(new ActionBarState { ActorName = character.Name, ActionsRemaining = 3,
                Hp = character.Health.CurrentHP, MaxHp = character.Health.MaxHP, CanStrike = true, CanDelay = true,
                SkillEntries = entries });
            bar.SetInteractable(true);
            panel.Render(ActiveCharacterView.From(character));
            await WaitSeconds(PoseSeconds);
            var signature = bar.GetNode<Control>("%SignatureActions");
            Check($"{character.Name} signature row fits beside the active card",
                signature.Visible && !signature.GetGlobalRect().Intersects(panel.GetGlobalRect()));
            Check($"{character.Name} dice have room above the signature row and hint",
                !dice.GetGlobalRect().Intersects(signature.GetGlobalRect())
                && !dice.GetGlobalRect().Intersects(bar.GetNode<Control>("%TargetingHint").GetGlobalRect()));
            Capture($"combat_signature_{character.Id}.png");
            dice.ClearRoll();
        }
    }
}
