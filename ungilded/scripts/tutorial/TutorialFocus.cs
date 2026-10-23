using System.Collections.Generic;
using System.Linq;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Tutorial;

/// <summary>A part of the fight a tutorial tip can point at.</summary>
public enum FocusPart
{
    /// <summary>The action squares on a hero's card.</summary>
    ActionPips,
    /// <summary>The reaction diamond on a hero's card.</summary>
    Reaction,
    /// <summary>The HP line and bar on a hero's card.</summary>
    HpBar,
    /// <summary>A command menu entry by label, with its open sub-menu and enabled quick slots.</summary>
    Command,
    /// <summary>One knowledge row on a creature's card.</summary>
    KnowledgeRow,
    /// <summary>The d20 roll banner at the bottom centre.</summary>
    RollBanner,
    /// <summary>The turn order down the left edge.</summary>
    Timeline,
    /// <summary>A unit's condition icons on the timeline.</summary>
    Condition,
    JournalButton,
    /// <summary>The live move bands and the gold tiles.</summary>
    MoveBand,
    /// <summary>The live gold tiles a restricted move accepts.</summary>
    GuideTiles,
    /// <summary>A fixed set of board tiles.</summary>
    Tiles,
    /// <summary>Units on the board, each by its sprite.</summary>
    Units,
    /// <summary>The attack preview card above the action bar, held on the target while Strike aims.</summary>
    AttackPreview,
}

/// <summary>One target of a <see cref="TutorialFocus"/>.</summary>
/// <param name="Unit">The hero whose card shows the part, or the creature whose card shows the
/// knowledge row, or the unit whose timeline row shows the condition.</param>
/// <param name="Label">The command label, or the condition icon key.</param>
/// <param name="Context">True keeps the target visible next to the tip without cutting it out:
/// the box does not cover it, and the dim stays over it.</param>
public sealed record FocusTarget(
    FocusPart Part,
    ICharacter? Unit = null,
    string Label = "",
    CreatureKnowledgeField Field = CreatureKnowledgeField.None,
    IReadOnlyList<PF2eVec>? Tiles = null,
    IReadOnlyList<ICharacter>? Units = null,
    bool Context = false);

/// <summary>
/// What a tutorial tip points at: HUD parts and board targets. The combat scene resolves it to
/// screen quads every frame, so the cutout follows the camera and the layout. While a tip with a
/// focus shows, the scene keeps its transient targets up: a hero part pins that hero's card, a
/// knowledge row pins the creature card, the roll banner holds, and the attack preview shows its
/// target while Strike aims.
/// </summary>
public sealed record TutorialFocus(IReadOnlyList<FocusTarget> Targets)
{
    /// <summary>False draws the outline with no dim, and a step tip then lets every click through.</summary>
    public bool Dimmed { get; init; } = true;

    public static TutorialFocus ActionPips(ICharacter hero) => One(new(FocusPart.ActionPips, hero));
    public static TutorialFocus Reaction(ICharacter hero) => One(new(FocusPart.Reaction, hero));
    public static TutorialFocus HpBar(ICharacter hero) => One(new(FocusPart.HpBar, hero));
    public static TutorialFocus Command(string label) => One(new(FocusPart.Command, Label: label));

    /// <summary>Every entry of the command menu: every label starts with the empty one.</summary>
    public static TutorialFocus CommandMenu => Command("");

    public static TutorialFocus KnowledgeRow(ICharacter creature, CreatureKnowledgeField field)
        => One(new(FocusPart.KnowledgeRow, creature, Field: field));

    public static TutorialFocus RollBanner => One(new(FocusPart.RollBanner));
    public static TutorialFocus Timeline => One(new(FocusPart.Timeline));
    public static TutorialFocus Condition(ICharacter unit, string iconKey) => One(new(FocusPart.Condition, unit, iconKey));
    public static TutorialFocus JournalButton => One(new(FocusPart.JournalButton));
    public static TutorialFocus MoveBand => One(new(FocusPart.MoveBand));
    public static TutorialFocus GuideTiles => One(new(FocusPart.GuideTiles));
    public static TutorialFocus Tiles(IEnumerable<PF2eVec> tiles) => One(new(FocusPart.Tiles, Tiles: tiles.ToArray()));
    public static TutorialFocus Units(params ICharacter[] units) => One(new(FocusPart.Units, Units: units));
    public static TutorialFocus AttackPreview(ICharacter target) => One(new(FocusPart.AttackPreview, target));

    public static TutorialFocus operator +(TutorialFocus a, TutorialFocus b)
        => new(a.Targets.Concat(b.Targets).ToArray()) { Dimmed = a.Dimmed && b.Dimmed };

    /// <summary>The same targets as context: kept clear of the box, not cut out.</summary>
    public TutorialFocus AsContext() => this with { Targets = Targets.Select(t => t with { Context = true }).ToArray() };

    public TutorialFocus Undimmed() => this with { Dimmed = false };

    /// <summary>The hero whose card the focus needs, or null.</summary>
    public ICharacter? PinnedHero
        => Targets.FirstOrDefault(t => t.Part is FocusPart.ActionPips or FocusPart.Reaction or FocusPart.HpBar)?.Unit;

    /// <summary>The creature whose card the focus needs, or null.</summary>
    public ICharacter? PinnedCreature => Targets.FirstOrDefault(t => t.Part == FocusPart.KnowledgeRow)?.Unit;

    public bool HoldsRollBanner => Targets.Any(t => t.Part == FocusPart.RollBanner);

    /// <summary>The creature the attack preview holds on while Strike aims, or null.</summary>
    public ICharacter? PreviewTarget => Targets.FirstOrDefault(t => t.Part == FocusPart.AttackPreview)?.Unit;

    private static TutorialFocus One(FocusTarget target) => new(new[] { target });
}
