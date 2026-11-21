# MacKeys

Windows 上使用 macOS 快捷鍵習慣的 AHK v2 小工具，提供設定視窗、程式偏好與自訂規則。

## 使用

發布包只包含 `MacKeysSetup.exe`。開啟它進入設定；它不會自行啟用改鍵。不需要另外安裝 AutoHotkey 或 .NET。

在設定視窗使用啟用／停用按鈕控制改鍵。儲存並套用會更新已啟用的改鍵，但不會從停止狀態啟動。關閉設定視窗不會停止改鍵；要停止時，請在改鍵程序的系統匣選單選擇停用改鍵。

設定視窗底部的「加入開機啟動」會安裝背景啟動項目，不會切換或重新啟動目前程式。開機啟動只有在明確按下按鈕後才會設定。

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
