# WindowsUpdate_Hardening.ps1
# Run as Administrator

Write-Output "=== Configuring Automatic Windows Updates ==="
$wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (!(Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
# 4 = auto download and schedule install
Set-ItemProperty -Path $wuKey -Name UseWUServer -Value 0 -Force  # use Microsoft Update
Set-ItemProperty -Path $wuKey -Name NoAutoUpdate -Value 0 -Force
Set-ItemProperty -Path $wuKey -Name AUOptions     -Value 4 -Force
Set-ItemProperty -Path $wuKey -Name ScheduledInstallDay  -Value 0 -Force
Set-ItemProperty -Path $wuKey -Name ScheduledInstallTime -Value 3 -Force
Write-Output "Enabled automatic updates (download and scheduled install at 3:00 daily)"
