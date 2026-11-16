using System.Runtime.InteropServices;
using MacKeymap.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Windows.System;

namespace MacKeymap;

/// <summary>Edit sheet for one custom rule or builtin override.</summary>
internal sealed partial class RuleEditor
{
    public enum Result { Cancel, Save, Restore }

    public Rule Rule { get; private set; }
    private readonly bool _existing;
    private readonly bool _canRestore;
    private readonly Func<Rule, int> _conflicts;
    private bool _recording;

    public RuleEditor(Rule rule, bool existing, bool canRestore, Func<Rule, int> conflicts)
    {
        Rule = rule.Copy();
        _existing = existing;
        _canRestore = canRestore;
        _conflicts = conflicts;
    }

    public async Task<Result> ShowAsync(XamlRoot root)
    {
        var r = Rule;
        var name = new TextBox { Header = "名稱", Text = r.Name };
        var enabled = new ToggleSwitch { Header = "啟用此行為", IsOn = r.Enabled, OnContent = "開啟", OffContent = "關閉" };
        var trigger = new TextBox { Text = r.Trigger, PlaceholderText = "例如 Command+C、RAlt+K、CapsLock", HorizontalAlignment = HorizontalAlignment.Stretch };
        var record = new ToggleButton { Content = "錄製", VerticalAlignment = VerticalAlignment.Bottom };
        var triggerRow = new Grid { ColumnSpacing = 8 };
        triggerRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        triggerRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        triggerRow.Children.Add(trigger);
        Grid.SetColumn(record, 1);
        triggerRow.Children.Add(record);
        var triggerHelp = new TextBlock
        {
            Text = "使用 Command／Option 會跟隨 Profile 鍵盤角色；LCtrl／RCtrl、LAlt／RAlt、LWin／RWin 則指定實體鍵。CapsLock 可直接填入。",
            TextWrapping = TextWrapping.Wrap, Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
            Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };

        var action = new ComboBox { Header = "執行動作", HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var (_, l) in MainWindow.Actions) action.Items.Add(l);
        action.SelectedIndex = Array.FindIndex(MainWindow.Actions, a => a.Item1 == r.Action);
        var value = new TextBox { Text = r.Value };
        void UpdateValueHeader() => value.Header = MainWindow.Actions[Math.Max(0, action.SelectedIndex)].Item1 switch
        {
            RuleAction.Shortcut => "送出組合鍵",
            RuleAction.Language => "切換語言的組合鍵",
            RuleAction.Text => "輸入文字",
            _ => "執行檔路徑",
        };
        UpdateValueHeader();
        action.SelectionChanged += (_, _) => UpdateValueHeader();

        var group = new ComboBox { Header = "所屬功能群組", HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var (_, l) in MainWindow.Groups) group.Items.Add(l);
        group.SelectedIndex = Array.FindIndex(MainWindow.Groups, g => g.Item1 == r.Group);

        var scope = new ComboBox { Header = "適用範圍", HorizontalAlignment = HorizontalAlignment.Stretch };
        foreach (var (_, l) in MainWindow.Scopes) scope.Items.Add(l);
        scope.SelectedIndex = Array.FindIndex(MainWindow.Scopes, s => s.Item1 == r.Scope);
        var apps = new TextBox { Header = "應用程式", Text = r.Apps, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, MinHeight = 72, PlaceholderText = "每行一個 EXE 名稱或完整路徑" };
        void UpdateApps() => apps.Visibility = scope.SelectedIndex == 0 ? Visibility.Collapsed : Visibility.Visible;
        UpdateApps();
        scope.SelectionChanged += (_, _) => UpdateApps();
        var priority = new NumberBox { Header = "優先順序", Value = r.Priority, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline, SmallChange = 1 };

        var error = new InfoBar { Severity = InfoBarSeverity.Error, IsClosable = false };
        var warning = new InfoBar { Severity = InfoBarSeverity.Warning, IsClosable = false };

        Rule Build() => new()
        {
            BuiltinId = r.BuiltinId,
            Group = MainWindow.Groups[Math.Max(0, group.SelectedIndex)].Item1,
            Name = name.Text.Trim(),
            Enabled = enabled.IsOn,
            Trigger = trigger.Text.Trim(),
            Action = MainWindow.Actions[Math.Max(0, action.SelectedIndex)].Item1,
            Value = value.Text.Trim(),
            Scope = MainWindow.Scopes[Math.Max(0, scope.SelectedIndex)].Item1,
            Apps = apps.Text.Replace("\r\n", "\n").Replace('\r', '\n').Trim(),
            Priority = double.IsNaN(priority.Value) ? 0 : (int)priority.Value,
        };
        void CheckConflicts()
        {
            var n = _conflicts(Build());
            warning.Message = $"另有 {n} 條規則使用相同觸發；請確認範圍與優先序。";
            warning.IsOpen = n > 0;
        }
        trigger.TextChanged += (_, _) => CheckConflicts();
        CheckConflicts();

        var form = new StackPanel { Spacing = 12, MinWidth = 460 };
        form.Children.Add(name);
        form.Children.Add(enabled);
        form.Children.Add(new StackPanel { Spacing = 4, Children = { new TextBlock { Text = "觸發按鍵" }, triggerRow, triggerHelp } });
        form.Children.Add(warning);
        form.Children.Add(action);
        form.Children.Add(value);
        form.Children.Add(group);
        form.Children.Add(scope);
        form.Children.Add(apps);
        form.Children.Add(priority);
        form.Children.Add(error);

        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = r.BuiltinId != null ? "自訂內建行為" : _existing ? "編輯自訂項目" : "新增自訂項目",
            Content = new ScrollViewer { Content = form, Padding = new Thickness(0, 0, 16, 0) },
            PrimaryButtonText = "完成",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary,
        };
        if (_canRestore) dialog.SecondaryButtonText = "恢復預設";

