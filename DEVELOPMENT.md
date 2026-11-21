# 開發指南

本專案只維護 AHK v2 版，開發與打包環境為 Windows x64。

## 目錄

```text
ahk/                     應用程式原始碼
  lib/                   JSON 函式庫及授權
  build/                 編譯暫存（Git 忽略）
DEVELOPMENT.md           開發指南
RELEASE.txt              發布包使用說明的來源
THIRD-PARTY.txt          第三方來源與授權資訊
scripts/                 工具下載與打包腳本（PowerShell）
tests/                   核心與整合測試（AHK）
.tools/                  下載的建置工具（Git 忽略）
dist/                    發布產物（Git 忽略）
```

- `ahk/MacKeymap.ahk`：入口與改鍵程序管理。
- `ahk/Settings.ahk`：設定視窗、EXE 選擇器及執行中程式選取器。
- `ahk/Engine.ahk`：內建規則、解析、設定讀寫與驗證。
- `ahk/Worker.ahk`：背景改鍵程序。
- 發布包只包含 `MacKeysSetup.exe`，用於設定；背景改鍵由使用者在設定中手動啟用。
- `RELEASE.txt`：打包時複製為發布包的 `README.txt`。
- `THIRD-PARTY.txt`：打包時複製至發布包的 `licenses/`。

## 下載工具與預覽

以下指令均從專案根目錄執行。下載腳本固定 AutoHotkey 與 Ahk2Exe 版本，
驗證 ZIP 的 SHA-256，下載至 `.tools/`；已有工具會重複使用。
首次下載需要網路。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
$tools = & ./scripts/Download-Tools.ps1
& $tools.AutoHotkey ./ahk/MacKeymap.ahk
```

開啟設定視窗時不會自動啟用改鍵。

## 測試

```powershell
Set-ExecutionPolicy -Scope Process Bypass
$tools = & ./scripts/Download-Tools.ps1
& $tools.AutoHotkey ./tests/Tests.ahk
```

`tests/IntegrationTests.ahk` 測試程序管理，必須以 `--data-dir` 指定
`$env:TEMP` 下名稱以 `mackeymap-test-` 開頭的獨立資料夾，勿使用日常設定資料夾。

## 打包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/Package.ps1
```

打包腳本會自動下載缺少的工具。產物為 `dist/MacKeys/` 與 `dist/MacKeys.zip`：

```text
MacKeys/
  MacKeysSetup.exe       設定視窗（唯一發布執行檔）
  README.txt             使用說明
  licenses/              第三方授權與來源資訊
  source/                AHK 原始碼，不含 PowerShell 建置腳本或測試
```

`dist/`、`ahk/build/` 和 `.tools/` 可重新產生，不納入 Git。

核心規則與程序管理已有自動測試；真實程式與鍵盤行為仍需實測。

## GitHub Release

提交並推送包含 `.github/workflows/release.yml` 的版本後，推送 `v` 開頭的 tag：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 會在 Windows 執行核心測試、打包，然後建立同名 Release，
附上 `MacKeys.zip`。同一 tag 的工作流程重跑時會更新 ZIP。
使用內建的 `GITHUB_TOKEN`，不需要另外設定 token secret。
GUI 整合測試仍在本機執行。

[回專案說明](README.md)
