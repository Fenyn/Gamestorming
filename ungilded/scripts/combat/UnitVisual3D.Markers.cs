using Ungilded.UI;
using Godot;

namespace Ungilded.Combat;

/// <summary>The FFT ground and turn markers: a soft blob shadow and the active-turn crystal; and
/// where a tutorial arrow over the unit points.</summary>
public partial class UnitVisual3D
{
    /// <summary>Blob shadow width per footprint tile, metres.</summary>
    [Export] public float ShadowWidthPerTile { get; set; } = 1.1f;

    /// <summary>Fill alpha of the team-coloured silhouette where something hides the body. Zero, so
    /// only the outline (the sprite's edge_opacity) shows: a filled silhouette washed over the face
    /// of any unit standing in front.</summary>
    [Export] public float SilhouetteAlpha { get; set; } = 0f;

    /// <summary>Extra height of the numbered HP plate over the head, metres, so the number
    /// clears the sprite's hair and hats.</summary>
    [Export] public float BoardPlateLift { get; set; } = 0.15f;

    /// <summary>Crystal height above the HP bar, metres.</summary>
    [Export] public float CrystalLift { get; set; } = 0.8f;

    /// <summary>The crystal's half width, metres (its mesh radius times its scale).</summary>
    [Export] public float CrystalHalfWidth { get; set; } = 0.3f;

    /// <summary>Screen pixels from the crystal's edge to the centre of a tutorial arrow beside it;
    /// more than half the arrow's width, so the arrow does not touch the crystal.</summary>
    [Export] public float CrystalArrowOffset { get; set; } = 22f;

    private Decal? _shadow;
    private ActiveCrystal? _crystal;

    /// <summary>Size the soft ground shadow to the rules footprint and hang the crystal over the
    /// HP bar. A Decal projects onto the terrain, so the blob follows slopes and ledges.</summary>
    private void ConfigureMarkers()
    {
        _shadow = GetNodeOrNull<Decal>("%Shadow");
        _crystal = GetNodeOrNull<ActiveCrystal>("%Crystal");
        if (_shadow != null)
        {
            float width = ShadowWidthPerTile * _character.TileWidth;
            _shadow.Size = _shadow.Size with { X = width, Z = width };
        }
        _crystal?.SetRestHeight(_hpBarY + BoardPlateLift + CrystalLift);
        var team = _character.TeamId == 1 ? UiColors.Ally : UiColors.Enemy;
        _sprite.SetSilhouetteColor(team with { A = SilhouetteAlpha });
        _hpBar.SetTeam(team);
    }

    /// <summary>The unit's place on the combat timeline, shown beside its HP bar; 0 hides it.</summary>
    /// <summary>The timeline number beside the HP bar. An enemy's carries its log letter in the same
    /// label ("3C"), so the two can never drift apart in a cluster.</summary>
    public void SetTimelineNumber(int number) => _hpBar.SetNumber(number, _isHero ? "" : _letter);

    public string TimelineNumberText => _hpBar.NumberText;

    /// <summary>The HP plate's current size step (<see cref="ZoomScale"/>); the command menu follows it.</summary>
    public float PlateZoom => _hpBar.Zoom;

    /// <summary>The numbered HP plate, for the scene's plate layout.</summary>
    public WorldHpBar HpPlate => _hpBar;

    private bool _ringHidden;

    /// <summary>Exploration draws the party with blob shadows only, as FFT does outside battle:
    /// no team ring and no HP bar (the party cards carry HP).</summary>
    public void UseExplorationMarkers()
    {
        _ringHidden = true;
        _ring.Visible = false;
        _hpBar.Visible = false;
    }

    /// <summary>The canvas point a tutorial arrow over this unit points down at: the top of the HP
    /// plate, or the top of the body while the plate layout has lifted the plate off it. While the
    /// turn crystal shows, the point moves left beside the crystal. Null when the body top is
    /// behind the camera.</summary>
    public Vector2? TipArrowPoint(Camera3D camera)
    {
        var head = GlobalPosition + Vector3.Up * _hpBarY;
        if (camera.IsPositionBehind(head)) return null;
        var point = camera.UnprojectPosition(head);
        if (_hpBar.IsVisibleInTree() && _hpBar.Nudge == 0)
            point.Y = Mathf.Min(point.Y, _hpBar.ScreenRect(camera, 0).Position.Y);
        if (_crystal != null && _crystal.IsVisibleInTree())
        {
            var centre = _crystal.GlobalPosition;
            var edge = centre - camera.GlobalBasis.X * CrystalHalfWidth;
            if (!camera.IsPositionBehind(centre) && !camera.IsPositionBehind(edge))
                point.X = camera.UnprojectPosition(edge).X - CrystalArrowOffset;
        }
        return point;
    }

    private void ShowCrystal(bool active)
    {
        if (_crystal != null) _crystal.Visible = active && !_dead;
    }

    private void FadeShadow(float duration)
    {
        if (_shadow == null) return;
        CreateTween().TweenProperty(_shadow, "modulate:a", 0f, duration);
    }
}
