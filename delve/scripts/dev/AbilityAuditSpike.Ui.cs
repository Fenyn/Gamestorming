using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class AbilityAuditSpike
{
    private async Task CheckSignatureUi()
    {
        var bar = BarScene.Instantiate<ActionBar>(); bar.Theme = BarTheme; AddChild(bar);
        var row = bar.GetNode<ChipFlyout>("%SignatureActions");
        var flyout = bar.GetNode<ChipFlyout>("%Flyout");
        Button[] Buttons(Control parent) => parent.FindChildren("*", "Button", true, false).Cast<Button>().ToArray();
        string[] Names(Control parent) => Buttons(parent).Select(b => b.GetNode<Label>("%NameLabel").Text).ToArray();
        var skill = new SkillEntryView { ActionId = "double-slice", Name = "Double Slice", ActionCost = 2,
            Castable = true, IsCharacterAbility = true, SignaturePriority = 10 };
        var general = new SkillEntryView { ActionId = "trip", Name = "Trip", ActionCost = 1, Castable = true };
        var state = new ActionBarState { ActorName = "Elara", ActionsRemaining = 3, SkillEntries = new[] { skill, general } };
        bar.Render(state); bar.SetInteractable(true);
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        Check("signature row promotes only the defining action", row.Visible && Names(row).SequenceEqual(new[] { "Double Slice" }));
        string? routed = null; bar.SkillChipPressed += id => routed = id;
        Buttons(row)[0].EmitSignal(Button.SignalName.Pressed);
        Check("signature button dispatches the original skill ID", routed == "double-slice");
        bar.Render(state with { ActionsRemaining = 1, SkillEntries = new[] { skill with { Castable = false, UnavailableReason = "Needs 2 actions (1 left)" }, general } });
        Check("unavailable signature stays in its slot with an explanation", Names(row).SequenceEqual(new[] { "Double Slice" })
            && Buttons(row)[0].Disabled && Buttons(row)[0].TooltipText.Contains("Needs 2 actions"));
        bar.GetNode<Button>("%SkillsButton").ButtonPressed = true;
        var headings = flyout.FindChildren("*", "Label", true, false).Cast<Label>().Select(l => l.Text).ToArray();
        // The quick slots are rows of the main menu (FFT), so they stay beside an open sub-menu; the
        // sub-menu itself lists each action once.
        Check("Abilities groups character and general actions, each listed once", row.Visible
            && headings.Contains("Character") && headings.Contains("General") && Names(flyout).Count(n => n == "Double Slice") == 1);
        bar.GetNode<Button>("%SkillsButton").ButtonPressed = false;
        bar.Render(state with { SkillEntries = Enumerable.Range(1, 4).Select(i => skill with { ActionId = $"a{i}", Name = $"Ability {i}", SignaturePriority = i }).ToArray() });
        Check("signature row is capped at three in authored order", Names(row).SequenceEqual(new[] { "Ability 1", "Ability 2", "Ability 3" }));
        var heal = new SpellEntryView { SpellId = "preset-heal", Name = "Heal (1 action)", SignatureName = "Heal", SignaturePriority = 10,
            VariantIndex = 0, ActionCost = 1, Castable = true };
        bar.Render(new ActionBarState { ActorName = "Tharr", SpellEntries = new[] { heal, heal with { VariantIndex = 1, ActionCost = 2, Name = "Heal (2 actions)" } } });
        int casts = 0, variant = -1; bar.SpellChipPressed += (_, v) => { casts++; variant = v; };
        Check("spell variants share one signature shortcut", Names(row).SequenceEqual(new[] { "Heal" }));
        Buttons(row)[0].EmitSignal(Button.SignalName.Pressed);
        Check("Heal shortcut opens cost choices without casting", casts == 0 && flyout.Visible && Buttons(flyout).Length == 2);
        Buttons(flyout)[1].EmitSignal(Button.SignalName.Pressed);
        Check("spell choice retains the chosen cost variant", casts == 1 && variant == 1);
        bar.SetInteractable(false);
        Check("signature row clears during other actors' turns", !row.Visible);
        RemoveChild(bar); bar.QueueFree();
    }
}
