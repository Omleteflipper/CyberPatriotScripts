@echo off
rem CyberPatriot safer script - revised per request
color 0b
title CyberPatriot Windows Script - Safer Revision
setlocal ENABLEDELAYEDEXPANSION

rem ----- logging -----
set LOGFILE=%~dp0cyberpatriot_script_log.txt
echo ================= Script run at %DATE% %TIME% > "%LOGFILE%"

rem ----- require admin -----
echo Checking administrator permissions... | tee -a "%LOGFILE%"
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo This Command Prompt does not have administrator permissions. Right click the batch file and select "Run as administrator". >> "%LOGFILE%"
    echo Press any key to exit...
    pause >nul
    goto :eof
)
echo Running as administrator. >> "%LOGFILE%"

rem ----- locate LGPO.exe (prefer script directory, then common locations) -----
set LGPO_PATH=
if exist "%~dp0LGPO.exe" set "LGPO_PATH=%~dp0LGPO.exe"
if not defined LGPO_PATH (
    for %%P in ("%USERPROFILE%\Desktop" "C:\Policies" "C:\" "%~dp0") do (
        if exist "%%~fP\LGPO.exe" set "LGPO_PATH=%%~fP\LGPO.exe"
    )
)
if not defined LGPO_PATH (
    for /f "delims=" %%a in ('dir /s /b C:\LGPO.exe 2^>nul') do (
        set "LGPO_PATH=%%~fa"
        goto :LGPO_found
    )
)
:LGPO_found
if defined LGPO_PATH (
    echo Found LGPO.exe at "%LGPO_PATH%". >> "%LOGFILE%"
) else (
    echo Warning: LGPO.exe not found. GPO import option will be skipped unless you place LGPO.exe in the script folder. >> "%LOGFILE%"
)

rem ----- initial menu ----- 
cls
echo ------------------------------------------------------------------------------------
echo *** CyberPatriot safer script - Revised ***
echo In the following prompts choose y for yes, n for no, c to cancel.
echo NOTE: User-audit and global password changes have been removed per instruction.
echo ------------------------------------------------------------------------------------
echo:

rem ----- Import GPOs (optional) - performed early so GPOs can apply before local tweaks -----
if defined LGPO_PATH (
    choice /c ync /m "Do you wish to import GPOs from .\Policies now? (Recommended to import before registry tweaks) "
    if %ERRORLEVEL% equ 3 (
        echo Canceling... >> "%LOGFILE%"
        pause
        goto :eof
    )
    if %ERRORLEVEL% equ 1 (
        echo Importing policies from .\Policies... >> "%LOGFILE%"
        pushd "%~dp0"
        "%LGPO_PATH%" /g .\Policies /v >> "%LOGFILE%" 2>&1
        if %ERRORLEVEL% equ 0 (
            echo LGPO import completed. >> "%LOGFILE%"
        ) else (
            echo LGPO import returned error code %ERRORLEVEL%. >> "%LOGFILE%"
        )
        popd
        echo Running gpupdate /force to apply policies... >> "%LOGFILE%"
        gpupdate /force >> "%LOGFILE%" 2>&1
    ) else (
        echo Skipping GPO import. >> "%LOGFILE%"
    )
) else (
    echo LGPO.exe not found; skipping GPO import. >> "%LOGFILE%"
)

echo:

