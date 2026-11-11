# Project Memory

## Windows 更新流程（2026-11-11）

- 更新流程：app 內檢查 GitHub Release（`lib/features/update/`）→ 下載
  `*-Windows-Setup.exe` 到「下載」資料夾 → `url_launcher` 開啟 → Inno Setup
  精靈（`windows/installer.iss`）。
- `windows/installer.iss` 設 `CloseApplications=force`：安裝時以 Windows
  Restart Manager 自動關閉執行中的 app，不出現「是否關閉應用程式」詢問頁。
  不自動重啟（Flutter runner 沒呼叫 `RegisterApplicationRestart`），新版由
  `[Run]` postinstall「啟動」項目開啟。
- installer 由 CI 編譯：`.github/workflows/build-release.yml` 安裝 Inno Setup
  後以 iscc 編譯，帶入 `/DMyAppName` 等參數。本機沒裝 Inno Setup，.iss 語法
  需靠 CI（tag push 觸發）驗證。

## 驗證指令

- Flutter：`flutter analyze`、`flutter test`
- Windows 安裝檔只能在 CI 驗證（本機無 ISCC）。
