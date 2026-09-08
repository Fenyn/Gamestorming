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
        if (ward.IsSpent)
            return "The ward is out.";
        if (ward.ShortRestWouldSpend)
            return $"Only {ward.Ward} ward is left. A rest costs {ward.Rules.ShortRestBurn} and would "
                   + "put the ward out, so there is no resting from here.";

        string line = $"Ward after rest: {ward.WardAfterShortRest} / {ward.Rules.MaxWard}.";
        return ward.UpshiftAfterShortRest > ward.Upshift
            ? line + $" Encounter threat rises to +{ward.UpshiftAfterShortRest}."
            : line;
    }

    /// <summary>Why a rest is unavailable, shown on the disabled buttons.</summary>
    public static string RestUnavailable(Wardstone ward) =>
        ward.IsSpent
            ? "Unavailable: the ward is out."
            : $"Unavailable: only {ward.Ward} ward is left, and a rest costs "
              + $"{ward.Rules.ShortRestBurn}.";
}
