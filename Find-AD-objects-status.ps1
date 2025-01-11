<#
Author # Amarnadh Janaswamy
.SYNOPSIS
Chekcing AD object status.
.DESCRIPTION
This Script retrieves the AD object status from the AD and the output is exported into XL#>

# Import the Active Directory module
Import-Module ActiveDirectory

# Define the path to the servers list and output CSV file
$serversList = "C:\urPath\servers.txt"
$outputCsv = "C:\urPath\ServerStatus.xlsx"

# Create an Excel package using the Export-Excel cmdlet (part of the ImportExcel module)
$excelPackage = @{
    Path = $outputCsv
    AutoSize = $true
}

# Read the server names from the servers.txt file
$servers = Get-Content -Path $serversList

# Create an empty array to store the results
$results = @()

# Loop through each server and check its status in Active Directory and ping status
foreach ($server in $servers) {
    # Try to get the computer object from Active Directory
    $adComputer = Get-ADComputer -Identity $server -ErrorAction SilentlyContinue
    $adStatus = "Not Found"
    $pingStatus = "Offline"

    if ($adComputer) {
        # Check if the computer account is enabled
        $adStatus = if ($adComputer.Enabled) { "Enabled" } else { "Disabled" }
    }

    # Perform a ping test to the server
    $pingTest = Test-Connection -ComputerName $server -Count 1 -Quiet
    if ($pingTest) {
        $pingStatus = "Online"
    }

    # Add the results to the array
    $results += New-Object PSObject -Property @{
        ServerName = $server
        ADStatus = $adStatus
        PingStatus = $pingStatus
    }
}

# Export the results to a CSV file and then open in Excel
$results | Export-Csv -Path $outputCsv -NoTypeInformation
Invoke-Item $outputCsv
