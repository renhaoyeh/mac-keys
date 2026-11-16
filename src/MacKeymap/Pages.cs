using CommunityToolkit.WinUI.Controls;
using MacKeymap.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Diagnostics;
using Windows.Storage.Pickers;

namespace MacKeymap;

public sealed partial class MainWindow
{
    internal static readonly (RuleAction, string)[] Actions =
        [(RuleAction.Shortcut, "送出組合鍵"), (RuleAction.Language, "切換語言"), (RuleAction.Text, "輸入文字"), (RuleAction.Launch, "啟動程式")];
    internal static readonly (Scope, string)[] Scopes =
        [(Scope.Global, "所有應用程式"), (Scope.Only, "僅指定應用程式"), (Scope.Except, "排除指定應用程式")];
    internal static readonly (FeatureGroup?, string)[] Groups =
        [(null, "獨立自訂"), (FeatureGroup.Command, "Command 快捷鍵"), (FeatureGroup.Option, "Option 逐字操作"), (FeatureGroup.Language, "CapsLock 輸入語言")];
    private static readonly (AppMode, string)[] Modes =
        [(AppMode.Inherit, "沿用 Profile"), (AppMode.Windows, "原始 Windows 操作"), (AppMode.Terminal, "終端機操作")];
    private static readonly string[] RoleLabels = ["左 Ctrl", "右 Ctrl", "左 Alt", "右 Alt", "左 Win", "右 Win"];

    internal static string Describe(Rule r)
    {
        var scope = r.Scope switch
        {
            Scope.Only => $" · 僅限 {string.Join("、", Profile.Lines(r.Apps).Where(s => s.Trim().Length > 0))}",
            Scope.Except => $" · 排除 {string.Join("、", Profile.Lines(r.Apps).Where(s => s.Trim().Length > 0))}",
            _ => "",
        };
        var value = r.Action == RuleAction.Shortcut ? r.Value : $"{Actions.First(a => a.Item1 == r.Action).Item2}：{r.Value}";
        return $"{r.Trigger}  →  {value}{scope}";
    }

    private static string KindDescription(ProfileKind k) => k switch
    {
        ProfileKind.MacOs => "Command 快捷鍵、Option 逐字操作與 CapsLock 輸入法切換，整組套用。",
        ProfileKind.Windows => "保留 Windows 操作習慣，預設不套用任何按鍵映射。",
        _ => "保留舊版自訂內容。",
    };

    private static string KindGlyph(ProfileKind k) => k switch
    {
        ProfileKind.MacOs => "",
        ProfileKind.Windows => "",
        _ => "",
    };

    private string RoleSummary()
    {
        var parts = Profile.RoleKeys.Select((_, i) => (Label: RoleLabels[i], Role: P.Roles[i]))
            .Where(x => x.Role != Profile.Keep).Select(x => $"{x.Label} → {x.Role}").ToList();
        return parts.Count == 0 ? "所有修飾鍵保留原功能" : string.Join("　", parts);
    }

    // ---------- 總覽 ----------
    private void BuildOverview()
    {
        AddMappingStatus();
        Add(Ui.Section("選擇操作習慣"));
        for (var i = 0; i < _config.Profiles.Count; i++)
        {
            var idx = i;
            var p = _config.Profiles[i];
            var active = i == _config.Active;
            var card = Ui.Link(p.Name, KindDescription(p.Kind), KindGlyph(p.Kind), () => { _config.Active = idx; Changed(); },
                active ? Ui.Tag("使用中") : null);
            card.IsActionIconVisible = !active;
            Add(card);
        }

        Add(Ui.Section("目前配置"));
        if (P.Kind == ProfileKind.MacOs)
        {
            var on = new[] { (P.Features.Command, "Command 快捷鍵"), (P.Features.Option, "Option 逐字操作"), (P.Features.Language, "CapsLock 語言切換") }
                .Where(f => f.Item1).Select(f => f.Item2).ToList();
            Add(Ui.Link("操作偏好", on.Count == 0 ? "所有功能群組都已關閉" : $"已開啟：{string.Join("、", on)}", "", () => Go("prefs")));
            Add(Ui.Link("鍵盤角色", RoleSummary(), "", () => Go("prefs")));
        }
        var exceptions = P.AppModes.Count(a => a.Mode != AppMode.Inherit);
        Add(Ui.Link("應用程式", exceptions == 0 ? "所有應用程式都沿用目前配置" : $"{exceptions} 個應用程式使用不同的操作模式", "", () => Go("apps")));
        Add(Ui.Link("我的自訂與例外", P.Overrides.Count == 0 ? "目前使用 Profile 預設" : $"{P.Overrides.Count} 項自訂", "", () => Go("advanced")));
    }

