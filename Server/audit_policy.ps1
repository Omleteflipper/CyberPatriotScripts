Write-Host "Applying Advanced Audit Policy (CIS Section 17)..."

# Detect Domain Controller
$IsDC = (Get-WmiObject Win32_ComputerSystem).DomainRole -ge 4

# Helper function
function Set-AuditPolicy {
    param (
        [string]$Category,
        [string]$Setting
    )
    auditpol /set /subcategory:"$Category" $Setting | Out-Null
}

############################
# 17.1 Account Logon
############################
Set-AuditPolicy "Credential Validation" "/success:enable /failure:enable"

if ($IsDC) {
    Set-AuditPolicy "Kerberos Authentication Service" "/success:enable /failure:enable"
    Set-AuditPolicy "Kerberos Service Ticket Operations" "/success:enable /failure:enable"
}

############################
# 17.2 Account Management
############################
Set-AuditPolicy "Application Group Management" "/success:enable /failure:enable"
Set-AuditPolicy "Security Group Management" "/success:enable"
Set-AuditPolicy "User Account Management" "/success:enable /failure:enable"

if ($IsDC) {
    Set-AuditPolicy "Computer Account Management" "/success:enable"
    Set-AuditPolicy "Distribution Group Management" "/success:enable"
    Set-AuditPolicy "Other Account Management Events" "/success:enable"
}

############################
# 17.3 Detailed Tracking
############################
Set-AuditPolicy "Plug and Play Events" "/success:enable"
Set-AuditPolicy "Process Creation" "/success:enable"

############################
# 17.4 DS Access (DC only)
############################
if ($IsDC) {
    Set-AuditPolicy "Directory Service Access" "/failure:enable"
    Set-AuditPolicy "Directory Service Changes" "/success:enable"
}

############################
# 17.5 Logon/Logoff
############################
Set-AuditPolicy "Account Lockout" "/failure:enable"
Set-AuditPolicy "Group Membership" "/success:enable"
Set-AuditPolicy "Logoff" "/success:enable"
Set-AuditPolicy "Logon" "/success:enable /failure:enable"
Set-AuditPolicy "Other Logon/Logoff Events" "/success:enable /failure:enable"
Set-AuditPolicy "Special Logon" "/success:enable"

############################
# 17.6 Object Access
############################
Set-AuditPolicy "Detailed File Share" "/failure:enable"
Set-AuditPolicy "File Share" "/success:enable /failure:enable"
Set-AuditPolicy "Other Object Access Events" "/success:enable /failure:enable"
Set-AuditPolicy "Removable Storage" "/success:enable /failure:enable"

############################
# 17.7 Policy Change
############################
Set-AuditPolicy "Audit Policy Change" "/success:enable"
Set-AuditPolicy "Authentication Policy Change" "/success:enable"
Set-AuditPolicy "Authorization Policy Change" "/success:enable"
Set-AuditPolicy "MPSSVC Rule-Level Policy Change" "/success:enable /failure:enable"
Set-AuditPolicy "Other Policy Change Events" "/failure:enable"

############################
# 17.8 Privilege Use
############################
Set-AuditPolicy "Sensitive Privilege Use" "/success:enable /failure:enable"

############################
# 17.9 System
############################
Set-AuditPolicy "IPsec Driver" "/success:enable /failure:enable"
Set-AuditPolicy "Other System Events" "/success:enable /failure:enable"
Set-AuditPolicy "Security State Change" "/success:enable"
Set-AuditPolicy "Security System Extension" "/success:enable"
Set-AuditPolicy "System Integrity" "/success:enable /failure:enable"

Write-Host "Advanced Audit Policy successfully applied."
