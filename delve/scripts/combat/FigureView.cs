namespace Delve.Combat;

/// <summary>
/// One number display: a caption over a large value ("Hit 65%"), or a before→after pair when
/// <see cref="Before"/> is set ("Shield 20 → 16"). Values arrive already masked.
/// </summary>
public sealed record FigureView(string Caption, string Value)
{
    public string Before { get; init; } = "";
    public bool IsChange => Before.Length > 0;
}
