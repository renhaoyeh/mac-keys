#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force
#Include Engine.ahk
#Include Settings.ahk

AppDir := A_IsCompiled ? A_ScriptDir : RegExReplace(A_LineFile, '\\[^\\]+$')
DataDir := A_AppData '\MacKeymap-AHK'
RunnerMode := A_IsCompiled && (StrLower(A_ScriptName) = 'mackeysrun.exe' || Normalize(A_ScriptFullPath) = Normalize(A_Startup '\MacKeys.exe'))
if A_Args.Length >= 2 && A_Args[1] = '--data-dir'
    DataDir := A_Args[2]
DirCreate DataDir
ConfigPath := DataDir '\config.json'
SnapshotPath := DataDir '\active.json'
PidPath := DataDir '\worker.pid'
WorkerExe := A_IsCompiled ? DataDir '\worker-' FileGetTime(A_ScriptFullPath, 'M') '.exe' : A_AhkPath
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
if !RunnerMode
    Config['paused'] := KnownWorker() ? JSON.false : JSON.true
SavedJson := JSON.stringify(Config)
if RunnerMode {
    try ApplyConfig('launch')
    catch as e {
        MsgBox e.Message, '無法啟用改鍵', 'Iconx'
        ExitApp 1
    }
    ExitApp
} else {
    ShowSettings()
}

KnownWorker() {
    global PidPath
    if !FileExist(PidPath)
        return 0
    pid := Trim(FileRead(PidPath))
    if !RegExMatch(pid, '^\d+$') || !ProcessExist(pid)
        return 0
    ; Verify executable AND command line before stopping a saved PID.
    for process in ComObjGet('winmgmts:').ExecQuery('SELECT ExecutablePath, CommandLine FROM Win32_Process WHERE ProcessId=' pid) {
        if !InStr(process.CommandLine, '"' SnapshotPath '"')
            continue
        path := Normalize(process.ExecutablePath)
        if A_IsCompiled {
            SplitPath path, &name, &directory
            if directory = Normalize(DataDir) && RegExMatch(name, '^worker-\d{14}\.exe$')
                return Integer(pid)
        } else if path = Normalize(A_AhkPath) && InStr(process.CommandLine, '"' AppDir '\Worker.ahk"') {
            return Integer(pid)
        }
    }
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

ApplyConfig(action := 'save') {
    previousCritical := A_IsCritical
    Critical true
    try {
        lock := AcquireApplyLock()
        ApplyConfigLocked(action)
    } finally {
        if IsSet(lock)
            lock.Close()
        Critical previousCritical
    }
}

AcquireApplyLock() {
    global DataDir
    lockPath := DataDir '\apply.lock'
    started := A_TickCount
    loop {
        try return FileOpen(lockPath, 'a-rwd')
        catch as e {
            if !(e is OSError) || e.Number != 32 || A_TickCount - started >= 10000
                throw e
            Sleep 25
        }
    }
}

ApplyConfigLocked(action) {
    global Config, SavedJson
    workerPid := KnownWorker()
    if action = 'launch' && workerPid
        return
    Config['paused'] := action = 'stop' || (action = 'save' && !workerPid) ? JSON.true : JSON.false
    ValidateConfig(Config)
    BuildContexts(Config['profiles'][Config['active'] + 1])
    if !Flag(Config['paused']) && OriginalIsRunning()
        throw Error('舊版仍在執行改鍵，請先停用舊版，避免按鍵衝突。')
    if Flag(Config['paused']) {
        WriteAtomic(ConfigPath, JSON.stringify(Config, 8))
        StopWorker()
    } else {
        if A_IsCompiled && !FileExist(WorkerExe)
            FileInstall 'build\Worker.exe', WorkerExe
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
        if A_IsCompiled
            PruneWorkerBinaries(WorkerExe)
    }
    SavedJson := JSON.stringify(Config)
    UpdateMappingStatus()
}

PruneWorkerBinaries(activePath) {
    global DataDir
    try {
        dataDir := Normalize(DataDir)
        ; Avoid traversing a redirected data directory; generated workers belong beside the config.
        if GetFileAttributes(DataDir) & 0x400
            return
        activePath := Normalize(activePath)
        Loop Files DataDir '\worker-*.exe', 'F' {
            path := A_LoopFileFullPath
            SplitPath path, &name, &directory
            if Normalize(directory) != dataDir || !RegExMatch(name, '^worker-\d{14}\.exe$') || Normalize(path) = activePath
                continue
            ; FILE_ATTRIBUTE_REPARSE_POINT; do not follow or remove links/reparse points.
            if GetFileAttributes(path) & 0x400
                continue
            try FileDelete path
            catch as e {
                ; Cleanup is best-effort: locked or otherwise unavailable old workers are retained.
            }
        }
    } catch as e {
        ; Cleanup must never turn a successful worker start into a failed mapping.
    }
}

GetFileAttributes(path) {
    return DllCall('GetFileAttributesW', 'WStr', path, 'UInt')
}

UpdateMappingStatus() {
    active := KnownWorker() > 0
    if IsSet(StatusText)
        StatusText.Text := active ? '改鍵已啟用' : '已暫停改鍵'
    if IsSet(MappingButton)
        MappingButton.Text := active ? '停用改鍵' : '啟用改鍵'
}

SetMappingPaused(paused) {
    global Config
    old := Config['paused']
    try {
        ApplyConfig(paused ? 'stop' : 'start')
    } catch as e {
        Config['paused'] := old
        MsgBox e.Message, '無法切換改鍵狀態', 'Iconx'
    }
}

InstallStartupRunner(*) {
    try InstallStartupCopy(A_ScriptFullPath, A_Startup)
    catch as e {
        MsgBox '無法安裝開機背景啟動。' '`n' e.Message, 'MacKeys', 'Iconx'
        return
    }
    MsgBox '已加入開機啟動；登入時會在背景啟用改鍵。', 'MacKeys'
}

; targetDir is injectable so verification never writes to the real Startup folder.
InstallStartupCopy(source, targetDir) {
    if !DirExist(targetDir)
        DirCreate targetDir
    target := targetDir '\MacKeys.exe'
    if Normalize(source) = Normalize(target)
        return target
    if FileExist(target) {
        if FilesIdentical(source, target)
            return target
    }
    staging := targetDir '\.MacKeys-' DllCall('GetCurrentProcessId', 'UInt') '-' A_TickCount '.tmp'
    try {
        FileCopy source, staging, true
        FileMove staging, target, true
    } catch as e {
        if FileExist(staging) {
            try FileDelete staging
            catch as cleanupError {
                ; Keep the actionable update error below even if staging cleanup fails.
            }
        }
        throw Error('無法更新 ' target '. 若 MacKeys 正從此位置執行，請先結束該程式後再重試。' '`n' e.Message)
    }
    return target
}

FilesIdentical(first, second) {
    if FileGetSize(first) != FileGetSize(second)
        return false
    a := FileRead(first, 'RAW'), b := FileRead(second, 'RAW')
    if !(a is Buffer) || !(b is Buffer)
        return false
    return DllCall('msvcrt\memcmp', 'Ptr', a, 'Ptr', b, 'UPtr', a.Size, 'CDecl Int') = 0
}

