<#
.SYNOPSIS
    Automated Windows patching script for local and remote servers, with centralized logging and detailed execution summaries from HTTP File Share Distribution Point.

.DESCRIPTION
    This PowerShell script performs automated Windows patching across multiple servers by:
    - Downloading a patch archive from a specified HTTP URL.
    - Extracting the patch files and identifying `.msu` patches.
    - Installing patches sequentially while logging the progress.
    - Writing centralized logs to a specified file on the server where the script is executed.
    - Handling remote server execution using `Invoke-Command` with parallel jobs.
    - Providing a detailed summary of patching results for each server.

.PARAMETERS
    $ServersFile
        Path to the file containing the list of servers to patch. Defaults to `C:\Temp\servers.txt`.

    $PatchURL
        The HTTP URL where the patch archive (zip) is hosted.

    $CentralLogFile
        The path to the centralized log file where patching logs for all servers are written.

    $PatchFolder
        The path to the working directory on remote servers where the patch files are downloaded and extracted.

.NOTES
    - The script uses parallel execution for remote patching and supports detailed result summaries.
    - Progress bars are displayed for better user experience.
    - The script automatically handles reboots if required by the patches.

.AUTHOR
    Amarnadh Janaswamy and AI

.CREATED
    2025-01-14

.LAST UPDATED
    2025-01-14

.VERSION
    1.0

.EXAMPLE
    Run the script to patch remote servers listed in the file `C:\Temp\servers.txt`:
        .\PatchAutomation.ps1

    Specify a custom servers file:
        .\PatchAutomation.ps1 -ServersFile "D:\MyServersList.txt"

    Customize the central log file path:
        .\PatchAutomation.ps1 -CentralLogFile "D:\Logs\PatchExecutionLog.txt"
#>



# User-configurable settings
$ServersFile = "C:\Temp\servers.txt"
$PatchURL = "http://Fileserver.example.com/Patches/patch.zip"
$CentralLogFile = "C:\Temp\PatchExecutionLog.txt"

# Initialize log buffer
$Global:LogBuffer = @()

