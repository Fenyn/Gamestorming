using Delve.UI;
using Godot;

namespace Delve.Combat;

/// <summary>The FFT ground and turn markers: a soft blob shadow and the active-turn crystal.</summary>
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
    public void SetTimelineNumber(int number) => _hpBar.SetNumber(number);

    public string TimelineNumberText => _hpBar.NumberText;

    private bool _ringHidden;

    /// <summary>Exploration draws the party with blob shadows only, as FFT does outside battle:
    /// no team ring and no HP bar (the party cards carry HP).</summary>
    public void UseExplorationMarkers()
    {
        _ringHidden = true;
        _ring.Visible = false;
        _hpBar.Visible = false;
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
