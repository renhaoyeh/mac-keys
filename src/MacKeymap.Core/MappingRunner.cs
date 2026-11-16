using System.Diagnostics;

namespace MacKeymap.Core;

/// <summary>
/// Runs the generated script with the bundled AutoHotkey. The AHK process stays resident after the
/// settings window closes; it is replaced on every save and stopped when the user pauses mapping.
/// </summary>
public sealed class MappingRunner(string dataDir, string ahkExe)
{
    public sealed record Status(bool Running, string Message, IReadOnlyList<string> Skipped);

    public static MappingRunner Default => new(
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MacKeymap"),
        Path.Combine(AppContext.BaseDirectory, "ahk", "AutoHotkey64.exe"));

    public string ScriptPath => Path.Combine(dataDir, "mapping.ahk");
    private string PidPath => Path.Combine(dataDir, "mapping.pid");
    public string AhkExe => ahkExe;

    public bool IsRunning => Current() is { } p && Dispose(p);

    /// <summary>Generates the script for the active profile and (re)starts AHK, or stops it when paused.</summary>
    public Status Apply(Config config)
    {
        if (config.Paused)
        {
            Stop();
            return new(false, "鍵盤配置已暫停", []);
        }
        if (!File.Exists(ahkExe)) return new(IsRunning, $"找不到 AutoHotkey：{ahkExe}", []);

        var result = AhkScript.Generate(config.ActiveProfile);
        Directory.CreateDirectory(dataDir);
        var temp = ScriptPath + ".tmp";
        File.WriteAllText(temp, result.Script, new System.Text.UTF8Encoding(true)); // BOM: AHK reads it as UTF-8
        if (Validate(temp) is string error)
        {
            File.Delete(temp);
            return new(IsRunning, $"產生的腳本無效，保留原本的配置：{error}", result.Skipped);
        }
        File.Move(temp, ScriptPath, overwrite: true);

        Stop();
        if (result.HotkeyCount == 0) return new(false, "目前配置沒有需要映射的按鍵", result.Skipped);
        var process = Process.Start(new ProcessStartInfo(ahkExe, $"\"{ScriptPath}\"") { UseShellExecute = false, WorkingDirectory = dataDir })
                      ?? throw new InvalidOperationException("無法啟動 AutoHotkey");
        File.WriteAllText(PidPath, process.Id.ToString());
        process.Dispose();
        return new(true, $"鍵盤配置執行中：{result.HotkeyCount} 個按鍵", result.Skipped);
    }

    public void Stop()
    {
        if (Current() is { } p)
        {
            try { p.Kill(); p.WaitForExit(3000); } catch { }
            p.Dispose();
        }
        try { File.Delete(PidPath); } catch { }
    }

    /// <summary>Loads the script without running it. Returns the error text, or null when valid.</summary>
    public string? Validate(string script)
    {
        using var p = Process.Start(new ProcessStartInfo(ahkExe, $"/ErrorStdOut=UTF-8 /validate \"{script}\"")
        {
            UseShellExecute = false, RedirectStandardError = true, RedirectStandardOutput = true, CreateNoWindow = true,
        })!;
        var err = p.StandardError.ReadToEnd() + p.StandardOutput.ReadToEnd();
        if (!p.WaitForExit(10000)) { p.Kill(); return "驗證逾時"; }
        return p.ExitCode == 0 ? null : (err.Trim().Length > 0 ? err.Trim() : $"exit code {p.ExitCode}");
    }

    /// <summary>The AHK process we started, verified by PID and executable path so we never kill anything else.</summary>
    private Process? Current()
    {
        try
        {
            if (!int.TryParse(File.ReadAllText(PidPath), out var pid)) return null;
            var p = Process.GetProcessById(pid);
            if (!p.HasExited && string.Equals(p.MainModule?.FileName, Path.GetFullPath(ahkExe), StringComparison.OrdinalIgnoreCase)) return p;
            p.Dispose();
        }
        catch { }
        return null;
    }

    private static bool Dispose(Process p) { p.Dispose(); return true; }
}
