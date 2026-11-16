ShowSettings() {
    global SettingsWindow, ProfileList, MappingButton, RoleControls, FeatureControls, RuleList, ExclusionEdit, AppList, StatusText
    if IsSet(SettingsWindow) {
        SettingsWindow.Show()
        return
    }
    g := SettingsWindow := Gui(, 'MacKeys')
    g.SetFont('s10', 'Microsoft JhengHei UI')
    g.AddText('x15 y21 w45 h24', '配置：')
    ProfileList := g.AddDropDownList('x65 y15 w300', ProfileNames())
    ProfileList.OnEvent('Change', SwitchProfile)
    g.AddButton('x380 y15 w100 h32', '複製配置').OnEvent('Click', CopyProfile)
    MappingButton := g.AddButton('x510 y15 w150 h32', Flag(Config['paused']) ? '啟用改鍵' : '停用改鍵')
    MappingButton.OnEvent('Click', (*) => SetMappingPaused(!Flag(Config['paused'])))
    tabs := g.AddTab3('x15 y65 w740 h420', ['基本設定', '規則', '程式與排除'])
    tabs.UseTab(1)
    g.AddText('x35 y105 w695 h24', '指定實體修飾鍵的角色；「保留」代表維持 Windows 原有功能。')
    RoleControls := []
    for i, name in ['左 Ctrl', '右 Ctrl', '左 Alt', '右 Alt', '左 Win', '右 Win'] {
        y := 140 + (i - 1) * 39
        g.AddText('x40 y' y ' w110', name)
        RoleControls.Push(g.AddDropDownList('x160 y' (y - 3) ' w180', ['保留', 'Command', 'Option']))
    }
    FeatureControls := Map()
    for i, item in [['command', 'Command 快捷鍵'], ['option', 'Option 字詞移動／刪除'], ['language', 'CapsLock 切換輸入語言']]
        FeatureControls[item[1]] := g.AddCheckbox('x390 y' (140 + (i - 1) * 40), item[2])
    g.AddText('x390 y280 w300', '預設左 Alt 是 Command、左 Win 是 Option。`nCommand+C / V 對應複製／貼上。`nWindowsTerminal 使用 Ctrl+Shift+C / V。')
    tabs.UseTab(2)
    g.AddText('x35 y105 w695 h24', '自訂規則與內建覆寫；Command、Option 可作為來源修飾鍵。')
    RuleList := g.AddListView('x35 y135 w695 h275 -Multi', ['啟用', '名稱', '來源', '動作', '目標', '範圍'])
    RuleList.OnEvent('DoubleClick', (*) => EditRule())
    g.AddButton('x35 y425 w100 h32', '新增規則').OnEvent('Click', (*) => EditRule(0))
    g.AddButton('x145 y425 w100 h32', '編輯規則').OnEvent('Click', (*) => EditRule())
    g.AddButton('x255 y425 w100 h32', '刪除覆寫').OnEvent('Click', DeleteRule)
    g.AddButton('x365 y425 w165 h32', '查看／覆寫內建規則').OnEvent('Click', ShowBuiltins)
    tabs.UseTab(3)
    g.AddText('x35 y105 w330 h24', '排除改鍵（每行一個 EXE 或完整路徑）：')
    ExclusionEdit := g.AddEdit('x35 y133 w330 h250 Multi WantReturn')
    g.AddButton('x35 y400 w145 h32', '選擇 EXE 加入排除').OnEvent('Click', (*) => AppendExe(ExclusionEdit))
    g.AddText('x390 y105 w335 h24', '程式偏好（Windows／終端機）：')
    AppList := g.AddListView('x390 y133 w335 h250 -Multi', ['程式', '模式'])
    g.AddButton('x390 y400 w100 h32', '選擇 EXE').OnEvent('Click', (*) => AddAppMode(true))
    g.AddButton('x500 y400 w100 h32', '輸入名稱').OnEvent('Click', (*) => AddAppMode())
    g.AddButton('x610 y400 w100 h32', '刪除偏好').OnEvent('Click', DeleteAppMode)
    tabs.UseTab()
    ; Keep the footer outside the tab regardless of the last page's control positions.
    StatusText := g.AddText('x15 y501 w425 h34', '尚未套用；原版設定不會被修改')
    g.AddButton('x455 y499 w150 h36 Default', '儲存並套用').OnEvent('Click', SaveSettings)
    g.AddButton('x615 y499 w140 h36', '隱藏視窗').OnEvent('Click', HideSettings)
    g.OnEvent('Close', HideSettings)
    LoadProfile()
    g.Show('w770 h550')
}

