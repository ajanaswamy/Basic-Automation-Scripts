<#
Author # Amarnadh Janaswamy
.SYNOPSIS
Create Firewall rules within the Windows Firewall.
.DESCRIPTION
This Script creates an Firewall rule entry within the Windows servers #>

# Define the path to the servers list and output CSV file
$serversList = "C:\urPath\servers.txt"
$outputCsv = "C:\urPath\ServerFirewallRules.csv"

# Define the ports you want to open (comma-separated list)
$portsToOpen = "80", "443", "3389"

# Define task number and application name
$taskNumber = "123"
$applicationName = "MyApp"

# Loop through each server and create inbound and outbound rules
foreach ($server in (Get-Content -Path $serversList)) {
    foreach ($port in $portsToOpen) {
        # Inbound rule
        $inboundRuleName = "Inbound Rule - Task $taskNumber - $applicationName - Port $port"
        New-NetFirewallRule -DisplayName $inboundRuleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port

        # Outbound rule
        $outboundRuleName = "Outbound Rule - Task $taskNumber - $applicationName - Port $port"
        New-NetFirewallRule -DisplayName $outboundRuleName -Direction Outbound -Action Allow -Protocol TCP -LocalPort $port
    }
}

Write-Host "Firewall rules for ports $portsToOpen (both inbound and outbound) have been created."
