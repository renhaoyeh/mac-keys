#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\..\ahk
#Include Engine.ahk

Assert(condition, message) {
    if !condition
        throw Error(message)
}
try {
    c := DefaultConfig()
    ValidateConfig(c)
    Assert(Combo('LAlt+Shift+Left') = '+<!Left', 'modifier order')
    Assert(Combo('LCtrl+Shift+Home', true) = '{LCtrl down}{LShift down}{Home}{LShift up}{LCtrl up}', 'send sequence')
    Assert(Combo('Hyper+C') = '', 'invalid modifier')
    Assert(Combo('RAlt+``') = '>!``', 'backtick')
    Assert(Combo('LAlt+') = '', 'missing key')
    Assert(Combo("LAlt+'") = "<!'", 'apostrophe')
    p := c['profiles'][1]
    maps := BuildContexts(p), actions := maps[1][Chr(1)]
    Assert(actions['<!c'][2] = '{LCtrl down}{c}{LCtrl up}', 'copy')
    Assert(!actions.Has('<!Tab'), 'identity passes through')
    Assert(maps[1]['windowsterminal.exe']['<!c'][2] = '{LCtrl down}{LShift down}{c}{LShift up}{LCtrl up}', 'terminal copy')
    undoRule := CommandRule('Command+Z'), redoRule := CommandRule('Command+Shift+Z')
    Assert(undoRule['builtin_id'] = 'Command+Z' && undoRule['name'] = '復原', 'Command+Z builtin identity and name')
    Assert(redoRule['builtin_id'] = 'Command+Shift+Z' && redoRule['name'] = '重做', 'Command+Shift+Z builtin identity and name')
    Assert(actions[Combo('LAlt+Z')][2] = '{LCtrl down}{z}{LCtrl up}', 'default Command+Z undo')
    Assert(actions[Combo('LAlt+Shift+Z')][2] = '{LCtrl down}{y}{LCtrl up}', 'default Command+Shift+Z redo')
    closeRule := CommandRule('Command+Q')
    Assert(closeRule['builtin_id'] = 'Command+Q' && closeRule['name'] = '關閉視窗', 'Command+Q builtin identity')
    Assert(actions[Combo('LAlt+Q')][2] = '{LAlt down}{F4}{LAlt up}', 'default Command+Q closes window')
    Assert(!actions.Has('^q'), 'no generic Ctrl+Q mapping')
    Assert(actions['!+4'][2] = '{LWin down}{LShift down}{s}{LShift up}{LWin up}', 'Alt+Shift+4 region screenshot')
    legacy := NewRule('Command+Shift+4', 'LCtrl+Insert'), p['overrides'].Push(legacy)
    actions := BuildContexts(p)[1][Chr(1)]
    Assert(actions[Combo('LAlt+Shift+4')][2] = '{LCtrl down}{Insert}{LCtrl up}', 'legacy screenshot override')
    p['overrides'].Pop()
    Assert(BuildContexts(c['profiles'][2])[2].Count = 0, 'Windows profile')
    p['app_modes'].Push(Map('app', 'game.exe', 'mode', 'Windows'))
    p['app_modes'].Push(Map('app', 'C:\Tools\WindowsTerminal.exe', 'mode', 'Windows'))
    maps := BuildContexts(p)
    Assert(maps[1]['game.exe'].Count = 0, 'Windows app mode')
    Assert(maps[1]['c:\tools\windowsterminal.exe'].Count = 0, 'path preference')
    r := NewRule('Command+C', 'LCtrl+Insert'), r['scope'] := 'Only', r['apps'] := 'notepad.exe'
    p['overrides'].Push(r)
    maps := BuildContexts(p)
    Assert(maps[1]['notepad.exe']['<!c'][2] = '{LCtrl down}{Insert}{LCtrl up}', 'scoped builtin override')
    Assert(maps[1][Chr(1)]['<!c'][2] = '{LCtrl down}{c}{LCtrl up}', 'override does not leak')
    text := NewRule('RAlt+M', '引號 " 和反引號 ``'), text['builtin_id'] := JSON.null, text['action'] := 'Text'
    p['overrides'].Push(text)
    maps := BuildContexts(p)
    Assert(maps[1][Chr(1)]['>!m'][2] = text['value'], 'literal text')
    p['exclusions'] := 'notepad.exe'
    Assert(BuildContexts(p)[1]['notepad.exe'].Count = 0, 'exclusions win')
    text['enabled'] := JSON.false
    Assert(!BuildContexts(p)[1][Chr(1)].Has('>!m'), 'disabled rule')
    c := JSON.parse(JSON.stringify(c), true)
    ValidateConfig(c)
    Assert(!Flag(c['profiles'][1]['overrides'][2]['enabled']), 'JSON false roundtrip')
    Assert(NullableText(c['profiles'][1]['overrides'][2]['builtin_id']) = '', 'JSON null roundtrip')
    invalid := JSON.parse(JSON.stringify(c), true), invalid['active'] := 999
    rejected := false
    try ValidateConfig(invalid)
    catch
        rejected := true
    Assert(rejected, 'reject invalid config')
    FileAppend 'PASS: AHK engine checks`n', '*'
    ExitApp 0
} catch as e {
    FileAppend 'FAIL: ' e.Message '`n' e.Stack '`n', '**'
    ExitApp 1
}

