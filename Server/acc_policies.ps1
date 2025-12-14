# Account_Password_Policy.ps1
# Run as Administrator

Write-Output "=== Configuring Password and Account Lockout Policies ==="
# Get current password policy values using `net accounts`
$net = net accounts
$minLength = ([regex]::Match($net, 'Minimum password length\s+(\d+)').Groups[1].Value) -as [int]
$history = ([regex]::Match($net, 'Number of passwords remembered\s+(\d+)').Groups[1].Value) -as [int]
$maxAge = ([regex]::Match($net, 'Maximum password age\s+(\d+)').Groups[1].Value) -as [int]
$minAge = ([regex]::Match($net, 'Minimum password age\s+(\d+)').Groups[1].Value) -as [int]
$lockoutThreshold = ([regex]::Match($net, 'Lockout threshold\s+(\d+)').Groups[1].Value) -as [int]
$lockoutDuration = ([regex]::Match($net, 'Lockout duration \(minutes\)\s+(\d+)').Groups[1].Value) -as [int]
$lockoutWindow = ([regex]::Match($net, 'Lockout observation window \(minutes\)\s+(\d+)').Groups[1].Value) -as [int]

# 1) Enforce password history >=24, length >=14, complexity enabled
if ($history -lt 24 -or $minLength -lt 14 -or $maxAge -gt 90 -or $minAge -lt 1) {
    # Apply secure settings via net accounts
    net accounts /MINPWLEN:14 /MAXPWAGE:90 /MINPWAGE:1 /UNIQUEPW:24
    Write-Output "Set minimum length 14, history 24, max age 90 days, min age 1 day (CIS 1.1.x):contentReference[oaicite:8]{index=8}"
}
# 2) Ensure password complexity is enabled
$secpol = "C:\temp\secpol.cfg"
secedit /export /cfg $secpol
if ((Select-String "PasswordComplexity = 0" $secpol) -ne $null) {
    (Get-Content $secpol) -replace "PasswordComplexity = 0", "PasswordComplexity = 1" | Set-Content $secpol
    secedit /configure /db C:\Windows\Security\Local.sdb /cfg $secpol /areas SECURITYPOLICY
    Write-Output "Enabled password complexity (CIS 1.1.5):contentReference[oaicite:9]{index=9}"
}
Remove-Item $secpol -Force -ErrorAction SilentlyContinue

# 3) Account lockout: threshold <=5, duration >=15, window >=15 (CIS 1.2.x)
if ($lockoutThreshold -lt 5 -or $lockoutWindow -lt 15 -or $lockoutDuration -lt 15) {
    net accounts /lockoutduration:15 /lockoutthreshold:5 /lockoutwindow:15
    Write-Output "Set lockout threshold 5, duration 15 min, reset window 15 min (CIS 1.2.x):contentReference[oaicite:10]{index=10}"
}

# 4) Disable the Guest account (Guest logons are insecure)
if ((Get-LocalUser -Name Guest -ErrorAction SilentlyContinue).Enabled) {
    Disable-LocalUser -Name Guest
    Write-Output "Disabled Guest account (CIS recommendation):contentReference[oaicite:11]{index=11}"
}
