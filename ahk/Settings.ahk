ShowSettings() {
    global SettingsWindow, ProfileList, MappingButton, RoleControls, FeatureControls, RuleList, SpecialRuleList, SpecialEditButton, SpecialHint, ExclusionList, ExclusionDetail, ExclusionDraft, AppList, StatusText
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
    MappingButton.OnEvent('Click', (*) => SetMappingPaused(KnownWorker() > 0))
    tabs := g.AddTab3('x15 y65 w740 h420', ['基本設定', '規則', '程式與排除', '特殊快捷鍵'])
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
    g.AddText('x35 y105 w330 h22', '排除改鍵：')
    ExclusionList := g.AddListView('x35 y130 w330 h145 -Multi NoSortHdr', ['程式名稱'])
    ExclusionList.ModifyCol(1, 310)
    ExclusionList.OnEvent('ItemSelect', ShowExclusionDetail)
    ExclusionDetail := g.AddEdit('x35 y300 w330 h42 Multi ReadOnly -WantReturn')
    g.AddText('x35 y280 w330 h20', '完整路徑／名稱：')
    g.AddButton('x35 y355 w115 h30', '選擇 EXE').OnEvent('Click', (*) => AppendExclusionExe())
    g.AddButton('x160 y355 w130 h30', '執行中程式…').OnEvent('Click', (*) => PickRunningAppExclusions())
    g.AddButton('x35 y393 w125 h30', '編輯清單…').OnEvent('Click', EditExclusionList)
    g.AddText('x390 y105 w335 h24', '程式偏好（Windows／終端機）：')
    AppList := g.AddListView('x390 y133 w335 h250 -Multi', ['程式', '模式'])
    g.AddButton('x390 y400 w100 h32', '選擇 EXE').OnEvent('Click', (*) => AddAppMode(true))
    g.AddButton('x500 y400 w100 h32', '輸入名稱').OnEvent('Click', (*) => AddAppMode())
    g.AddButton('x610 y400 w100 h32', '刪除偏好').OnEvent('Click', DeleteAppMode)
    tabs.UseTab(4)
    SpecialHint := g.AddText('x35 y105 w695 h24')
    SpecialRuleList := g.AddListView('x35 y135 w695 h260 -Multi NoSortHdr', ['功能', '預設觸發鍵', '目標', '內建 ID'])
    SpecialRuleList.OnEvent('DoubleClick', (ctrl, row) => row ? EditSpecialRule() : 0)
    SpecialEditButton := g.AddButton('x35 y410 w125 h32', '編輯選取項目')
    SpecialEditButton.OnEvent('Click', EditSpecialRule)
    SpecialRuleList.ModifyCol(1, 150), SpecialRuleList.ModifyCol(2, 180), SpecialRuleList.ModifyCol(3, 300), SpecialRuleList.ModifyCol(4, 0)
    tabs.UseTab()
    ; Keep the footer outside the tab regardless of the last page's control positions.
    if A_IsCompiled {
        startupButton := g.AddButton('x15 y499 w165 h36', '加入開機啟動')
        startupButton.OnEvent('Click', InstallStartupRunner)
    }
    StatusText := g.AddText('x190 y501 w250 h34', '尚未套用；原版設定不會被修改')
    g.AddButton('x450 y499 w145 h36 Default', '儲存並套用').OnEvent('Click', SaveSettings)
    g.AddButton('x605 y499 w150 h36', '關閉設定').OnEvent('Click', HideSettings)
    g.OnEvent('Close', HideSettings)
    LoadProfile()
    g.Show('w770 h550')
    SetTimer(UpdateMappingStatus, 1000)
}

ProfileNames() {
    names := []
    for p in Config['profiles']
        names.Push(p['name'])
    return names
}
CurrentProfile() => Config['profiles'][Config['active'] + 1]

