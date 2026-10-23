using Godot;

namespace Ungilded.Combat;

public partial class UnitVisual3D
{
    /// <summary>Hang the hand lantern on the body; it shows only when this character carries it. Its
    /// light goes out at 0 HP on the bar (dying or dead), the state the Dying badge shows, and comes
    /// back when the bar rises again.</summary>
    private void ConfigureLantern() => GetNode<HandLantern>("%Lantern")
        .Bind(_sprite, _character.Id, () => ShownHp > 0 && _character.Health?.IsDead != true);
}
