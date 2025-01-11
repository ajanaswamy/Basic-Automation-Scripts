<#
Author # Amarnadh Janaswamy
.SYNOPSIS
Checks the CrowdStrike and Rapid7 IR agent install status, version, and service state.

.DESCRIPTION
This function retrieves the install status, version, and service state of both CrowdStrike and Rapid7 IR agent on a remote server.
It then prints the server name, IP address, CrowdStrike version, Rapid7 IR agent version, install status, and service state.
The results are exported to a CSV file.#>

function Get-FileVersion {
    param (
        [string]$filePath
    )

    if (Test-Path -Path $filePath -PathType Leaf) {
        return (Get-Item $filePath).VersionInfo.ProductVersion
    } else {
        return "Not Installed"
    }
}
function Check-EndpointStatus {
    param (
        [string]$serverName
    )

    # Get the IP address of the remote server
    $ipAddress = (Test-Connection -ComputerName $serverName -Count 1).IPv4Address.IPAddressToString

    # Get the CrowdStrike service state
    $crowdStrikeService = Get-Service -Name "CSAgent" -ComputerName $serverName
    $crowdStrikeServiceState = if ($crowdStrikeService) { $crowdStrikeService.Status } else { "Service Not Found" }

    # Get the CrowdStrike version using Get-FileVersion function
    $crowdStrikeVersionPath = "C:\Program Files\CrowdStrike\CSFalconService.exe"
    $crowdStrikeVersion = Get-FileVersion -filePath $crowdStrikeVersionPath
    $crowdStrikeInstallStatus = if ($crowdStrikeVersion -ne "Not Installed" -and $crowdStrikeVersion -ne "Service Not Found") { "Installed" } else { $crowdStrikeVersion }

    # Get the Rapid7 IR agent service state
    $rapid7Service = Get-Service -Name "ir_agent" -ComputerName $serverName
    $rapid7ServiceState = if ($rapid7Service) { $rapid7Service.Status } else { "Service Not Found" }

    # Get the Rapid7 IR agent version using Get-FileVersion function, Update the path based on your version
    $rapid7VersionPath1 = "C:\Program Files\Rapid7\Insight Agent\components\insight_agent\4.0.5.26\ir_agent.exe"
    $rapid7VersionPath2 = "C:\Program Files\Rapid7\Insight Agent\components\insight_agent\4.0.4.14\ir_agent.exe"
    $rapid7Version1 = Get-FileVersion -filePath $rapid7VersionPath1
    $rapid7Version2 = Get-FileVersion -filePath $rapid7VersionPath2
    $rapid7InstallStatus = if ($rapid7Version1 -ne "Not Installed" -and $rapid7Version1 -ne "Service Not Found") { "Installed" } else { $rapid7Version1 }

    # Create an object with the collected information
    $resultObject = [PSCustomObject]@{
        "Server Name"             = $serverName
        "IPAddress"              = $ipAddress
        "CSAgent Version"         = $crowdStrikeVersion
        "CSAgent InstallStatus"   = $crowdStrikeInstallStatus
        "CSAgent ServiceState"    = $crowdStrikeServiceState
        "Rapid7 Agent Version1"    = $rapid7Version1
        "Rapid7 Agen tVersion2"    = $rapid7Version2
        "Rapid7 Agent InstallStatus"= $rapid7InstallStatus
        "Rapid7 Agent ServiceState"= $rapid7ServiceState
    }

    # Output the result object
    $resultObject
}

# Input file
$inputFile = "C:\urpath\servers.txt"

# Output file
$outputFile = "C:\urpath\EndpointStatus.csv"

# Create an array to store results
$results = @()

# Read server names from the input file
$servers = Get-Content $inputFile

foreach ($server in $servers) {
    # Call the Check-EndpointStatus function for each server
    $result = Check-EndpointStatus -serverName $server

    # Add the result object to the results array
    $results += $result
}

# Export the results to a CSV file
$results | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Endpoint information collected and saved to $outputFile"


