using Godot;

namespace Delve.UI;

/// <summary>An item icon and its readable name share one hover target.</summary>
public partial class ItemIconEntry : HBoxContainer
{
    public void Fill(string label, Texture2D? texture)
    {
        GetNode<Label>("%ItemName").Text = label;
        GetNode<TextureRect>("%ItemIcon").Texture = texture;
    }
}
