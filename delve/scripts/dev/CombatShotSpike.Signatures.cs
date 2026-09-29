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
        var card = scene.GetNode<Control>("%UnitInspect");
        var log = scene.GetNode<CombatLogPanel>("%CombatLog");
        log.SetExpanded(false);
        foreach (var row in log.Rows) row.GetNode<Button>("%Disclosure").ButtonPressed = false;
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
            bar.Render(new ActionBarState { ActorName = character.Name, ActorId = character.Id, ActionsRemaining = 3,
                Hp = character.Health.CurrentHP, MaxHp = character.Health.MaxHP, CanStrike = true, CanDelay = true,
                SkillEntries = entries });
            bar.SetInteractable(true);
            await WaitSeconds(PoseSeconds);
            var signature = bar.GetNode<Control>("%SignatureActions");
            Check($"{character.Name} quick slots show as rows inside the command menu",
                signature.Visible && bar.BarPanel.GetGlobalRect().Grow(1).Encloses(signature.GetGlobalRect()));
            AssertZones(scene, $"combat_signature_{character.Id}.png");
            Check($"{character.Name} card slot stays clear of the bar", !card.GetGlobalRect().Intersects(bar.BarPanel.GetGlobalRect()));
            Capture($"combat_signature_{character.Id}.png");
            dice.ClearRoll();
        }
    }
}
