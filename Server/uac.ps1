# UAC_Hardening.ps1
# Run as Administrator

Write-Output "=== Configuring User Account Control (UAC) ==="
$uacKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
# 1) Run all admins in Admin Approval Mode (FilterAdministratorToken = 1)
Set-ItemProperty -Path $uacKey -Name FilterAdministratorToken -Value 1 -Force
# 2) Prompt on secure desktop for admin approvals (ConsentPromptBehaviorAdmin = 2)
Set-ItemProperty -Path $uacKey -Name ConsentPromptBehaviorAdmin -Value 2 -Force
# 3) Enable secure desktop for prompts (PromptOnSecureDesktop = 1)
Set-ItemProperty -Path $uacKey -Name PromptOnSecureDesktop -Value 1 -Force
Write-Output "Enabled UAC for all admins with secure desktop prompts:contentReference[oaicite:20]{index=20}"