LoadProfile() {
    global ExclusionDraft
    p := CurrentProfile()
    ProfileList.Choose(Config['active'] + 1)
    for i, ctrl in RoleControls
        ctrl.Choose(p['roles'][i] = 'Command' ? 2 : p['roles'][i] = 'Option' ? 3 : 1)
    for name, ctrl in FeatureControls
        ctrl.Value := Flag(p['features'][name])
    ExclusionDraft := p['exclusions']
    RefreshExclusions()
    RefreshRules()
    RefreshSpecialRules()
    RefreshApps()
}
CaptureProfile() {
    p := CurrentProfile()
    for i, ctrl in RoleControls
        p['roles'][i] := ctrl.Text
    for name, ctrl in FeatureControls
        p['features'][name] := ctrl.Value ? JSON.true : JSON.false
    p['exclusions'] := ExclusionDraft
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
RefreshSpecialRules() {
    global SpecialRuleList, SpecialEditButton, SpecialHint
    SpecialRuleList.Delete()
    isMac := CurrentProfile()['kind'] = 'MacOs'
    SpecialEditButton.Enabled := isMac
    SpecialHint.Text := isMac ? 'Command 依照「基本設定」的按鍵角色，預設為左 Alt。' : 'Windows 原始操作配置不使用內建快捷鍵。'
    if !isMac
        return
    for r in Catalog()
        if IsSpecialBuiltin(r)
            SpecialRuleList.Add(, r['name'], r['trigger'], r['value'], r['builtin_id'])
}
IsSpecialBuiltin(r) => r['builtin_id'] = 'Command+Q' || r['builtin_id'] = 'Command+Shift+4'
    || r['builtin_id'] = 'Command+Z' || r['builtin_id'] = 'Command+Shift+Z'
EditSpecialRule(*) {
    global SpecialRuleList
    if CurrentProfile()['kind'] != 'MacOs'
        return
    if !(row := SpecialRuleList.GetNext())
        return
    id := SpecialRuleList.GetText(row, 4)
    for builtin in Catalog()
        if builtin['builtin_id'] = id {
            ; Reuse an existing global override; app-specific variants remain in the regular rule list.
            bestIndex := 0, best := false
            for index, saved in CurrentProfile()['overrides']
                if NullableText(saved.Get('builtin_id', '')) = id && saved['scope'] = 'Global' && (!best || CompareRules(saved, 1, best, 1) >= 0)
                    bestIndex := index, best := saved
            if bestIndex {
                EditRule(bestIndex)
                return
            }
            EditRule(0, builtin)
            return
        }
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
    list := dlg.AddListView('w580 h450 -Multi NoSortHdr', ['來源', '目標'])
    rules := []
    for rule in Catalog()
        if !IsSpecialBuiltin(rule)
            rules.Push(rule)
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
    dlg.AddText('xm', '每行輸入一個程式檔名或完整路徑：')
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
        control.Value := AppendExclusionPath(control.Value, path)
    }
}

AppendExclusionExe() {
    global ExclusionDraft
    if path := FileSelect(1, , '選擇程式', '程式 (*.exe)') {
        ExclusionDraft := AppendExclusionPath(ExclusionDraft, path)
        RefreshExclusions()
    }
}

RefreshExclusions() {
    global ExclusionList, ExclusionDetail, ExclusionDraft
    ExclusionList.Delete()
    for line in StrSplit(ExclusionDraft, '`n', '`r') {
        value := Trim(line)
        if value {
            SplitPath(value, &baseName)
            ExclusionList.Add(, baseName)
        }
    }
    ExclusionDetail.Value := ''
}

ShowExclusionDetail(ctrl, row, *) {
    global ExclusionDetail, ExclusionDraft
    if !row {
        ExclusionDetail.Value := ''
        return
    }
    index := 0
    for line in StrSplit(ExclusionDraft, '`n', '`r') {
        if Trim(line) && ++index = row {
            ExclusionDetail.Value := Trim(line)
            return
        }
    }
    ExclusionDetail.Value := ''
}