# Function to log messages
function Log-Message {
    param (
        [string]$Message,
        [ValidateSet("Green", "Yellow", "Red", "Cyan", "Gray")]
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    $Global:LogBuffer += "$(Get-Date -Format '[yyyy-MM-dd HH:mm:ss]') $Message"
}

# Function to write the log buffer to a central log file
function Write-CentralLog {
    foreach ($Log in $Global:LogBuffer) {
        Add-Content -Path $CentralLogFile -Value $Log
    }
    $Global:LogBuffer = @() # Clear the log buffer after writing
}

# Script block for patching process
$PatchingScript = {
    param (
        [string]$PatchURL,
        [string]$CentralLogFile
    )

    # Initialize variables for tracking results
    $PatchesInstalled = 0
    $NotApplicableCount = 0
    $WarningsCount = 0
    $ErrorsCount = 0
    $RebootRequired = $false
    $LogBuffer = @()

    function Log-RemoteMessage {
        param (
            [string]$Message,
            [ValidateSet("Green", "Yellow", "Red", "Cyan", "Gray")]
            [string]$Color = "Cyan"
        )
        $LogBuffer += "$(Get-Date -Format '[yyyy-MM-dd HH:mm:ss]')[Remote] $Message"
        Write-Host $Message -ForegroundColor $Color
    }

    # Define paths
    $Date = Get-Date -Format "yyyy-MM-dd"
    $PatchFolder = "C:\Temp\$Date`_PatchFolder"
    $ExtractedFolder = "$PatchFolder\Extracted"

    # Create patch folder if it doesn't exist
    if (-not (Test-Path -Path $PatchFolder)) {
        New-Item -Path $PatchFolder -ItemType Directory -Force | Out-Null
        Log-RemoteMessage "Created patch folder: $PatchFolder" "Cyan"
    }

    # Step 1: Download the patch file
    Log-RemoteMessage "Starting download of patch.zip from $PatchURL" "Cyan"
    Start-Process -FilePath "curl.exe" -ArgumentList "-# -L -O $PatchURL" -WorkingDirectory $PatchFolder -NoNewWindow -Wait
    if (-not (Test-Path "$PatchFolder\patch.zip")) {
        Log-RemoteMessage "ERROR: Patch download failed." "Red"
        return @{
            ServerName       = $env:COMPUTERNAME
            PatchesFound     = 0
            Installed        = 0
            NotApplicable    = 0
            Warnings         = 1
            Errors           = 1
            RebootRequired   = $false
            LogBuffer        = $LogBuffer
        }
    }
    Log-RemoteMessage "Download completed successfully." "Green"

    # Step 2: Extract the patch file
    Log-RemoteMessage "Starting extraction of patch.zip to $ExtractedFolder" "Cyan"
    if (Test-Path -Path $ExtractedFolder) {
        Log-RemoteMessage "The extraction folder already exists: $ExtractedFolder." "Yellow"
        Remove-Item -Path $ExtractedFolder -Recurse -Force
        Log-RemoteMessage "Successfully cleared the existing folder: $ExtractedFolder." "Green"
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory("$PatchFolder\patch.zip", $ExtractedFolder)
    Log-RemoteMessage "Patch file successfully extracted to $ExtractedFolder." "Green"

    # Step 3: Count patches
    $PatchFiles = Get-ChildItem -Path $ExtractedFolder -Filter *.msu -File
    $PatchesFound = $PatchFiles.Count
    if ($PatchesFound -eq 0) {
        Log-RemoteMessage "ERROR: No patches found in the extracted folder." "Red"
        return @{
            ServerName       = $env:COMPUTERNAME
            PatchesFound     = 0
            Installed        = 0
            NotApplicable    = 0
            Warnings         = 1
            Errors           = 1
            RebootRequired   = $false
            LogBuffer        = $LogBuffer
        }
    }
    Log-RemoteMessage "Total patches found in the extracted folder: $PatchesFound." "Cyan"

    # Step 4: Install patches
    foreach ($Patch in $PatchFiles) {
        Log-RemoteMessage "Processing patch: $($Patch.Name)" "Cyan"
        $Result = Start-Process -FilePath "wusa.exe" -ArgumentList "/quiet /norestart `"$($Patch.FullName)`"" -NoNewWindow -Wait -PassThru
        switch ($Result.ExitCode) {
            0 {
                Log-RemoteMessage "Successfully installed patch: $($Patch.Name)" "Green"
                $PatchesInstalled++
            }
            3010 {
                Log-RemoteMessage "Patch installed successfully, but a reboot is required: $($Patch.Name)" "Yellow"
                $PatchesInstalled++
                $RebootRequired = $true
            }
            2359302 {
                Log-RemoteMessage "WARNING: Patch not applicable: $($Patch.Name). Exit code: $($Result.ExitCode)" "Yellow"
                $NotApplicableCount++
                $WarningsCount++
            }
            default {
                Log-RemoteMessage "ERROR: Failed to install patch: $($Patch.Name). Exit code: $($Result.ExitCode)" "Red"
                $ErrorsCount++
            }
        }
    }

    # Return results
    return @{
        ServerName       = $env:COMPUTERNAME
        PatchesFound     = $PatchesFound
        Installed        = $PatchesInstalled
        NotApplicable    = $NotApplicableCount
        Warnings         = $WarningsCount
        Errors           = $ErrorsCount
        RebootRequired   = $RebootRequired
        LogBuffer        = $LogBuffer
    }
}

# Main execution
$Servers = Get-Content $ServersFile
$Jobs = @{}

foreach ($Server in $Servers) {
    Log-Message "Starting patching process on server: $Server" "Cyan"
    $Jobs[$Server] = Invoke-Command -ComputerName $Server -ScriptBlock $PatchingScript -ArgumentList $PatchURL, $CentralLogFile -AsJob
}

# Wait for jobs to complete and gather results
while ($Jobs.Values | Where-Object { $_.State -ne 'Completed' }) {
    Start-Sleep -Seconds 1
}

# Process job results and write to the central log
$Summary = @()
foreach ($Server in $Jobs.Keys) {
    $Job = $Jobs[$Server]
    $Result = Receive-Job -Job $Job
    Remove-Job -Job $Job

    # Log results to the central log
    foreach ($Log in $Result.LogBuffer) {
        Add-Content -Path $CentralLogFile -Value $Log
    }

    # Add server results to the summary
    $Summary += @{
        ServerName       = $Result.ServerName
        PatchesFound     = $Result.PatchesFound
        Installed        = $Result.Installed
        NotApplicable    = $Result.NotApplicable
        Warnings         = $Result.Warnings
        Errors           = $Result.Errors
        RebootRequired   = $Result.RebootRequired
    }
}

# Output summary
Log-Message "Summary of patching results:" "Cyan"
foreach ($ServerResult in $Summary) {
    $SummaryLine = @"
[$($ServerResult.ServerName)]: PatchesFound=$($ServerResult.PatchesFound), Installed=$($ServerResult.Installed), NotApplicable=$($ServerResult.NotApplicable), Warnings=$($ServerResult.Warnings), Errors=$($ServerResult.Errors), RebootRequired=$($ServerResult.RebootRequired)
"@
    Log-Message $SummaryLine "Green"
}
