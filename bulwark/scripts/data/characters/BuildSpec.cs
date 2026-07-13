namespace Bulwark.Data.Characters;

// TODO: FA build layer. When populated, the Characters registry
// auto-registers a PartyPresetSpec for recruitable characters.
public sealed class BuildSpec
{
    public string? FreeArchetypeLine { get; init; }
    public string? VariantComboId { get; init; }
    public string? EquipmentNotes { get; init; }
}
