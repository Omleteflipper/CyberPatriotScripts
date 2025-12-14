# Windows Server 2022 – Local Policies Hardening
# Covers CIS 2.x: Audit Policy, User Rights Assignment, Security Options
# CyberPatriot-safe, role-aware (DC vs Member Server)
# Run as Administrator

Write-Output "=== Applying Local Policies: User Rights & Security Options ==="

# Detect Domain Controller
$IsDC = (Get-WindowsFeature AD-Domain-Services -ErrorAction SilentlyContinue).Installed

# -------------------------------
# USER RIGHTS ASSIGNMENT (CIS 2.2)
# Implemented via secedit INF template (safe + auditable)
# -------------------------------

$inf = "$env:TEMP\\user_rights.inf"
@"
[Unicode]
Unicode=yes

[Version]
signature=\"$CHICAGO$\"
Revision=1

[Privilege Rights]
SeTrustedCredManAccessPrivilege =
SeTcbPrivilege =
SeCreateTokenPrivilege =
SeCreatePermanentPrivilege =
SeLockMemoryPrivilege =
SeDebugPrivilege = Administrators
SeBackupPrivilege = Administrators
SeRestorePrivilege = Administrators
SeShutdownPrivilege = Administrators
SeTakeOwnershipPrivilege = Administrators
SeLoadDriverPrivilege = Administrators
SeSystemEnvironmentPrivilege = Administrators
SeManageVolumePrivilege = Administrators
SeProfileSingleProcessPrivilege = Administrators
SeProfileSystemPerformancePrivilege = Administrators,NT SERVICE\\WdiServiceHost
SeIncreaseQuotaPrivilege = Administrators,LOCAL SERVICE,NETWORK SERVICE
SeChangeNotifyPrivilege = Everyone
SeCreateGlobalPrivilege = Administrators,LOCAL SERVICE,NETWORK SERVICE,SERVICE
SeImpersonatePrivilege = Administrators,LOCAL SERVICE,NETWORK SERVICE,SERVICE
SeAssignPrimaryTokenPrivilege = LOCAL SERVICE,NETWORK SERVICE
SeIncreaseBasePriorityPrivilege = Administrators
SeCreatePagefilePrivilege = Administrators
SeTimeZonePrivilege = Administrators,LOCAL SERVICE
SeSystemtimePrivilege = Administrators,LOCAL SERVICE
SeRemoteShutdownPrivilege = Administrators
SeDenyNetworkLogonRight = Guests
SeDenyBatchLogonRight = Guests
SeDenyServiceLogonRight = Guests
SeDenyInteractiveLogonRight = Guests
SeDenyRemoteInteractiveLogonRight = Guests
"@ | Set-Content $inf

secedit /configure /db C:\\Windows\\Security\\Local.sdb /cfg $inf /areas USER_RIGHTS | Out-Null
Remove-Item $inf -Force -ErrorAction SilentlyContinue
Write-Output "User Rights Assignment applied (CIS 2.2)"

# DC-specific user rights
if ($IsDC) {
    Write-Output "Applying Domain Controller–specific user rights"
    $dcInf = "$env:TEMP\\dc_rights.inf"
    @"
[Unicode]
Unicode=yes
[Version]
signature=\"$CHICAGO$\"
Revision=1
[Privilege Rights]
SeInteractiveLogonRight = Administrators,ENTERPRISE DOMAIN CONTROLLERS
SeNetworkLogonRight = Administrators,Authenticated Users,ENTERPRISE DOMAIN CONTROLLERS
SeRemoteInteractiveLogonRight = Administrators
SeAddUsersPrivilege = Administrators
SeTrustedDelegationPrivilege = Administrators
SeMachineAccountPrivilege = Administrators
SeSyncAgentPrivilege =
"@ | Set-Content $dcInf

    secedit /configure /db C:\\Windows\\Security\\Local.sdb /cfg $dcInf /areas USER_RIGHTS | Out-Null
    Remove-Item $dcInf -Force -ErrorAction SilentlyContinue
}
else {
    Write-Output "Applying Member Server user rights"
    $msInf = "$env:TEMP\\ms_rights.inf"
    @"
[Unicode]
Unicode=yes
[Version]
signature=\"$CHICAGO$\"
Revision=1
[Privilege Rights]
SeInteractiveLogonRight = Administrators
SeNetworkLogonRight = Administrators,Authenticated Users
SeRemoteInteractiveLogonRight = Administrators,Remote Desktop Users
SeTrustedDelegationPrivilege =
"@ | Set-Content $msInf

    secedit /configure /db C:\\Windows\\Security\\Local.sdb /cfg $msInf /areas USER_RIGHTS | Out-Null
    Remove-Item $msInf -Force -ErrorAction SilentlyContinue
}

