#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Engine.ahk
#Include Settings.ahk

; Keep the tray controller alive when its only GUI is hidden.
Persistent

AppDir := A_IsCompiled ? A_ScriptDir : RegExReplace(A_LineFile, '\\[^\\]+$')
DataDir := A_AppData '\MacKeymap-AHK'
if A_Args.Length >= 2 && A_Args[1] = '--data-dir'
    DataDir := A_Args[2]
DirCreate DataDir
ConfigPath := DataDir '\config.json'
SnapshotPath := DataDir '\active.json'
PidPath := DataDir '\worker.pid'
WorkerExe := A_IsCompiled ? DataDir '\worker-' FileGetTime(A_ScriptFullPath, 'M') '.exe' : A_AhkPath
if A_IsCompiled && !FileExist(WorkerExe)
    FileInstall 'build\Worker.exe', WorkerExe
Config := DefaultConfig()
try {
    if FileExist(ConfigPath)
        Config := JSON.parse(FileRead(ConfigPath, 'UTF-8'), true)
    else if FileExist(A_AppData '\MacKeymap\config\config.json') {
        Config := JSON.parse(FileRead(A_AppData '\MacKeymap\config\config.json', 'UTF-8'), true)
        ; Import is a copy; trying this version never overwrites the original config.
        Config['paused'] := JSON.true
    }
    ValidateConfig(Config)
} catch as e {
    MsgBox '無法讀取設定，原檔未修改。`n`n' e.Message, 'MacKeys', 'Iconx'
    ExitApp 1
}
if A_Args.Length && A_Args[1] = '--preview'
    Config['paused'] := JSON.true
SavedJson := JSON.stringify(Config)
A_IconTip := 'MacKeys：已暫停改鍵'
A_TrayMenu.Delete()
A_TrayMenu.Add('啟用改鍵', (*) => SetMappingPaused(!Flag(Config['paused'])))
A_TrayMenu.Add('開啟設定', (*) => ShowSettings())
A_TrayMenu.Add()
A_TrayMenu.Add('結束程式', (*) => Quit())
A_TrayMenu.Default := '開啟設定'
OnExit((*) => StopWorker())
ShowSettings()
if !Flag(Config['paused']) {
    try ApplyConfig(false)
    catch as e
        MsgBox e.Message, '無法恢復改鍵', 'Iconx'
}

KnownWorker() {
    global PidPath
    if !FileExist(PidPath)
        return 0
    pid := Trim(FileRead(PidPath))
    if !RegExMatch(pid, '^\d+$') || !ProcessExist(pid)
        return 0
    ; Verify executable AND command line before stopping a saved PID.
    for process in ComObjGet('winmgmts:').ExecQuery('SELECT ExecutablePath, CommandLine FROM Win32_Process WHERE ProcessId=' pid)
        if StrLower(process.ExecutablePath) = StrLower(WorkerExe) && (A_IsCompiled || InStr(process.CommandLine, '"' AppDir '\Worker.ahk"')) && InStr(process.CommandLine, '"' SnapshotPath '"')
            return pid
    return 0
}

StopWorker() {
    if pid := KnownWorker() {
        ProcessClose pid
        ProcessWaitClose pid, 3
    }
}

OriginalIsRunning() {
    file := A_AppData '\MacKeymap\mapping.pid'
    if !FileExist(file)
        return false
    pid := Trim(FileRead(file))
    if !RegExMatch(pid, '^\d+$') || !ProcessExist(pid)
        return false
    for process in ComObjGet('winmgmts:').ExecQuery('SELECT CommandLine FROM Win32_Process WHERE ProcessId=' pid)
        if InStr(process.CommandLine, A_AppData '\MacKeymap\mapping.ahk')
            return true
    return false
}

ApplyConfig(save := true) {
    global Config, SavedJson
    ValidateConfig(Config)
    BuildContexts(Config['profiles'][Config['active'] + 1])
    if !Flag(Config['paused']) && OriginalIsRunning()
        throw Error('舊版仍在執行改鍵，請先停用舊版，避免按鍵衝突。')
    if Flag(Config['paused']) {
        if save
            WriteAtomic(ConfigPath, JSON.stringify(Config, 8))
        StopWorker()
    } else {
        previous := FileExist(SnapshotPath) ? FileRead(SnapshotPath, 'UTF-8') : ''
        WriteAtomic(SnapshotPath, JSON.stringify(Config, 8))
        ready := DataDir '\ready-' A_TickCount
        pid := 0
        try {
            command := '"' WorkerExe '" ' (A_IsCompiled ? '' : '/ErrorStdOut "' AppDir '\Worker.ahk" ') '"' SnapshotPath '" "' ready '"'
            Run command, AppDir, , &pid
            start := A_TickCount
            while !FileExist(ready) {
                if FileExist(ready '.error')
                    throw Error(FileRead(ready '.error', 'UTF-8'))
                if !ProcessExist(pid) || A_TickCount - start > 5000
                    throw Error('改鍵程序未能啟動，舊映射繼續使用。')
                Sleep 25
            }
            if save
                WriteAtomic(ConfigPath, JSON.stringify(Config, 8))
            StopWorker()
            WriteAtomic(PidPath, pid)
            DetectHiddenWindows true
            PostMessage 0x8001, 0, 0, , 'ahk_pid ' pid
        } catch as e {
            if pid && ProcessExist(pid)
                ProcessClose pid
            if previous != ''
                WriteAtomic(SnapshotPath, previous)
            throw e
        } finally {
            for file in [ready, ready '.error']
                if FileExist(file)
                    FileDelete file
        }
    }
    SavedJson := JSON.stringify(Config)
    StatusText.Text := Flag(Config['paused']) ? '已暫停改鍵' : '改鍵已啟用'
    MappingButton.Text := Flag(Config['paused']) ? '啟用改鍵' : '停用改鍵'
    A_IconTip := 'MacKeys：' StatusText.Text
    if Flag(Config['paused'])
        A_TrayMenu.Uncheck('啟用改鍵')
    else
        A_TrayMenu.Check('啟用改鍵')
}

SetMappingPaused(paused) {
    global Config
    old := Config['paused']
    Config['paused'] := paused ? JSON.true : JSON.false
    try {
        ApplyConfig()
    } catch as e {
        Config['paused'] := old
        MsgBox e.Message, '無法切換改鍵狀態', 'Iconx'
    }
}

Quit() {
    if CanClose()
        ExitApp
}

