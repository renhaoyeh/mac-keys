#Requires AutoHotkey v2.0
if A_Args.Length != 2 || A_Args[1] != '--data-dir' || !InStr(A_Args[2], A_Temp '\mackeymap-test-')
    ExitApp 2
#Include %A_ScriptDir%\..\ahk
#Include MacKeymap.ahk

fixturePid := 0
startupTestDir := ''
OnExit(CleanupFixture)
try {
    startupTestDir := A_Args[2] '\startup-copy-test'
    DirCreate startupTestDir
    sourceFixture := A_Args[2] '\startup-source.exe'
    FileAppend 'fixture payload', sourceFixture
    copiedFixture := InstallStartupCopy(sourceFixture, startupTestDir)
    AssertUI(copiedFixture = startupTestDir '\MacKeys.exe' && FileRead(copiedFixture) = 'fixture payload', 'startup copy installs into an injected isolated folder')
    AssertUI(InstallStartupCopy(sourceFixture, startupTestDir) = copiedFixture, 'identical startup copy is a no-op')
    FileDelete sourceFixture
    AssertUI(RoleControls.Length = 6 && ProfileList.Value = 1, 'settings controls loaded')
    Run('"' A_AhkPath '" /force "' A_ScriptDir '\PickerFixture.ahk"', , , &fixturePid)
    WinWait('MacKeys picker fixture', , 5)
    AssertUI(DllCall('IsWindow', 'Ptr', WinExist('MacKeys picker fixture'), 'Int'), 'picker fixture window started')
    runningApps := RunningWindowApps(), seenPaths := Map(), foundFixture := false
    for app in runningApps {
        AssertUI(app['title'] != 'MacKeys', 'picker skips its own settings window')
        AssertUI(!seenPaths.Has(Normalize(app['path'])), 'picker deduplicates executable paths')
        seenPaths[Normalize(app['path'])] := true
        if app['title'] = 'MacKeys picker fixture' && Normalize(app['path']) = Normalize(A_AhkPath)
            foundFixture := true
    }
    AssertUI(foundFixture, 'picker discovers another process window title and full executable path')
    ExclusionDraft := 'C:\Tools\blocked.exe`r`nD:\Other\blocked.exe`r`nmanual.exe'
    RefreshExclusions()
    AssertUI(ExclusionList.GetCount() = 3 && ExclusionList.GetText(1, 1) = 'blocked.exe' && ExclusionList.GetText(2, 1) = 'blocked.exe' && ExclusionList.GetText(3, 1) = 'manual.exe', 'exclusion projection shows basenames and preserves duplicates')
    ShowExclusionDetail(ExclusionList, 2)
    AssertUI(ExclusionDetail.Value = 'D:\Other\blocked.exe', 'selection reveals exact stored path for duplicate basename')
    AssertUI(AppendExclusionPath(ExclusionDraft, 'c:/tools/BLOCKED.exe') = ExclusionDraft, 'picker append uses exclusion matching')
    ExclusionDraft := AppendExclusionPath(ExclusionDraft, 'C:\Tools\allowed.exe')
    AssertUI(InStr(ExclusionDraft, 'allowed.exe'), 'picker appends a new full path')
    Config['profiles'][1]['exclusions'] := ExclusionDraft
    CaptureProfile()
    Config['active'] := 1
    LoadProfile()
    AssertUI(ExclusionDraft = Config['profiles'][2]['exclusions'], 'profile switch loads its exclusion draft')
    Config['active'] := 0
    LoadProfile()
    AssertUI(ExclusionDraft = 'C:\Tools\blocked.exe`r`nD:\Other\blocked.exe`r`nmanual.exe`r`nC:\Tools\allowed.exe', 'profile switch restores draft and exact stored values')
    ExclusionDraft := ''
    RefreshExclusions()
    CaptureProfile()
    SavedJson := JSON.stringify(Config)
    AssertUI(DllCall('IsWindowVisible', 'Ptr', SettingsWindow.Hwnd), 'settings remains visible until explicitly closed')
    Config := DefaultConfig(), Config['active'] := 1
    ApplyConfig()
    AssertUI(!KnownWorker() && Flag(JSON.parse(FileRead(ConfigPath), true)['paused']), 'save and apply leave a stopped mapping stopped')
    Config['paused'] := JSON.false
    r := NewRule('RAlt+F12', 'AHK 測試成功'), r['builtin_id'] := JSON.null, r['action'] := 'Text'
    Config['profiles'][2]['overrides'].Push(r)
    LoadProfile()
    CaptureProfile()
    ApplyConfig('start')
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
    SetMappingPaused(false)
    AssertUI(KnownWorker() > 0 && !Flag(JSON.parse(FileRead(ConfigPath), true)['paused']), 'tray resume persisted and worker started')
    AssertUI(MappingButton.Text = '停用改鍵', 'button offers disable while enabled')
    SetMappingPaused(true)
    StatusText.Text := '測試完成'
    FileAppend 'PASS: GUI load, running-app picker discovery, exclusion deduplication, save/apply, worker replacement, failure recovery, tray pause/resume`n', '*'
    ExitApp 0
} catch as e {
    FileAppend 'FAIL: ' e.Message '`n' e.Stack '`n', '**'
    ExitApp 1
}
CleanupFixture(*) {
    global fixturePid
    if fixturePid && ProcessExist(fixturePid)
        ProcessClose(fixturePid)
}
AssertUI(condition, message) {
    if !condition
        throw Error(message)
}
