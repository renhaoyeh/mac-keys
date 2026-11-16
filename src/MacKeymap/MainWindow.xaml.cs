using MacKeymap.Core;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.Graphics;

namespace MacKeymap;

public sealed partial class MainWindow : Window
{
    private Config _config = new();
    private string _savedJson;
    private readonly string _path = Storage.DefaultPath;
    private string? _loadError;

    /// <summary>Navigation stack within the current top-level page, e.g. ["advanced", "builtin"].</summary>
    private readonly List<(string Key, string Title)> _crumbs = [];
    private string _builtinQuery = "";
    private string _previewApp = "notepad.exe";
    private bool _closeConfirmed;

    public MainWindow()
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        SystemBackdrop = new MicaBackdrop();
        AppWindow.Resize(new SizeInt32(1180, 820));
        AppWindow.Closing += OnClosing;

        if (File.Exists(_path))
        {
            try { _config = Storage.Load(_path); }
            catch (Exception e) { _loadError = $"無法載入設定（原檔未變更）：{e.Message}"; _config = new(); }
        }
        // First launch never writes; the user saves explicitly.
        // After a load failure, saving is offered so the user can replace the broken file deliberately.
        _savedJson = _loadError == null ? Storage.Serialize(_config) : "";

        Nav.SelectedItem = Nav.MenuItems[0];
    }

    private Profile P => _config.ActiveProfile;

    // ---------- navigation ----------
    private void Nav_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item)
        {
            _crumbs.Clear();
            _crumbs.Add(((string)item.Tag, (string)item.Content));
            Render(resetScroll: true);
        }
    }

    private void Go(string top)
    {
        Nav.SelectedItem = Nav.MenuItems.OfType<NavigationViewItem>().First(i => (string)i.Tag == top);
    }

    private void Push(string key, string title)
    {
        _crumbs.Add((key, title));
        Render(resetScroll: true);
    }

    private void Breadcrumb_ItemClicked(BreadcrumbBar sender, BreadcrumbBarItemClickedEventArgs args)
    {
        _crumbs.RemoveRange(args.Index + 1, _crumbs.Count - args.Index - 1);
        Render(resetScroll: true);
    }

    private void SearchBox_QuerySubmitted(AutoSuggestBox sender, AutoSuggestBoxQuerySubmittedEventArgs args)
    {
        _builtinQuery = args.QueryText.Trim();
        Go("advanced");
        Push("builtin", "Profile 內建行為");
    }

    private void Render(bool resetScroll = false)
    {
        Breadcrumb.ItemsSource = _crumbs.Select(c => c.Title).ToList();
        PageHost.Children.Clear();
        if (_loadError != null)
            PageHost.Children.Add(Ui.Info("載入失敗", _loadError, InfoBarSeverity.Error));
        var key = _crumbs.Count > 0 ? _crumbs[^1].Key : "overview";
        switch (key)
        {
            case "overview": BuildOverview(); break;
            case "prefs": BuildPrefs(); break;
            case "advanced": BuildAdvanced(); break;
            case "builtin": BuildBuiltin(); break;
            case "preview": BuildPreview(); break;
            case "exclusions": BuildExclusions(); break;
            case "input": BuildInput(); break;
            case "apps": BuildApps(); break;
            case "profiles": BuildProfiles(); break;
            case "general": BuildGeneral(); break;
        }
        if (resetScroll) PageScroll.ChangeView(null, 0, null, true);
        UpdateDirty();
    }

    private void Add(UIElement e) => PageHost.Children.Add(e);

    // ---------- state ----------
    private bool IsDirty => Storage.Serialize(_config) != _savedJson;

    /// <summary>Call after a model change. Rebuilds the page unless the change came from a text field.</summary>
    private void Changed(bool rerender = true)
    {
        if (rerender) Render(); else UpdateDirty();
    }

    private void UpdateDirty()
    {
        var dirty = IsDirty;
        SaveButton.IsEnabled = dirty;
        DirtyText.Visibility = dirty ? Visibility.Visible : Visibility.Collapsed;
    }

    private async void Save_Click(object sender, RoutedEventArgs e) => await SaveAsync();

    private async Task<bool> SaveAsync()
    {
        try
        {
            Storage.Save(_path, _config);
            _savedJson = Storage.Serialize(_config);
            _loadError = null;
            Render();
            return true;
        }
        catch (Exception ex)
        {
            await Ui.Alert(Content.XamlRoot, "無法儲存", ex.Message);
            return false;
        }
    }

    private async void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_closeConfirmed || !IsDirty) return;
        args.Cancel = true;
        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "要儲存變更嗎？",
            Content = "設定有尚未儲存的變更。",
            PrimaryButtonText = "儲存",
            SecondaryButtonText = "不要儲存",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary,
        };
        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.None) return;
        if (result == ContentDialogResult.Primary && !await SaveAsync()) return;
        _closeConfirmed = true;
        Close();
    }

    internal nint Hwnd => WinRT.Interop.WindowNative.GetWindowHandle(this);
}
