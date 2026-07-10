namespace Bulwark.Data;

/// <summary>
/// The four calendar seasons. Ordering is the rollover order the day clock advances through
/// (Spring → Summer → Fall → Winter → Spring, incrementing the year on the wrap).
/// </summary>
public enum Season
{
    Spring,
    Summer,
    Fall,
    Winter,
}
