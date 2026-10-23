using System.Collections.Generic;
using System.Linq;
using Ungilded.Story;
using Ungilded.Terrain;
using Ungilded.Tutorial;
using Godot;
using PF2e.Core;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Ungilded.Combat;

/// <summary>
/// Resolves a <see cref="TutorialFocus"/> to screen quads in HUD coordinates: a HUD part to its
/// padded rect, a tile set to one quad per block of tiles projected at surface height. A unit gets
/// no quad: its rect from its feet to its HP bar goes to the rects the box keeps clear of, and a
/// mark over it tells the tip where to draw its arrow. A part that is not drawn now adds nothing.
/// Also keeps a focused tip's transient targets up: the pinned hero card, the pinned creature card,
/// the held roll banner and the held attack preview (CombatScene.HeldPreview.cs).
/// </summary>
public partial class CombatScene
{
    /// <summary>Pixels a focused HUD part's cutout reaches past its rect.</summary>
    [Export] public float FocusPadding { get; set; } = 8f;

    /// <summary>Pixels a focused part of a unit card reaches past its rect. Card rows sit close
    /// together, so this stays small enough to leave the next row's text uncovered.</summary>
    [Export] public float FocusCardPadding { get; set; } = 2f;

    /// <summary>Pixels a focused unit's keep-clear rect reaches past its sprite.</summary>
    [Export] public float FocusUnitPadding { get; set; } = 6f;

    /// <summary>A focused unit the command menu covers more of than this share adds no rect until
    /// the menu closes.</summary>
    [Export(PropertyHint.Range, "0,1,0.05")] public float FocusUnitMinShownShare { get; set; } = 0.5f;

    /// <summary>The most quads one focus resolves to; a tile set that needs more becomes one block.
    /// Matches MAX_QUADS in the spotlight shader.</summary>
    [Export] public int MaxFocusQuads { get; set; } = 16;

    private ICharacter? _pinnedHero;
    private ICharacter? _pinnedCreature;

    /// <summary>Keep the focus's transient targets up while its tip shows (true), or let them go.</summary>
    public void HoldFocus(TutorialFocus focus, bool hold)
    {
        if (focus.PinnedHero is { } hero) _pinnedHero = hold ? hero : null;
        if (focus.PinnedCreature is { } creature) _pinnedCreature = hold ? creature : null;
        if (focus.HoldsRollBanner) _dice.Hold(hold);
        if (focus.PreviewTarget is { } previewed) HoldPreview(hold ? previewed : null);
        if (_session != null) RefreshCard();
    }

    /// <summary>Drop every pin, for a teardown.</summary>
    private void ReleaseFocusHolds()
    {
        _pinnedHero = null;
        _pinnedCreature = null;
        _dice.Hold(false);
        _previewHeldOn = null;
    }

    /// <summary>Fill <paramref name="quads"/> with the focus's screen quads, four corners each,
    /// clockwise on screen, and <paramref name="clear"/> with what a tip box must not cover (the
    /// cards the focused parts sit on, the named units and the context targets) and with a mark
    /// over each named unit, where the tip draws its arrow. A focus of units alone fills only
    /// <paramref name="clear"/>. When no target that is not context shows, both stay empty.</summary>
    public void ResolveFocus(TutorialFocus focus, List<Vector2[]> quads, TipClearance clear)
    {
        quads.Clear();
        clear.Reset();
        if (_session == null) return;
        _markRects.Clear();
        _contextRects.Clear();
        foreach (var target in focus.Targets)
        {
            if (target.Part == FocusPart.Units)
            {
                foreach (var unit in target.Units ?? System.Array.Empty<ICharacter>())
                {
                    AddUnit(target.Context ? _contextRects : _markRects, unit);
                    if (!target.Context) AddMark(clear.Marks, unit);
                }
                continue;
            }
            if (!target.Context)
            {
                ResolveTarget(target, quads, clear);
                continue;
            }
            _contextQuads.Clear();
            ResolveTarget(target, _contextQuads, clear);
            foreach (var quad in _contextQuads) _contextRects.Add(QuadBounds(quad));
        }
        if (quads.Count == 0 && _markRects.Count == 0 && clear.Marks.Count == 0)
        {
            clear.Reset();
            return;
        }
        clear.AddRange(_markRects);
        clear.AddRange(_contextRects);
        if (quads.Count > MaxFocusQuads) quads.RemoveRange(MaxFocusQuads, quads.Count - MaxFocusQuads);
    }

    private readonly List<Vector2[]> _contextQuads = new();
    private readonly List<Rect2> _markRects = new();
    private readonly List<Rect2> _contextRects = new();

    private static Rect2 QuadBounds(Vector2[] quad)
    {
        var rect = new Rect2(quad[0], Vector2.Zero);
        foreach (var corner in quad) rect = rect.Expand(corner);
        return rect;
    }

