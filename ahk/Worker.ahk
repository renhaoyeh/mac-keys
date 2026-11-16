#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off
#UseHook
#Include Engine.ahk

; Start suspended: the settings process commits only after registration succeeds.
Suspend true
Persistent
KeyHistory 0
ListLines false
A_MenuMaskKey := 'vkE8'
try {
    cfg := JSON.parse(FileRead(A_Args[1], 'UTF-8'), true)
    ValidateConfig(cfg)
    maps := BuildContexts(cfg['profiles'][cfg['active'] + 1])
    Contexts := maps[1]
    HotIf (hk) => Lookup(hk) is Array
    for hk in maps[2]
        Hotkey hk, Fire
    HotIf
    OnMessage(0x8001, (*) => Suspend(false))
    FileAppend DllCall('GetCurrentProcessId'), A_Args[2], 'UTF-8'
} catch as e {
    FileAppend e.Message, A_Args[2] '.error', 'UTF-8'
    ExitApp 1
}

Lookup(hk) {
    global Contexts
    try path := Normalize(WinGetProcessPath('A'))
    catch
        path := ''
    SplitPath path, &name
    ctx := Contexts.Has(path) ? Contexts[path] : Contexts.Has(name) ? Contexts[name] : Contexts[Chr(1)]
    return ctx.Get(hk, false)
}

Fire(hk) {
    action := Lookup(hk)
    if !(action is Array)
        return
    switch action[1] {
        case 'send': Send action[2]
        case 'Text': SendText action[2]
        case 'Launch':
            try Run action[2]
            catch as e
                TrayTip e.Message, '無法啟動程式'
        case 'caps': SetCapsLockState !GetKeyState('CapsLock', 'T')
    }
}