rem ----- Services: conservative, hardcoded list only -----
rem This list is intentionally minimal and conservative. Only services listed here will ever be disabled.
rem Modify this list only if you are sure the service is safe to remove for your image.
set "safeDisableList=Tlntsvr Fax MSFTPSVC SMTPSVC IISADMIN"
echo The script will only operate on this predefined list of services: %safeDisableList% >> "%LOGFILE%"
choice /c ync /m "Do you wish to disable the conservative, hardcoded service list? (recommended: Y) "
if %ERRORLEVEL% equ 3 (
    echo Canceling... >> "%LOGFILE%"
    pause
    goto :eof
)
if %ERRORLEVEL% equ 2 (
    echo Skipping service changes. >> "%LOGFILE%"
) else (
    echo Managing services from the hardcoded list... >> "%LOGFILE%"
    for %%s in (%safeDisableList%) do (
        sc query "%%s" >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            echo Stopping and disabling %%s... >> "%LOGFILE%"
            sc stop "%%s" >> "%LOGFILE%" 2>&1
            sc config "%%s" start=disabled >> "%LOGFILE%" 2>&1
        ) else (
            echo Service %%s not present; skipping. >> "%LOGFILE%"
        )
    )
    echo Services management finished. >> "%LOGFILE%"
)
echo:

rem ----- Remote Desktop handling (kept optional, minimal) -----
choice /c ync /m "Do you wish to disable Remote Desktop services (TermService, SessionEnv, UmRdpService)? "
if %ERRORLEVEL% equ 3 (
    echo Canceling... >> "%LOGFILE%"
    pause
    goto :eof
)
if %ERRORLEVEL% equ 2 (
    echo Skipping Remote Desktop changes. >> "%LOGFILE%"
) else (
    echo Disabling Remote Desktop services... >> "%LOGFILE%"
    sc query TermService >nul 2>&1 && ( sc stop "TermService" >> "%LOGFILE%" 2>&1 & sc config "TermService" start=disabled >> "%LOGFILE%" 2>&1 )
    sc query SessionEnv >nul 2>&1 && ( sc stop "SessionEnv" >> "%LOGFILE%" 2>&1 & sc config "SessionEnv" start=disabled >> "%LOGFILE%" 2>&1 )
    sc query UmRdpService >nul 2>&1 && ( sc stop "UmRdpService" >> "%LOGFILE%" 2>&1 & sc config "UmRdpService" start=disabled >> "%LOGFILE%" 2>&1 )
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fDenyTSConnections" /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
    echo Remote Desktop changes applied. >> "%LOGFILE%"
)
echo:

rem ----- Registry tweaks (optional, performed after GPO import) -----
choice /c ync /m "Do you wish to apply a conservative set of registry security tweaks? (UAC, LSA hardening, Netlogon settings, SMB plaintext disable) "
if %ERRORLEVEL% equ 3 (
    echo Canceling... >> "%LOGFILE%"
    pause
    goto :eof
)
if %ERRORLEVEL% equ 2 (
    echo Skipping registry tweaks. >> "%LOGFILE%"
) else (
    echo Applying registry tweaks... >> "%LOGFILE%"

    rem UAC: prompt on secure desktop and enable LUA
    reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
    reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

    rem LSA protections (enable RunAsPPL where supported)
    reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
    reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

    rem SMB plaintext disabled
    reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanWorkstation\Parameters /v EnablePlainTextPassword /t REG_DWORD /d 0 /f >> "%LOGFILE%" 2>&1

    rem Show hidden files for current user (non-destructive)
    reg ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v Hidden /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1
    reg ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v ShowSuperHidden /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

    rem Clear pagefile at shutdown (optional; informs log)
    reg ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f >> "%LOGFILE%" 2>&1

    echo Registry tweaks applied. >> "%LOGFILE%"
)
echo:

rem ----- Removed: user audit / deletion logic and password-changing sections -----
echo User-audit and password-change operations have been removed from this script as requested. >> "%LOGFILE%"

rem ----- Final steps -----
echo Performing final policy refresh and cleanup... >> "%LOGFILE%"
gpupdate /target:computer /force >> "%LOGFILE%" 2>&1
gpupdate /target:user /force >> "%LOGFILE%" 2>&1

echo ------------------------------------------------------------------------------------
echo *** Script finished. Review log at "%LOGFILE%". ***
echo ------------------------------------------------------------------------------------
echo:
pause
exit /b 0