    // ---------- 操作偏好 ----------
    private void BuildPrefs()
    {
        if (!RequireMac()) return;
        Add(Ui.Note("整套 macOS 操作已選取：Command、Option 與輸入法偏好一起管理。群組開關會保留你的自訂偏好。"));
        Add(Ui.Section("功能群組"));
        Add(Ui.Card("Command 快捷鍵", "複製、貼上、復原、分頁、導航與視窗切換。一般 Command＋按鍵會轉送 Ctrl＋同鍵。",
            Ui.Toggle(P.Features.Command, v => { P.Features.Command = v; Changed(false); }), ""));
        Add(Ui.Card("Option 逐字操作", "逐字移動、選取與刪除。",
            Ui.Toggle(P.Features.Option, v => { P.Features.Option = v; Changed(false); }), ""));
        Add(Ui.Card("CapsLock 輸入語言切換", "CapsLock 切換輸入語言；Shift＋CapsLock 切換大小寫鎖定。",
            Ui.Toggle(P.Features.Language, v => { P.Features.Language = v; Changed(false); }), ""));

        Add(Ui.Section("鍵盤角色"));
        var exp = Ui.Expander("修飾鍵角色", RoleSummary(), "");
        exp.IsExpanded = true;
        for (var i = 0; i < 6; i++)
        {
            var idx = i;
            exp.Items.Add(new SettingsCard
            {
                Header = RoleLabels[i],
                Content = Ui.Combo([(Profile.Keep, "保留原功能"), ("Command", "Command"), ("Option", "Option")], P.Roles[i],
                    v => { P.Roles[idx] = v; exp.Description = RoleSummary(); Changed(false); }),
            });
        }
        exp.Items.Add(new SettingsCard
        {
            Header = "macOS 預設鍵盤角色",
            Description = "左 Alt → Command　左 Win → Option；Ctrl 與右 Alt 保留原功能。",
            Content = Ui.Button("恢復預設", () => { P.Roles = [.. Profile.MacOs().Roles]; Changed(); }),
        });
        Add(exp);
        Add(Ui.Note("變更鍵盤角色後，Command／Option 操作會跟著使用指定的實體鍵；輸出動作不變。"));
    }

    private bool RequireMac()
    {
        if (P.Kind == ProfileKind.MacOs) return true;
        Add(Ui.Info(P.Kind == ProfileKind.Windows ? "此 Profile 使用 Windows 原始操作" : "此 Profile 保留既有的自訂規則",
            "切換至 macOS 操作配置後，即可整組調整 Command、Option 與 CapsLock 行為。個別自訂仍可在進階自訂管理。"));
        Add(Ui.Button("前往總覽選擇配置", () => Go("overview"), ""));
        return false;
    }

