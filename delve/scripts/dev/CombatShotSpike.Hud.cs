using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Delve.Combat;
using Delve.UI;
using Godot;

namespace Delve.Dev;

public partial class CombatShotSpike
{
    // Deterministic presentation fixtures cover states the random encounter cannot guarantee.
    private async Task CaptureHudReview(CombatScene scene)
    {
        var bar = scene.GetNode<ActionBar>("%ActionBar");
        var icons = bar.SpellIcons;
        bool covered = icons != null;
        foreach (var field in typeof(Delve.Data.PresetSpells).GetFields(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static))
            if (field.IsLiteral && field.FieldType == typeof(string) && field.Name.EndsWith("Id"))
            {
                var id = (string)field.GetRawConstantValue()!;
                covered &= icons?.ForSpell(id) != null && icons.ForSpell(id) != icons.Fallback;
            }
        Check("every preset spell has dedicated artwork", covered);
        Check("heightened spells keep their icon", icons != null
            && icons.ForSpell("preset-fireball-rank-5") == icons.ForSpell("preset-fireball"));
        Check("unknown spells have a fallback icon", icons?.ForSpell("unknown-spell") != null);
        var controls = bar.GetNode<Button>("%ControlButton");
        var options = bar.GetNode<Control>("%ControlOptions");
        var spells = bar.GetNode<Button>("%SpellsButton");
        controls.ButtonPressed = true;
        await WaitSeconds(PoseSeconds);
        Check("control preferences open without the spell menu", options.Visible && !bar.GetNode<Control>("%Flyout").Visible);
        Check("Overview and Plan orders live in the Control flyout",
            bar.GetNode<Control>("%Overview").IsVisibleInTree() && bar.GetNode<Control>("%StageOrders").IsVisibleInTree());
        Capture("combat_controls.png");
        spells.ButtonPressed = true;
        Check("spell menu closes control preferences", !options.Visible && !controls.ButtonPressed);
        spells.ButtonPressed = false;
        controls.ButtonPressed = true;
        bar._UnhandledInput(new InputEventAction { Action = InputNames.UiCancel, Pressed = true });
        Check("Escape closes preferences", !options.Visible && !controls.ButtonPressed);

        var inspect = scene.GetNode<UnitInspectPanel>("%UnitInspect");
        inspect.Render(new UnitInspectView
        {
            Name = "Goblin Warrior E", Letter = "E", BaseName = "Goblin Warrior", IsAlly = false, Hp = 14, MaxHp = 20,
            AcText = "AC ?", HpText = "?/?",
            Conditions = new[] { "Frightened 2", "Off-guard", "Shield Raised" },
        });
        bar.SetTargetingHint(true);
        bar.ShowAttackPreview(new AttackPreviewView
        {
            AttackerName = "Fenwick", TargetName = "Goblin Warrior E", WeaponName = "Crossbow",
            TotalAttackBonus = 3, TargetAcText = "?", HitChanceText = "?%",
            CritChanceText = "?%", DamageFormula = "1d8 piercing",
            Figures = new FigureView[] { new("Hit", "?%"), new("Crit", "?%"), new("Damage", "1d8 piercing") },
            Modifiers = new ModifierChip[] { new("MAP", -5), new("Off-guard (Prone)", 2, "Prone"), new("Frightened 1", -1, "Frightened") },
        });
        await WaitSeconds(PoseSeconds);
        var card = bar.Decision.Card;
        var end = bar.GetNode<Control>("%EndButton");
        Check("inspect does not overlap the command row", !inspect.GetGlobalRect().Intersects(end.GetGlobalRect()));
        Check("inspect and attack forecast have separate space", !inspect.GetGlobalRect().Intersects(card.GetGlobalRect()));
        var figures = bar.Decision.FigureLabels;
        Check($"forecast draws labelled figures ({string.Join(", ", figures.Select(f => $"{f.CaptionText} {f.ValueText}"))})",
            figures.Count == 3 && figures[0].CaptionText == "Hit" && figures[0].ValueText == "?%");
        Check("forecast keeps the sentences on its hover", card.TooltipText.Contains("?% hit"));
        Check($"forecast draws the modifier line in order ({string.Join(", ", bar.Decision.ModifierTexts)})",
            bar.Decision.ModifierTexts.SequenceEqual(new[] { "MAP -5", "Off-guard (Prone) +2", "Frightened 1 -1" }));
        var slot = inspect.GetGlobalRect();
        var nameLabel = inspect.GetNode<Label>("%NameLabel");
        float nameWidth = nameLabel.GetThemeFont("font").GetStringSize(nameLabel.Text, HorizontalAlignment.Left, -1,
            nameLabel.GetThemeFontSize("font_size")).X;
        Check($"the card slot hides unknown HP and AC, fits the base name beside the badge and stays 288x72 ('{inspect.NameText}' {nameWidth:0}/{nameLabel.Size.X:0}; {slot.Size})",
            !inspect.HpShown && !inspect.AcShown && inspect.NameText == "Goblin Warrior" && nameWidth <= nameLabel.Size.X + 1
            && Mathf.Abs(slot.Size.X - 288) <= 1 && slot.Size.Y <= 72.5f);
        Check("inspect carries the enemy letter", inspect.GetNode<Label>("%BadgeLabel").Text == "E"
            && inspect.GetNode<Control>("%Badge").Visible);
        AssertZones(scene, "combat_target_preview.png");
        CheckBudget(scene, "targeting", 0, null);
        Capture("combat_target_preview.png");
        bar.ShowAttackPreview(new AttackPreviewView
        {
            AttackerName = "Fenwick", TargetName = "Goblin Warrior E", WeaponName = "Electric Arc",
            OutcomeText = "65% target fails · 15% critical failure",
            DetailText = "Reflex +6 vs spell DC 20 · 3d4 damage · Basic save",
            Figures = new FigureView[] { new("Fails", "65%"), new("Crit fail", "15%"), new("Damage", "3d4") },
            Tags = new[] { "Reflex DC 20", "Basic save" },
        });
        await WaitSeconds(PoseSeconds);
        AssertZones(scene, "combat_spell_preview.png");
        Capture("combat_spell_preview.png");
        inspect.Render(null);
        bar.ShowAttackPreview(null);
        bar.SetTargetingHint(false);
    }
}
