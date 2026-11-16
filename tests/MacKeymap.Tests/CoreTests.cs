using System.Text.Json.Nodes;
using MacKeymap.Core;

namespace MacKeymap.Tests;

public class ModelTests
{
    [Fact]
    public void FreshProfilesStoreNoGeneratedRules()
    {
        var c = new Config();
        Assert.All(c.Profiles, p => Assert.Empty(p.Overrides));
        var json = JsonNode.Parse(Storage.Serialize(c))!;
        Assert.Empty(json["profiles"]![0]!["overrides"]!.AsArray());
        Assert.Null(json["profiles"]![0]!["rules"]);
        foreach (var key in new[] { "B", "C", "V", "F", "S", "9", "F5" })
            Assert.Equal($"LCtrl+{key}", Builtin.Command($"Command+{key}")!.Value);
        Assert.Equal("LAlt+Tab", Builtin.Command("Command+Tab")!.Value);
        Assert.Equal("Home", Builtin.Command("Command+Left")!.Value);
    }

    [Fact]
    public void OverridesReplaceOnlyTargetedBehaviorAndRestoreWithoutResidue()
    {
        var p = Profile.MacOs();
        var b = p.BuiltinRule("Command+C")!;
        Assert.False(p.SetOverride(null, b.Copy()));
        Assert.Empty(p.Overrides);
        var custom = b with { Value = "LCtrl+Insert", Scope = Scope.Only, Apps = "notepad.exe" };
        Assert.True(p.SetOverride(null, custom));
        var notepad = p.PreviewRules("notepad.exe");
        Assert.Single(notepad, r => r.Trigger == "LAlt+C");
        Assert.Equal("LCtrl+Insert", notepad.First(r => r.Trigger == "LAlt+C").Value);
        Assert.Equal("LCtrl+C", p.PreviewRules("browser.exe").First(r => r.Trigger == "LAlt+C").Value);
        Assert.Equal("LCtrl+Shift+C", p.PreviewRules("WindowsTerminal.exe").First(r => r.Trigger == "LAlt+C").Value);
        p.SetOverride(0, custom with { Enabled = false });
        Assert.DoesNotContain(p.PreviewRules("notepad.exe"), r => r.Trigger == "LAlt+C");
        Assert.Contains(p.PreviewRules("notepad.exe"), r => r.Trigger == "LAlt+V");
        p.Features.Option = false;
        p.SetOverride(0, b);
        Assert.Empty(p.Overrides);
        Assert.False(p.Features.Option);
        Assert.Equal("LCtrl+C", p.PreviewRules("notepad.exe").First(r => r.Trigger == "LAlt+C").Value);
    }

    [Fact]
    public void VersionTwoMigrationKeepsOnlyActualEditsAndDeletedDefaults()
    {
        Config Make(Action<List<Rule>> edit)
        {
            var c = new Config { Version = 2 };
            var legacy = Builtin.LegacyCatalog().Select(r => r with { BuiltinId = null }).ToList();
            edit(legacy);
            c.Profiles[0].Overrides = legacy;
            return c;
        }
        Assert.Empty(Make(_ => { }).Migrate().Profiles[0].Overrides);
        var migrated = Make(l =>
        {
            var i = l.FindIndex(r => r.Name == "複製"); l[i] = l[i] with { Value = "LCtrl+Insert" };
            var j = l.FindIndex(r => r.Name == "貼上"); l[j] = l[j] with { Enabled = false };
            l.RemoveAll(r => r.Name == "剪下");
            l.Add(new Rule { Name = "自訂動作", Trigger = "RAlt+K", Value = "LCtrl+P" });
        }).Migrate();
        var p = migrated.Profiles[0];
        Assert.Equal(4, p.Overrides.Count);
        var actual = p.PreviewRules("notepad.exe");
        Assert.Equal("LCtrl+Insert", actual.First(r => r.Trigger == "LAlt+C").Value);
        Assert.DoesNotContain(actual, r => r.Trigger is "LAlt+V" or "LAlt+X");
        Assert.Contains(actual, r => r.Trigger == "RAlt+K");
    }

    [Fact]
    public void GroupSwitchesPreserveIndividualRules()
    {
        var p = Profile.MacOs();
        p.Overrides.Add(p.BuiltinRule("Command+X")! with { Enabled = false });
        var original = string.Join(",", p.Overrides);
        var count = p.PreviewRules("notepad.exe").Count;
        p.Features.Command = false;
        var without = p.PreviewRules("notepad.exe");
        Assert.All(without, r => Assert.NotEqual(FeatureGroup.Command, r.Group));
        Assert.Contains(without, r => r.Group == FeatureGroup.Option);
        Assert.Contains(without, r => r.Action == RuleAction.Language);
        Assert.Equal(original, string.Join(",", p.Overrides));
        p.Features.Command = true;
        Assert.Equal(count, p.PreviewRules("notepad.exe").Count);
        Assert.DoesNotContain(p.PreviewRules("notepad.exe"), r => r.Name == "剪下");
        p.Features.Option = false;
        p.Features.Language = false;
        Assert.All(p.PreviewRules("notepad.exe"), r => Assert.Equal(FeatureGroup.Command, r.Group));
    }

    [Fact]
    public void CommandRoleMovesWholeFamily()
    {
        var p = Profile.MacOs();
        p.Roles[2] = Profile.Keep;
        p.Roles[4] = "Command";
        var rules = p.PreviewRules("notepad.exe");
        var copy = rules.First(r => r.Name == "複製");
        Assert.Equal("LWin+C", copy.Trigger);
        Assert.Equal("LCtrl+C", copy.Value);
        var sw = rules.First(r => r.Name == "切換視窗");
        Assert.Equal("LWin+Tab", sw.Trigger);
        Assert.Equal("LAlt+Tab", sw.Value);
        Assert.DoesNotContain(rules, r => r.Group == FeatureGroup.Option);
        Assert.DoesNotContain(rules, r => r.Trigger == "LCtrl+C");
    }

