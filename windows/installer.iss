; ============================================================
; Generic Flutter Windows Installer
;
; GitHub Actions supplies:
; /DMyAppName=...
; /DMyAppVersion=...
; /DMyAppPublisher=...
; /DMyAppId=...
; /DBuildDir=...
; /DOutputDir=...
;
; Derived automatically:
; MyAppExeName = MyAppName + ".exe"
; Installer    = MyAppName + "-Windows-Setup.exe"
;
; Defaults are provided for local compilation.
; ============================================================

#ifndef MyAppName
#define MyAppName "flutter_app"
#endif

#ifndef MyAppExeName
#define MyAppExeName MyAppName + ".exe"
#endif

#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif

#ifndef MyAppPublisher
#define MyAppPublisher "Flutter App"
#endif

#ifndef BuildDir
#define BuildDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "..\dist"
#endif

; 每個獨立應用程式必須使用固定且唯一的 AppId。
; 應用程式首次發佈後，不要再更改 AppId，否則 Windows
; 會將新版本視為另一個應用程式。
#ifndef MyAppId
#define MyAppId "{{B43F6267-C230-4B22-9905-9A9881234567}"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

OutputDir={#OutputDir}
OutputBaseFilename={#MyAppName}-Windows-Setup

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}

SetupLogging=yes

; 安裝時以 Windows Restart Manager 自動關閉正在執行的本程式，
; 不再顯示「是否關閉應用程式」詢問頁；安裝完成後由 [Run] 的
; postinstall 啟動項目重新開啟新版。
; （RestartApplications 預設為 yes，但本程式沒有呼叫
; RegisterApplicationRestart，因此 Restart Manager 不會另外重啟，
; 不會與 postinstall 產生重複啟動。）
CloseApplications=force

[Files]
Source: "{#BuildDir}\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\{#MyAppName}"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    Tasks: desktopicon

[Tasks]
Name: "desktopicon"; \
    Description: "建立桌面捷徑"; \
    GroupDescription: "其他選項："; \
    Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "啟動 {#MyAppName}"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent