using System;
using Godot;

namespace Ungilded.Settings;

/// <summary>How quickly combat presents its beats. The paces themselves are exports on the combat scene.</summary>
public enum CombatSpeed { Slow, Normal, Fast }

/// <summary>Options the player sets in the pause menu, persisted to a small config file.</summary>
public static class UserSettings
{
    private const string Section = "options";
    private static bool _fullscreen;
    private static bool _diceReveal = true;
    private static CombatSpeed _combatSpeed = CombatSpeed.Normal;

    /// <summary>Raised after any option changes.</summary>
    public static event Action? Changed;

    public static string Path { get; private set; } = "";

    public static bool Fullscreen
    {
        get => _fullscreen;
        set { if (_fullscreen == value) return; _fullscreen = value; Changed?.Invoke(); }
    }

    /// <summary>The dice panel's short d20 reveal. Off skips the animation and never gates combat.</summary>
    public static bool DiceReveal
    {
        get => _diceReveal;
        set { if (_diceReveal == value) return; _diceReveal = value; Changed?.Invoke(); }
    }

    /// <summary>The pace of combat's beats, dice and damage numbers. Walking keeps its speed.</summary>
    public static CombatSpeed CombatSpeed
    {
        get => _combatSpeed;
        set { if (_combatSpeed == value) return; _combatSpeed = value; Changed?.Invoke(); }
    }

    public static void Load(string path)
    {
        Path = path;
        var file = new ConfigFile();
        if (file.Load(path) != Error.Ok) return;
        _fullscreen = file.GetValue(Section, nameof(Fullscreen), false).AsBool();
        _diceReveal = file.GetValue(Section, nameof(DiceReveal), true).AsBool();
        _combatSpeed = Enum.TryParse(file.GetValue(Section, nameof(CombatSpeed), nameof(CombatSpeed.Normal)).AsString(), out CombatSpeed speed)
            ? speed : CombatSpeed.Normal;
        Changed?.Invoke();
    }

    /// <summary>Points saves at another file without loading it. Spikes use it to keep the player's file untouched.</summary>
    public static void Redirect(string path) => Path = path;

    public static Error Save()
    {
        if (Path.Length == 0) return Error.Unconfigured;
        var file = new ConfigFile();
        file.SetValue(Section, nameof(Fullscreen), _fullscreen);
        file.SetValue(Section, nameof(DiceReveal), _diceReveal);
        file.SetValue(Section, nameof(CombatSpeed), _combatSpeed.ToString());
        return file.Save(Path);
    }
}
