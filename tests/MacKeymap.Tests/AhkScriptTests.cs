using MacKeymap.Core;

namespace MacKeymap.Tests;

public class AhkScriptTests : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("mackeymap-ahk").FullName;
    public void Dispose() => Directory.Delete(_dir, true);

    private static string BundledAhk()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
        {
            var exe = Path.Combine(d.FullName, "third_party", "AutoHotkey", "AutoHotkey64.exe");
            if (File.Exists(exe)) return exe;
        }
        throw new FileNotFoundException("third_party/AutoHotkey/AutoHotkey64.exe");
    }

    [Theory]
    [InlineData("LAlt+C", "<!c")]
    [InlineData("LAlt+Shift+Left", "+<!Left")]
    [InlineData("LWin+Backspace", "<#Backspace")]
    [InlineData("Shift+CapsLock", "+CapsLock")]
    [InlineData("RAlt+]", ">!]")]
    [InlineData("LCtrl+F5", "<^F5")]
    [InlineData("Hyper+C", null)]
    [InlineData("LAlt+", null)]
    public void TriggersBecomeAhkHotkeys(string trigger, string? expected) => Assert.Equal(expected, AhkScript.Hotkey(trigger));

    [Fact]
    public void ValuesBecomeSendSequences()
    {
        Assert.Equal("{LCtrl down}{c}{LCtrl up}", AhkScript.SendKeys("LCtrl+C"));
        Assert.Equal("{LCtrl down}{LShift down}{Home}{LShift up}{LCtrl up}", AhkScript.SendKeys("LCtrl+Shift+Home"));
        Assert.Equal("{LWin down}{Space}{LWin up}", AhkScript.SendKeys("Win+Space"));
        Assert.Equal("{End}", AhkScript.SendKeys("End"));
    }

    [Fact]
    public void MacProfileMapsCommandAndPerAppModes()
    {
        var p = Profile.MacOs();
        p.AppModes.Add(new() { App = "game.exe", Mode = AppMode.Windows });
        p.AppModes.Add(new() { App = @"D:\Tools\Term.exe", Mode = AppMode.Terminal });
        var r = AhkScript.Generate(p);
        Assert.Contains("\"<!c\"", r.Script);
        Assert.Contains("[\"send\", \"{LCtrl down}{c}{LCtrl up}\"]", r.Script);
        Assert.Contains("[\"send\", \"{LCtrl down}{LShift down}{c}{LShift up}{LCtrl up}\"]", r.Script); // terminal copy
        Assert.Contains("[\"caps\", \"\"]", r.Script);
        Assert.Contains("\"windowsterminal.exe\"", r.Script);
        Assert.Contains("\"d:\\tools\\term.exe\"", r.Script);
        // Windows mode maps to an empty context, so every key passes through in game.exe.
        Assert.Matches("Contexts\\[\"c\\d+\"\\] := Map\\(\\)", r.Script);
        Assert.Contains("\"game.exe\"", r.Script);
        // Command+Tab is LAlt+Tab with default roles: left to Windows instead of being re-sent.
        Assert.DoesNotContain("\"<!Tab\"", r.Script);
        Assert.Empty(r.Skipped);
    }

    [Fact]
    public void WindowsProfileHasNoHotkeys() => Assert.Equal(0, AhkScript.Generate(Profile.Windows()).HotkeyCount);

    [Fact]
    public void UnsupportedRulesAreReportedNotEmitted()
    {
        var p = Profile.Windows();
        p.Overrides.Add(new Rule { Name = "壞的", Trigger = "Hyper+K", Value = "LCtrl+K" });
        p.Overrides.Add(new Rule { Name = "文字", Trigger = "RAlt+M", Action = RuleAction.Text, Value = "a\"b`c;d" });
        var r = AhkScript.Generate(p);
        Assert.Single(r.Skipped);
        Assert.Equal(1, r.HotkeyCount);
        Assert.Contains("[\"text\", \"a`\"b``c;d\"]", r.Script);
    }

    [Fact]
    public void GeneratedScriptsPassAutoHotkeyValidation()
    {
        var runner = new MappingRunner(_dir, BundledAhk());
        var mac = Profile.MacOs();
        mac.AppModes.Add(new() { App = @"C:\Program Files\Foo\foo.exe", Mode = AppMode.Windows });
        mac.Overrides.Add(new Rule { Name = "文字", Trigger = "RAlt+M", Action = RuleAction.Text, Value = "x\"y`z" });
        mac.Overrides.Add(new Rule { Name = "反引號", Trigger = "RAlt+`", Value = "LCtrl+`", Scope = Scope.Only, Apps = "notepad.exe" });
        foreach (var profile in new[] { mac, Profile.Windows() })
        {
            var path = Path.Combine(_dir, "t.ahk");
            File.WriteAllText(path, AhkScript.Generate(profile).Script, new System.Text.UTF8Encoding(true));
            Assert.Null(runner.Validate(path));
        }
        File.WriteAllText(Path.Combine(_dir, "bad.ahk"), "x := (");
        Assert.NotNull(runner.Validate(Path.Combine(_dir, "bad.ahk")));
    }

    [Fact]
    public void PausedConfigStopsAndDoesNotStart()
    {
        var runner = new MappingRunner(_dir, BundledAhk());
        var s = runner.Apply(new Config { Paused = true });
        Assert.False(s.Running);
        Assert.False(runner.IsRunning);
        Assert.False(File.Exists(runner.ScriptPath));
    }
}