ProfileNames() {
    names := []
    for p in Config['profiles']
        names.Push(p['name'])
    return names
}
CurrentProfile() => Config['profiles'][Config['active'] + 1]

LoadProfile() {
    p := CurrentProfile()
    ProfileList.Choose(Config['active'] + 1)
    for i, ctrl in RoleControls
        ctrl.Choose(p['roles'][i] = 'Command' ? 2 : p['roles'][i] = 'Option' ? 3 : 1)
    for name, ctrl in FeatureControls
        ctrl.Value := Flag(p['features'][name])
    ExclusionEdit.Value := p['exclusions']
    RefreshRules()
    RefreshApps()
}
CaptureProfile() {
    p := CurrentProfile()
    for i, ctrl in RoleControls
        p['roles'][i] := ctrl.Text
    for name, ctrl in FeatureControls
        p['features'][name] := ctrl.Value ? JSON.true : JSON.false
    p['exclusions'] := ExclusionEdit.Value
}
SwitchProfile(*) {
    CaptureProfile()
    Config['active'] := ProfileList.Value - 1
    LoadProfile()
}
CopyProfile(*) {
    CaptureProfile()
    answer := InputBox('新配置名稱：', '複製目前配置', 'w350 h130', CurrentProfile()['name'] ' 副本')
    if answer.Result != 'OK' || !Trim(answer.Value)
        return
    p := JSON.parse(JSON.stringify(CurrentProfile()), true), p['name'] := Trim(answer.Value)
    Config['profiles'].Push(p), Config['active'] := Config['profiles'].Length - 1
    ProfileList.Delete(), ProfileList.Add(ProfileNames())
    LoadProfile()
}
RefreshRules() {
    RuleList.Delete()
    for r in CurrentProfile()['overrides']
        RuleList.Add(, Flag(r['enabled']) ? '✓' : '', r['name'], r['trigger'], r['action'], r['value'], r['scope'])
    for i, width in [45, 125, 135, 80, 165, 75]
        RuleList.ModifyCol(i, width)
}
DeleteRule(*) {
    if row := RuleList.GetNext() {
        CurrentProfile()['overrides'].RemoveAt(row)
        RefreshRules()
    }
}
ShowBuiltins(*) {
    if CurrentProfile()['kind'] != 'MacOs' {
        MsgBox '這個配置沒有內建規則。'
        return
    }
    dlg := Gui('+Owner' SettingsWindow.Hwnd, '內建規則 — 雙擊新增覆寫')
    dlg.SetFont('s10', 'Microsoft JhengHei UI')
    list := dlg.AddListView('w580 h450 -Multi', ['來源', '目標'])
    rules := Catalog()
    for r in rules
        list.Add(, r['trigger'], r['value'])
    list.ModifyCol(1, 270), list.ModifyCol(2, 270)
    list.OnEvent('DoubleClick', SelectBuiltin)
    dlg.Show()
    SelectBuiltin(ctrl, row) {
        if !row
            return
        rule := rules[row], dlg.Destroy()
        EditRule(0, rule)
    }
}
EditRule(index := -1, source := false) {
    if index = -1
        index := RuleList.GetNext()
    rules := CurrentProfile()['overrides']
    r := source ? source.Clone() : index ? rules[index].Clone() : NewRule('LAlt+C', 'LCtrl+C', '', '新規則')
    if !source && !index
        r['builtin_id'] := JSON.null
    dlg := Gui('+Owner' SettingsWindow.Hwnd, '編輯規則')
    dlg.SetFont('s10', 'Microsoft JhengHei UI')
    fields := Map()
    for label, key in Map('名稱', 'name', '來源快捷鍵', 'trigger', '目標／文字／程式', 'value') {
        dlg.AddText('xm w160', label)
        fields[key] := dlg.AddEdit('x+10 w330', r[key])
    }
    dlg.AddText('xm w160', '動作')
    action := dlg.AddDropDownList('x+10 w330', ['Shortcut', 'Language', 'Text', 'Launch'])
    for i, value in ['Shortcut', 'Language', 'Text', 'Launch']
        if value = r['action']
            action.Choose(i)
    dlg.AddText('xm w160', '範圍')
    scope := dlg.AddDropDownList('x+10 w330', ['Global', 'Only', 'Except'])
    scope.Choose(r['scope'] = 'Only' ? 2 : r['scope'] = 'Except' ? 3 : 1)
    dlg.AddText('xm', 'Global：全部；Only：僅指定程式；Except：排除指定程式')
    dlg.AddText('xm', '程式（每行 EXE 名稱或完整路徑）：')
    apps := dlg.AddEdit('xm w500 h90 Multi WantReturn', r['apps'])
    dlg.AddButton('xm w130 h30', '選擇適用 EXE').OnEvent('Click', (*) => AppendExe(apps))
    dlg.AddButton('x+10 w160 h30', '選擇啟動的 EXE').OnEvent('Click', ChooseLaunch)
    dlg.AddText('xm w160', '優先序（數字越大越優先）')
    priority := dlg.AddEdit('x+10 w120', r['priority'])
    enabled := dlg.AddCheckbox('xm', '啟用這條規則'), enabled.Value := Flag(r['enabled'])
    dlg.AddText('xm w500', '快捷鍵例：Command+Shift+Z、RAlt+M；目標例：LCtrl+C。`n動作：Shortcut 快捷鍵、Language 切換語言、Text 輸入文字、Launch 啟動程式。')
    dlg.AddButton('xm w110 Default', '確定').OnEvent('Click', Commit)
    dlg.AddButton('x+10 w110', '取消').OnEvent('Click', (*) => dlg.Destroy())
    dlg.Show()
    ChooseLaunch(*) {
        if path := FileSelect(1, , '選擇要啟動的程式', '程式 (*.exe)') {
            fields['value'].Value := '"' path '"'
            action.Choose(4)
        }
    }
    Commit(*) {
        try {
            for key, ctrl in fields
                r[key] := ctrl.Value
            if !Trim(r['name']) || !IsInteger(priority.Value)
                throw Error('請填寫名稱及整數優先序')
            r['priority'] := Integer(priority.Value), r['action'] := action.Text, r['scope'] := scope.Text
            r['apps'] := apps.Value, r['enabled'] := enabled.Value ? JSON.true : JSON.false
            if r['scope'] != 'Global' && !Trim(r['apps'])
                throw Error('指定範圍時，程式清單不能空白')
            p := JSON.parse(JSON.stringify(CurrentProfile()), true)
            if index
                p['overrides'][index] := r
            else
                p['overrides'].Push(r)
            BuildContexts(p)
            if index
                rules[index] := r
            else
                rules.Push(r)
            RefreshRules(), dlg.Destroy()
        } catch as e
            MsgBox e.Message, '規則無效', 'Iconx'
    }
}
RefreshApps() {
    AppList.Delete()
    for pref in CurrentProfile()['app_modes']
        AppList.Add(, pref['app'], pref['mode'])
    AppList.ModifyCol(1, 210), AppList.ModifyCol(2, 100)
}
AppendExe(control) {
    if path := FileSelect(1, , '選擇程式', '程式 (*.exe)') {
        if !MatchesLines(control.Value, path)
            control.Value := RTrim(control.Value, '`r`n ') (Trim(control.Value) = '' ? '' : '`r`n') path
    }
}
AddAppMode(browse := false) {
    if browse
        app := FileSelect(1, , '選擇程式', '程式 (*.exe)')
    else {
        answer := InputBox('EXE 名稱或完整路徑：', '新增程式偏好', 'w450 h130')
        app := answer.Result = 'OK' ? Trim(answer.Value) : ''
    }
    if !app
        return
    for pref in CurrentProfile()['app_modes']
        if Normalize(pref['app']) = Normalize(app) {
            MsgBox '已有這個程式的偏好；請先刪除再新增。'
            return
        }
    mode := MsgBox('是否使用終端機快捷鍵（Ctrl+Shift+C / V）？`n選「否」代表保留 Windows 原始操作。', '程式模式', 'YesNoCancel')
    if mode = 'Cancel'
        return
    CurrentProfile()['app_modes'].Push(Map('app', app, 'mode', mode = 'Yes' ? 'Terminal' : 'Windows'))
    RefreshApps()
}
DeleteAppMode(*) {
    if row := AppList.GetNext() {
        CurrentProfile()['app_modes'].RemoveAt(row)
        RefreshApps()
    }
}
SaveSettings(*) {
    CaptureProfile()
    try ApplyConfig()
    catch as e
        MsgBox e.Message, '無法套用；請修正後重試', 'Iconx'
}
CanClose() {
    CaptureProfile()
    return JSON.stringify(Config) = SavedJson || MsgBox('有尚未儲存的修改，仍要關閉嗎？', 'MacKeys', 'YesNo') = 'Yes'
}
HideSettings(*) {
    if CanClose()
        SettingsWindow.Hide()
}