EditExclusionList(*) {
    global SettingsWindow, ExclusionDraft
    dlg := Gui('+Owner' SettingsWindow.Hwnd, '編輯排除清單')
    dlg.SetFont('s10', 'Microsoft JhengHei UI')
    dlg.AddText('xm', '每行輸入一個程式檔名或完整路徑：')
    edit := dlg.AddEdit('xm w430 h220 Multi WantReturn', ExclusionDraft)
    dlg.AddButton('xm w100 h32 Default', '確定').OnEvent('Click', Commit)
    dlg.AddButton('x+10 w100 h32', '取消').OnEvent('Click', CloseEditor)
    dlg.OnEvent('Close', CloseEditor), dlg.OnEvent('Escape', CloseEditor)
    SettingsWindow.Opt('+Disabled')
    dlg.Show()
    Commit(*) {
        ExclusionDraft := edit.Value
        RefreshExclusions()
        CloseEditor()
    }
    CloseEditor(*) {
        dlg.Destroy()
        SettingsWindow.Opt('-Disabled')
    }
}

AppendExclusionPath(value, path) => !path || MatchesLines(value, path) ? value : RTrim(value, '`r`n ') (Trim(value) = '' ? '' : '`r`n') path

PickRunningAppExclusions() {
    global SettingsWindow, ExclusionDraft
    dlg := Gui('+Owner' SettingsWindow.Hwnd, '選擇執行中的程式')
    dlg.SetFont('s10', 'Microsoft JhengHei UI')
    dlg.AddText('xm', '勾選要排除的程式；選取項目可檢視完整路徑。')
    list := dlg.AddListView('xm w620 h240 Checked', ['視窗名稱', '程式名稱', ''])
    list.ModifyCol(1, 340), list.ModifyCol(2, 260), list.ModifyCol(3, 0)
    list.OnEvent('ItemFocus', ShowPath), list.OnEvent('ItemSelect', ShowPath)
    empty := dlg.AddText('xm y+5 w620', '找不到可加入的執行中程式。')
    dlg.AddText('xm y+5 w620 h20', '完整路徑：')
    detail := dlg.AddEdit('xm w620 h42 Multi ReadOnly -WantReturn')
    dlg.AddButton('xm w110 h32', '重新整理').OnEvent('Click', Refresh)
    dlg.AddButton('x+10 w130 h32 Default', '加入排除').OnEvent('Click', AddSelected)
    dlg.AddButton('x+10 w100 h32', '取消').OnEvent('Click', ClosePicker)
    dlg.OnEvent('Close', ClosePicker), dlg.OnEvent('Escape', ClosePicker)
    SettingsWindow.Opt('+Disabled')
    Refresh()
    dlg.Show()
    Refresh(*) {
        list.Delete()
        detail.Value := ''
        for app in RunningWindowApps()
            if !MatchesLines(ExclusionDraft, app['path']) {
                SplitPath(app['path'], &exeName)
                list.Add(, app['title'], exeName, app['path'])
            }
        empty.Visible := list.GetCount() = 0
    }
    ShowPath(ctrl, row, *) {
        detail.Value := row ? ctrl.GetText(row, 3) : ''
    }
    AddSelected(*) {
        value := ExclusionDraft
        row := 0
        while row := list.GetNext(row, 'C') {
            path := list.GetText(row, 3)
            value := AppendExclusionPath(value, path)
        }
        ExclusionDraft := value
        RefreshExclusions()
        ClosePicker()
    }
    ClosePicker(*) {
        dlg.Destroy()
        SettingsWindow.Opt('-Disabled')
    }
}

RunningWindowApps() {
    apps := [], paths := Map(), ownPid := DllCall('GetCurrentProcessId', 'UInt')
    for hwnd in WinGetList() {
        if !DllCall('IsWindowVisible', 'Ptr', hwnd, 'Int')
            continue
        try {
            title := WinGetTitle(hwnd)
            if !Trim(title) || WinGetPID(hwnd) = ownPid
                continue
            path := WinGetProcessPath(hwnd)
            if !path || paths.Has(Normalize(path))
                continue
            paths[Normalize(path)] := true
            apps.Push(Map('title', title, 'path', path))
        } catch {
            ; Windows can disappear, or their process path can be inaccessible, during enumeration.
            continue
        }
    }
    return apps
}
AddAppMode(browse := false) {
    if browse
        app := FileSelect(1, , '選擇程式', '程式 (*.exe)')
    else {
        answer := InputBox('程式檔名或完整路徑：', '新增程式偏好', 'w450 h130')
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
        ExitApp()
}
