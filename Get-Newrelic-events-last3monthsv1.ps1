# Define parameters
$LogName = "System"
$EventID = 7036
$ServiceName = "New Relic Infrastructure Agent"
$StartTime = (Get-Date).AddMonths(-3)
$ServerListPath = "C:\Users\ajanaswamy_pa\scripts\server.txt"  # Path to server list

# Read server names from the file
$Servers = Get-Content -Path $ServerListPath

# Initialize an array to store results
$ServiceEvents = @()

# Loop through each server to query logs
foreach ($Server in $Servers) {
    Write-Output "Querying $Server for NewRelic service stop events..."
    try {
        # Retrieve events with specific Event ID in XML format
        $Events = Get-WinEvent -ComputerName $Server -FilterHashtable @{
            LogName = $LogName
            ID = $EventID
            StartTime = $StartTime
        } -ErrorAction Stop | Where-Object {
            # Additional filtering to match the specific service name
            $_.Message -match "$ServiceName.*stopped"
        } | ForEach-Object {
            # Convert each event to XML format to access detailed data
            [xml]$EventXml = $_.ToXml()

            # Extract specific details from the XML structure
            $ServiceEvents += [PSCustomObject]@{
                Computer      = $EventXml.Event.System.Computer
                ServiceName   = $EventXml.Event.EventData.Data[0].'#text'  # First Data element (Service Name)
                ServiceState  = $EventXml.Event.EventData.Data[1].'#text'  # Second Data element (Status, e.g., "stopped")
                TimeCreated   = [datetime]$EventXml.Event.System.TimeCreated.SystemTime  # Convert to normal timestamp
            }
        }
    }
    catch {
        Write-Output "Could not retrieve logs from $Server. Error: $_"
        $ServiceEvents += [PSCustomObject]@{
            Computer     = $Server
            ServiceName  = "N/A"
            ServiceState = "Error retrieving logs"
            TimeCreated  = "N/A"
        }
    }
}

# Display results in table and export to CSV
$ServiceEvents | Format-Table -AutoSize
$ServiceEvents | Export-Csv -Path "NewRelicAgentServiceStopEvents_Last3Months.csv" -NoTypeInformation
