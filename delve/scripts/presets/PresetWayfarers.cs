using Delve.Run;
using PF2e.Core;
namespace Delve.Presets;
public static partial class PresetCharacters
{
    public const string RavenId = "raven";
    public const string ThistleId = "thistle";
    public static PF2eCharacter BuildRaven(int level) => BuildWayfarer(BulwarkWayfarers.Raven, level);
    public static PF2eCharacter BuildThistle(int level) => BuildWayfarer(BulwarkWayfarers.Thistle, level);
}
