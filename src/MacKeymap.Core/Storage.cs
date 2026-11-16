using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MacKeymap.Core;

/// <summary>Versioned JSON settings, compatible with the earlier Rust prototype's file format.</summary>
public static class Storage
{
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        Converters = { new JsonStringEnumConverter() },
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        RespectNullableAnnotations = false,
    };

    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MacKeymap", "config", "config.json");

    public static Config Load(string path)
    {
        var config = JsonSerializer.Deserialize<Config>(File.ReadAllBytes(path), Json)
                     ?? throw new InvalidDataException("設定檔是空的");
        return config.Migrate();
    }

    public static string Serialize(Config config) => JsonSerializer.Serialize(config, Json);

    /// <summary>Writes to a temp file in the same folder, flushes it, then atomically replaces the target.</summary>
    public static void Save(string path, Config config)
    {
        config.Validate();
        var dir = Path.GetDirectoryName(Path.GetFullPath(path)) ?? throw new IOException("缺少父目錄");
        Directory.CreateDirectory(dir);
        var temp = Path.Combine(dir, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            using (var fs = new FileStream(temp, FileMode.CreateNew, FileAccess.Write))
            {
                JsonSerializer.Serialize(fs, config, Json);
                fs.Flush(flushToDisk: true);
            }
            File.Move(temp, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temp)) File.Delete(temp);
        }
    }
}
