#Requires AutoHotkey v2.0
#Include lib\JSON.ahk

Flag(value) => value is ComValue ? ComObjValue(value) != 0 : !!value
NullableText(value) => value is ComValue ? '' : value

DefaultConfig() {
    mac := Map('name', 'macOS 操作習慣', 'kind', 'MacOs', 'roles', ['保留', '保留', 'Command', '保留', 'Option', '保留'],
        'features', Map('command', JSON.true, 'option', JSON.true, 'language', JSON.true),
        'overrides', [], 'exclusions', '', 'app_modes', [Map('app', 'WindowsTerminal.exe', 'mode', 'Terminal')])
    win := JSON.parse(JSON.stringify(mac), true)
    win['name'] := 'Windows 原始操作', win['kind'] := 'Windows', win['app_modes'] := []
    win['roles'] := ['保留', '保留', '保留', '保留', '保留', '保留']
    return Map('version', 3, 'active', 0, 'paused', JSON.true, 'profiles', [mac, win])
}

ValidateConfig(c) {
    if !(c is Map) || c.Get('version', 0) != 3
        throw Error('只支援版本 3 的設定，請先用舊版儲存升級。')
    if !(c['profiles'] is Array) || !c['profiles'].Length || !IsInteger(c['active']) || c['active'] < 0 || c['active'] >= c['profiles'].Length
        throw Error('配置索引無效')
    for p in c['profiles'] {
        if !Trim(p['name']) || p['roles'].Length != 6
            throw Error('配置名稱或修飾鍵設定無效')
        for role in p['roles']
            if role != '保留' && role != 'Command' && role != 'Option'
                throw Error('不支援的修飾鍵角色：' role)
        seen := Map()
        for pref in p['app_modes'] {
            app := Normalize(pref['app'])
            if !app || seen.Has(app) || !InStr('|Inherit|Windows|Terminal|', '|' pref['mode'] '|')
                throw Error('程式偏好無效或重複')
            seen[app] := true
        }
        for r in p['overrides'] {
            if !InStr('|Shortcut|Language|Text|Launch|', '|' r['action'] '|') || !InStr('|Global|Only|Except|', '|' r['scope'] '|')
                throw Error('規則類型無效：' r['name'])
            if !IsNumber(r['priority'])
                throw Error('規則優先序無效')
        }
    }
}