    [Fact]
    public void ApplicationModesAreProfileWideAndPathTakesPrecedence()
    {
        var p = Profile.MacOs();
        var terminal = p.PreviewRules(@"C:\Windows\WindowsTerminal.EXE");
        Assert.Equal("LCtrl+Shift+C", terminal.First(r => r.Name == "複製").Value);
        p.AppModes.Add(new() { App = @"D:\other\WindowsTerminal.exe", Mode = AppMode.Windows });
        Assert.Empty(p.PreviewRules("d:/other/windowsterminal.exe"));
        Assert.Equal(AppMode.Terminal, p.AppModeFor(@"C:\Windows\WindowsTerminal.exe"));
        Assert.Equal(AppMode.Inherit, p.AppModeFor("notwindowsterminal.exe"));
        p.Exclusions = "WindowsTerminal.exe";
        Assert.Empty(p.PreviewRules(@"C:\Windows\WindowsTerminal.exe"));
        Assert.Empty(Profile.Windows().PreviewRules("notepad.exe"));
        Assert.NotEmpty(Profile.MacOs().PreviewRules("notepad.exe"));
    }

    [Fact]
    public void TerminalModeRespectsGroupDisabling()
    {
        var p = Profile.MacOs();
        p.Features.Command = false;
        Assert.DoesNotContain(p.PreviewRules("WindowsTerminal.exe"), r => r.Name is "複製" or "貼上");
    }
}

public class StorageTests : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("mackeymap").FullName;
    public void Dispose() => Directory.Delete(_dir, true);

    [Fact]
    public void RoundtripAndReplace()
    {
        var path = Path.Combine(_dir, "config.json");
        var c = new Config();
        Storage.Save(path, c);
        c.Profiles[0].Name = "changed";
        c.Profiles[0].Features.Command = false;
        c.Profiles[0].AppModes[0].Mode = AppMode.Windows;
        c.Active = 1;
        Storage.Save(path, c);
        var saved = Storage.Load(path);
        Assert.Equal("changed", saved.Profiles[0].Name);
        Assert.Equal(1, saved.Active);
        Assert.False(saved.Profiles[0].Features.Command);
        Assert.Empty(saved.Profiles[0].PreviewRules("WindowsTerminal.exe"));
        Assert.Single(Directory.GetFiles(_dir));
    }

    [Fact]
    public void RejectFutureVersion() => Assert.Throws<InvalidDataException>(() => new Config { Version = 99 }.Validate());

    [Fact]
    public void LegacyImportPreservesRulesWithoutWriting()
    {
        var path = Path.Combine(_dir, "legacy.json");
        const string text = """{"version":1,"active":0,"paused":false,"profiles":[{"name":"我的舊設定","roles":["保留","保留","Command","保留","Option","保留"],"exclusions":"game.exe","rules":[{"name":"自訂複製","enabled":false,"trigger":"LAlt+C","action":"Shortcut","value":"LCtrl+Insert","scope":"Global","apps":"","priority":7}]}]}""";
        File.WriteAllText(path, text);
        var c = Storage.Load(path);
        Assert.Equal(3, c.Version);
        Assert.False(c.Paused);
        Assert.Equal("我的舊設定", c.Profiles[0].Name);
        Assert.Equal("LAlt+C", c.Profiles[0].Overrides[0].Trigger);
        Assert.False(c.Profiles[0].Overrides[0].Enabled);
        Assert.Equal("game.exe", c.Profiles[0].Exclusions);
        Assert.Equal(3, c.Profiles.Count);
        Assert.Equal(text, File.ReadAllText(path));
        c.Version = 1; c.Active = 99;
        Assert.Throws<InvalidDataException>(() => c.Migrate());
    }

    [Fact]
    public void ReadsRustPrototypeFile()
    {
        var path = Path.Combine(_dir, "rust.json");
        File.WriteAllText(path, """{"version":3,"active":0,"paused":true,"profiles":[{"name":"m","overrides":[{"builtin_id":"Command+C","group":"Command","name":"複製","enabled":true,"trigger":"Command+C","action":"Shortcut","value":"LCtrl+Insert","scope":"Global","apps":"","priority":0}],"exclusions":"","roles":["保留","保留","Command","保留","Option","保留"],"kind":"MacOs","features":{"command":true,"option":false,"language":true},"app_modes":[{"app":"a.exe","mode":"Terminal"}]}]}""");
        var p = Storage.Load(path).Profiles[0];
        Assert.Equal(FeatureGroup.Command, p.Overrides[0].Group);
        Assert.Equal(AppMode.Terminal, p.AppModes[0].Mode);
        Assert.False(p.Features.Option);
        Assert.Contains("\"builtin_id\": \"Command+C\"", Storage.Serialize(Storage.Load(path)));
    }

    [Fact]
    public void DuplicateApplicationPreferenceDoesNotOverwrite()
    {
        var path = Path.Combine(_dir, "config.json");
        var c = new Config();
        Storage.Save(path, c);
        var before = File.ReadAllBytes(path);
        c.Profiles[0].AppModes.Add(new() { App = "WINDOWSTERMINAL.EXE", Mode = AppMode.Windows });
        Assert.Throws<InvalidDataException>(() => Storage.Save(path, c));
        Assert.Equal(before, File.ReadAllBytes(path));
    }
}
