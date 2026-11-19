
#define MyAppName "Ameera POS"
#define MyAppVersion "1.0.0"

[Setup]
AppId={{A71F6C29-8D43-4B52-9E21-71C9A2F48310}
        AppName={#MyAppName}
        AppVersion={#MyAppVersion}
        DefaultDirName={autopf}\POS System
        DefaultGroupName=POS System
        OutputDir=installer_output
        OutputBaseFilename=POS-Setup
        Compression=lzma
        SolidCompression=yes
        WizardStyle=modern
        PrivilegesRequired=admin

        [Tasks]
        Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

        [Files]
        Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

        [Icons]
        Name: "{autoprograms}\POS System"; Filename: "{app}\demoproject.exe"
        Name: "{autodesktop}\POS System"; Filename: "{app}\demoproject.exe"; Tasks: desktopicon

        [Run]
        Filename: "{app}\demoproject.exe"; Description: "Launch POS System"; Flags: postinstall nowait skipifsilent
