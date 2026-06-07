using Godot;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public partial class GridVisual : Node2D
{
    public const int TileSize = 64;
    public const int GridWidth = CombatOrchestrator.GridWidth;
    public const int GridHeight = CombatOrchestrator.GridHeight;

    private static readonly Color TileColorA = new(0.15f, 0.15f, 0.2f);
    private static readonly Color TileColorB = new(0.12f, 0.12f, 0.17f);
    private static readonly Color PlayerZoneColor = new(0.1f, 0.2f, 0.1f, 0.3f);
    private static readonly Color EnemyZoneColor = new(0.2f, 0.1f, 0.1f, 0.3f);
    private static readonly Color GridLineColor = new(0.3f, 0.3f, 0.35f, 0.5f);
    private static readonly Color HighlightColor = new(1f, 1f, 0.3f, 0.25f);

    private PF2eVec? _highlightedTile;
    private bool _showZones = true;

    public int PlayerZoneMaxRow { get; set; } = 3;

    public static Vector2 GridToWorld(PF2eVec gridPos)
    {
        return new Vector2(gridPos.x * TileSize, gridPos.y * TileSize);
    }

    public static Vector2 GridToWorldCenter(PF2eVec gridPos)
    {
        return new Vector2(gridPos.x * TileSize + TileSize / 2f, gridPos.y * TileSize + TileSize / 2f);
    }

    public static PF2eVec WorldToGrid(Vector2 worldPos)
    {
        int x = Mathf.Clamp((int)(worldPos.X / TileSize), 0, GridWidth - 1);
        int y = Mathf.Clamp((int)(worldPos.Y / TileSize), 0, GridHeight - 1);
        return new PF2eVec(x, y);
    }

    public Vector2 GetBoardPixelSize()
    {
        return new Vector2(GridWidth * TileSize, GridHeight * TileSize);
    }

    public void SetHighlightedTile(PF2eVec? tile)
    {
        _highlightedTile = tile;
        QueueRedraw();
    }

    public void SetShowZones(bool show)
    {
        _showZones = show;
        QueueRedraw();
    }

    public override void _Draw()
    {
        for (int x = 0; x < GridWidth; x++)
        {
            for (int y = 0; y < GridHeight; y++)
            {
                var rect = new Rect2(x * TileSize, y * TileSize, TileSize, TileSize);
                bool isLight = (x + y) % 2 == 0;
                DrawRect(rect, isLight ? TileColorA : TileColorB);
            }
        }

        if (_showZones)
        {
            var playerZone = new Rect2(0, 0, GridWidth * TileSize, (PlayerZoneMaxRow + 1) * TileSize);
            DrawRect(playerZone, PlayerZoneColor);

            var enemyZone = new Rect2(0, (GridHeight - PlayerZoneMaxRow - 1) * TileSize,
                GridWidth * TileSize, (PlayerZoneMaxRow + 1) * TileSize);
            DrawRect(enemyZone, EnemyZoneColor);
        }

        for (int x = 0; x <= GridWidth; x++)
        {
            var from = new Vector2(x * TileSize, 0);
            var to = new Vector2(x * TileSize, GridHeight * TileSize);
            DrawLine(from, to, GridLineColor, 1f);
        }
        for (int y = 0; y <= GridHeight; y++)
        {
            var from = new Vector2(0, y * TileSize);
            var to = new Vector2(GridWidth * TileSize, y * TileSize);
            DrawLine(from, to, GridLineColor, 1f);
        }

        if (_highlightedTile.HasValue)
        {
            var ht = _highlightedTile.Value;
            var highlightRect = new Rect2(ht.x * TileSize, ht.y * TileSize, TileSize, TileSize);
            DrawRect(highlightRect, HighlightColor);
        }
    }

    public bool IsInPlayerZone(PF2eVec pos)
    {
        return pos.y >= 0 && pos.y <= PlayerZoneMaxRow && pos.x >= 0 && pos.x < GridWidth;
    }

    public bool IsInEnemyZone(PF2eVec pos)
    {
        return pos.y >= GridHeight - PlayerZoneMaxRow - 1 && pos.y < GridHeight && pos.x >= 0 && pos.x < GridWidth;
    }
}
