<#
Author # Amarnadh Janaswamy
Created on # 10/30/2024
.SYNOPSIS
Checks the New Relic Infrastructure Agent service status.
.DESCRIPTION
This Script retrieves the New Relic Infrastructure Agent Service status on a remote Windows servers.
The results are printed on screen On out Grid-view #>

# Define parameters
$ServiceName = "newrelic-infra"
$ServerListPath = "C:\urpath\server.txt"  # Path to server list

# Read server names from the file
$Servers = Get-Content -Path $ServerListPath

# Initialize an array to store results
$ServiceStatus = @()

# Loop through each server and check service status, IP, and ping status
foreach ($Server in $Servers) {
    try {
        # Resolve IP Address
        $IPAddress = [System.Net.Dns]::GetHostAddresses($Server) | Select-Object -First 1

        # Ping the server to check status
        $PingStatus = Test-Connection -ComputerName $Server -Count 1 -Quiet

        # Check service status on each server
        $Service = Get-Service -ComputerName $Server -Name $ServiceName -ErrorAction Stop
        $ServiceState = if ($Service.Status -eq 'Stopped') { 'Stopped' } else { 'Running' }

        # Store the result
        $ServiceStatus += [PSCustomObject]@{
            Server      = $Server
            IPAddress   = $IPAddress.IPAddressToString
            PingStatus  = if ($PingStatus) { 'Online' } else { 'Offline' }
            ServiceName = $ServiceName
            Status      = $ServiceState
        }
    }
    catch {
        Write-Output "Could not retrieve data from $Server. Error: $_"
        $ServiceStatus += [PSCustomObject]@{
            Server      = $Server
            IPAddress   = "N/A"
            PingStatus  = "Error"
            ServiceName = $ServiceName
            Status      = "Error retrieving status"
        }
    }
}

# Display results in Out-GridView and export to CSV
$ServiceStatus | Out-GridView -Title "Current Status of New Relic Agent Service with IP and Ping Status"
$ServiceStatus | Export-Csv -Path "Current_NewRelicAgentServiceStatus.csv" -NoTypeInformation
