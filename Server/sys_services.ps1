# Windows Server 2022 – System Services Hardening
# CIS Section 5 – System Services
# CyberPatriot-safe, role-aware (DC vs Member Server)
# Run as Administrator

Write-Output "=== Applying System Services Hardening (CIS 5.x) ==="

# Detect Domain Controller
$IsDC = (Get-WindowsFeature AD-Domain-Services -ErrorAction SilentlyContinue).Installed

# -------------------------------
# 5.1 Microsoft FTP Service (FTPSVC)
# STIG-only: Ensure Not Installed
# -------------------------------
$ftpFeature = Get-WindowsFeature Web-Ftp-Service -ErrorAction SilentlyContinue
if ($ftpFeature -and $ftpFeature.Installed) {
    Uninstall-WindowsFeature Web-Ftp-Service -Remove -ErrorAction SilentlyContinue | Out-Null
    Write-Output "Removed Microsoft FTP Service (FTPSVC)"
} else {
    Write-Output "Microsoft FTP Service not installed"
}

# -------------------------------
# 5.2 Peer Name Resolution Protocol (PNRPsvc)
# STIG-only: Ensure Not Installed
# -------------------------------
$pnrp = Get-Service PNRPsvc -ErrorAction SilentlyContinue
if ($pnrp) {
    Stop-Service PNRPsvc -Force -ErrorAction SilentlyContinue
    Set-Service PNRPsvc -StartupType Disabled
    Write-Output "Disabled Peer Name Resolution Protocol service"
} else {
    Write-Output "PNRP service not present"
}

# -------------------------------
# 5.3 / 5.4 Print Spooler
# Disabled on both DC and Member Server
# -------------------------------
$spooler = Get-Service Spooler -ErrorAction SilentlyContinue
if ($spooler) {
    Stop-Service Spooler -Force -ErrorAction SilentlyContinue
    Set-Service Spooler -StartupType Disabled
    if ($IsDC) {
        Write-Output "Print Spooler disabled (Domain Controller)"
    } else {
        Write-Output "Print Spooler disabled (Member Server)"
    }
}

# -------------------------------
# 5.5 Simple TCP/IP Services (simptcp)
# STIG-only: Ensure Not Installed
# -------------------------------
$simpleTcp = Get-WindowsFeature Simple-TCPIP -ErrorAction SilentlyContinue
if ($simpleTcp -and $simpleTcp.Installed) {
    Uninstall-WindowsFeature Simple-TCPIP -Remove -ErrorAction SilentlyContinue | Out-Null
    Write-Output "Removed Simple TCP/IP Services"
} else {
    Write-Output "Simple TCP/IP Services not installed"
}

Write-Output "=== System Services Hardening Complete ==="
