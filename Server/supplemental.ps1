<#
 Section 20 – STIG Supplemental Controls (CyberPatriot-Safe)
 ---------------------------------------------------------
 This script ONLY enforces STIG items that:
  • Are safely automatable
  • Do not require DoD PKI, CAC, TPM, or AD schema changes
  • Have historically appeared in CyberPatriot scoring

 All remaining items are documented as MANUAL CHECKS.
#>

Write-Output "Applying CyberPatriot-safe STIG supplemental controls (Section 20)"

############################
# Helper
############################
function Disable-FeatureIfPresent {
    param($FeatureName)
    $f = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
    if ($f -and $f.Installed) {
        Uninstall-WindowsFeature -Name $FeatureName -Remove -Confirm:$false
        Write-Output "Removed feature: $FeatureName"
    }
}

############################
# Accounts Require Passwords
############################
Get-LocalUser | Where-Object { $_.Enabled -eq $true -and $_.PasswordRequired -eq $false } |
    ForEach-Object {
        Write-Warning "User $($_.Name) does not require a password – MANUAL FIX REQUIRED"
    }

############################
# Disable SMBv1
############################
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue

############################
# Remove Legacy Clients
############################
Disable-FeatureIfPresent Telnet-Client
Disable-FeatureIfPresent TFTP-Client
Disable-FeatureIfPresent Fax

############################
# Remove PowerShell v2
############################
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction SilentlyContinue
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue

############################
# Firewall Presence Validation
############################
if ((Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $false })) {
    Write-Warning "Firewall profile disabled – MANUAL FIX REQUIRED"
}

# Disable Guest account (CyberPatriot requirement)
net user Guest /active:no 2>$null

############################
# Antivirus Presence Validation
############################
if (-not (Get-Service WinDefend -ErrorAction SilentlyContinue)) {
    Write-Warning "Antivirus not detected – MANUAL FIX REQUIRED"
}

############################
# NTFS Validation
############################
Get-Volume | Where-Object { $_.FileSystem -ne 'NTFS' } |
    ForEach-Object { Write-Warning "Volume $($_.DriveLetter) is not NTFS" }

############################
# Outdated / Temporary Accounts (Report Only)
############################
$limit = (Get-Date).AddDays(-90)
Get-LocalUser | Where-Object { $_.LastLogon -and $_.LastLogon -lt $limit } |
    ForEach-Object { Write-Warning "Inactive account detected: $($_.Name)" }

############################
# Shared Accounts (Report Only)
############################
Get-LocalUser | Group-Object Name | Where-Object { $_.Count -gt 1 } |
    ForEach-Object { Write-Warning "Potential shared account: $($_.Name)" }

############################
# Feature Inventory (Documentation Aid)
############################
Get-WindowsFeature | Where-Object Installed | Select Name | Out-File "$env:SystemDrive\\InstalledRoles.txt"

############################
# MANUAL STIG ITEMS (Documented)
############################
Write-Output "The following STIG items REQUIRE MANUAL VERIFICATION:" 
Write-Output " - DoD PKI / CAC / PIV requirements"
Write-Output " - AdminSDHolder auditing"
Write-Output " - AD object permissions & auditing"
Write-Output " - krbtgt password rotation"
Write-Output " - Audit log offloading"
Write-Output " - TPM / UEFI enforcement"
Write-Output " - Dedicated DC hardware"
Write-Output " - Emergency & shared account lifecycle"
Write-Output " - Application allowlisting (SRP/AppLocker)"

Write-Output "Section 20 CyberPatriot-safe STIG processing complete"