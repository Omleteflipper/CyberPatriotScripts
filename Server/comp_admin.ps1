<# 
CyberPatriot-Optimized Administrative Templates (Computer) Hardening
Target: Windows Server 2022 (Unknown Role)
Purpose: Enforce ALL commonly scored CyberPatriot Administrative Template / GPO-equivalent settings
Safe for: Member Server / Standalone / Domain Member

NOTE:
- NO DC-breaking settings
- NO hardware/TPM/BitLocker assumptions
- NO Enterprise-only features (Device Guard, full ASR matrix)
- Covers what CP scoring engines actually check
#>

Write-Host "[+] Applying CyberPatriot Administrative Template Hardening (Section 18)" -ForegroundColor Cyan

function Set-RegDWORD($Path,$Name,$Value){
    if(!(Test-Path $Path)){ New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

############################################
# Privacy / Telemetry / Consumer Features
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" AllowTelemetry 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableConsumerFeatures 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" DisabledByGroupPolicy 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" PublishUserActivities 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" UploadUserActivities 0

############################################
# Lock Screen / Sign-in Hardening
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" NoLockScreenCamera 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" NoLockScreenSlideshow 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" BlockUserFromShowingAccountDetailsOnSignin 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" DontDisplayNetworkSelectionUI 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" DisableLockScreenAppNotifications 1

############################################
# PowerShell Logging (High-Value CP Item)
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" EnableScriptBlockLogging 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" EnableTranscripting 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" EnableInvocationHeader 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" OutputDirectory 1

############################################
# Process Creation Command Line Logging
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" ProcessCreationIncludeCmdLine_Enabled 1

############################################
# Windows Defender Core Protections
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" DisableAntiSpyware 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" DisableRealtimeMonitoring 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" DisableBehaviorMonitoring 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" DisableOnAccessProtection 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" DisableEmailScanning 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" DisableRemovableDriveScanning 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" ScanPackedExecutables 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\PUAProtection" PUAProtection 1

############################################
# SmartScreen
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" EnableSmartScreen 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" ShellSmartScreenLevel 1

############################################
# Remote Access Hardening
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" fPromptForPassword 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" MinEncryptionLevel 3
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" fDisableCdm 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" MaxIdleTime 900000
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" MaxDisconnectionTime 60000

############################################
# WinRM Hardening
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" AllowBasic 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" AllowUnencryptedTraffic 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" AllowBasic 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" AllowUnencryptedTraffic 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" DisableRunAs 1

############################################
# Autoplay / Autorun
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" NoAutoplayfornonVolume 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" NoViewContextMenu 0
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" NoAutorun 1

############################################
# OneDrive Disable (Common CP Finding)
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" DisableFileSyncNGSC 1

############################################
# Event Log Sizing
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Application" MaxSize 32768
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\Security" MaxSize 196608
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\System" MaxSize 32768

# Disable PowerShell 2.0 (CyberPatriot / CIS safe)
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction SilentlyContinue
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue

# Ensure Windows Firewall is enabled on all profiles (CyberPatriot critical)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

############################################
# Internet Communication Restrictions
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" DisableAutomaticRestartSignOn 1
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" EnableCdp 0

############################################
# Camera Disable
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Camera" AllowCamera 0

############################################
# Notifications
############################################
Set-RegDWORD "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" NoToastApplicationNotification 1

Write-Host "[+] Section 18 CyberPatriot Administrative Template Hardening Complete" -ForegroundColor Green
