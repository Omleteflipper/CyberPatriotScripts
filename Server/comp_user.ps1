<#
 CyberPatriot-focused User Administrative Template Hardening
 Applies ONLY settings historically scored or safely applicable
 Applies to HKCU and Default User where appropriate
#>

Write-Output "Applying CyberPatriot User Administrative Template Hardening (Section 19)"

# Helper function
function Set-Reg {
    param($Path,$Name,$Type,$Value)
    if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force
}

############################
# Notifications / Lock Screen
############################
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" NoToastApplicationNotificationOnLockScreen DWord 1

############################
# Internet Communication
############################
Set-Reg "HKCU:\Software\Policies\Microsoft\Assistance\Client\1.0" NoImplicitFeedback DWord 1

############################
# Attachment Manager
############################
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" SaveZoneInformation DWord 2
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments" ScanWithAntiVirus DWord 3

############################
# Cloud Content / Spotlight
############################
$cc = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
Set-Reg $cc DisableWindowsSpotlightFeatures DWord 1
Set-Reg $cc DisableThirdPartySuggestions DWord 1
Set-Reg $cc DisableTailoredExperiencesWithDiagnosticData DWord 1
Set-Reg $cc DisableSpotlightCollectionOnDesktop DWord 1

############################
# Network Sharing
############################
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" NoInplaceSharing DWord 1

############################
# Windows Installer
############################
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Installer" AlwaysInstallElevated DWord 0

############################
# Media Player Codec Downloads
############################
Set-Reg "HKCU:\Software\Policies\Microsoft\WindowsMediaPlayer" PreventCodecDownload DWord 1

############################
# Search / Copilot / Consumer UX
############################
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" DisableSearchBoxSuggestions DWord 1
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" TurnOffWindowsCopilot DWord 1

############################
# Error Reporting
############################
Set-Reg "HKCU:\Software\Microsoft\Windows\Windows Error Reporting" Disabled DWord 1

############################
# Defender SmartScreen (User)
############################
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" EnableWebContentEvaluation DWord 1

############################
# Apply to Default User (future users)
############################
$defaultHive = "HKU:\.DEFAULT"
Set-Reg "$defaultHive\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" NoToastApplicationNotificationOnLockScreen DWord 1
Set-Reg "$defaultHive\Software\Policies\Microsoft\Windows\CloudContent" DisableWindowsSpotlightFeatures DWord 1

Write-Output "Section 19 User Administrative Template Hardening Complete"