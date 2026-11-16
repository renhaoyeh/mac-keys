# Mac Keymap

Windows 鍵盤映射工具，以 C#／WinUI 3 製作原生 Windows 11 設定介面（NavigationView、Mica、Settings 卡片），外觀與「設定」App 一致。實際按鍵映射由內附的 AutoHotkey v2 執行：設定儲存後，程式把目前配置轉成 AHK 腳本並重新啟動。預設為暫停，須在「一般」關閉「暫停鍵盤配置」並儲存才會生效。不修改 herdr-zed。

## 執行

Windows 10 1809 以上、.NET 10 SDK：

```powershell
dotnet run --project src/MacKeymap
dotnet test
dotnet build MacKeymap.slnx -c Release
```

Windows App SDK 以 self-contained、免封裝方式輸出，執行檔為 `src/MacKeymap/bin/<組態>/net10.0-windows10.0.19041.0/win-x64/MacKeymap.exe`，不需安裝 MSIX。

### 打包（免安裝版）

在 Visual Studio 對 `MacKeymap` 專案按右鍵 →「發行」，選擇 `Portable-x64` 或 `Portable-arm64` 設定檔；或使用命令列：

```powershell
dotnet publish src/MacKeymap -p:PublishProfile=Portable-x64
```

輸出 `dist/MacKeymap-<版本>-x64-portable/` 資料夾與同名 zip，內含 .NET 及 Windows App SDK，解壓縮後直接執行 `MacKeymap.exe`。版本號由 `MacKeymap.csproj` 的 `<Version>` 設定。

設定存在 `%APPDATA%\MacKeymap\config\config.json`（「一般」頁顯示實際路徑），格式與先前 Rust 原型相容。首次開啟不寫檔，變更後按右上方「儲存」或 Ctrl+S；有未儲存變更時關閉視窗會詢問。匯入取代記憶體內容，再按儲存才會覆寫使用者設定。載入失敗保留原檔並顯示錯誤；手動儲存會以目前內容取代原檔，請先備份損壞設定。

## UI 選擇

早期以 Rust egui 模仿 macOS System Settings，但字型與控制項在 Windows 上不自然。改用 WinUI 3（Windows App SDK）加 CommunityToolkit `SettingsCard`／`SettingsExpander`，直接使用系統控制項、主題（淺色／深色跟隨系統）、Mica 背景、捲軸與對話框。子頁用 BreadcrumbBar 導覽，編輯規則用 ContentDialog。

## 主要操作：以 Profile 為單位

1. 在總覽選擇「macOS 操作習慣」或「Windows 原始操作」。選擇會切換整套規則、鍵盤角色、功能群組及應用程式偏好，不必逐鍵設定。
2. macOS 配置用三個功能群組開關管理 Command 快捷鍵、Option 逐字操作、CapsLock 語言切換。關閉群組不會改寫規則本身；重新開啟恢復原本的個別設定。
3. 在「應用程式」為 EXE 名稱或完整路徑選擇「沿用 Profile」「原始 Windows 操作」或「終端機操作」。未列出的程式沿用目前配置。完整路徑優先於 EXE 名稱，舊版全域排除優先。
4. 進階自訂只列出你新增或修改的例外。沒有自訂時顯示「目前使用 Profile 預設」。需要改某個預設行為時，進入「Profile 內建行為」子頁，搜尋動作再建立覆寫；「恢復預設」移除覆寫。內建清單為唯讀查詢。「鍵盤角色」「套用結果」也各自進入獨立子頁，用左上返回／前進導覽，不在原頁展開或收合。打開編輯但不修改就完成，不會建立多餘的覆寫。
5. 按右上方「儲存」保存整套偏好並立即套用到實際按鍵（未暫停時）。

設定格式為版本 3。新配置只儲存 Profile 類型、鍵盤角色、群組及程式偏好與 `overrides`，不將生成的內建映射逐條寫入設定檔。一般 Command＋按鍵透過通用策略轉送 Ctrl＋同鍵（含 Shift），導航、重做、分頁及視窗切換使用動作例外；例如左 Alt+C 複製、左 Alt+V 貼上，程式本身需支援對應的 Windows 快捷鍵。這不是將整顆左 Alt 換成 Ctrl。

