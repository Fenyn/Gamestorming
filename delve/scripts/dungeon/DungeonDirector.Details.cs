using System.Linq;
using Delve.Combat;
using Delve.Flow;
using Delve.UI;
using Godot;
using PF2e.Core;

namespace Delve.Dungeon;

public partial class DungeonDirector
{
    private CharacterDetailsOverlay _details = null!;
    private UnitVisual3D? _hoveredPartyMember;

    private void SetHoveredPartyMember(UnitVisual3D? member)
    {
        if (_hoveredPartyMember == member) return;
        if (GodotObject.IsInstanceValid(_hoveredPartyMember))
            _hoveredPartyMember!.GetNode<BillboardSpriteAnimator>("%Sprite").SetHoverHighlight(false, Colors.White);
        _hoveredPartyMember = member;
        if (member != null)
            member.GetNode<BillboardSpriteAnimator>("%Sprite").SetHoverHighlight(true, UiColors.CharacterAccent(member.Character.Id));
    }

    private UnitVisual3D? PickPartyMember(Vector2 screen)
    {
        var camera = _camera.Camera;
        var origin = camera.ProjectRayOrigin(screen);
        var direction = camera.ProjectRayNormal(screen);
        UnitVisual3D? closest = null;
        float nearest = float.PositiveInfinity;
        foreach (var token in _tokens)
            if (token.GetNode<UnitPickArea>("%PickArea").HitSprite(camera, origin, direction, out float distance)
                && distance < nearest)
            {
                closest = token;
                nearest = distance;
            }
        return closest;
    }

    private void OpenCharacterDetails(UnitVisual3D token)
    {
        if (Phase != DungeonPhase.Doors || ScreenOpen || token.Character is not PF2eCharacter character) return;
        _pendingDoorClick = null;
        SetHoveredPartyMember(null);
        _doorPress = null;
        CurrentView.SetHoveredDoor(null);
        _focusedDoor = null;
        _hud.HideDoorTip();
        _details.SetPromotionQueue(State.Party.Members);
        _details.Open(character, HeroPortraits.For(character.Id), UiColors.CharacterAccent(character.Id));
        _camera.ProcessMode = ProcessModeEnum.Disabled;
    }

    /// <summary>A party strip chip was clicked.</summary>
    private void OpenMemberDetails(int uniqueId)
    {
        if (Phase != DungeonPhase.Doors || ScreenOpen) return;
        var token = _tokens.FirstOrDefault(t => t.Character.UniqueId == uniqueId);
        if (token != null) OpenCharacterDetails(token);
    }

    private void CloseCharacterDetails()
    {
        RefreshHud();
        _pendingDoorClick = null;
        _doorPress = null;
        if (IsVisibleInTree() && Phase == DungeonPhase.Doors)
            _camera.ProcessMode = ProcessModeEnum.Inherit;
    }
}
