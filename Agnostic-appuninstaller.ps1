<#
Author # Amarnadh Janaswamy
.SYNOPSIS
Agnostic Applictaion uninstall script.

.DESCRIPTION
This Script retrieves the Applications that are installed on a server from Registry and Wmi sources.
Applist is shown in outgird-view and waits for user selection that which applications user want to uninstall.
Post selection it will take a confirmation to proceed with silent uninstallation showing the progress onscreen along with onscreen logs
The logs are exported to a CSV file.#>


# Define Registry Paths for installed applications
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# Store detected applications
$ApplicationsFound = @()

# Function to Retrieve Installed Applications
function Get-InstalledApplications {
    Write-Host "`nScanning installed applications... Please wait.`n" -ForegroundColor Cyan

    # Fetch applications from Registry
    foreach ($Path in $RegistryPaths) {
        Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | ForEach-Object {
            $AppName = $_.GetValue("DisplayName")
            $UninstallString = $_.GetValue("UninstallString")
            if ($AppName -and $UninstallString) {
                $ApplicationsFound += [PSCustomObject]@{
                    Name            = $AppName
                    UninstallString = $UninstallString
                    Source          = "Registry"
                }
            }
        }
    }

    # Fetch applications from WMI
    $WMIApps = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | ForEach-Object {
        $ApplicationsFound += [PSCustomObject]@{
            Name            = $_.Name
            UninstallString = "MsiExec.exe /X$($_.IdentifyingNumber) /quiet /norestart"
            Source          = "WMI"
        }
    }

    # Display applications in GridView for selection
    if ($ApplicationsFound.Count -gt 0) {
        Write-Host "`nDetected Applications:`n" -ForegroundColor Green
        $SelectedApps = $ApplicationsFound | Out-GridView -Title "Select Applications to Uninstall" -PassThru
        return $SelectedApps
    } else {
        Write-Host "No applications found." -ForegroundColor Yellow
        exit
    }
}

# Function to Ensure Silent Uninstall Flags Are Applied
function Get-SilentUninstallCommand {
    param (
        [string]$UninstallCmd
    )

    # Force silent uninstall flags for known applications
    if ($UninstallCmd -match "unins000.exe") {
        return "$UninstallCmd /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
    }
    elseif ($UninstallCmd -match "MsiExec.exe") {
        if ($UninstallCmd -notmatch "/quiet") {
            return "$UninstallCmd /quiet /norestart"
        }
    }
    else {
        if ($UninstallCmd -notmatch "/S|/silent|/quiet") {
            return "$UninstallCmd /S"
        }
    }

    return $UninstallCmd
}

# Function to Verify Uninstallation
function Verify-ApplicationUninstall {
    param (
        [string]$AppName
    )

    # Re-scan installed applications
    $UpdatedList = @()
    foreach ($Path in $RegistryPaths) {
        Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.GetValue("DisplayName") -eq $AppName) {
                $UpdatedList += $AppName
            }
        }
    }

    # Re-check in WMI
    $WMIResult = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $AppName }

    if ($UpdatedList.Count -eq 0 -and -not $WMIResult) {
        return $true  # Uninstalled successfully
    } else {
        return $false # Still exists
    }
}

# Function to Uninstall Selected Applications with Progress Bar
function Uninstall-Applications {
    param (
        [array]$SelectedApps
    )

    $Results = @()
    $TotalApps = $SelectedApps.Count
    $Counter = 0

    foreach ($App in $SelectedApps) {
        $Counter++
        $ProgressPercent = ($Counter / $TotalApps) * 100

        # Show progress bar
        Write-Progress -Activity "Uninstalling Applications" -Status "Processing: $($App.Name)" -PercentComplete $ProgressPercent

        Write-Host "`n[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Uninstalling $($App.Name)..." -ForegroundColor Cyan

        # Ensure Silent Parameters Are Applied
        $UninstallCmd = Get-SilentUninstallCommand -UninstallCmd $App.UninstallString
        Write-Host "Executing: $UninstallCmd"

        try {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c $UninstallCmd" -Wait -NoNewWindow

            # Wait briefly before verification
            Start-Sleep -Seconds 3  

            # Verify if the application is still installed
            if (Verify-ApplicationUninstall -AppName $App.Name) {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($App.Name) uninstalled successfully!" -ForegroundColor Green
                $Results += [PSCustomObject]@{
                    Application = $App.Name
                    Status      = "Uninstalled"
                    Timestamp   = Get-Date
                }
            } else {
                Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Uninstallation of $($App.Name) failed! Application still detected." -ForegroundColor Red
                $Results += [PSCustomObject]@{
                    Application = $App.Name
                    Status      = "Failed"
                    Timestamp   = Get-Date
                }
            }
        } catch {
            Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Error uninstalling $($App.Name). $_" -ForegroundColor Red
            $Results += [PSCustomObject]@{
                Application = $App.Name
                Status      = "Error: $_"
                Timestamp   = Get-Date
            }
        }

        # Update progress bar
        Write-Progress -Activity "Uninstalling Applications" -Status "Completed: $Counter of $TotalApps" -PercentComplete $ProgressPercent
    }

    # Close progress bar
    Write-Progress -Activity "Uninstalling Applications" -Completed

    # Export results to CSV
    $Results | Export-Csv -Path "C:\Users\ajanaswamy_pa\scripts\Uninstall_Applications_Results.csv" -NoTypeInformation -Force
    Write-Host "`nResults exported to Uninstall_Applications_Results.csv" -ForegroundColor Green
}

# Main Execution Flow
$SelectedApps = Get-InstalledApplications

if ($SelectedApps.Count -gt 0) {
    Write-Host "`nYou selected the following applications for uninstallation:" -ForegroundColor Yellow
    $SelectedApps | ForEach-Object { Write-Host "- $($_.Name)" -ForegroundColor Green }
    
    $Confirm = Read-Host "`nType 'Y' to confirm uninstallation"
    if ($Confirm -eq 'Y') {
        Uninstall-Applications -SelectedApps $SelectedApps
    } else {
        Write-Host "Uninstallation canceled." -ForegroundColor Cyan
    }
} else {
    Write-Host "`nNo applications selected." -ForegroundColor Red
}
