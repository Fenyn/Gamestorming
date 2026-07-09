using Godot;

namespace Bulwark.Autoload;

// Single authoritative mutable state root for the whole game.
// Mutations only ever happen via intent-named command methods
// (e.g. PlantCrop, SpendResources, RepairBuilding) that validate
// input and emit change events. UI reads state and raises intents;
// it never mutates state directly (keeps a future co-op seam clean).
// No state or commands implemented yet — scaffold only.
public partial class GameState : Node
{
}
