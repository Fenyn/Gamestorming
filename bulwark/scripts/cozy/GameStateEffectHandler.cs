using Bulwark.Autoload;

namespace Bulwark.Cozy;

/// <summary>
/// Routes dialogue effects through the existing GameState commands. Implements
/// <see cref="IDialogueEffectHandler"/> for the <see cref="DialogueRunner"/>.
/// </summary>
public sealed class GameStateEffectHandler : IDialogueEffectHandler
{
    private readonly GameState? _gs;

    public GameStateEffectHandler(GameState? gs)
    {
        _gs = gs;
    }

    public void SetFlag(string flagId) => _gs?.SetStoryFlag(flagId);

    public void AddFriendship(string charId, int amount) => _gs?.AddDialogueFriendship(charId, amount);

    public void GiveItem(string itemId, int quantity) => _gs?.AddItem(itemId, quantity);

    public void MarkSeen(string dialogueId) => _gs?.MarkDialogueSeen(dialogueId);
}