載入版本 1 保留全部舊自訂與排除，另附加新配置。載入版本 2 的 macOS 配置時，移除未改動的內建資料，只留下修改／停用的覆寫；原先刪掉的內建行為以停用覆寫保留。獨立自訂、配置索引、群組及程式偏好維持原意。載入／匯入不改寫原檔，按儲存才寫入新版格式。新 macOS 配置使用更新後的通用轉送策略。

## 功能與邊界

- 七個頁面：總覽、操作偏好、進階自訂、輸入法、應用程式、配置、一般。進階頁只有少量自訂例外，完整內建行為收在唯讀查詢中。
- 四類動作與三類範圍，EXE 名稱／完整路徑欄位、優先序、重複觸發初步提示。
- 原始按鍵錄製只在編輯對話框有焦點且使用者按下「錄製」後讀取；Windows API 區分左右修飾鍵。CapsLock、單獨修飾鍵、保留組合可手動輸入。沒有全域錄製鉤子。
- 程式可用檔案選擇器選取，或按鈕列出有主視窗的程式；此操作只查詢程序，不切換視窗。受保護程序可能只能取得 EXE 名稱。
- 配置新增、複製、切換、改名；版本化 JSON、同目錄暫存檔 flush/sync 後原子取代、匯入匯出。
- 預設左 Alt 為 Command、左 Win 為 Option，Ctrl／右 Alt 保留。設定預覽可依角色展開整組觸發，並考慮群組開關與程式模式；Command 按動作映射，不將整顆左 Alt 換為 Ctrl。實際事件比對引擎及後端仍未啟用。
- 開機啟動尚未提供，重新開機後須開啟一次 Mac Keymap 才會恢復映射。映射執行時，系統匣顯示 AutoHotkey 圖示，可從該處暫停或結束。
- 四類動作都會實際執行：送出組合鍵、切換語言（送出組合鍵）、輸入文字（`SendText`）、啟動程式（`Run`）。

## 按鍵映射（AutoHotkey）

- `MacKeymap.Core/AhkScript.cs` 以 `Profile.PreviewRules` 對每個提到的應用程式與預設情況各算一次規則，產生 `%APPDATA%\MacKeymap\mapping.ahk`，所以「套用結果」頁顯示的內容就是實際生效的規則。執行時依前景視窗的程式（先比對完整路徑，再比對 EXE 名稱）選擇規則；設為「原始 Windows 操作」的程式不攔截任何按鍵。
- 儲存時先用 `AutoHotkey64.exe /validate` 檢查腳本，失敗時保留原本正在執行的配置。只停止自己啟動的 AHK 行程（以 PID 和執行檔路徑確認）。
- 單獨按 Alt／Win 不會叫出選單列或開始功能表（`A_MenuMaskKey`）。送出的組合鍵若與觸發鍵相同（例如預設角色下 Command+Tab = 左 Alt+Tab），交由 Windows 原生處理。
- 限制：以系統管理員身分執行的視窗收不到映射，除非 Mac Keymap 也以系統管理員身分執行。無法轉換的按鍵名稱會略過，並在總覽列出。
- `third_party/AutoHotkey/` 是未修改的官方 AutoHotkey 2.0.31（GPLv2，見該目錄的 README 與 license），建置時複製到輸出的 `ahk\` 資料夾。

## 架構與後續階段

- `src/MacKeymap.Core`：與 UI 無關的資料模型。`Model.cs` 包含設定、覆寫合成、預覽及遷移；`Builtin.cs` 是內建通用策略與動作例外；`Storage.cs` 處理 JSON 格式（snake_case，與舊檔相容）及原子寫入。
- `src/MacKeymap`：WinUI 3 介面。`MainWindow` 負責外框、導覽及儲存；`Pages.cs` 包含七個頁面與子頁；`RuleEditor.cs` 是規則編輯對話框（只在對話框內錄製按鍵）；`Ui.cs` 是設定卡片元件。
- `tests/MacKeymap.Tests`：xUnit，移植原有 Rust 測試，並加入舊檔讀取測試。

`MappingRunner.cs` 負責產生、驗證腳本，以及啟動和停止 AHK。
