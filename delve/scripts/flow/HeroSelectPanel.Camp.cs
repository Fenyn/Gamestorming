using Godot;

namespace Delve.Flow;

public partial class HeroSelectPanel
{
    public void OpenDetails()
    {
        if (_recruitment.Visible) return;
        _details.Show();
        GetNode<Button>("%CloseDetails").GrabFocus();
    }

    public void CloseDetails()
    {
        _details.Hide();
        _sheet.HideTips();
        GetNode<Button>("%DetailsButton").GrabFocus();
    }

    public override void _Process(double delta)
    {
        if (!IsVisibleInTree()) return;
        foreach (var resident in _cards)
            resident.Position = _camp.SeatPosition(_seats[resident.Id]) - new Vector2(82, 160);
    }
}
