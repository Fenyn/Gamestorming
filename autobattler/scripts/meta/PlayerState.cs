using System.Collections.Generic;
using Godot;
using PF2e.Data;
using PF2eVec = PF2e.Vector2Int;

namespace Autobattler;

public class OwnedUnit
{
    public EnemyDefinition Definition { get; set; }
    public string InstanceId { get; set; }
    public int Tier { get; set; }
    public int Cost { get; set; }
    public bool IsElite { get; set; }

    public OwnedUnit(EnemyDefinition def)
    {
        Definition = def;
        InstanceId = System.Guid.NewGuid().ToString("N")[..8];
        Tier = DataManager.GetTier(def.StatBlock.CreatureLevel);
        Cost = DataManager.GetCost(Tier);
    }
}

public class BoardPlacement
{
    public OwnedUnit Unit { get; set; }
    public PF2eVec Position { get; set; }
}

public class PlayerState
{
    public int Gold { get; set; } = 5;
    public int HP { get; set; } = 100;
    public int MaxHP { get; set; } = 100;
    public int Level { get; set; } = 1;
    public int XP { get; set; }
    public int RoundNumber { get; set; } = 1;
    public int WinStreak { get; set; }
    public int LossStreak { get; set; }

    public List<OwnedUnit> Bench { get; set; } = new();
    public List<BoardPlacement> Board { get; set; } = new();

    public int MaxBoardUnits => Level + 2;
    public int MaxBenchSlots => 8;

    private static readonly int[] LevelThresholds = { 0, 4, 10, 18, 28, 40, 54, 70 };

    public int CalculateIncome()
    {
        int baseIncome = 5;
        int interest = Mathf.Min(Gold / 10, 5);

        int streakBonus = 0;
        if (WinStreak >= 5) streakBonus = 3;
        else if (WinStreak >= 3) streakBonus = 2;
        else if (WinStreak >= 2) streakBonus = 1;

        if (LossStreak >= 5) streakBonus = 3;
        else if (LossStreak >= 3) streakBonus = Mathf.Max(streakBonus, 2);
        else if (LossStreak >= 2) streakBonus = Mathf.Max(streakBonus, 1);

        return baseIncome + interest + streakBonus;
    }

    public int CalculateDamageOnLoss(int survivingEnemies)
    {
        return 2 + survivingEnemies;
    }

    public void ApplyRoundResult(bool won, int survivingEnemies)
    {
        XP += 2;
        if (won)
        {
            XP += 1;
            WinStreak++;
            LossStreak = 0;
        }
        else
        {
            int damage = CalculateDamageOnLoss(survivingEnemies);
            HP -= damage;
            LossStreak++;
            WinStreak = 0;
        }

        Gold += CalculateIncome();

        CheckLevelUp();
        RoundNumber++;
    }

    private void CheckLevelUp()
    {
        for (int i = LevelThresholds.Length - 1; i >= 0; i--)
        {
            if (XP >= LevelThresholds[i] && Level < i + 1)
            {
                Level = i + 1;
                GD.Print($"[PlayerState] Leveled up to {Level}! Max board units: {MaxBoardUnits}");
                break;
            }
        }
    }

    public bool CanBuy(int cost) => Gold >= cost;

    public bool CanAddToBench() => Bench.Count < MaxBenchSlots;

    public bool CanAddToBoard() => Board.Count < MaxBoardUnits;

    public bool IsGameOver => HP <= 0;

    public void BuyUnit(OwnedUnit unit)
    {
        Gold -= unit.Cost;
        Bench.Add(unit);
    }

    public void SellUnit(OwnedUnit unit)
    {
        int sellPrice = DataManager.GetSellPrice(unit.Tier);
        Gold += sellPrice;
        Bench.Remove(unit);

        var placement = Board.Find(p => p.Unit == unit);
        if (placement != null)
            Board.Remove(placement);
    }

    public void PlaceOnBoard(OwnedUnit unit, PF2eVec position)
    {
        Bench.Remove(unit);

        var existing = Board.Find(p => p.Unit == unit);
        if (existing != null)
        {
            existing.Position = position;
        }
        else if (Board.Count < MaxBoardUnits)
        {
            Board.Add(new BoardPlacement { Unit = unit, Position = position });
        }
    }

    public void ReturnToBench(OwnedUnit unit)
    {
        var placement = Board.Find(p => p.Unit == unit);
        if (placement != null)
        {
            Board.Remove(placement);
            if (Bench.Count < MaxBenchSlots)
                Bench.Add(unit);
        }
    }
}