    private void ResolveTarget(FocusTarget target, List<Vector2[]> quads, List<Rect2> clear)
    {
        switch (target.Part)
        {
            case FocusPart.ActionPips: AddCardPart(quads, clear, CardFor(target.Unit), c => c.ActionPipsPart); break;
            case FocusPart.Reaction: AddCardPart(quads, clear, CardFor(target.Unit), c => c.ReactionPart); break;
            case FocusPart.HpBar:
                if (CardFor(target.Unit) is { } heroCard)
                {
                    AddParts(quads, heroCard.HpParts(), FocusCardPadding);
                    clear.Add(heroCard.GetGlobalRect());
                }
                break;
            case FocusPart.Command:
                // The box keeps off the whole menu, so the disabled entries stay readable, and off
                // the hero the menu belongs to.
                if (!AddParts(quads, _actionBar.CommandParts(target.Label))) break;
                clear.Add(_actionBar.BarPanel.GetGlobalRect());
                if (_session.CurrentActor is { } actor) AddUnit(clear, actor);
                break;
            case FocusPart.KnowledgeRow:
                if (KnowledgePart(target.Unit, target.Field) is { } row)
                {
                    AddPart(quads, row, FocusCardPadding);
                    clear.Add(_targetCard.GetGlobalRect());
                }
                break;
            case FocusPart.RollBanner: AddPart(quads, _dice.IsVisibleInTree() ? _dice : null); break;
            case FocusPart.Timeline:
                if (_turnBar.IsVisibleInTree()) AddRect(quads, _turnBar.ContentRect, FocusPadding);
                break;
            case FocusPart.Condition:
                if (target.Unit == null || _turnBar.MarksFor(target.Unit.UniqueId) is not { } marks) break;
                AddPart(quads, marks);
                // The timeline row and the hero card both list the condition; the box covers neither.
                clear.Add(_turnBar.ContentRect);
                if (CardFor(target.Unit) is { } conditionCard) clear.Add(conditionCard.GetGlobalRect());
                break;
            case FocusPart.JournalButton: AddPart(quads, JournalButton.IsVisibleInTree() ? JournalButton : null); break;
            case FocusPart.MoveBand:
                AddTiles(quads, _lastBands.Keys.Concat(_session.Tutorial?.MoveTiles ?? NoTiles).Distinct().ToArray());
                break;
            case FocusPart.GuideTiles: AddTiles(quads, (_session.Tutorial?.MoveTiles ?? NoTiles).ToArray()); break;
            case FocusPart.Tiles: AddTiles(quads, target.Tiles ?? NoTiles); break;
            case FocusPart.AttackPreview:
                var preview = _actionBar.Decision.Card;
                AddPart(quads, preview.IsVisibleInTree() ? preview : null);
                break;
        }
    }

    /// <summary>The hero card when it shows <paramref name="hero"/> (or anyone, for null).</summary>
    private Ungilded.UI.UnitInspectPanel? CardFor(ICharacter? hero)
        => _inspectPanel.Visible && (hero == null || _inspectPanel.NameText == hero.Name) ? _inspectPanel : null;

    private Control? KnowledgePart(ICharacter? creature, CreatureKnowledgeField field)
    {
        if (creature == null || _targetCardUnit != creature) return null;
        return field == CreatureKnowledgeField.Name
            ? _targetCard.NamePart
            : _targetCard.KnowledgePart(UnitInspectFactory.CardLabel(field));
    }

    private void AddCardPart(List<Vector2[]> quads, List<Rect2> clear, Ungilded.UI.UnitInspectPanel? card,
        System.Func<Ungilded.UI.UnitInspectPanel, Control?> part)
    {
        if (card == null || part(card) is not { } control) return;
        AddPart(quads, control, FocusCardPadding);
        clear.Add(card.GetGlobalRect());
    }

    /// <summary>True when any part was drawn.</summary>
    private bool AddParts(List<Vector2[]> quads, IEnumerable<Control> parts, float? padding = null)
    {
        float pad = padding ?? FocusPadding;
        Rect2? union = null;
        bool any = false;
        foreach (var part in parts)
        {
            any = true;
            // A sub-menu or quick-slot row is a separate panel; the entry and its own label merge.
            var rect = part.GetGlobalRect();
            if (part is Ungilded.UI.ChipFlyout) AddRect(quads, rect, pad);
            else union = union is { } u ? u.Merge(rect) : rect;
        }
        if (union is { } merged) AddRect(quads, merged, pad);
        return any;
    }

    private void AddPart(List<Vector2[]> quads, Control? part, float? padding = null)
    {
        if (part != null) AddRect(quads, part.GetGlobalRect(), padding ?? FocusPadding);
    }

    private static void AddRect(List<Vector2[]> quads, Rect2 rect, float padding)
    {
        var r = rect.Grow(padding);
        quads.Add(new[] { r.Position, new Vector2(r.End.X, r.Position.Y), r.End, new Vector2(r.Position.X, r.End.Y) });
    }

