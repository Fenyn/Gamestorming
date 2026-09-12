using System.IO;
using System.Text.Json;

namespace Delve.Run;

/// <summary>Plain filesystem persistence. The composition root owns path resolution and error reporting.</summary>
public static class CampaignProgressStore
{
    public static CampaignProgress Load(string path)
    {
        if (!File.Exists(path)) return new CampaignProgress();
        var data = JsonSerializer.Deserialize<CampaignProgressData>(File.ReadAllText(path))
            ?? throw new InvalidDataException("The campaign save contains no progress data.");
        return CampaignProgress.Restore(data);
    }

    public static void Save(string path, CampaignProgress progress)
    {
        string? directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
        string temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(progress.Capture()));
        File.Move(temporary, path, overwrite: true);
    }
}
