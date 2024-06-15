@echo off

:: Run as Admin
FSUTIL DIRTY query %SYSTEMDRIVE% >nul || (
    PowerShell "Start-Process -FilePath cmd.exe -Args '/C CHDIR /D %CD% & "%0"' -Verb RunAs"
    EXIT
)


reg add "HKEY_CLASSES_ROOT\*\shell\GofileUploader (Upload as zip with password)" /t REG_SZ /f /v "Icon" /d imageres.dll,-5339"
reg add "HKEY_CLASSES_ROOT\*\shell\GofileUploader (Upload as zip with password)\command" /t REG_SZ /f /v "" /d "\"%windir%\System32\WindowsPowershell\v1.0\powershell.exe\" -WindowStyle Hidden -NoProfile -NoLogo -ExecutionPolicy Bypass -File \"%~dp0Gofile.io-Uploader.ps1\" \"%%V"\""

reg add "HKEY_CLASSES_ROOT\Directory\shell\GofileUploader (Upload as zip with password)" /t REG_SZ /f /v "Icon" /d imageres.dll,-5339"
reg add "HKEY_CLASSES_ROOT\Directory\shell\GofileUploader (Upload as zip with password)\command" /t REG_SZ /f /v "" /d "\"%windir%\System32\WindowsPowershell\v1.0\powershell.exe\" -WindowStyle Hidden -NoProfile -NoLogo -ExecutionPolicy Bypass -File \"%~dp0Gofile.io-Uploader.ps1\" \"%%V"\""

exit /b
