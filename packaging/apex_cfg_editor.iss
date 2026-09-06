; Apex CFG Editor 单文件安装器脚本（Inno Setup 6）。
;
; CI 用法（windows-build.yml）：
;   1. flutter build windows --release 产出 build/windows/x64/runner/Release/
;   2. 复制到 packaging/Release/
;   3. ISCC packaging/apex_cfg_editor.iss → 输出到仓库根 installer/
;
; 版本号来源：编译期定义 /DMyAppVersion=v1.2.3 优先，其次环境变量
; APP_VERSION（CI 在 tag 触发时置为 tag 名，如 v1.2.3），都缺失则 0.0.0。

#define MyAppName "Apex CFG Editor"
#define MyAppPublisher "NoelOrin"
#define MyAppExeName "apex_cfg_editor.exe"

#ifndef MyAppVersion
  #define MyAppVersion GetEnv("APP_VERSION")
#endif

#if MyAppVersion == ""
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{9E5A4C2E-6D1B-4A37-9B8F-2C41D6A7E503}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ApexCfgEditor
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir=..\installer
OutputBaseFilename=ApexCfgEditorSetup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
; 配置编辑器不需要管理员：允许用户按需选择按用户安装。
PrivilegesRequiredOverridesAllowed=dialog commandline
UninstallDisplayIcon={app}\{#MyAppExeName}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "Release\*"; DestDir: "{app}"; \
    Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; \
    Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
    Description: "{cm:LaunchProgram,{#MyAppName}}"; \
    Flags: nowait postinstall skipifsilent
