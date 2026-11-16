using System.Text.Json.Serialization;

namespace MacKeymap.Core;

public enum RuleAction { Shortcut, Language, Text, Launch }
public enum Scope { Global, Only, Except }
public enum FeatureGroup { Command, Option, Language }
public enum ProfileKind { MacOs, Windows, Custom }
public enum AppMode { Inherit, Windows, Terminal }

public sealed record Rule
{
    public string? BuiltinId { get; set; }
    public FeatureGroup? Group { get; set; }
    public string Name { get; set; } = "新規則";
    public bool Enabled { get; set; } = true;
    public string Trigger { get; set; } = "LAlt+C";
    public RuleAction Action { get; set; } = RuleAction.Shortcut;
    public string Value { get; set; } = "LCtrl+C";
    public Scope Scope { get; set; } = Scope.Global;
    public string Apps { get; set; } = "";
    public int Priority { get; set; }

    public Rule Copy() => this with { };
}

public sealed class Features
{
    public bool Command { get; set; } = true;
    public bool Option { get; set; } = true;
    public bool Language { get; set; } = true;
}

public sealed class AppPreference
{
    public string App { get; set; } = "";
    public AppMode Mode { get; set; }
}

public sealed class Profile
{
    public static readonly string[] RoleKeys = ["LCtrl", "RCtrl", "LAlt", "RAlt", "LWin", "RWin"];
    public const string Keep = "保留";

    public string Name { get; set; } = "";
    public List<Rule> Overrides { get; set; } = [];

    /// <summary>Version 1 alias of <see cref="Overrides"/>; read only.</summary>
    [JsonPropertyName("rules"), JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<Rule>? LegacyRules { get => null; set { if (value != null) Overrides = value; } }

    public string Exclusions { get; set; } = "";
    public List<string> Roles { get; set; } = [];
    public ProfileKind Kind { get; set; } = ProfileKind.Custom;
    public Features Features { get; set; } = new();
    public List<AppPreference> AppModes { get; set; } = [];

    public static Profile MacOs() => new()
    {
        Name = "macOS 操作習慣",
        Roles = [Keep, Keep, "Command", Keep, "Option", Keep],
        Kind = ProfileKind.MacOs,
        AppModes = [new() { App = "WindowsTerminal.exe", Mode = AppMode.Terminal }],
    };

    public static Profile Windows() => new()
    {
        Name = "Windows 原始操作",
        Roles = [.. Enumerable.Repeat(Keep, 6)],
        Kind = ProfileKind.Windows,
        Features = new() { Command = false, Option = false, Language = false },
    };

    public Profile Clone() => new()
    {
        Name = Name,
        Overrides = [.. Overrides.Select(r => r.Copy())],
        Exclusions = Exclusions,
        Roles = [.. Roles],
        Kind = Kind,
        Features = new() { Command = Features.Command, Option = Features.Option, Language = Features.Language },
        AppModes = [.. AppModes.Select(a => new AppPreference { App = a.App, Mode = a.Mode })],
    };

    public bool FeatureEnabled(FeatureGroup? g) => g switch
    {
        FeatureGroup.Command => Features.Command,
        FeatureGroup.Option => Features.Option,
        FeatureGroup.Language => Features.Language,
        _ => true,
    };

    public List<Rule> BuiltinRules() => Kind == ProfileKind.MacOs ? Builtin.Catalog() : [];
    public Rule? BuiltinRule(string id) => Kind == ProfileKind.MacOs ? Builtin.Find(id) : null;

    /// <summary>Stores an edit. Returns whether anything changed; an unmodified builtin removes its override.</summary>
    public bool SetOverride(int? index, Rule rule)
    {
        if (index is int i && i >= Overrides.Count) throw new InvalidOperationException("自訂項目已移除，請重新編輯");
        var unchangedBuiltin = rule.BuiltinId != null && BuiltinRule(rule.BuiltinId) == rule;
        if (unchangedBuiltin)
        {
            if (index is int j) { Overrides.RemoveAt(j); return true; }
            return false;
        }
        if (index is int k)
        {
            if (Overrides[k] == rule) return false;
            Overrides[k] = rule;
        }
        else Overrides.Add(rule);
        return true;
    }

    public AppMode AppModeFor(string app)
    {
        // Legacy global exclusions take precedence over per-application preferences.
        if (Lines(Exclusions).Any(s => AppMatches(s, app))) return AppMode.Windows;
        var pref = AppModes.FirstOrDefault(p => p.App.IndexOfAny(['\\', '/']) >= 0 && AppMatches(p.App, app))
                   ?? AppModes.FirstOrDefault(p => AppMatches(p.App, app));
        return pref?.Mode ?? AppMode.Inherit;
    }

    /// <summary>Compiles settings for the UI preview; never reads or writes keyboard events.</summary>
    public List<Rule> PreviewRules(string app)
    {
        var mode = AppModeFor(app);
        if (mode == AppMode.Windows) return [];
        var builtin = BuiltinRules();
        foreach (var r in Overrides)
            if (r.BuiltinId is string id && !builtin.Any(b => b.BuiltinId == id) && BuiltinRule(id) is Rule extra)
                builtin.Add(extra);

        var merged = new List<(bool Custom, Rule Rule)>();
        foreach (var b in builtin)
        {
            var baseRule = b.Copy();
            if (mode == AppMode.Terminal)
            {
                if (baseRule.BuiltinId == "Command+C") baseRule.Value = "LCtrl+Shift+C";
                if (baseRule.BuiltinId == "Command+V") baseRule.Value = "LCtrl+Shift+V";
            }
            var ov = Overrides.Where(r => r.BuiltinId == baseRule.BuiltinId && Applies(r, app))
                .OrderBy(r => r.Scope == Scope.Only).ThenBy(r => r.Priority).LastOrDefault();
            merged.Add(ov != null ? (true, ov.Copy()) : (false, baseRule));
        }
        foreach (var r in Overrides)
            if (r.BuiltinId == null || !builtin.Any(b => b.BuiltinId == r.BuiltinId))
                merged.Add((true, r.Copy()));

        var ordered = merged
            .Select((m, i) => (m, i))
            .OrderByDescending(x => x.m.Rule.Scope == Scope.Only)
            .ThenByDescending(x => x.m.Rule.Priority)
            .ThenByDescending(x => x.m.Custom)
            .ThenBy(x => x.i)
            .Select(x => x.m.Rule);

        var result = new List<Rule>();
        var seen = new HashSet<string>();
        foreach (var r in ordered)
        {
            if (!r.Enabled || !FeatureEnabled(r.Group) || !Applies(r, app)) continue;
            var triggers = new List<string> { "" };
            foreach (var token in r.Trigger.Split('+'))
            {
                IEnumerable<string> keys = token is "Command" or "Option"
                    ? RoleKeys.Zip(Roles).Where(p => p.Second == token).Select(p => p.First)
                    : [token];
                var keyList = keys.ToList();
                triggers = [.. triggers.SelectMany(prefix => keyList.Select(k => prefix.Length == 0 ? k : $"{prefix}+{k}"))];
            }
            foreach (var t in triggers)
            {
                var key = string.Join("+", t.Split('+').Select(s => s.ToLowerInvariant()).Order(StringComparer.Ordinal));
                if (seen.Add(key)) result.Add(r with { Trigger = t });
            }
        }
        return result;
    }

    public static bool Applies(Rule r, string app)
    {
        var matches = Lines(r.Apps).Any(s => AppMatches(s, app));
        return r.Scope switch { Scope.Only => matches, Scope.Except => !matches, _ => true };
    }

    public static bool AppMatches(string pattern, string app)
    {
        var p = Normalize(pattern);
        var a = Normalize(app);
        if (p.Length == 0) return false;
        return p.Contains('\\') ? p == a : a[(a.LastIndexOf('\\') + 1)..] == p;
    }

    public static string Normalize(string s) => s.Trim().Replace('/', '\\').ToLowerInvariant();
    public static IEnumerable<string> Lines(string s) => s.Split('\n').Select(l => l.TrimEnd('\r'));
}

public sealed class Config
{
    public const int CurrentVersion = 3;
    public int Version { get; set; } = CurrentVersion;
    public int Active { get; set; }
    public bool Paused { get; set; } = true;
    public List<Profile> Profiles { get; set; } = [Profile.MacOs(), Profile.Windows()];

    [JsonIgnore] public Profile ActiveProfile => Profiles[Active];

    public void Validate()
    {
        if (Version != CurrentVersion) throw new InvalidDataException("不支援的設定版本");
        if (Profiles.Count == 0 || Active < 0 || Active >= Profiles.Count) throw new InvalidDataException("配置索引無效");
        if (Profiles.Any(p => string.IsNullOrWhiteSpace(p.Name) || p.Roles.Count != 6))
            throw new InvalidDataException("配置名稱或修飾鍵設定無效");
        foreach (var p in Profiles)
        {
            var seen = new HashSet<string>();
            foreach (var pref in p.AppModes)
                if (string.IsNullOrWhiteSpace(pref.App) || !seen.Add(Profile.Normalize(pref.App)))
                    throw new InvalidDataException("程式偏好有空白或重複的程式");
        }
    }

    public Config Migrate()
    {
        if (Version == 1)
        {
            if (Profiles.Count == 0 || Active < 0 || Active >= Profiles.Count) throw new InvalidDataException("舊版配置索引無效");
            // Keep every old rule and physical trigger intact; offer new presets alongside it.
            foreach (var p in Profiles) p.Kind = ProfileKind.Custom;
            Profiles.Add(Profile.MacOs());
            Profiles.Add(Profile.Windows());
            Version = CurrentVersion;
        }
        else if (Version == 2)
        {
            foreach (var p in Profiles.Where(p => p.Kind == ProfileKind.MacOs))
            {
                var baseline = Builtin.LegacyCatalog();
                var found = new HashSet<string>();
                var overrides = new List<Rule>();
                foreach (var old in p.Overrides)
                {
                    var b = baseline.FirstOrDefault(b => b.Trigger == old.Trigger && (b.Group == old.Group || b.Name == old.Name))
                            ?? baseline.FirstOrDefault(b => b.Name == old.Name);
                    if (b != null)
                    {
                        found.Add(b.BuiltinId!);
                        if (old != b with { BuiltinId = null }) overrides.Add(old with { BuiltinId = b.BuiltinId });
                    }
                    else overrides.Add(old);
                }
                foreach (var b in baseline.Where(b => !found.Contains(b.BuiltinId!)))
                    overrides.Add(b with { Enabled = false });
                p.Overrides = overrides;
            }
            Version = CurrentVersion;
        }
        Validate();
        return this;
    }
}
