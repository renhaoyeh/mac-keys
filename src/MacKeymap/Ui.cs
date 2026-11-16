using CommunityToolkit.WinUI.Controls;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace MacKeymap;

/// <summary>Small factory helpers for Windows 11 Settings-style layouts.</summary>
internal static class Ui
{
    public static FontIcon Icon(string glyph) => new() { Glyph = glyph };

    public static TextBlock Section(string text) => new()
    {
        Text = text,
        Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
        Margin = new Thickness(1, 28, 0, 6),
    };

    public static TextBlock Note(string text) => new()
    {
        Text = text,
        TextWrapping = TextWrapping.Wrap,
        Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        Margin = new Thickness(1, 4, 0, 4),
    };

    public static SettingsCard Card(string header, string? description = null, object? content = null, string? glyph = null) => new()
    {
        Header = header,
        Description = description,
        Content = content,
        HeaderIcon = glyph == null ? null : Icon(glyph),
    };

    /// <summary>A card that navigates elsewhere, like the chevron rows in Windows Settings.</summary>
    public static SettingsCard Link(string header, string? description, string? glyph, Action onClick, object? content = null)
    {
        var card = Card(header, description, content, glyph);
        card.IsClickEnabled = true;
        card.Click += (_, _) => onClick();
        return card;
    }

    public static SettingsExpander Expander(string header, string? description, string? glyph, object? content = null) => new()
    {
        Header = header,
        Description = description,
        HeaderIcon = glyph == null ? null : Icon(glyph),
        Content = content,
    };

    public static ToggleSwitch Toggle(bool value, Action<bool> set, bool enabled = true)
    {
        var t = new ToggleSwitch { IsOn = value, IsEnabled = enabled, OnContent = "開啟", OffContent = "關閉" };
        t.Toggled += (_, _) => set(t.IsOn);
        return t;
    }

    public static ComboBox Combo<T>(IEnumerable<(T Value, string Label)> items, T selected, Action<T> set, double width = 200)
    {
        var list = items.ToList();
        var c = new ComboBox { MinWidth = width };
        foreach (var (_, label) in list) c.Items.Add(label);
        c.SelectedIndex = Math.Max(0, list.FindIndex(i => EqualityComparer<T>.Default.Equals(i.Value, selected)));
        c.SelectionChanged += (_, _) => { if (c.SelectedIndex >= 0) set(list[c.SelectedIndex].Value); };
        return c;
    }

    public static Button Button(string text, Action onClick, string? glyph = null, bool accent = false)
    {
        object content = glyph == null
            ? text
            : new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 8,
                Children = { new FontIcon { Glyph = glyph, FontSize = 14 }, new TextBlock { Text = text } },
            };
        var b = new Button { Content = content };
        if (accent) b.Style = (Style)Application.Current.Resources["AccentButtonStyle"];
        b.Click += (_, _) => onClick();
        return b;
    }

    public static StackPanel Row(params UIElement[] children)
    {
        var s = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, VerticalAlignment = VerticalAlignment.Center };
        foreach (var c in children) s.Children.Add(c);
        return s;
    }

    public static InfoBar Info(string title, string message, InfoBarSeverity severity = InfoBarSeverity.Informational) => new()
    {
        Title = title,
        Message = message,
        Severity = severity,
        IsOpen = true,
        IsClosable = false,
        Margin = new Thickness(0, 4, 0, 4),
    };

    public static Border Tag(string text) => new()
    {
        CornerRadius = new CornerRadius(4),
        Padding = new Thickness(6, 1, 6, 2),
        Background = (Brush)Application.Current.Resources["AccentFillColorDefaultBrush"],
        Child = new TextBlock
        {
            Text = text,
            FontSize = 12,
            Foreground = (Brush)Application.Current.Resources["TextOnAccentFillColorPrimaryBrush"],
        },
    };

    public static async Task Alert(XamlRoot root, string title, string message)
    {
        await new ContentDialog { XamlRoot = root, Title = title, Content = message, CloseButtonText = "確定" }.ShowAsync();
    }

    public static async Task<bool> Confirm(XamlRoot root, string title, string message, string primary)
    {
        var d = new ContentDialog
        {
            XamlRoot = root, Title = title, Content = message,
            PrimaryButtonText = primary, CloseButtonText = "取消", DefaultButton = ContentDialogButton.Close,
        };
        return await d.ShowAsync() == ContentDialogResult.Primary;
    }

    public static async Task<string?> Prompt(XamlRoot root, string title, string initial, string primary = "確定")
    {
        var box = new TextBox { Text = initial, MinWidth = 320 };
        var d = new ContentDialog
        {
            XamlRoot = root, Title = title, Content = box,
            PrimaryButtonText = primary, CloseButtonText = "取消", DefaultButton = ContentDialogButton.Primary,
        };
        box.SelectAll();
        return await d.ShowAsync() == ContentDialogResult.Primary && !string.IsNullOrWhiteSpace(box.Text) ? box.Text.Trim() : null;
    }
}
