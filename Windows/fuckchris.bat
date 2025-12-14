echo Misc browser security settings
reg ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v DisablePasswordCaching /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnonBadCertRecving /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnOnPostRedirect /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Internet Explorer\Main" /v DoNotTrack /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Internet Explorer\Download" /v RunInvalidSignatures /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN\Settings" /v LOCALMACHINE_CD_UNLOCK /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnonZoneCrossing /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV9 /t REG_DWORD /d 1 /f
reg ADD "HKCU\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV8 /t REG_DWORD /d 1 /f
echo Done
echo Turning Firewall on...
netsh advfirewall set allprofiles state on
echo Firewall turned on
netsh advfirewall firewall set rule name="Remote Assistance (DCOM-In)" new enable=no
netsh advfirewall firewall set rule name="Remote Assistance (PNRP-In)" new enable=no
netsh advfirewall firewall set rule name="Remote Assistance (RA Server TCP-In)" new enable=no
netsh advfirewall firewall set rule name="Remote Assistance (SSDP TCP-In)" new enable=no
netsh advfirewall firewall set rule name="Remote Assistance (SSDP UDP-In)" new enable=no
netsh advfirewall firewall set rule name="Remote Assistance (TCP-In)" new enable=no
netsh advfirewall firewall set rule name="Telnet Server" new enable=no
netsh advfirewall firewall set rule name="netcat" new enable=no
echo Rules set
reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AllocateCDRoms /t REG_DWORD /d 1 /f
reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AllocateFloppies /t REG_DWORD /d 1 /f
reg ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_DWORD /d 0 /f
reg ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f
reg ADD "HKLM\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers" /v AddPrinterDrivers /t REG_DWORD /d 1 /f
reg ADD "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v everyoneincludesanonymous /t REG_DWORD /d 0 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v restrictanonymoussam /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v restrictanonymous /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v auditbaseobjects /t REG_DWORD /d 1 /f
reg ADD HKCU\SYSTEM\CurrentControlSet\Services\CDROM /v AutoRun /t REG_DWORD /d 1 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 1 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v dontdisplaylastusername /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v MaximumPasswordAge /t REG_DWORD /d 15 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v DisableCAD /t REG_DWORD /d 0 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v undockwithoutlogon /t REG_DWORD /d 0 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableInstallerDetection /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v RequireStrongKey /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v RequireSignOrSeal /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v SignSecureChannel /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v SealSecureChannel /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v autodisconnect /t REG_DWORD /d 45 /f
echo Setting password policies
net accounts /lockoutthreshold:5 /MINPWLEN:14 /MAXPWAGE:30 /MINPWAGE:7 /UNIQUEPW:24
echo Set policies
echo Setting Auditing
auditpol /set /category:* /success:enable
auditpol /set /category:* /failure:enable
echo Set Auditing
set badServices=RemoteAccess Telephony TapiSrv Tlntsvr tlntsvr p2pimsvc simptcp fax msftpsvc iprip ftpsvc RemoteRegistry RasMan RasAuto seclogon MSFTPSVC W3SVC SMTPSVC Dfs TrkWks MSDTC DNS ERSVC NtFrs MSFtpsvc helpsvc HTTPFilter IISADMIN IsmServ WmdmPmSN Spooler RDSessMgr RPCLocator RsoPProv	ShellHWDetection ScardSvr Sacsvr TermService Uploadmgr VDS VSS WINS WinHttpAutoProxySvc SZCSVC CscService hidserv IPBusEnum PolicyAgent SCPolicySvc SharedAccess SSDPSRV Themes upnphost nfssvc nfsclnt MSSQLServerADHelper
for %%a in (%badServices%) do (
  echo Service: %%a
  sc stop "%%a"
  sc config "%%a" start=disabled
)
echo Make sure update services are enabled
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v AutoInstallMinorUpdates /t REG_DWORD /d 1 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v NoAutoUpdate /t REG_DWORD /d 0 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v AUOptions /t REG_DWORD /d 4 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 4 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate /v ElevateNonAdmins /t REG_DWORD /d 0 /f
reg add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer /v NoWindowsUpdate /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\Internet Communication Management\Internet Communication" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
reg add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
echo Enabled update services
@echo off
title Windows Privilege Escalation Script
echo.
echo Loading System Information, 3secs...
systeminfo > systeminfo.txt 2> nul
find "KB" systeminfo.txt > hotfix.txt 2> nul
cls
:MENU
echo " _       ___       ____       _       ______         
echo "| |     / (_)___  / __ \_____(_)   __/ ____/_________
echo "| | /| / / / __ \/ /_/ / ___/ / | / / __/ / ___/ ___/
echo "| |/ |/ / / / / / ____/ /  / /| |/ / /___(__  ) /__  
echo "|__/|__/_/_/ /_/_/   /_/  /_/ |___/_____/____/\___/   
echo.
echo Windows Enumeration and Privilege Escalation Script
echo www.joshruppe.com ^| Twitter: @josh_ruppe
echo.

