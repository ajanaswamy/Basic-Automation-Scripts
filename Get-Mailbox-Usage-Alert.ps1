# Set paths
$reportCsv = "C:\Temp\Team-MailboxReport.csv"
$userCsv   = "C:\Temp\Team-Users.csv"
$DM        = "delivery.manager@domain.com"

# Step 1: Get Mailbox usage info
$mailboxes = Get-Mailbox -ResultSize Unlimited |
    Where-Object { $_.CustomAttribute1 -eq "VendorTeamFilterValue" }

$mailboxStats = foreach ($mb in $mailboxes) {
    $stats = Get-MailboxStatistics $mb.Identity

    $maxQuota = if ($mb.ProhibitSendQuota -ne "Unlimited") {
        [math]::Round($mb.ProhibitSendQuota.Value.ToMB(),1)
    } else { 0 }

    $usedQuota = [math]::Round($stats.TotalItemSize.Value.ToMB(),1)

    [PSCustomObject]@{
        DisplayName        = $mb.DisplayName
        PrimarySmtpAddress = $mb.PrimarySmtpAddress.ToString()
        MaximumQuotaMB     = $maxQuota
        OccupiedQuotaMB    = $usedQuota
    }
}

$mailboxStats | Export-Csv $reportCsv -NoTypeInformation

# Step 2: Load mailbox data and user roles
$mailboxUsage = Import-Csv $reportCsv
$teamUsers    = Import-Csv $userCsv

# Build lookup for Leads
$userLookup = @{}
foreach ($user in $teamUsers) {
    $userLookup[$user.UserPrincipalName.Trim().ToLower()] = @{
        Role  = $user.Role
        Leads = $user.Leads.Trim().ToLower()
    }
}

# Step 3: Alert Logic
foreach ($entry in $mailboxUsage) {

    $email = $entry.PrimarySmtpAddress.Trim().ToLower()

    if (-not $userLookup.ContainsKey($email)) {
        Write-Warning "User $email not found in CSV — skipping."
        continue
    }

    $max  = [double]$entry.MaximumQuotaMB
    $used = [double]$entry.OccupiedQuotaMB

    if ($max -eq 0) { continue }

    $usagePct = [math]::Round(($used / $max) * 100, 2)

    if ($usagePct -lt 80) { continue }

    $remaining = [math]::Round($max - $used, 2)

    $leadEmail = $userLookup[$email].Leads
    if (-not $leadEmail) { continue }

    $subject = "Mailbox Usage Alert – $usagePct% Used – $($entry.DisplayName)"

    $body = @"
Hello,

Mailbox usage has exceeded 80%.

User: $($entry.DisplayName)
Email: $email
Usage: $used MB of $max MB ($usagePct%)
Remaining: $remaining MB

Please review and take appropriate action.

Regards,
Mailbox Monitoring System
"@

    Send-MailMessage `
        -From "mailbox.monitor@domain.com" `
        -To $email `
        -Cc "$leadEmail,$DM" `
        -Subject $subject `
        -Body $body `
        -SmtpServer "smtp.domain.com" `
        -Port 25

    Write-Host "Alert sent → $email ($usagePct%)"
}