        // Raw key recording: only while this dialog has focus and the user pressed 錄製. No global hook.
        record.Checked += (_, _) => { _recording = true; record.Content = "請按下組合鍵…"; trigger.Focus(FocusState.Programmatic); };
        record.Unchecked += (_, _) => { _recording = false; record.Content = "錄製"; };
        dialog.PreviewKeyDown += (_, e) =>
        {
            if (!_recording) return;
            e.Handled = true;
            var key = KeyName(e.Key, e.OriginalKey);
            if (key == null) return; // modifier alone: wait for the main key
            var parts = ModifiersDown();
            parts.Add(key);
            trigger.Text = string.Join("+", parts);
            record.IsChecked = false;
        };

        dialog.PrimaryButtonClick += (_, args) =>
        {
            var built = Build();
            if (built.Name.Length == 0 || built.Trigger.Length == 0 || built.Value.Length == 0 || (built.Scope != Scope.Global && built.Apps.Length == 0))
            {
                error.Title = "請填完名稱、觸發鍵、動作及指定程式。";
                error.IsOpen = true;
                args.Cancel = true;
                return;
            }
            Rule = built;
        };

        return await dialog.ShowAsync() switch
        {
            ContentDialogResult.Primary => Result.Save,
            ContentDialogResult.Secondary => Result.Restore,
            _ => Result.Cancel,
        };
    }

    [LibraryImport("user32.dll")]
    private static partial short GetAsyncKeyState(int vKey);

    private static List<string> ModifiersDown()
    {
        (int Vk, string Name)[] mods = [(0xA2, "LCtrl"), (0xA3, "RCtrl"), (0xA4, "LAlt"), (0xA5, "RAlt"), (0x5B, "LWin"), (0x5C, "RWin")];
        // Read-only physical key state, only while the user records inside our UI.
        var list = mods.Where(m => GetAsyncKeyState(m.Vk) < 0).Select(m => m.Name).ToList();
        if (GetAsyncKeyState(0xA0) < 0 || GetAsyncKeyState(0xA1) < 0) list.Add("Shift");
        return list;
    }

    private static string? KeyName(VirtualKey key, VirtualKey original)
    {
        var k = (int)key;
        if (k is >= 0x41 and <= 0x5A or >= 0x30 and <= 0x39) return ((char)k).ToString();
        if (k is >= 0x70 and <= 0x87) return $"F{k - 0x6F}";
        if (k is >= 0x60 and <= 0x69) return $"Num{k - 0x60}";
        return k switch
        {
            0x10 or 0x11 or 0x12 or 0x5B or 0x5C or >= 0xA0 and <= 0xA5 => null,
            0x14 => "CapsLock",
            0x09 => "Tab",
            0x0D => "Enter",
            0x08 => "Backspace",
            0x2E => "Delete",
            0x2D => "Insert",
            0x20 => "Space",
            0x1B => "Esc",
            0x25 => "Left",
            0x26 => "Up",
            0x27 => "Right",
            0x28 => "Down",
            0x24 => "Home",
            0x23 => "End",
            0x21 => "PageUp",
            0x22 => "PageDown",
            0xDB => "[",
            0xDD => "]",
            0xBA => ";",
            0xDE => "'",
            0xBC => ",",
            0xBE => ".",
            0xBF => "/",
            0xDC => "\\",
            0xBD => "-",
            0xBB => "=",
            0xC0 => "`",
            _ => original.ToString(),
        };
    }
}