Normalize(s) => StrLower(StrReplace(Trim(s, ' `t`r`n'), '/', '\'))
AppMatches(pattern, app) {
    pattern := Normalize(pattern), app := Normalize(app)
    SplitPath app, &name
    return pattern != '' && pattern = (InStr(pattern, '\') ? app : name)
}
MatchesLines(lines, app) {
    for line in StrSplit(lines, '`n', '`r')
        if AppMatches(line, app)
            return true
    return false
}

NewRule(trigger, value, group := '', name := '') => Map('builtin_id', trigger, 'group', group,
    'name', name = '' ? trigger : name, 'trigger', trigger, 'value', value, 'enabled', JSON.true,
    'action', 'Shortcut', 'scope', 'Global', 'apps', '', 'priority', 0)

CommandRule(trigger) {
    if !RegExMatch(trigger, '^Command\+(Shift\+)?([^+]+)$', &m)
        return false
    shift := m[1], key := m[2]
    if !shift && key = 'Q'
        return NewRule(trigger, 'Alt+F4', 'Command', '關閉視窗')
    switch key {
        case 'Tab': value := 'LAlt+' shift key
        case 'Left': value := shift 'Home'
        case 'Right': value := shift 'End'
        case 'Up': value := 'LCtrl+' shift 'Home'
        case 'Down': value := 'LCtrl+' shift 'End'
        default: value := 'LCtrl+' shift key
    }
    if shift {
        switch key {
            case 'Z': value := 'LCtrl+Y'
            case ']': value := 'LCtrl+Tab'
            case '[': value := 'LCtrl+Shift+Tab'
        }
    }
    name := trigger = 'Command+Z' ? '復原' : trigger = 'Command+Shift+Z' ? '重做' : ''
    return NewRule(trigger, value, 'Command', name)
}

Catalog() {
    rules := [], keys := StrSplit('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
    keys.Push('Tab', 'Left', 'Right', 'Up', 'Down', 'Enter', 'Backspace', 'Delete', 'Space', '[', ']')
    for key in keys {
        rules.Push(CommandRule('Command+' key))
        if key != '4'
            rules.Push(CommandRule('Command+Shift+' key))
    }
    ; Keep the old generated ID so existing Command+Shift+4 overrides still apply.
    screenshot := NewRule('Alt+Shift+4', 'Win+Shift+S', 'Command', '區域螢幕截圖')
    screenshot['builtin_id'] := 'Command+Shift+4'
    rules.Push(screenshot)
    for key in ['Left', 'Right', 'Backspace', 'Delete'] {
        rules.Push(NewRule('Option+' key, 'LCtrl+' key, 'Option'))
        if key = 'Left' || key = 'Right'
            rules.Push(NewRule('Option+Shift+' key, 'LCtrl+Shift+' key, 'Option'))
    }
    rules.Push(NewRule('Shift+CapsLock', 'CapsLock', 'Language', '大小寫鎖定'))
    r := NewRule('CapsLock', 'Win+Space', 'Language', '切換輸入語言'), r['action'] := 'Language'
    rules.Push(r)
    return rules
}

Applies(r, app) => r['scope'] = 'Only' ? MatchesLines(r['apps'], app) : r['scope'] = 'Except' ? !MatchesLines(r['apps'], app) : true
CompareRules(a, ac, b, bc) {
    onlyA := a['scope'] = 'Only', onlyB := b['scope'] = 'Only'
    return onlyA != onlyB ? onlyA - onlyB : a['priority'] != b['priority'] ? a['priority'] - b['priority'] : ac - bc
}

ResolveRules(p, app) {
    if MatchesLines(p['exclusions'], app)
        return []
    mode := 'Inherit'
    for pref in p['app_modes']
        if AppMatches(pref['app'], app) {
            mode := pref['mode']
            if InStr(Normalize(pref['app']), '\')
                break
        }
    if mode = 'Windows'
        return []
    base := p['kind'] = 'MacOs' ? Catalog() : [], ids := Map()
    for r in base
        ids[r['builtin_id']] := true
    for r in p['overrides'] {
        id := NullableText(r.Get('builtin_id', ''))
        if id && !ids.Has(id) && p['kind'] = 'MacOs' && (extra := CommandRule(id))
            base.Push(extra), ids[id] := true
    }
    merged := []
    for b in base {
        if mode = 'Terminal' && (b['trigger'] = 'Command+C' || b['trigger'] = 'Command+V')
            b['value'] := 'LCtrl+Shift+' SubStr(b['trigger'], -1)
        chosen := b, custom := 0
        for r in p['overrides']
            if NullableText(r.Get('builtin_id', '')) = b['builtin_id'] && Applies(r, app) && (!custom || CompareRules(r, 1, chosen, 1) >= 0)
                chosen := r, custom := 1
        merged.Push([chosen, custom])
    }
    for r in p['overrides']
        if !NullableText(r.Get('builtin_id', '')) || !ids.Has(r['builtin_id'])
            merged.Push([r, 1])
    ; Stable insertion sort preserves the original ordering for equally ranked rules.
    ordered := []
    for item in merged {
        i := 1
        while i <= ordered.Length && CompareRules(ordered[i][1], ordered[i][2], item[1], item[2]) >= 0
            i++
        ordered.InsertAt(i, item)
    }
    result := [], seen := Map(), roleKeys := ['LCtrl', 'RCtrl', 'LAlt', 'RAlt', 'LWin', 'RWin']
    for item in ordered {
        r := item[1], group := NullableText(r.Get('group', ''))
        if !Flag(r['enabled']) || (group && !Flag(p['features'][StrLower(group)])) || !Applies(r, app)
            continue
        combos := ['']
        for token in StrSplit(r['trigger'], '+') {
            keys := []
            if token = 'Command' || token = 'Option' {
                for i, role in p['roles']
                    if role = token
                        keys.Push(roleKeys[i])
            } else
                keys.Push(token)
            next := []
            for prefix in combos
                for key in keys
                    next.Push(prefix = '' ? key : prefix '+' key)
            combos := next
        }
        for resolvedTrigger in combos {
            hk := Combo(resolvedTrigger)
            if hk = ''
                throw Error('不支援的來源按鍵：' r['name'] ' (' resolvedTrigger ')')
            canonical := StrLower(hk)
            if !seen.Has(canonical) {
                seen[canonical] := true
                resolved := r.Clone(), resolved['trigger'] := resolvedTrigger
                result.Push(resolved)
            }
        }
    }
    return result
}

Combo(text, send := false) {
    static mods := Map('lctrl', '<^', 'rctrl', '>^', 'ctrl', '^', 'lalt', '<!', 'ralt', '>!', 'alt', '!',
        'lwin', '<#', 'rwin', '>#', 'win', '#', 'lshift', '<+', 'rshift', '>+', 'shift', '+')
    static sends := Map('ctrl', 'LCtrl', 'alt', 'LAlt', 'win', 'LWin', 'shift', 'LShift')
    static names := Map('pageup', 'PgUp', 'pagedown', 'PgDn', 'esc', 'Escape')
    tokens := StrSplit(text, '+', ' `t'), key := tokens.Pop(), prefixes := [], down := '', up := ''
    if key = ''
        return ''
    for token in tokens {
        token := StrLower(token)
        if !mods.Has(token)
            return ''
        if send {
            physical := sends.Get(token, token)
            if !InStr(down, '{' physical ' down}')
                down .= '{' physical ' down}', up := '{' physical ' up}' up
        } else {
            if !InStr('|' Join(prefixes, '|') '|', '|' mods[token] '|')
                prefixes.Push(mods[token])
        }
    }
    if names.Has(StrLower(key))
        key := names[StrLower(key)]
    else if RegExMatch(key, 'i)^Num([0-9])$', &m)
        key := 'Numpad' m[1]
    else if !RegExMatch(key, 'i)^([a-z0-9]|F([1-9]|1[0-9]|2[0-4])|Left|Right|Up|Down|Tab|Enter|Backspace|Delete|Insert|Space|Home|End|Escape|CapsLock)$') && !(StrLen(key) = 1 && InStr("[];',./\-=``", key))
        return ''
    if StrLen(key) = 1
        key := StrLower(key)
    if send
        return down '{' key '}' up
    sorted := Sort(Join(prefixes, '`n'), 'D`n'), prefix := StrReplace(sorted, '`n')
    return prefix key
}

Join(items, separator := '') {
    result := ''
    for i, item in items
        result .= (i = 1 ? '' : separator) item
    return result
}

BuildContexts(p) {
    patterns := Map(Chr(1), true), contexts := Map(), hotkeys := Map()
    for pref in p['app_modes']
        patterns[Normalize(pref['app'])] := true
    lists := [p['exclusions']]
    for r in p['overrides']
        lists.Push(r['apps'])
    for lines in lists
        for line in StrSplit(lines, '`n', '`r')
            if Normalize(line) != ''
                patterns[Normalize(line)] := true
    for pattern in patterns {
        actions := Map(), actions.CaseSense := false
        for r in ResolveRules(p, pattern) {
            hk := Combo(r['trigger']), action := r['action'], value := r['value']
            if action = 'Shortcut' || action = 'Language' {
                if StrLower(hk) = StrLower(Combo(value))
                    continue
                if StrLower(Trim(value)) = 'capslock'
                    action := 'caps'
                else {
                    value := Combo(value, true)
                    if value = ''
                        throw Error('不支援的目標按鍵：' r['name'])
                    action := 'send'
                }
            } else if value = ''
                throw Error('動作內容不能空白：' r['name'])
            actions[hk] := [action, value], hotkeys[hk] := true
        }
        contexts[pattern] := actions
    }
    return [contexts, hotkeys]
}

WriteAtomic(path, content) {
    temp := path '.tmp'
    try {
        file := FileOpen(temp, 'w', 'UTF-8')
        file.Write(content)
        if !DllCall('FlushFileBuffers', 'ptr', file.Handle)
            throw OSError()
        file.Close()
        FileMove temp, path, true
    } finally {
        if IsSet(file)
            file.Close()
        if FileExist(temp)
            FileDelete temp
    }
}

