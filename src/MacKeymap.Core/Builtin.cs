namespace MacKeymap.Core;

/// <summary>Profile policies. These are derived behavior, never a list serialized into user settings.</summary>
public static class Builtin
{
    public static Rule? Command(string trigger)
    {
        if (!trigger.StartsWith("Command+", StringComparison.Ordinal)) return null;
        var suffix = trigger["Command+".Length..];
        var shift = suffix.StartsWith("Shift+", StringComparison.Ordinal);
        var key = shift ? suffix["Shift+".Length..] : suffix;
        if (key.Length == 0 || key.Contains('+')) return null;
        var s = shift ? "Shift+" : "";
        var value = (shift, key) switch
        {
            (true, "Z") => "LCtrl+Y",
            (true, "]") => "LCtrl+Tab",
            (true, "[") => "LCtrl+Shift+Tab",
            (_, "Tab") => $"LAlt+{s}Tab",
            (_, "Left") => $"{s}Home",
            (_, "Right") => $"{s}End",
            (_, "Up") => $"LCtrl+{s}Home",
            (_, "Down") => $"LCtrl+{s}End",
            _ => $"LCtrl+{s}{key}",
        };
        var name = (shift, key) switch
        {
            (false, "C") => "複製",
            (false, "V") => "貼上",
            (false, "X") => "剪下",
            (false, "A") => "全選",
            (false, "Z") => "復原",
            (true, "Z") => "重做",
            (false, "T") => "新分頁",
            (false, "W") => "關閉分頁",
            (false, "S") => "儲存",
            (false, "F") => "搜尋",
            (false, "O") => "開啟",
            (false, "N") => "新增",
            (false, "P") => "列印",
            (true, "]") => "下一分頁",
            (true, "[") => "上一分頁",
            (false, "Left") => "行首",
            (false, "Right") => "行尾",
            (false, "Up") => "文件開頭",
            (false, "Down") => "文件結尾",
            (false, "Tab") => "切換視窗",
            _ => trigger,
        };
        return new Rule { BuiltinId = trigger, Group = FeatureGroup.Command, Name = name, Trigger = trigger, Value = value };
    }

    public static List<Rule> Catalog()
    {
        // Common keys are catalogued for read-only inspection. The forwarding policy above is generic.
        var keys = Enumerable.Range('A', 26).Concat(Enumerable.Range('0', 10)).Select(c => ((char)c).ToString())
            .Concat(["Tab", "Left", "Right", "Up", "Down", "Enter", "Backspace", "Delete", "Space", "[", "]"]);
        var rules = new List<Rule>();
        foreach (var key in keys)
            foreach (var shift in new[] { false, true })
                rules.Add(Command($"Command+{(shift ? "Shift+" : "")}{key}")!);
        (string Name, string Trigger, string Value)[] extra =
        [
            ("前一個字", "Option+Left", "LCtrl+Left"),
            ("下一個字", "Option+Right", "LCtrl+Right"),
            ("選取前一個字", "Option+Shift+Left", "LCtrl+Shift+Left"),
            ("選取下一個字", "Option+Shift+Right", "LCtrl+Shift+Right"),
            ("刪除前一個字", "Option+Backspace", "LCtrl+Backspace"),
            ("刪除下一個字", "Option+Delete", "LCtrl+Delete"),
            ("大小寫鎖定", "Shift+CapsLock", "CapsLock"),
            ("切換輸入語言", "CapsLock", "Win+Space"),
        ];
        foreach (var (name, trigger, value) in extra)
            rules.Add(new Rule
            {
                BuiltinId = trigger,
                Group = trigger.Contains("CapsLock") ? FeatureGroup.Language : FeatureGroup.Option,
                Name = name,
                Trigger = trigger,
                Action = trigger == "CapsLock" ? RuleAction.Language : RuleAction.Shortcut,
                Value = value,
            });
        return rules;
    }

    public static Rule? Find(string id) => Command(id) ?? Catalog().FirstOrDefault(r => r.BuiltinId == id);

    /// <summary>Version 2 serialized these entries; used only to preserve edits/deletions during migration.</summary>
    public static List<Rule> LegacyCatalog()
    {
        string[] names =
        [
            "複製", "貼上", "剪下", "全選", "復原", "重做", "新分頁", "關閉分頁", "下一分頁", "上一分頁",
            "行首", "行尾", "文件開頭", "文件結尾", "切換視窗", "前一個字", "下一個字", "選取前一個字",
            "選取下一個字", "刪除前一個字", "刪除下一個字", "大小寫鎖定", "切換輸入語言",
        ];
        return [.. Catalog().Where(r => names.Contains(r.Name))];
    }
}
