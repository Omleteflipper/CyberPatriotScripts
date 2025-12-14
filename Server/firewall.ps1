# Firewall_Defender_Hardening.ps1
# Run as Administrator

Write-Output "=== Configuring Windows Firewall and Defender ==="
# Enable Windows Firewall for all profiles; block inbound by default
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True `
    -DefaultInboundAction Block -DefaultOutboundAction Allow
Write-Output "Enabled Windows Firewall (all profiles), block inbound, allow outbound (CyberPatriot guidance)"
# Enable detailed logging for troubleshooting (optional)
Set-NetFirewallProfile -Profile Domain,Private,Public -LogFileName '%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log' -LogMaxSizeKilobytes 16384

# Ensure Windows Defender and its features are enabled
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableBehaviorMonitoring $false
Set-MpPreference -DisableIntrusionPreventionSystem $false
Set-MpPreference -DisableScriptScanning $false
Set-MpPreference -PUAProtection 1
Set-MpPreference -SubmitSamplesConsent 2
Write-Output "Enabled Windows Defender protections (real-time, script scanning, ASR, etc.)"
