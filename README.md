# MacKeys

Windows 上使用 macOS 快捷鍵習慣的 AHK v2 小工具，提供設定視窗、程式偏好與自訂規則。

## 使用

開啟發布包中的 `MacKeys.exe`，不需要另外安裝 AutoHotkey 或 .NET。
首次啟動預設暫停，可在設定視窗調整規則後啟用改鍵。

關閉設定視窗後仍會保留系統匣圖示；要完全停止程式與改鍵，請使用系統匣的結束選項。
右鍵點選系統匣圖示的「啟用改鍵」可直接開關改鍵，勾選代表已啟用；背景改鍵程序不另外顯示圖示。

目前為 Windows x64 試用版，EXE 尚未簽章，真實程式與鍵盤行為仍需實測。

## 設定

設定檔位於 `%APPDATA%\MacKeymap-AHK\config.json`。
首次啟動可複製舊版的版本 3 設定，不覆寫舊檔，且預設暫停。

## 開發文件

下載工具、目錄結構、預覽、測試與打包方式見 [開發指南](DEVELOPMENT.md)。
發布包的使用說明來源為 [RELEASE.txt](RELEASE.txt)。

## 授權

第三方來源與授權資訊見 [THIRD-PARTY.txt](THIRD-PARTY.txt)。
AutoHotkey 授權原文隨工具下載，打包時附於 `licenses/license.txt`；
JSON 函式庫的 MIT 授權保留在 [JSON-LICENSE](ahk/lib/JSON-LICENSE)。

MacKeys 自有程式碼尚未指定授權；第三方授權不代表本專案的授權。