echo 1 - All to Report
echo 2 - Operating System
echo 3 - Storage
echo 4 - Networking
echo 5 - Processess
echo 6 - User Info
echo 7 - Exit
echo.
SET /P C=Select^>
echo.
IF %C%==1 GOTO ALL
IF %C%==2 GOTO OS
IF %C%==3 GOTO STORAGE
IF %C%==4 GOTO NETWORK
IF %C%==5 GOTO PROCESSES
IF %C%==6 GOTO USERS
IF %C%==7 GOTO EXIT

:ALL
echo WinPrivEsc >> report.txt
echo Windows Enumeration and Privilege Escalation Script>> report.txt
echo www.joshruppe.com ^| Twitter: @josh_ruppe>> report.txt
echo.>> report.txt
echo Report generated: >> report.txt
echo. >> report.txt
for /F "tokens=* USEBACKQ" %%F IN ('Date') do (
set Date=%%F
echo %Date% >> report.txt
)
echo __________________________ >> report.txt
echo. >> report.txt
echo      OPERATING SYSTEM >> report.txt
echo __________________________>> report.txt
echo.>> report.txt
echo [++OS Name]>> report.txt
echo.>> report.txt
for /F "tokens=3-7" %%a IN ('find /i "OS Name:" systeminfo.txt') do set Name=%%a %%b %%c %%d %%e>> report.txt
echo %Name%>> report.txt
echo.>> report.txt
echo [++OS Version]>> report.txt
echo.>> report.txt
for /F "tokens=3-6" %%a IN ('findstr /B /C:"OS Version:" systeminfo.txt') do set Version=%%a %%b %%c %%d>> report.txt
echo %Version%>> report.txt
echo.>> report.txt
echo.>> report.txt
echo [++System Architecture]>> report.txt
echo.>> report.txt
for /F "tokens=3-4"  %%a IN ('findstr /B /C:"System Type:" systeminfo.txt') do set Type=%%a %%b>> report.txt
echo %Type%>> report.txt
echo.>> report.txt
echo [++System Boot Time]>> report.txt
echo.>> report.txt
for /F "tokens=4-6" %%a IN ('findstr /B /C:"System Boot Time:" systeminfo.txt') do set UpTime=%%a %%b %%c>> report.txt
echo %UpTime%>> report.txt
echo.>> report.txt
echo [++Page File Location(s)]>> report.txt
echo.>> report.txt
for /F "tokens=4" %%a IN ('findstr /B /C:"Page File Location(s):" systeminfo.txt') do set Page=%%a>> report.txt
echo %Page%>> report.txt
echo.>> report.txt
echo [++Hotfix(s) Installed]>> report.txt
echo.>> report.txt
setlocal enabledelayedexpansion 
for /F "tokens=2" %%a IN ('findstr /v ".TXT" hotfix.txt') do (
  set Hot=%%~a
  echo !Hot!>> report.txt
)
echo.>> report.txt
echo [++Hosts File]>> report.txt
echo.>> report.txt
more c:\WINDOWS\System32\drivers\etc\hosts>> report.txt
echo.>> report.txt
echo [++Networks File]>> report.txt
echo.>> report.txt
more c:\WINDOWS\System32\drivers\etc\networks>> report.txt
echo.>> report.txt
echo [++Running Services]>> report.txt
echo.>> report.txt
net start>> report.txt
echo.>> report.txt
echo.>> report.txt
echo _________________>> report.txt
echo.>> report.txt
echo      STORAGE >> report.txt
echo _________________>> report.txt
echo.>> report.txt
echo [++Physical Drives]>> report.txt
net share>> report.txt
echo.>> report.txt
echo [++Network Drives]>> report.txt
echo.>> report.txt
net use>> report.txt
echo.>> report.txt
echo.>> report.txt
echo ____________________>> report.txt
echo.>> report.txt
echo      NETWORKING >> report.txt
echo ____________________>> report.txt
echo.>> report.txt
echo [++ICONFIG]>> report.txt
ipconfig /allcompartments /all>> report.txt
echo.>> report.txt
echo [++MAC Addresses]>> report.txt
getmac>> report.txt
echo.>> report.txt
echo [++Route]>> report.txt
echo.>> report.txt
route PRINT>> report.txt
echo.>> report.txt
echo [++Netstat]>> report.txt
netstat -ano>> report.txt
echo.>> report.txt
echo [++ARP]>> report.txt
arp -a>> report.txt
echo.>> report.txt
echo [++Firewall Configuration]>> report.txt
netsh firewall show config>> report.txt
echo [++Domain]>> report.txt
echo.>> report.txt
set userdomain>> report.txt
echo.>> report.txt
echo.>> report.txt
echo ___________________>> report.txt
echo.>> report.txt
echo      PROCESSES >> report.txt
echo ___________________>> report.txt
echo.>> report.txt
echo [++Tasklist]>> report.txt
tasklist /v>> report.txt
echo.>> report.txt
echo [++Drivers Installed]>> report.txt
driverquery /v>> report.txt
echo.>> report.txt
echo.>> report.txt
echo ___________________>> report.txt
echo.>> report.txt
echo      USER INFO >> report.txt
echo ___________________>> report.txt
echo.>> report.txt
echo [++Current User]>> report.txt
echo.>> report.txt
whoami>> report.txt
echo.>> report.txt
echo [++All Users]>> report.txt
net users>> report.txt
echo.>> report.txt
echo [++User Groups]>> report.txt
net localgroup>> report.txt
echo.>> report.txt
echo Done, check report.txt
echo.
del systeminfo.txt
del hotfix.txt
EXIT /B

