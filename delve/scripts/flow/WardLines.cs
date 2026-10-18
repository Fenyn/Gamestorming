using Delve.Run;

namespace Delve.Flow;

/// <summary>
/// One place that turns Wardstone state into the strings the run screens show. The map sidebar and
/// the short-rest panel price the same block, so the wording lives here instead of twice over.
/// </summary>
public static class WardLines
{
    /// <summary>What the next ten-minute block does to the ward.</summary>
    public static string RestPreview(Wardstone ward)
    {
        if (ward.IsSpent || ward.ShortRestWouldSpend)
            return RestUnavailable(ward);

        string line = $"Ward after rest: {ward.WardAfterShortRest} / {ward.Rules.MaxWard}";
        return ward.UpshiftAfterShortRest > ward.Upshift
            ? line + $"\nDanger after rest: +{ward.UpshiftAfterShortRest}"
            : line;
    }

    /// <summary>Why a rest is unavailable, shown on the disabled buttons.</summary>
    public static string RestUnavailable(Wardstone ward) =>
        ward.IsSpent
            ? "Unavailable: the ward is out."
            : $"Unavailable: only {ward.Ward} ward is left, and a rest costs "
              + $"{ward.Rules.ShortRestBurn}.";
}
