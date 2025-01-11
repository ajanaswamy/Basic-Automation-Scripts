<#
Author # Amarnadh Janaswamy
.SYNOPSIS
Checks the Ping status of your servers.
.DESCRIPTION
This Script pings the list of servers that you want to check if they are online with clear color coding Green as good and Red as offline #>


function Test-PingStatus {
    param (
        [string]$serversList = "C:\urPath\servers.txt",
        [string]$outputCsv = "C:\urPath\pingOutput.csv"
    )

    # Create an empty array to store the results
    $results = @()

    # Read the server names from the servers.txt file
    $servers = Get-Content -Path $serversList

    # Loop through each server and check the ping status
    foreach ($server in $servers) {
        # Perform a ping test to the server
        $pingTest = Test-Connection -ComputerName $server -Count 1 -Quiet
        if ($pingTest) {
            # Server is online, return green status
            $status = "Green"
        } else {
            # Server is offline, return red status
            $status = "Red"
        }

        # Add the results to the array
        $results += New-Object PSObject -Property @{
            ServerName = $server
            PingStatus = $status
        }
    }

    # Export the results to a CSV file
    $results | Export-Csv -Path $outputCsv -NoTypeInformation
}

# Call the function with the path to your servers.txt and desired output CSV file
Test-PingStatus -serversList "C:\Path\To\servers.txt" -outputCsv "C:\Path\To\pingOutput.csv"
