#Requires AutoHotkey v2.0
if A_Args.Length != 2 || A_Args[1] != '--data-dir' || !InStr(A_Args[2], A_Temp '\mackeymap-test-')
    ExitApp 2
#Include %A_ScriptDir%\..\ahk
#Include MacKeymap.ahk

try {
    AssertUI(Persistent(), 'controller stays resident without a visible window')
    AssertUI(RoleControls.Length = 6 && ProfileList.Value = 1, 'settings controls loaded')
    HideSettings()
    AssertUI(!DllCall('IsWindowVisible', 'Ptr', SettingsWindow.Hwnd), 'settings hidden')
    AssertUI(!A_IconHidden, 'controller tray icon remains enabled')
    ShowSettings()
    AssertUI(DllCall('IsWindowVisible', 'Ptr', SettingsWindow.Hwnd), 'settings reopened')
    Config := DefaultConfig(), Config['active'] := 1, Config['paused'] := JSON.false
    r := NewRule('RAlt+F12', 'AHK 測試成功'), r['builtin_id'] := JSON.null, r['action'] := 'Text'
    Config['profiles'][2]['overrides'].Push(r)
    LoadProfile()
    CaptureProfile()
    ApplyConfig()
    AssertUI(KnownWorker() > 0, 'worker started and verified')
    AssertUI(!Flag(JSON.parse(FileRead(ConfigPath), true)['paused']), 'saved enabled config')
    pid := KnownWorker()
    ApplyConfig()
    AssertUI(!ProcessExist(pid) && KnownWorker() > 0, 'old worker replaced')
    bad := NewRule('Hyper+C', 'LCtrl+C'), bad['builtin_id'] := JSON.null
    Config['profiles'][2]['overrides'].Push(bad)
    rejected := false, pid := KnownWorker(), before := FileRead(ConfigPath)
    try ApplyConfig()
    catch
        rejected := true
    AssertUI(rejected && KnownWorker() = pid && FileRead(ConfigPath) = before, 'failed apply preserves worker and config')
    Config['profiles'][2]['overrides'].Pop()
    SetMappingPaused(true)
    AssertUI(!KnownWorker() && Flag(JSON.parse(FileRead(ConfigPath), true)['paused']), 'pause persisted and worker stopped')
    AssertUI(MappingButton.Text = '啟用改鍵', 'button offers enable while paused')
    AssertUI(!(DllCall('GetMenuState', 'Ptr', A_TrayMenu.Handle, 'UInt', 0, 'UInt', 0x400, 'UInt') & 8), 'first tray item unchecked while paused')
    SetMappingPaused(false)
    AssertUI(KnownWorker() > 0 && !Flag(JSON.parse(FileRead(ConfigPath), true)['paused']), 'tray resume persisted and worker started')
    AssertUI(MappingButton.Text = '停用改鍵', 'button offers disable while enabled')
    AssertUI(DllCall('GetMenuState', 'Ptr', A_TrayMenu.Handle, 'UInt', 0, 'UInt', 0x400, 'UInt') & 8, 'first tray item checked while enabled')
    SetMappingPaused(true)
    StatusText.Text := '測試完成'
    FileAppend 'PASS: GUI load, save/apply, worker replacement, failure recovery, tray pause/resume`n', '*'
    ExitApp 0
} catch as e {
    FileAppend 'FAIL: ' e.Message '`n' e.Stack '`n', '**'
    ExitApp 1
}
AssertUI(condition, message) {
    if !condition
        throw Error(message)
}
