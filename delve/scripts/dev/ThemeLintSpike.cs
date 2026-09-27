using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Delve.Autoload;
using Godot;

namespace Delve.Dev;

/// <summary>Fails when a theme-discipline count rises above its ceiling. Lower ceilings as counts drop.</summary>
public partial class ThemeLintSpike : SpikeBase
{
    [Export] public string[] SceneDirectories { get; set; } = [];
    [Export] public string[] SceneFiles { get; set; } = [];
    [Export] public string[] ThemeFiles { get; set; } = [];
    [Export] public string[] ScriptFiles { get; set; } = [];
    [Export] public string[] ScriptDirectories { get; set; } = [];
    [Export] public int FontSizeFloor { get; set; } = 14;

    [Export] public int MaxColorOverrides { get; set; }
    [Export] public int MaxFontSizeOverrides { get; set; }
    [Export] public int MaxFontOverrides { get; set; }
    [Export] public int MaxStyleOverrides { get; set; }
    [Export] public int MaxSceneThemes { get; set; }
    [Export] public int MaxScriptOverrides { get; set; }
    [Export] public int MaxScriptColorLiterals { get; set; }
    [Export] public int MaxSizesBelowFloor { get; set; }
    [Export] public int MaxMojibake { get; set; }
    [Export] public int MaxSceneColorLiterals { get; set; }

    private static readonly Regex FontSize = new(@"font_size(?:s/[a-z_]+)? = (\d+)");
    private static readonly Regex ScriptOverride = new(@"AddTheme(?:Color|FontSize|Font|Stylebox)Override");
    private static readonly Regex ColorLiteral = new(@"new Color\(|Color\.FromHtml|(?<!Ui)Colors\.");
    private static readonly Regex SceneColor = new(@"(?m)^color = Color\(");
    private static readonly string[] MojibakeMarks =
        [new string([(char)0xE2, (char)0x20AC]), new string([(char)0xC2, (char)0xB7]), ((char)0xC3).ToString()];

    protected override Task RunSpikeAsync(DataManager data)
    {
        List<string> scenes = SceneDirectories.SelectMany(d => Files(d, "*.tscn"))
            .Concat(SceneFiles.Select(ProjectSettings.GlobalizePath)).ToList();
        List<string> themes = ThemeFiles.Select(ProjectSettings.GlobalizePath).ToList();
        List<string> scripts = ScriptFiles.Select(ProjectSettings.GlobalizePath)
            .Concat(ScriptDirectories.SelectMany(d => Files(d, "*.cs"))).ToList();

        string[] sceneText = scenes.Select(File.ReadAllText).ToArray();
        string[] themeText = themes.Select(File.ReadAllText).ToArray();
        string[] scriptText = scripts.Select(File.ReadAllText).ToArray();

        Report("colour overrides in scenes", Count(sceneText, "theme_override_colors/"), MaxColorOverrides);
        Report("font size overrides in scenes", Count(sceneText, "theme_override_font_sizes/"), MaxFontSizeOverrides);
        Report("font overrides in scenes", Count(sceneText, "theme_override_fonts/"), MaxFontOverrides);
        Report("style overrides in scenes", Count(sceneText, "theme_override_styles/"), MaxStyleOverrides);
        Report("theme assignments in scenes", sceneText.Sum(t => Regex.Matches(t, @"(?m)^theme = ").Count), MaxSceneThemes);
        Report("theme overrides set from scripts", scriptText.Sum(t => ScriptOverride.Matches(t).Count), MaxScriptOverrides);
        Report("colour literals in UI scripts", scriptText.Sum(t => ColorLiteral.Matches(t).Count), MaxScriptColorLiterals);
        Report("ColorRect colour literals in scenes", sceneText.Sum(t => SceneColor.Matches(t).Count), MaxSceneColorLiterals);

        int belowFloor = sceneText.Concat(themeText)
            .SelectMany(t => FontSize.Matches(t).Select(m => int.Parse(m.Groups[1].Value)))
            .Count(size => size < FontSizeFloor);
        Report($"font sizes below {FontSizeFloor} px", belowFloor, MaxSizesBelowFloor);

        int mojibake = sceneText.Concat(scriptText).Sum(t => MojibakeMarks.Sum(mark => Occurrences(t, mark)));
        Report("mojibake sequences in scenes and UI scripts", mojibake, MaxMojibake);
        return Task.CompletedTask;
    }

    private void Report(string label, int count, int ceiling) =>
        Check($"{label}: {count} (ceiling {ceiling})", count <= ceiling);

    private static IEnumerable<string> Files(string directory, string pattern) =>
        Directory.EnumerateFiles(ProjectSettings.GlobalizePath(directory), pattern, SearchOption.AllDirectories);

    private static int Count(IEnumerable<string> texts, string token) => texts.Sum(t => Occurrences(t, token));

    private static int Occurrences(string text, string token)
    {
        int count = 0;
        for (int i = text.IndexOf(token, System.StringComparison.Ordinal); i >= 0;
             i = text.IndexOf(token, i + token.Length, System.StringComparison.Ordinal))
            count++;
        return count;
    }
}
