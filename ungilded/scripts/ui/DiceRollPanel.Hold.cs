namespace Ungilded.UI;

/// <summary>Holding the banner up while a tutorial tip points at it.</summary>
public partial class DiceRollPanel
{
    private enum HoldKind { None, Paused, Reshown }

    private HoldKind _hold;
    private Pending? _last;

    /// <summary>True keeps the banner on screen: the showing roll stops before its fade, or the last
    /// roll comes back as its settled row. False lets the roll fade, or hides the row again.</summary>
    public void Hold(bool hold)
    {
        if (hold == (_hold != HoldKind.None)) return;
        if (!hold)
        {
            var kind = _hold;
            _hold = HoldKind.None;
            if (kind == HoldKind.Paused) _tween?.Play();
            else if (kind == HoldKind.Reshown && _current == null)
            {
                Visible = false;
                StartNextRoll();
            }
            return;
        }
        if (_current != null)
        {
            _hold = HoldKind.Paused;
            _tween?.Pause();
        }
        else if (_last != null)
        {
            _hold = HoldKind.Reshown;
            FillRow(_last.Roll, _last.Damage);
            ShowSettledRow();
            Visible = true;
        }
        else return;
        Modulate = Modulate with { A = 1 };
    }

    public bool Held => _hold != HoldKind.None;
}