# -------------------------------
# SECURITY OPTIONS (CIS 2.3)
# -------------------------------

$lsa = "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa"
$pol = "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System"

# Accounts
Set-ItemProperty $pol NoConnectedUser -Value 3 -Force   # Block Microsoft accounts
Set-ItemProperty $lsa LimitBlankPasswordUse -Value 1 -Force

# Audit
Set-ItemProperty $lsa SCENoApplyLegacyAuditPolicy -Value 1 -Force
Set-ItemProperty $lsa CrashOnAuditFail -Value 0 -Force

# Devices
Set-ItemProperty "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Print\\Providers\\LanMan Print Services\\Servers" AddPrinterDrivers -Value 1 -Force

# Domain member secure channel
Set-ItemProperty $lsa RequireSignOrSeal -Value 1 -Force
Set-ItemProperty $lsa SealSecureChannel -Value 1 -Force
Set-ItemProperty $lsa SignSecureChannel -Value 1 -Force
Set-ItemProperty $lsa DisablePasswordChange -Value 0 -Force
Set-ItemProperty $lsa MaximumPasswordAge -Value 30 -Force
Set-ItemProperty $lsa RequireStrongKey -Value 1 -Force

# Interactive logon
Set-ItemProperty $pol DisableCAD -Value 0 -Force
Set-ItemProperty $pol DontDisplayLastUserName -Value 1 -Force
Set-ItemProperty $pol InactivityTimeoutSecs -Value 900 -Force
Set-ItemProperty $pol CachedLogonsCount -Value 4 -Force
Set-ItemProperty $pol PasswordExpiryWarning -Value 7 -Force

# Microsoft network client/server
$netCli = "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters"
$netSrv = "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters"
Set-ItemProperty $netCli RequireSecuritySignature -Value 1 -Force
Set-ItemProperty $netCli EnableSecuritySignature -Value 1 -Force
Set-ItemProperty $netCli EnablePlainTextPassword -Value 0 -Force
Set-ItemProperty $netSrv RequireSecuritySignature -Value 1 -Force
Set-ItemProperty $netSrv EnableSecuritySignature -Value 1 -Force
Set-ItemProperty $netSrv AutoDisconnect -Value 15 -Force
Set-ItemProperty $netSrv EnableForcedLogoff -Value 1 -Force

# Network access / NTLM
Set-ItemProperty $lsa NoLMHash -Value 1 -Force
Set-ItemProperty $lsa LmCompatibilityLevel -Value 5 -Force
Set-ItemProperty $lsa EveryoneIncludesAnonymous -Value 0 -Force
Set-ItemProperty $lsa RestrictAnonymous -Value 2 -Force
Set-ItemProperty $lsa RestrictAnonymousSAM -Value 1 -Force

# UAC
Set-ItemProperty $pol EnableLUA -Value 1 -Force
Set-ItemProperty $pol ConsentPromptBehaviorAdmin -Value 2 -Force
Set-ItemProperty $pol ConsentPromptBehaviorUser -Value 0 -Force
Set-ItemProperty $pol PromptOnSecureDesktop -Value 1 -Force
Set-ItemProperty $pol EnableInstallerDetection -Value 1 -Force
Set-ItemProperty $pol EnableSecureUIAPaths -Value 1 -Force
Set-ItemProperty $pol FilterAdministratorToken -Value 1 -Force
Set-ItemProperty $pol EnableVirtualization -Value 1 -Force

Write-Output "Local Policies hardening complete (CIS 2.x)"
