# Windows Server 2022 – Windows Defender Firewall Hardening
# CIS Benchmark Sections 9.x (Firewall Profiles)
# CyberPatriot-safe, applies to all server roles
# Run as Administrator

Write-Output "=== Applying Windows Defender Firewall Hardening (CIS 9.x) ==="

# Ensure Windows Defender Firewall service is running
Set-Service -Name MpsSvc -StartupType Automatic
Start-Service -Name MpsSvc -ErrorAction SilentlyContinue

# Common firewall logging size (KB)
$LogSize = 16384

# -------------------------------
# DOMAIN PROFILE (CIS 9.1.x)
# -------------------------------
Set-NetFirewallProfile -Profile Domain `
    -Enabled True `
    -DefaultInboundAction Block `
    -NotifyOnListen False

Set-NetFirewallProfile -Profile Domain `
    -LogFileName "%SystemRoot%\\System32\\logfiles\\firewall\\domainfw.log" `
    -LogMaxSizeKilobytes $LogSize `
    -LogBlocked True `
    -LogAllowed True

Write-Output "Domain firewall profile configured"

# -------------------------------
# PRIVATE PROFILE (CIS 9.2.x)
# -------------------------------
Set-NetFirewallProfile -Profile Private `
    -Enabled True `
    -DefaultInboundAction Block `
    -NotifyOnListen False

Set-NetFirewallProfile -Profile Private `
    -LogFileName "%SystemRoot%\\System32\\logfiles\\firewall\\privatefw.log" `
    -LogMaxSizeKilobytes $LogSize `
    -LogBlocked True `
    -LogAllowed True

Write-Output "Private firewall profile configured"

# -------------------------------
# PUBLIC PROFILE (CIS 9.3.x)
# -------------------------------
Set-NetFirewallProfile -Profile Public `
    -Enabled True `
    -DefaultInboundAction Block `
    -NotifyOnListen False `
    -AllowLocalFirewallRules False `
    -AllowLocalIPsecRules False

Set-NetFirewallProfile -Profile Public `
    -LogFileName "%SystemRoot%\\System32\\logfiles\\firewall\\publicfw.log" `
    -LogMaxSizeKilobytes $LogSize `
    -LogBlocked True `
    -LogAllowed True

Write-Output "Public firewall profile configured"

Write-Output "=== Windows Defender Firewall Hardening Complete ==="