    private void AddTiles(List<Vector2[]> quads, IReadOnlyCollection<PF2eVec> allTiles)
    {
        // Only tiles that show: on screen and not under a HUD panel, which draws over the board.
        var tiles = TilesInView(allTiles);
        if (tiles.Count == 0) return;
        var heights = SurfaceHeights;
        var blocks = TileRegions.Blocks(tiles, heights.CenterY);
        if (quads.Count + blocks.Count > MaxFocusQuads) blocks = new() { TileRegions.Bounds(tiles, heights.CenterY) };
        var camera = _cameraRig.Camera;
        foreach (var block in blocks)
        {
            var corners = new[]
            {
                new Vector3(block.X0, block.Height, block.Y0),
                new Vector3(block.X1 + 1, block.Height, block.Y0),
                new Vector3(block.X1 + 1, block.Height, block.Y1 + 1),
                new Vector3(block.X0, block.Height, block.Y1 + 1),
            };
            if (corners.Any(camera.IsPositionBehind)) continue;
            quads.Add(Clockwise(corners.Select(camera.UnprojectPosition).ToArray()));
        }
    }

    /// <summary>The unit's rect from its feet to its HP bar, one footprint wide. Only the part
    /// outside the open command menu counts, since the menu draws over the board.</summary>
    private void AddUnit(List<Rect2> rects, ICharacter unit)
    {
        if (UnitScreenRect(unit) is not { } rect) return;
        var menu = _actionBar.BarPanel;
        if (menu.IsVisibleInTree())
        {
            if (OutsideOf(rect, menu.GetGlobalRect()) is not { } visible
                || visible.Area < rect.Area * FocusUnitMinShownShare) return;
            rect = visible;
        }
        rects.Add(rect);
    }

    /// <summary>The point the tip's arrow over <paramref name="unit"/> points down at, when its token shows.</summary>
    private void AddMark(List<Vector2> marks, ICharacter unit)
    {
        if (_tacticalUnits.TryGetValue(unit.UniqueId, out var visual) && visual.IsVisibleInTree()
            && visual.TipArrowPoint(_cameraRig.Camera) is { } point)
            marks.Add(point);
    }

    /// <summary>The unit's padded screen rect from its feet to its HP bar, one footprint wide, or
    /// null when it has no visible token or part of it is behind the camera.</summary>
    private Rect2? UnitScreenRect(ICharacter unit)
    {
        if (!_tacticalUnits.TryGetValue(unit.UniqueId, out var visual) || !visual.IsVisibleInTree()) return null;
        var camera = _cameraRig.Camera;
        var right = camera.GlobalBasis.X * (TeamRing.RadiusPerTile * unit.TileWidth);
        var feet = visual.GlobalPosition;
        var head = feet + Vector3.Up * visual.HpBarHeight;
        var points = new[] { feet - right, feet + right, head - right, head + right };
        if (points.Any(camera.IsPositionBehind)) return null;
        var screen = points.Select(camera.UnprojectPosition).ToArray();
        var rect = new Rect2(screen[0], Vector2.Zero);
        foreach (var p in screen) rect = rect.Expand(p);
        return rect.Grow(FocusUnitPadding);
    }

    /// <summary>The largest part of <paramref name="rect"/> outside <paramref name="cover"/>, or null
    /// when the cover hides all of it.</summary>
    private static Rect2? OutsideOf(Rect2 rect, Rect2 cover)
    {
        if (!rect.Intersects(cover)) return rect;
        var parts = new[]
        {
            new Rect2(rect.Position, new Vector2(cover.Position.X - rect.Position.X, rect.Size.Y)),
            new Rect2(new Vector2(cover.End.X, rect.Position.Y), new Vector2(rect.End.X - cover.End.X, rect.Size.Y)),
            new Rect2(rect.Position, new Vector2(rect.Size.X, cover.Position.Y - rect.Position.Y)),
            new Rect2(new Vector2(rect.Position.X, cover.End.Y), new Vector2(rect.Size.X, rect.End.Y - cover.End.Y)),
        };
        Rect2? best = null;
        foreach (var part in parts)
            if (part.Size.X > 0 && part.Size.Y > 0 && (best == null || part.Area > best.Value.Area)) best = part;
        return best;
    }

    /// <summary>The corners in the order the spotlight shader expects: positive shoelace area on screen.</summary>
    private static Vector2[] Clockwise(Vector2[] corners)
    {
        float area = 0;
        for (int i = 0; i < corners.Length; i++)
        {
            var a = corners[i];
            var b = corners[(i + 1) % corners.Length];
            area += a.X * b.Y - b.X * a.Y;
        }
        if (area < 0) System.Array.Reverse(corners);
        return corners;
    }
}