:OS
echo __________________________
echo.
echo      OPERATING SYSTEM 
echo __________________________
echo.
echo [++OS Name]
echo.
for /F "tokens=3-7" %%a IN ('find /i "OS Name:" systeminfo.txt') do set Name=%%a %%b %%c %%d %%e
echo %Name%
echo.
echo [++OS Version]
echo.
for /F "tokens=3-6" %%a IN ('findstr /B /C:"OS Version:" systeminfo.txt') do set Version=%%a %%b %%c %%d
echo %Version%
echo.
echo [++System Architecture]
echo.
for /F "tokens=3-4"  %%a IN ('findstr /B /C:"System Type:" systeminfo.txt') do set Type=%%a %%b
echo %Type%
echo.
echo [++System Boot Time]
echo.
for /F "tokens=4-6" %%a IN ('findstr /B /C:"System Boot Time:" systeminfo.txt') do set UpTime=%%a %%b %%c
echo %UpTime%
echo.
echo [++Page File Location(s)]
echo.
for /F "tokens=4" %%a IN ('findstr /B /C:"Page File Location(s):" systeminfo.txt') do set Page=%%a
echo %Page%
echo.
echo [++Hotfix(s) Installed]
echo.
setlocal enabledelayedexpansion 
for /F "tokens=2" %%a IN ('findstr /v ".TXT" hotfix.txt') do (
  set Hot=%%~a
  echo !Hot!
)
echo.
echo [++Hosts File]
echo.
more c:\WINDOWS\System32\drivers\etc\hosts
echo.
echo [++Networks File]
echo.
more c:\WINDOWS\System32\drivers\etc\networks
echo.
echo [++Running Services]
echo.
net start
echo.
del systeminfo.txt
del hotfix.txt
EXIT /B

:STORAGE
echo _________________
echo.
echo      STORAGE 
echo _________________
echo.
echo [++Physical Drives]
net share
echo.
echo [++Network Drives]
echo.
net use
del systeminfo.txt
del hotfix.txt
EXIT /B

:NETWORK
echo ____________________
echo.
echo      NETWORKING 
echo ____________________
echo.
echo [++ICONFIG]
ipconfig /allcompartments /all
echo.
echo [++MAC Addresses]
getmac
echo.
echo [++Route]
echo.
route PRINT
echo.
echo [++Netstat]
netstat -ano
echo.
echo [++ARP]
arp -a
echo.
echo [++Firewall Configuration]
netsh firewall show config
echo [++Domain]
echo.
set userdomain
echo.
del systeminfo.txt
del hotfix.txt
EXIT /B

:PROCESSES
echo ___________________
echo.
echo      PROCESSES 
echo ___________________
echo.
echo [++Tasklist]
tasklist /v
echo.
echo [++Drivers Installed]
driverquery /vw
del systeminfo.txt
del hotfix.txt
EXIT /B

:USERS
echo ___________________
echo.
echo      USER INFO 
echo ___________________
echo.
echo [++Current User]
echo.
whoami
echo.
echo [++All Users]
net users
echo.
echo [++User Groups]
net localgroup
echo.
del systeminfo.txt
del hotfix.txt
EXIT /B

:EXIT
del systeminfo.txt
del hotfix.txt
EXIT /B