    // ---------- 進階自訂 ----------
    private void BuildAdvanced()
    {
        Add(Ui.Note("一般操作已由配置統一處理，只需要加入特殊需求。"));
        var header = new Grid { Margin = new Thickness(0, 20, 0, 6) };
        header.Children.Add(new TextBlock { Text = "我的自訂與例外", Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"], VerticalAlignment = VerticalAlignment.Center });
        var add = Ui.Button("新增自訂", () => _ = EditRule(null, new Rule()), "");
        add.HorizontalAlignment = HorizontalAlignment.Right;
        header.Children.Add(add);
        Add(header);

        if (P.Overrides.Count == 0)
            Add(Ui.Card("目前使用 Profile 預設", "目前沒有自訂項目。需要改某個預設行為時，從下方「Profile 內建行為」建立覆寫。", null, ""));
        for (var i = 0; i < P.Overrides.Count; i++)
            Add(OverrideCard(i));

        Add(Ui.Section("詳細設定"));
        if (P.Kind == ProfileKind.MacOs)
            Add(Ui.Link("Profile 內建行為", "查閱 Profile 預設，只有特殊需求才建立自訂。", "", () => { _builtinQuery = ""; Push("builtin", "Profile 內建行為"); }));
        Add(Ui.Link("套用結果", "唯讀設定預覽：查看某個應用程式實際會套用的按鍵。", "", () => Push("preview", "套用結果")));
        Add(Ui.Link("舊版程式排除", "列出的程式保留原始 Windows 輸入，優先於應用程式操作模式。", "", () => Push("exclusions", "舊版程式排除")));
    }

    private SettingsCard OverrideCard(int i)
    {
        var r = P.Overrides[i];
        var builtin = r.BuiltinId != null ? P.BuiltinRule(r.BuiltinId) : null;
        var edit = Ui.Button("編輯", () => _ = EditRule(i, P.Overrides[i]));
        var remove = Ui.Button(builtin != null ? "恢復預設" : "刪除", () => { P.Overrides.RemoveAt(i); Changed(); });
        var toggle = Ui.Toggle(r.Enabled, v => { P.Overrides[i] = P.Overrides[i] with { Enabled = v }; Changed(false); });
        var card = Ui.Card(r.Name, Describe(r) + (builtin != null ? "　（覆寫內建行為）" : ""), Ui.Row(toggle, edit, remove),
            builtin != null ? "" : "");
        return card;
    }

    private async Task EditRule(int? index, Rule rule)
    {
        var builtinTemplate = rule.BuiltinId != null ? P.BuiltinRule(rule.BuiltinId) : null;
        var conflicts = (Rule candidate) => P.Overrides.Where((o, j) => j != index && string.Equals(o.Trigger, candidate.Trigger, StringComparison.OrdinalIgnoreCase)).Count();
        var editor = new RuleEditor(rule, index != null || builtinTemplate != null, builtinTemplate != null && index != null, conflicts);
        var result = await editor.ShowAsync(Content.XamlRoot);
        if (result == RuleEditor.Result.Restore && index is int i) { P.Overrides.RemoveAt(i); Changed(); return; }
        if (result != RuleEditor.Result.Save) return;
        try { if (P.SetOverride(index, editor.Rule)) Changed(); }
        catch (Exception e) { await Ui.Alert(Content.XamlRoot, "無法儲存此項目", e.Message); Changed(); }
    }

    private void BuildBuiltin()
    {
        if (!RequireMac()) return;
        Add(Ui.Note("內建清單為唯讀查詢。「自訂…」會建立覆寫；取消或未修改就完成，不會新增項目。"));
        var list = new StackPanel { Spacing = 4 };
        var search = new AutoSuggestBox
        {
            PlaceholderText = "搜尋動作或按鍵，例如：貼上、Command+S",
            QueryIcon = new SymbolIcon(Symbol.Find),
            Text = _builtinQuery,
            Margin = new Thickness(0, 8, 0, 12),
        };
        void Fill()
        {
            list.Children.Clear();
            var q = _builtinQuery;
            var matches = P.BuiltinRules().Where(r => q.Length == 0 || r.Name.Contains(q, StringComparison.OrdinalIgnoreCase)
                || r.Trigger.Contains(q, StringComparison.OrdinalIgnoreCase) || r.Value.Contains(q, StringComparison.OrdinalIgnoreCase)).ToList();
            if (matches.Count == 0) list.Children.Add(Ui.Card("沒有符合的內建行為", null, null, ""));
            foreach (var group in matches.GroupBy(r => r.Group))
            {
                list.Children.Add(Ui.Section(Groups.First(g => g.Item1 == group.Key).Item2 + (P.FeatureEnabled(group.Key) ? "" : "（群組已關閉）")));
                foreach (var b in group)
                {
                    var idx = P.Overrides.FindIndex(o => o.BuiltinId == b.BuiltinId);
                    var content = Ui.Row(idx >= 0 ? Ui.Tag("已自訂") : new Border(),
                        Ui.Button("自訂…", () => _ = EditRule(idx >= 0 ? idx : null, idx >= 0 ? P.Overrides[idx] : b)));
                    list.Children.Add(Ui.Card(b.Name, $"{b.Trigger}  →  {b.Value}", content));
                }
            }
        }
        search.TextChanged += (s, a) => { if (a.Reason == AutoSuggestionBoxTextChangeReason.UserInput) { _builtinQuery = s.Text.Trim(); Fill(); } };
        Add(search);
        Add(list);
        Fill();
    }

    private void BuildPreview()
    {
        Add(Ui.Info("唯讀設定預覽", "目前不會改變實際鍵盤操作。"));
        var list = new StackPanel { Spacing = 4 };
        var box = new TextBox { Text = _previewApp, PlaceholderText = "EXE 名稱或完整路徑", MinWidth = 280 };
        var mode = new TextBlock { VerticalAlignment = VerticalAlignment.Center };
        void Fill()
        {
            list.Children.Clear();
            var m = P.AppModeFor(_previewApp);
            mode.Text = Modes.First(x => x.Item1 == m).Item2;
            var rules = P.PreviewRules(_previewApp);
            if (rules.Count == 0) list.Children.Add(Ui.Card("此範圍保留原始 Windows 輸入", null, null, ""));
            foreach (var r in rules) list.Children.Add(Ui.Card(r.Name, Describe(r)));
        }
        box.TextChanged += (_, _) => { _previewApp = box.Text; Fill(); };
        Add(Ui.Card("應用程式", "輸入要預覽的程式", Ui.Row(mode, box), ""));
        Add(Ui.Section("套用的按鍵"));
        Add(list);
        Fill();
    }

    private void BuildExclusions()
    {
        Add(Ui.Note("這份清單優先於應用程式操作模式。列出的程式保留原始 Windows 輸入。建議改用「應用程式」頁設定。"));
        var box = new TextBox
        {
            Text = P.Exclusions, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 160,
            PlaceholderText = "每行一個 EXE 名稱或完整路徑", Margin = new Thickness(0, 8, 0, 0),
        };
        box.TextChanged += (_, _) => { P.Exclusions = box.Text.Replace("\r\n", "\n").Replace('\r', '\n'); Changed(false); };
        Add(box);
    }

    // ---------- 輸入法 ----------
    private void BuildInput()
    {
        if (!RequireMac()) return;
        Add(Ui.Section("CapsLock"));
        Add(Ui.Card("CapsLock 輸入語言切換", "CapsLock 切換輸入語言；Shift＋CapsLock 切換大小寫鎖定。",
            Ui.Toggle(P.Features.Language, v => { P.Features.Language = v; Changed(false); }), ""));
        Add(Ui.Note("這是 Profile 的整組偏好，不需要分別建立兩條 CapsLock 規則。語言切換組合的特殊需求可在進階自訂調整。"));
        Add(Ui.Link("修改語言切換組合…", "在 Profile 內建行為中搜尋 CapsLock", "", () => { _builtinQuery = "CapsLock"; Go("advanced"); Push("builtin", "Profile 內建行為"); }));
    }

    // ---------- 應用程式 ----------
    private void BuildApps()
    {
        Add(Ui.Note("完整路徑優先於 EXE 名稱；未列出的程式自動沿用 Profile。舊版全域排除優先。"));
        var box = new TextBox { PlaceholderText = "EXE 名稱或完整路徑", MinWidth = 260 };
        var browse = Ui.Button("瀏覽…", async () => { if (await PickExe() is string f) box.Text = f; }, "");
        var running = new DropDownButton { Content = "執行中視窗" };
        var flyout = new MenuFlyout();
        flyout.Opening += (_, _) =>
        {
            flyout.Items.Clear();
            foreach (var (name, path) in RunningApps())
            {
                var item = new MenuFlyoutItem { Text = name };
                item.Click += (_, _) => box.Text = path;
                flyout.Items.Add(item);
            }
            if (flyout.Items.Count == 0) flyout.Items.Add(new MenuFlyoutItem { Text = "找不到有主視窗的程式", IsEnabled = false });
        };
        running.Flyout = flyout;
        var add = Ui.Button("加入", async () =>
        {
            var app = box.Text.Trim();
            if (app.Length == 0) return;
            if (P.AppModes.Any(a => Profile.Normalize(a.App) == Profile.Normalize(app)))
            {
                await Ui.Alert(Content.XamlRoot, "無法加入", "此程式已在清單中，請直接修改操作模式");
                return;
            }
            P.AppModes.Add(new AppPreference { App = app, Mode = AppMode.Windows });
            Changed();
        }, "", accent: true);
        var addCard = Ui.Card("加入應用程式", "選擇程式後再設定它的操作模式", Ui.Row(box, browse, running, add), "");
        Add(addCard);

        Add(Ui.Section("應用程式操作模式"));
        if (P.AppModes.Count == 0) Add(Ui.Card("所有應用程式都沿用目前配置", null, null, ""));
        for (var i = 0; i < P.AppModes.Count; i++)
        {
            var pref = P.AppModes[i];
            var mode = Ui.Combo(Modes, pref.Mode, v => { pref.Mode = v; Changed(false); });
            var del = new Button { Content = new FontIcon { Glyph = "", FontSize = 14 } };
            ToolTipService.SetToolTip(del, "移除例外，恢復沿用 Profile");
            del.Click += (_, _) => { P.AppModes.Remove(pref); Changed(); };
            var isPath = pref.App.IndexOfAny(['\\', '/']) >= 0;
            Add(Ui.Card(Path.GetFileName(pref.App), isPath ? pref.App : "EXE 名稱", Ui.Row(mode, del), ""));
        }
        Add(Ui.Info("模式說明", "沿用 Profile：使用整套配置及群組偏好。\n原始 Windows：此程式完全略過映射。\n終端機：沿用配置，Command+C/V 改用 Ctrl+Shift+C/V；實體 Ctrl+C 保留中斷功能。"));
    }

    private async Task<string?> PickExe()
    {
        var picker = new FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(picker, Hwnd);
        picker.FileTypeFilter.Add(".exe");
        var file = await picker.PickSingleFileAsync();
        return file?.Path;
    }

    /// <summary>Lists processes that own a main window. Only queries; never activates them.</summary>
    private static List<(string Name, string Path)> RunningApps()
    {
        var result = new List<(string, string)>();
        foreach (var p in Process.GetProcesses())
        {
            try
            {
                if (p.MainWindowHandle == 0) continue;
                string path;
                try { path = p.MainModule?.FileName ?? p.ProcessName + ".exe"; }
                catch { path = p.ProcessName + ".exe"; } // Protected process: name only.
                var title = string.IsNullOrWhiteSpace(p.MainWindowTitle) ? "" : $" — {p.MainWindowTitle}";
                result.Add(($"{Path.GetFileName(path)}{title}", path));
            }
            catch { }
            finally { p.Dispose(); }
        }
        return [.. result.DistinctBy(r => r.Item2.ToLowerInvariant()).OrderBy(r => r.Item1, StringComparer.CurrentCultureIgnoreCase)];
    }

    // ---------- 配置 ----------
    private void BuildProfiles()
    {
        var header = new Grid { Margin = new Thickness(0, 8, 0, 6) };
        header.Children.Add(new TextBlock { Text = "管理 Profile", Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"], VerticalAlignment = VerticalAlignment.Center });
        var newBtn = new DropDownButton { Content = "新增配置", HorizontalAlignment = HorizontalAlignment.Right };
        var menu = new MenuFlyout();
        foreach (var (label, make) in new (string, Func<Profile>)[] { ("macOS 操作習慣", Profile.MacOs), ("Windows 原始操作", Profile.Windows) })
        {
            var item = new MenuFlyoutItem { Text = label };
            item.Click += (_, _) => { var p = make(); p.Name = UniqueName(p.Name); _config.Profiles.Add(p); Changed(); };
            menu.Items.Add(item);
        }
        newBtn.Flyout = menu;
        header.Children.Add(newBtn);
        Add(header);

        for (var i = 0; i < _config.Profiles.Count; i++)
        {
            var idx = i;
            var p = _config.Profiles[i];
            var active = i == _config.Active;
            var more = new MenuFlyout();
            void Item(string text, string glyph, Action a, bool enabled = true)
            {
                var m = new MenuFlyoutItem { Text = text, Icon = Ui.Icon(glyph), IsEnabled = enabled };
                m.Click += (_, _) => a();
                more.Items.Add(m);
            }
            Item("重新命名", "", async () =>
            {
                if (await Ui.Prompt(Content.XamlRoot, "重新命名配置", p.Name) is string n) { p.Name = n; Changed(); }
            });
            Item("複製", "", () => { var c = p.Clone(); c.Name = UniqueName(p.Name + " 複本"); _config.Profiles.Insert(idx + 1, c); if (_config.Active > idx) _config.Active++; Changed(); });
            Item("刪除", "", async () =>
            {
                if (!await Ui.Confirm(Content.XamlRoot, $"刪除「{p.Name}」？", "按儲存後才會從設定檔移除。", "刪除")) return;
                _config.Profiles.RemoveAt(idx);
                if (_config.Active >= idx && _config.Active > 0) _config.Active--;
                Changed();
            }, _config.Profiles.Count > 1);
            var moreBtn = new Button { Content = new FontIcon { Glyph = "", FontSize = 14 }, Flyout = more };
            UIElement use = active ? Ui.Tag("使用中") : Ui.Button("使用", () => { _config.Active = idx; Changed(); });
            var kind = p.Kind switch { ProfileKind.MacOs => "macOS 操作", ProfileKind.Windows => "Windows 原始操作", _ => "自訂（舊版）" };
            Add(Ui.Card(p.Name, $"{kind} · {p.Overrides.Count} 項自訂 · {p.AppModes.Count} 個應用程式偏好", Ui.Row(use, moreBtn), KindGlyph(p.Kind)));
        }
    }

    private string UniqueName(string name)
    {
        var n = name;
        for (var i = 2; _config.Profiles.Any(p => p.Name == n); i++) n = $"{name} {i}";
        return n;
    }

    private void AddMappingStatus()
    {
        var running = _runner.IsRunning;
        if (_mapping is { } m && (m.Running != running || m.Message.StartsWith("無法") || m.Message.StartsWith("找不到") || m.Message.StartsWith("產生")))
            Add(Ui.Info("鍵盤配置", m.Message, InfoBarSeverity.Error));
        else if (running)
            Add(Ui.Info("鍵盤配置執行中", (_mapping?.Message ?? "由 AutoHotkey 套用已儲存的配置。") + "關閉此視窗後仍會繼續執行；可在「一般」暫停。", InfoBarSeverity.Success));
        else
            Add(Ui.Info(_config.Paused ? "鍵盤配置已暫停" : "鍵盤配置未執行",
                _config.Paused ? "按鍵維持 Windows 原本行為。到「一般」關閉「暫停鍵盤配置」並儲存即可啟用。" : _mapping?.Message ?? "儲存設定後即會套用。",
                InfoBarSeverity.Warning));
        if (_mapping is { Skipped.Count: > 0 } s)
            Add(Ui.Info("部分規則無法套用", $"以下規則的按鍵名稱無法轉換，已略過：{string.Join("、", s.Skipped)}", InfoBarSeverity.Warning));
        if (IsDirty) Add(Ui.Note("有尚未儲存的變更；儲存後才會套用到實際按鍵。"));
    }

    // ---------- 一般 ----------
    private void BuildGeneral()
    {
        Add(Ui.Section("鍵盤配置"));
        AddMappingStatus();
        Add(Ui.Card("暫停鍵盤配置", "暫停時停止 AutoHotkey，所有按鍵恢復 Windows 原本行為。按儲存後生效。",
            Ui.Toggle(_config.Paused, v => { _config.Paused = v; Changed(false); }), ""));
        Add(Ui.Card("開機時啟動", "尚未提供：不註冊任何常駐或開機項目。", Ui.Toggle(false, _ => { }, enabled: false), ""));
        Add(Ui.Card("在系統匣顯示", "尚未提供。", Ui.Toggle(false, _ => { }, enabled: false), ""));

        Add(Ui.Section("設定檔"));
        var openDir = Ui.Button("開啟資料夾", () =>
        {
            var dir = Path.GetDirectoryName(_path)!;
            if (Directory.Exists(dir)) Process.Start(new ProcessStartInfo("explorer.exe", $"\"{dir}\"") { UseShellExecute = true });
        }, "");
        Add(Ui.Card("設定位置", _path, openDir, ""));
        Add(Ui.Card("匯入", "取代記憶體中的設定；按儲存後才會覆寫使用者設定。", Ui.Button("匯入…", async () => await Import()), ""));
        Add(Ui.Card("匯出", "將目前設定（含未儲存的變更）寫到另一個檔案。", Ui.Button("匯出…", async () => await Export()), ""));
        Add(Ui.Card("捨棄變更", "重新從磁碟載入已儲存的設定。", Ui.Button("重新載入", async () =>
        {
            if (!IsDirty || await Ui.Confirm(Content.XamlRoot, "捨棄所有未儲存的變更？", "目前的編輯會遺失。", "捨棄"))
            {
                try { _config = File.Exists(_path) ? Storage.Load(_path) : new(); _loadError = null; _savedJson = Storage.Serialize(_config); }
                catch (Exception e) { _loadError = $"無法載入設定（原檔未變更）：{e.Message}"; }
                Render();
            }
        }), ""));
    }

    private async Task Import()
    {
        var picker = new FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(picker, Hwnd);
        picker.FileTypeFilter.Add(".json");
        var file = await picker.PickSingleFileAsync();
        if (file == null) return;
        try { _config = Storage.Load(file.Path); Render(); }
        catch (Exception e) { await Ui.Alert(Content.XamlRoot, "無法匯入", e.Message); }
    }

    private async Task Export()
    {
        var picker = new FileSavePicker { SuggestedFileName = "mac-keymap" };
        WinRT.Interop.InitializeWithWindow.Initialize(picker, Hwnd);
        picker.FileTypeChoices.Add("JSON", [".json"]);
        var file = await picker.PickSaveFileAsync();
        if (file == null) return;
        try { Storage.Save(file.Path, _config); }
        catch (Exception e) { await Ui.Alert(Content.XamlRoot, "無法匯出", e.Message); }
    }
}
