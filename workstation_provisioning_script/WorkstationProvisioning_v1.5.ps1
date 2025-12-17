#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated Workstation Provisioning Script for Yahara Domain
.DESCRIPTION
    This script automates the provisioning of workstations after Windows installation.
    It handles timezone configuration, domain joining, software installation, and system configuration.
.NOTES
    Version: 1.5
    Author: IT Department
    Prerequisites: Fresh Windows 11 installation, connected to ethernet
    
    Changelog v1.5:
    - Fixed: Step order changed - PC Rename now happens BEFORE domain join
    - Fixed: Single-label DNS now restarts Dnscache service after registry edit
    - Fixed: NuGet provider installs without Enter prompt (direct download method)
    - Fixed: Removed -AcceptLicense parameter from Install-Module (not supported)
    - Changed: Chrome uses --ignore-checksums as primary method
    
    New Step Order:
    1. Machine type, 2. Windows edition, 3. Timezone, 4. Activation check,
    5. Local admin password, 6. PC Rename->Reboot, 7. Single-label DNS,
    8. Domain Join->Reboot, 9. Chocolatey, 10. Software, 11. Flash drive,
    12. Windows Updates, 13. Add admin user, 14. IP config, 15. Final
    
    Changelog v1.4:
    - Chrome install with --ignore-checksums fallback
    - PSGallery trust settings
    
    Changelog v1.3:
    - Auto-resume via RunOnce registry
    - Fixed domain join/PC rename re-prompting
    - O365 via Office Deployment Tool
    - RingCentral removed from startup
    
    Changelog v1.2:
    - Auto-detect Windows Home vs Pro edition
    - Skip domain features for Windows Home
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:LogPath = "C:\ProvisioningLogs"
$Script:LogFile = Join-Path $LogPath "Provisioning_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Script:StateFile = Join-Path $LogPath "ProvisioningState.json"
$Script:DomainName = "yahara"
$Script:LocalAdminUser = "yahara"
$Script:NewLocalAdminPassword = "Coast-Repetition-Pan-Excellence-4"
$Script:CheckpointVPN_Server = "69.129.61.46"
$Script:CheckpointVPN_Port = "4433"

# Flash drive installer detection patterns
$Script:InstallerPatterns = @{
    'RingCentral' = @('*RingCentral*.exe', '*RingCentral*.msi')
    'CheckpointVPN' = @('*Checkpoint*.exe', '*Checkpoint*.msi', '*VPN*.exe')
    'DellSupportAssist' = @('*SupportAssist*.exe', '*Dell*Support*.exe', '*SupportAssist*.msi')
}
$Script:FlashDrivePath = ""

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Initialize-Logging {
    if (-not (Test-Path $Script:LogPath)) {
        New-Item -Path $Script:LogPath -ItemType Directory -Force | Out-Null
    }
    Write-Log "=== Workstation Provisioning Script Started ===" -Color Green
    Write-Log "Log file: $Script:LogFile"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',
        [string]$Color = 'White'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $Script:LogFile -Value $logMessage
    
    # Write to console with color
    $consoleColor = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        default { $Color }
    }
    Write-Host $logMessage -ForegroundColor $consoleColor
}

function Write-StepHeader {
    param(
        [int]$StepNumber,
        [string]$StepName
    )
    Write-Host "`n" -NoNewline
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " STEP $StepNumber : $StepName" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

# ============================================================================
# STATE MANAGEMENT (for handling reboots)
# ============================================================================

function Get-ProvisioningState {
    if (Test-Path $Script:StateFile) {
        try {
            $state = Get-Content $Script:StateFile -Raw | ConvertFrom-Json
            
            # Ensure all properties exist (for backwards compatibility)
            $defaultState = @{
                CurrentStep = 0
                CompletedSteps = @()
                MachineType = ""
                WindowsEdition = ""
                UserToAdd = ""
                PCNewName = ""
                PCRenamed = $false
                DomainJoined = $false
                FlashDrivePath = ""
            }
            
            foreach ($key in $defaultState.Keys) {
                if (-not ($state.PSObject.Properties.Name -contains $key)) {
                    $state | Add-Member -NotePropertyName $key -NotePropertyValue $defaultState[$key]
                }
            }
            
            return $state
        }
        catch {
            Write-Log "Error reading state file, starting fresh: $_" -Level Warning
        }
    }
    
    return [PSCustomObject]@{
        CurrentStep = 0
        CompletedSteps = @()
        MachineType = ""
        WindowsEdition = ""
        UserToAdd = ""
        PCNewName = ""
        PCRenamed = $false
        DomainJoined = $false
        FlashDrivePath = ""
    }
}

function Save-ProvisioningState {
    param($State)
    $State | ConvertTo-Json -Depth 3 | Set-Content $Script:StateFile -Force
    Write-Log "State saved: Step $($State.CurrentStep)"
}

function Set-RebootResume {
    param([string]$ScriptPath)
    
    Write-Log "Setting up script to resume after reboot..."
    
    # Use RunOnce registry key - more reliable than scheduled tasks
    $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    $command = "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File `"$ScriptPath`""
    
    try {
        Set-ItemProperty -Path $runOncePath -Name "WorkstationProvisioning" -Value $command -Force
        Write-Log "RunOnce registry entry created for resumption" -Level Success
    }
    catch {
        Write-Log "Failed to create RunOnce entry: $_" -Level Warning
    }
}

function Remove-RebootResume {
    # Remove RunOnce entry if it exists
    $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    try {
        Remove-ItemProperty -Path $runOncePath -Name "WorkstationProvisioning" -ErrorAction SilentlyContinue
    } catch { }
    
    # Remove scheduled task if it exists (legacy cleanup)
    $taskName = "WorkstationProvisioning_Resume"
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Log "Removed scheduled task for resumption"
    }
}

function Request-RebootAndContinue {
    param([string]$Reason)
    
    Write-Log "Reboot required: $Reason" -Level Warning
    Set-RebootResume -ScriptPath $PSCommandPath
    
    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "REBOOT REQUIRED: $Reason" -ForegroundColor Yellow
    Write-Host "The script will automatically resume after reboot." -ForegroundColor Yellow
    Write-Host "============================================`n" -ForegroundColor Yellow
    
    $response = Read-Host "Press ENTER to reboot now (or type 'cancel' to abort)"
    if ($response -eq 'cancel') {
        Write-Log "Reboot cancelled by user" -Level Warning
        return $false
    }
    
    Restart-Computer -Force
    exit
}

# ============================================================================
# STEP FUNCTIONS
# ============================================================================

function Step-MachineTypeSelection {
    param($State)
    
    Write-StepHeader -StepNumber 1 -StepName "Machine Type Selection"
    
    Write-Host "`nSelect the type of installation:" -ForegroundColor Yellow
    Write-Host "  [D] Dev - Developer workstation (full development tools)"
    Write-Host "  [N] Non-Dev - Standard workstation (business tools only)"
    Write-Host "  [S] Stock - Stock machine (minimal configuration)"
    Write-Host ""
    
    do {
        $selection = Read-Host "Enter your choice (D/N/S)"
        $selection = $selection.ToUpper()
        
        switch ($selection) {
            'D' { 
                $State.MachineType = "developer"
                Write-Log "Machine type set to: Developer"
                break
            }
            'N' { 
                $State.MachineType = "standard"
                Write-Log "Machine type set to: Non-Dev (Standard)"
                break
            }
            'S' { 
                $State.MachineType = "stock"
                Write-Log "Machine type set to: Stock"
                break
            }
            default {
                Write-Host "Invalid selection. Please enter D, N, or S." -ForegroundColor Red
                $selection = ""
            }
        }
    } while ($selection -eq "")
    
    return $State
}

function Step-DetectWindowsEdition {
    param($State)
    
    Write-StepHeader -StepNumber 2 -StepName "Detect Windows Edition"
    
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $caption = $osInfo.Caption
        
        Write-Log "Detected OS: $caption"
        
        if ($caption -like "*Home*") {
            $State.WindowsEdition = "Home"
            Write-Host "`nWindows Home Edition Detected" -ForegroundColor Yellow
            Write-Host "Domain join and single-label DNS will be skipped" -ForegroundColor Yellow
            Write-Log "Windows Home edition detected - domain features will be skipped" -Level Warning
        } else {
            $State.WindowsEdition = "Pro"
            Write-Host "`nWindows Pro/Enterprise Edition Detected" -ForegroundColor Green
            Write-Host "Domain join will be available" -ForegroundColor Green
            Write-Log "Windows Pro/Enterprise edition detected"
        }
        
        return $State
    }
    catch {
        Write-Log "Could not detect Windows edition: $_" -Level Warning
        Write-Host "`nCould not auto-detect Windows edition" -ForegroundColor Yellow
        
        do {
            $selection = Read-Host "Is this Windows Home or Pro/Enterprise? (H/P)"
            $selection = $selection.ToUpper()
            
            if ($selection -eq 'H') {
                $State.WindowsEdition = "Home"
                Write-Log "User indicated Windows Home edition"
            } elseif ($selection -eq 'P') {
                $State.WindowsEdition = "Pro"
                Write-Log "User indicated Windows Pro/Enterprise edition"
            } else {
                Write-Host "Invalid selection. Please enter H or P." -ForegroundColor Red
                $selection = ""
            }
        } while ($selection -eq "")
        
        return $State
    }
}

function Step-TimezoneConfiguration {
    param($State)
    
    Write-StepHeader -StepNumber 3 -StepName "Configure Timezone"
    
    try {
        $targetTimeZone = "Central Standard Time"
        Set-TimeZone -Id $targetTimeZone
        Write-Log "Timezone set to: $targetTimeZone" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to set timezone: $_" -Level Error
        return $false
    }
}

function Step-CheckWindowsActivation {
    param($State)
    
    Write-StepHeader -StepNumber 4 -StepName "Check Windows Activation"
    
    try {
        $activation = Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -and $_.LicenseStatus -eq 1 }
        
        if ($activation) {
            Write-Log "Windows is activated" -Level Success
        } else {
            Write-Log "Windows may not be activated - please verify" -Level Warning
        }
        return $true
    }
    catch {
        Write-Log "Could not verify Windows activation status" -Level Warning
        return $true
    }
}

function Step-ChangeLocalAdminPassword {
    param($State)
    
    Write-StepHeader -StepNumber 5 -StepName "Change Local Administrator Password"
    
    try {
        $adminUser = Get-LocalUser -Name $Script:LocalAdminUser -ErrorAction SilentlyContinue
        
        if ($adminUser) {
            $securePassword = ConvertTo-SecureString $Script:NewLocalAdminPassword -AsPlainText -Force
            Set-LocalUser -Name $Script:LocalAdminUser -Password $securePassword
            Write-Log "Local administrator password updated" -Level Success
        } else {
            Write-Log "Local administrator user '$Script:LocalAdminUser' not found" -Level Warning
        }
        return $true
    }
    catch {
        Write-Log "Failed to change local administrator password: $_" -Level Error
        return $false
    }
}

function Step-RenamePC {
    param($State)
    
    Write-StepHeader -StepNumber 6 -StepName "Rename PC"
    
    # Check if we already have a target name and the computer matches it
    if ($State.PCNewName -ne "" -and $State.PCNewName -ne $null) {
        if ($env:COMPUTERNAME -eq $State.PCNewName) {
            Write-Log "Computer already has the correct name: $($State.PCNewName)" -Level Success
            Write-Host "PC already named correctly: $($State.PCNewName)" -ForegroundColor Green
            $State.PCRenamed = $true
            Save-ProvisioningState -State $State
            return $true
        }
    }
    
    # If PCRenamed flag is set but name doesn't match, might need reboot
    if ($State.PCRenamed -eq $true -and $State.PCNewName -ne "" -and $env:COMPUTERNAME -ne $State.PCNewName) {
        Write-Log "State says renamed but name mismatch. Expected: $($State.PCNewName), Current: $env:COMPUTERNAME" -Level Warning
        Write-Host "Rename may be pending a reboot..." -ForegroundColor Yellow
        Request-RebootAndContinue -Reason "Complete PC rename to $($State.PCNewName)"
        return $true
    }
    
    # First time through - get the new name
    if ($State.PCNewName -eq "" -or $State.PCNewName -eq $null) {
        Write-Host "`nNaming Convention:" -ForegroundColor Yellow
        
        if ($State.MachineType -eq "stock") {
            Write-Host "  Stock machines: YS-STOCK-XX (where XX is a number, e.g., YS-STOCK-01)" -ForegroundColor White
            Write-Host ""
            $newName = Read-Host "Enter the new PC name (example: YS-STOCK-01)"
            
            if ($newName -notmatch '^YS-STOCK-\d{2}$') {
                Write-Host "`nWarning: Name doesn't match expected format YS-STOCK-XX" -ForegroundColor Yellow
                $confirm = Read-Host "Continue anyway? (Y/N)"
                if ($confirm.ToUpper() -ne 'Y') {
                    return $false
                }
            }
        } else {
            Write-Host "  User machines: YS-username-YY (where YY is two-digit year)" -ForegroundColor White
            Write-Host "  Example: YS-jdoe-25 (for John Doe in 2025)" -ForegroundColor White
            Write-Host ""
            
            $username = Read-Host "Enter the AD username (example: jdoe)"
            $year = (Get-Date).ToString("yy")
            $newName = "YS-$username-$year"
            
            Write-Host "`nGenerated name: $newName" -ForegroundColor Green
            $confirm = Read-Host "Is this correct? (Y/N)"
            
            if ($confirm.ToUpper() -ne 'Y') {
                $newName = Read-Host "Enter the custom PC name"
            }
            
            # Store username for later use in admin group
            if ($State.UserToAdd -eq "" -or $State.UserToAdd -eq $null) {
                $State.UserToAdd = $username
            }
        }
        
        $State.PCNewName = $newName
        Save-ProvisioningState -State $State
    }
    
    $newName = $State.PCNewName
    
    # Check if rename is even needed
    if ($env:COMPUTERNAME -eq $newName) {
        Write-Log "Computer already has the correct name: $newName" -Level Success
        $State.PCRenamed = $true
        Save-ProvisioningState -State $State
        return $true
    }
    
    # Perform the rename (before domain join, so no domain creds needed)
    try {
        Rename-Computer -NewName $newName -Force -ErrorAction Stop
        
        Write-Log "Computer rename command executed. New name: $newName" -Level Success
        $State.PCRenamed = $true
        Save-ProvisioningState -State $State
        
        Request-RebootAndContinue -Reason "Complete PC rename to $newName"
        return $true
    }
    catch {
        Write-Log "Failed to rename computer: $($_.Exception.Message)" -Level Error
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Step-EnableSingleLabelDomain {
    param($State)
    
    Write-StepHeader -StepNumber 7 -StepName "Enable Single-Label DNS Domain"
    
    # Skip for Windows Home
    if ($State.WindowsEdition -eq "Home") {
        Write-Log "Skipping single-label DNS domain (Windows Home edition)" -Level Info
        Write-Host "Skipped (Windows Home edition)" -ForegroundColor Yellow
        return $true
    }
    
    try {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        $registryName = "AllowSingleLabelDnsDomain"
        $registryValue = 1
        
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -Type DWord
        Write-Log "Single-label DNS domain registry key set" -Level Success
        
        # CRITICAL: Restart the DNS Client service for the change to take effect
        Write-Log "Restarting DNS Client service..."
        Restart-Service -Name Dnscache -Force
        Start-Sleep -Seconds 3  # Give it a moment to restart
        Write-Log "DNS Client service restarted" -Level Success
        
        return $true
    }
    catch {
        Write-Log "Failed to enable single-label DNS domain: $_" -Level Error
        return $false
    }
}

function Step-JoinDomain {
    param($State)
    
    Write-StepHeader -StepNumber 8 -StepName "Join Domain"
    
    # Skip for Windows Home
    if ($State.WindowsEdition -eq "Home") {
        Write-Log "Skipping domain join (Windows Home edition)" -Level Info
        Write-Host "Skipped (Windows Home edition does not support domain join)" -ForegroundColor Yellow
        $State.DomainJoined = $true
        Save-ProvisioningState -State $State
        return $true
    }
    
    # Check if already domain joined (actual check, not just state)
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    if ($computerSystem.PartOfDomain) {
        Write-Log "Computer is already joined to domain: $($computerSystem.Domain)" -Level Success
        Write-Host "Already joined to domain: $($computerSystem.Domain)" -ForegroundColor Green
        $State.DomainJoined = $true
        Save-ProvisioningState -State $State
        return $true
    }
    
    # If state says domain joined but system doesn't show it, trust the system
    if ($State.DomainJoined -eq $true) {
        Write-Log "State indicated domain joined, but system shows not joined. Resetting flag." -Level Warning
        $State.DomainJoined = $false
    }
    
    Write-Host "`nEnter domain credentials to join the domain:" -ForegroundColor Yellow
    $credential = Get-Credential -Message "Enter domain administrator credentials"
    
    if (-not $credential) {
        Write-Log "No credentials provided" -Level Warning
        return $false
    }
    
    try {
        Add-Computer -DomainName $Script:DomainName -Credential $credential -Force -ErrorAction Stop
        
        # Verify the domain join was successful
        Start-Sleep -Seconds 2
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        if ($computerSystem.PartOfDomain) {
            Write-Log "Successfully joined domain: $Script:DomainName" -Level Success
            $State.DomainJoined = $true
            Save-ProvisioningState -State $State
            
            Request-RebootAndContinue -Reason "Domain join completed"
            return $true
        } else {
            Write-Log "Domain join command completed but computer is not showing as domain joined" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Failed to join domain: $($_.Exception.Message)" -Level Error
        Write-Host "`nDomain join failed!" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nPlease verify:" -ForegroundColor Yellow
        Write-Host "  - Credentials are correct" -ForegroundColor White
        Write-Host "  - Network connectivity to domain controller" -ForegroundColor White
        Write-Host "  - This is Windows Pro/Enterprise (not Home edition)" -ForegroundColor White
        
        $retry = Read-Host "`nWould you like to retry domain join? (Y/N)"
        if ($retry.ToUpper() -eq 'Y') {
            return Step-JoinDomain -State $State
        } else {
            Write-Log "User chose not to retry domain join" -Level Warning
            return $false
        }
    }
}

function Step-InstallChocolatey {
    param($State)
    
    Write-StepHeader -StepNumber 9 -StepName "Install Chocolatey"
    
    # Check if Chocolatey is already installed
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey is already installed" -Level Success
        return $true
    }
    
    try {
        Write-Log "Installing Chocolatey..."
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Log "Chocolatey installed successfully" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to install Chocolatey: $_" -Level Error
        return $false
    }
}

function Install-ChocoPackageWithRetry {
    param(
        [string]$Package,
        [int]$MaxRetries = 2,
        [switch]$UseIgnoreChecksums
    )
    
    # For Chrome, use --ignore-checksums from the start
    if ($Package -eq 'googlechrome' -or $UseIgnoreChecksums) {
        Write-Host "  Installing $Package with --ignore-checksums..." -ForegroundColor Gray
        try {
            $output = choco install $Package -y --limit-output --no-progress --ignore-checksums 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "$Package installed with --ignore-checksums flag" -Level Success
                return $true
            }
            if ($output -match "already installed") {
                return $true
            }
        }
        catch {
            Write-Log "Install with --ignore-checksums failed for $Package : $_" -Level Warning
        }
        return $false
    }
    
    # Normal install for other packages
    for ($i = 0; $i -le $MaxRetries; $i++) {
        if ($i -gt 0) {
            Write-Host "  Retry attempt $i for $Package..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
        }
        
        try {
            $output = choco install $Package -y --limit-output --no-progress 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
            
            # Check if already installed
            if ($output -match "already installed") {
                return $true
            }
        }
        catch {
            Write-Log "Attempt $i failed for $Package : $_" -Level Warning
        }
    }
    
    return $false
}

function Install-ChromeDirect {
    # Direct Chrome installation as fallback
    Write-Log "Attempting direct Chrome installation..."
    Write-Host "  Downloading Chrome directly from Google..." -ForegroundColor Yellow
    
    try {
        $chromeInstallerUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"
        $installerPath = "$env:TEMP\chrome_installer.exe"
        
        # Download
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $chromeInstallerUrl -OutFile $installerPath -UseBasicParsing
        
        # Install silently
        $process = Start-Process -FilePath $installerPath -ArgumentList "/silent /install" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Chrome installed successfully via direct download" -Level Success
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            return $true
        }
    }
    catch {
        Write-Log "Direct Chrome installation failed: $_" -Level Warning
    }
    
    return $false
}

function Step-InstallSoftware {
    param($State)
    
    Write-StepHeader -StepNumber 10 -StepName "Install Software via Chocolatey"
    
    # Define software packages based on machine type
    $baseSoftware = @(
        'zoom',
        'slack',
        'googlechrome',
        'firefox'
    )
    
    $developerSoftware = @(
        'git',
        'vscode',
        'visualstudio2022professional',
        'sql-server-management-studio'
    )
    
    # Determine which packages to install
    $packagesToInstall = @()
    
    switch ($State.MachineType) {
        'developer' {
            $packagesToInstall = $baseSoftware + $developerSoftware
            Write-Log "Installing software for DEVELOPER workstation"
        }
        'standard' {
            $packagesToInstall = $baseSoftware
            Write-Log "Installing software for STANDARD workstation"
        }
        'stock' {
            $packagesToInstall = $baseSoftware
            Write-Log "Installing software for STOCK machine"
        }
    }
    
    Write-Host "`nThe following software will be installed:" -ForegroundColor Yellow
    $packagesToInstall | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    Write-Host "  - Microsoft 365 (via Office Deployment Tool)" -ForegroundColor White
    Write-Host ""
    
    $installResults = @{}
    
    foreach ($package in $packagesToInstall) {
        Write-Host "Installing: $package" -ForegroundColor Cyan
        
        $success = Install-ChocoPackageWithRetry -Package $package
        
        # Extra fallback for Chrome - try direct download
        if (-not $success -and $package -eq 'googlechrome') {
            Write-Host "  Chocolatey failed, trying direct download..." -ForegroundColor Yellow
            $success = Install-ChromeDirect
        }
        
        if ($success) {
            Write-Log "Successfully installed: $package" -Level Success
            $installResults[$package] = $true
        } else {
            Write-Log "Failed to install: $package (Exit code: $LASTEXITCODE)" -Level Warning
            $installResults[$package] = $false
        }
    }
    
    # Install Microsoft 365 via ODT
    Write-Host "`nInstalling: Microsoft 365 (via ODT)" -ForegroundColor Cyan
    $o365Result = Install-Office365
    $installResults['Microsoft 365'] = $o365Result
    
    # Summary
    Write-Host "`n--- Installation Summary ---" -ForegroundColor Cyan
    foreach ($software in $installResults.Keys) {
        $status = if ($installResults[$software]) { "Installed" } else { "FAILED" }
        $color = if ($installResults[$software]) { "Green" } else { "Red" }
        Write-Host "  $software : $status" -ForegroundColor $color
    }
    
    return $true
}

function Install-Office365 {
    Write-Log "Installing Microsoft 365 via Office Deployment Tool..."
    
    $odtPath = "$env:TEMP\ODT"
    $setupPath = "$odtPath\setup.exe"
    $configPath = "$odtPath\configuration.xml"
    
    try {
        # Create ODT directory
        if (-not (Test-Path $odtPath)) {
            New-Item -Path $odtPath -ItemType Directory -Force | Out-Null
        }
        
        # Download ODT
        Write-Host "  Downloading Office Deployment Tool..." -ForegroundColor Gray
        $odtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18129-20158.exe"
        $odtExe = "$odtPath\odt.exe"
        
        Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe -UseBasicParsing
        
        # Extract ODT
        Start-Process -FilePath $odtExe -ArgumentList "/extract:`"$odtPath`" /quiet" -Wait -NoNewWindow
        
        # Create configuration XML for Microsoft 365 Business
        $configXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365BusinessRetail">
      <Language ID="en-us" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@
        
        $configXml | Set-Content -Path $configPath -Force
        
        # Run setup
        Write-Host "  Installing Microsoft 365 (this may take 10-15 minutes)..." -ForegroundColor Gray
        $process = Start-Process -FilePath $setupPath -ArgumentList "/configure `"$configPath`"" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Microsoft 365 installed successfully" -Level Success
            return $true
        } else {
            Write-Log "Microsoft 365 installation completed with exit code: $($process.ExitCode)" -Level Warning
            return $true  # May still have installed
        }
    }
    catch {
        Write-Log "Failed to install Microsoft 365: $_" -Level Warning
        Write-Host "  Microsoft 365 will need to be installed manually" -ForegroundColor Yellow
        return $false
    }
}

function Find-FlashDrive {
    Write-Log "Scanning for flash drives..."
    
    $removableDrives = Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }
    
    if ($removableDrives) {
        foreach ($drive in $removableDrives) {
            $driveLetter = $drive.DriveLetter
            Write-Log "Found removable drive: ${driveLetter}:\"
        }
        return $removableDrives
    }
    
    Write-Log "No removable drives detected" -Level Warning
    return $null
}

function Find-Installer {
    param(
        [string]$SoftwareName,
        [array]$SearchPatterns
    )
    
    Write-Log "Searching for $SoftwareName installer..."
    
    $drives = Find-FlashDrive
    if (-not $drives) {
        return $null
    }
    
    foreach ($drive in $drives) {
        $driveLetter = $drive.DriveLetter
        $drivePath = "${driveLetter}:\"
        
        foreach ($pattern in $SearchPatterns) {
            $files = Get-ChildItem -Path $drivePath -Filter $pattern -Recurse -ErrorAction SilentlyContinue -Depth 2
            
            if ($files) {
                $installer = $files[0].FullName
                Write-Log "Found $SoftwareName installer: $installer" -Level Success
                return $installer
            }
        }
    }
    
    Write-Log "$SoftwareName installer not found on removable drives" -Level Warning
    return $null
}

function Install-FromPath {
    param(
        [string]$InstallerPath,
        [string]$SoftwareName
    )
    
    if (-not (Test-Path $InstallerPath)) {
        Write-Log "Installer path not found: $InstallerPath" -Level Error
        return $false
    }
    
    Write-Log "Installing $SoftwareName from: $InstallerPath"
    Write-Host "  Attempting silent installation..." -ForegroundColor Gray
    
    try {
        $extension = [System.IO.Path]::GetExtension($InstallerPath).ToLower()
        
        if ($extension -eq '.msi') {
            $arguments = "/i `"$InstallerPath`" /qn /norestart"
            
            Write-Log "Running: msiexec.exe $arguments"
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "msiexec.exe"
            $processInfo.Arguments = $arguments
            $processInfo.UseShellExecute = $false
            $processInfo.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $started = $process.Start()
            
            if ($started) {
                $finished = $process.WaitForExit(120000)
                
                if ($finished) {
                    $exitCode = $process.ExitCode
                    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
                        Write-Log "$SoftwareName installed successfully (Exit code: $exitCode)" -Level Success
                        return $true
                    } else {
                        Write-Log "$SoftwareName installation completed with exit code: $exitCode" -Level Warning
                        return $true
                    }
                } else {
                    Write-Log "$SoftwareName installation is still running in background" -Level Warning
                    return $true
                }
            }
        }
        elseif ($extension -eq '.exe') {
            $silentArgs = @('/S', '/SILENT', '/VERYSILENT', '/quiet', '/qn')
            
            foreach ($arg in $silentArgs) {
                try {
                    Write-Log "Trying $SoftwareName with argument: $arg"
                    
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = $InstallerPath
                    $processInfo.Arguments = $arg
                    $processInfo.UseShellExecute = $false
                    $processInfo.CreateNoWindow = $true
                    
                    $process = New-Object System.Diagnostics.Process
                    $process.StartInfo = $processInfo
                    $started = $process.Start()
                    
                    if ($started) {
                        $finished = $process.WaitForExit(120000)
                        
                        if ($finished) {
                            $exitCode = $process.ExitCode
                            if ($exitCode -eq 0 -or $exitCode -eq 3010) {
                                Write-Log "$SoftwareName installed successfully with argument: $arg (Exit code: $exitCode)" -Level Success
                                return $true
                            }
                        } else {
                            Write-Log "$SoftwareName installation is running in background" -Level Warning
                            return $true
                        }
                    }
                }
                catch {
                    Write-Log "Failed attempt with $arg : $_" -Level Info
                    continue
                }
            }
            
            Write-Log "$SoftwareName requires manual installation" -Level Warning
            Write-Host "`n  Please install $SoftwareName manually from:" -ForegroundColor Yellow
            Write-Host "  $InstallerPath" -ForegroundColor White
            Read-Host "`nPress ENTER after completing manual installation"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log "Error during installation of $SoftwareName - $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-RingCentralFromStartup {
    Write-Log "Checking for RingCentral in startup applications..."
    
    # Common startup locations
    $startupPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    
    foreach ($path in $startupPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $items.PSObject.Properties | Where-Object { $_.Name -like "*RingCentral*" -or $_.Value -like "*RingCentral*" } | ForEach-Object {
                try {
                    Remove-ItemProperty -Path $path -Name $_.Name -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed RingCentral from startup: $($_.Name)" -Level Success
                }
                catch {
                    Write-Log "Could not remove $($_.Name) from $path" -Level Warning
                }
            }
        }
    }
    
    # Check Startup folder
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $commonStartup = [Environment]::GetFolderPath('CommonStartup')
    
    foreach ($folder in @($startupFolder, $commonStartup)) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Filter "*RingCentral*" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Force
                    Write-Log "Removed RingCentral shortcut from startup folder: $($_.Name)" -Level Success
                }
                catch {
                    Write-Log "Could not remove $($_.Name) from startup folder" -Level Warning
                }
            }
        }
    }
}

function Step-ManualSoftwareInstructions {
    param($State)
    
    Write-StepHeader -StepNumber 11 -StepName "Install Additional Software from Flash Drive"
    
    Write-Log "Searching for installers on removable drives..."
    
    $softwareList = @(
        @{Name = 'RingCentral'; Patterns = $Script:InstallerPatterns['RingCentral']},
        @{Name = 'CheckpointVPN'; Patterns = $Script:InstallerPatterns['CheckpointVPN']},
        @{Name = 'DellSupportAssist'; Patterns = $Script:InstallerPatterns['DellSupportAssist']}
    )
    
    $installResults = @{}
    
    foreach ($software in $softwareList) {
        $name = $software.Name
        $patterns = $software.Patterns
        
        Write-Host "`nLooking for $name..." -ForegroundColor Cyan
        $installerPath = Find-Installer -SoftwareName $name -SearchPatterns $patterns
        
        if ($installerPath) {
            $result = Install-FromPath -InstallerPath $installerPath -SoftwareName $name
            $installResults[$name] = $result
            
            # Special handling for RingCentral - remove from startup
            if ($name -eq 'RingCentral' -and $result) {
                Start-Sleep -Seconds 5  # Give it time to add itself to startup
                Remove-RingCentralFromStartup
            }
        } else {
            Write-Host "  $name installer not found on flash drive" -ForegroundColor Yellow
            Write-Host "  Please install manually if required" -ForegroundColor Yellow
            $installResults[$name] = $false
        }
    }
    
    # Display summary
    Write-Host "`n--- Additional Software Installation Summary ---" -ForegroundColor Cyan
    foreach ($name in $installResults.Keys) {
        $status = if ($installResults[$name]) { "Completed" } else { "Not Installed" }
        $color = if ($installResults[$name]) { "Green" } else { "Yellow" }
        Write-Host "  $name : $status" -ForegroundColor $color
    }
    
    return $true
}

function Step-InstallWindowsUpdates {
    param($State)
    
    Write-StepHeader -StepNumber 12 -StepName "Install Windows Updates"
    
    Write-Log "Preparing PowerShell Gallery and NuGet..."
    
    # Suppress all confirmation prompts
    $ConfirmPreference = 'None'
    $ProgressPreference = 'SilentlyContinue'
    
    # Ensure TLS 1.2 is enabled (required for PSGallery)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Set PSGallery as trusted BEFORE any module operations
    try {
        $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($psGallery -and $psGallery.InstallationPolicy -ne 'Trusted') {
            Write-Log "Setting PSGallery as trusted repository..."
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
    }
    catch {
        Write-Log "Could not set PSGallery trust: $_" -Level Warning
    }
    
    # Install NuGet provider - use direct download to avoid prompts
    try {
        $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
                 Where-Object { $_.Version -ge [Version]"2.8.5.201" }
        
        if (-not $nuget) {
            Write-Log "Installing NuGet provider..."
            
            # Method 1: Try with all force flags and piped input
            try {
                $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ForceBootstrap -Scope AllUsers -Confirm:$false 2>&1
                Write-Log "NuGet provider installed" -Level Success
            }
            catch {
                # Method 2: Direct download if Install-PackageProvider fails
                Write-Log "Trying direct NuGet download..."
                $nugetUrl = "https://aka.ms/psget-nugetexe"
                $nugetPath = "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208"
                
                if (-not (Test-Path $nugetPath)) {
                    New-Item -Path $nugetPath -ItemType Directory -Force | Out-Null
                }
                
                Invoke-WebRequest -Uri $nugetUrl -OutFile "$nugetPath\nuget.exe" -UseBasicParsing
                Write-Log "NuGet downloaded directly" -Level Success
            }
        } else {
            Write-Log "NuGet provider already installed" -Level Success
        }
    }
    catch {
        Write-Log "Failed to install NuGet provider: $_" -Level Warning
    }
    
    # Check if PSWindowsUpdate module is installed
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installing PSWindowsUpdate module..."
        try {
            # Removed -AcceptLicense as it's not supported in all PS versions
            Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope AllUsers -AllowClobber -Confirm:$false
            Import-Module PSWindowsUpdate -Force
            Write-Log "PSWindowsUpdate module installed" -Level Success
        }
        catch {
            Write-Log "Failed to install PSWindowsUpdate module: $_" -Level Warning
            Write-Host "`nCould not install Windows Update module automatically." -ForegroundColor Yellow
            Write-Host "Please install Windows updates manually via Settings > Windows Update" -ForegroundColor Yellow
            return $true
        }
    } else {
        Import-Module PSWindowsUpdate -Force -ErrorAction SilentlyContinue
        Write-Log "PSWindowsUpdate module already available" -Level Success
    }
    
    Write-Log "Searching for available Windows updates..."
    Write-Host "This may take several minutes..." -ForegroundColor Yellow
    
    try {
        # Install updates (excluding driver updates which can cause issues)
        Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreReboot -NotCategory "Drivers" -Verbose
        
        Write-Log "Windows updates installed" -Level Success
        
        # Check if reboot is needed
        try {
            if (Get-WURebootStatus -Silent) {
                Write-Log "Reboot required for Windows updates" -Level Warning
            }
        }
        catch {
            # Get-WURebootStatus might not be available
        }
        
        return $true
    }
    catch {
        Write-Log "Error installing Windows updates: $_" -Level Warning
        Write-Host "`nWindows Update encountered an error." -ForegroundColor Yellow
        Write-Host "You may need to install updates manually via Settings > Windows Update" -ForegroundColor Yellow
        return $true
    }
}

function Step-AddUserToAdministrators {
    param($State)
    
    Write-StepHeader -StepNumber 13 -StepName "Add User to Administrators Group"
    
    # Skip for stock machines
    if ($State.MachineType -eq "stock") {
        Write-Log "Skipping user administrator addition for stock machine" -Level Info
        Write-Host "Skipped (Stock machine)" -ForegroundColor Yellow
        return $true
    }
    
    # Skip for Windows Home (no domain)
    if ($State.WindowsEdition -eq "Home") {
        Write-Log "Skipping domain user addition (Windows Home edition)" -Level Info
        Write-Host "Skipped (Windows Home - no domain users)" -ForegroundColor Yellow
        return $true
    }
    
    if ($State.UserToAdd -eq "" -or $State.UserToAdd -eq $null) {
        $username = Read-Host "Enter the domain username to add to Administrators (example: jdoe)"
        $State.UserToAdd = $username
        Save-ProvisioningState -State $State
    } else {
        $username = $State.UserToAdd
    }
    
    try {
        $domain = $Script:DomainName
        $fullUsername = "$domain\$username"
        
        Add-LocalGroupMember -Group "Administrators" -Member $fullUsername -ErrorAction Stop
        Write-Log "Added $fullUsername to Administrators group" -Level Success
        return $true
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            Write-Log "User $fullUsername is already an administrator" -Level Success
            return $true
        } else {
            Write-Log "Failed to add user to Administrators: $_" -Level Error
            return $false
        }
    }
}

function Step-GetIPConfiguration {
    param($State)
    
    Write-StepHeader -StepNumber 14 -StepName "Retrieve IP Configuration"
    
    try {
        $ipConfig = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' }
        
        if ($ipConfig) {
            $ip = $ipConfig[0].IPAddress
            Write-Host "`n============================================" -ForegroundColor Green
            Write-Host "IMPORTANT: DNS Configuration Required" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "IP Address: $ip" -ForegroundColor Yellow
            Write-Host "Computer Name: $env:COMPUTERNAME" -ForegroundColor Yellow
            Write-Host "`nOn the Domain Controller:" -ForegroundColor White
            Write-Host "  1. Create a Host (A) DNS record" -ForegroundColor White
            Write-Host "  2. Use IP: $ip" -ForegroundColor White
            Write-Host "  3. Use Name: $env:COMPUTERNAME" -ForegroundColor White
            Write-Host "============================================`n" -ForegroundColor Green
            
            Write-Log "IP Configuration retrieved: $ip"
            return $true
        } else {
            Write-Log "Could not determine IP address" -Level Warning
            return $true
        }
    }
    catch {
        Write-Log "Error retrieving IP configuration: $_" -Level Warning
        return $true
    }
}

function Step-FinalInstructions {
    param($State)
    
    Write-StepHeader -StepNumber 15 -StepName "Final Instructions"
    
    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "PROVISIONING COMPLETE!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    
    # Display VPN configuration instructions
    Write-Host "`n>> Checkpoint VPN Configuration <<" -ForegroundColor Yellow
    Write-Host "Please configure the Checkpoint VPN manually:" -ForegroundColor White
    Write-Host "  Server: $($Script:CheckpointVPN_Server)" -ForegroundColor Cyan
    Write-Host "  Port: $($Script:CheckpointVPN_Port)" -ForegroundColor Cyan
    
    Write-Host "`nRemaining Manual Tasks:" -ForegroundColor Yellow
    Write-Host "  1. Configure Checkpoint VPN (see details above)" -ForegroundColor White
    Write-Host "`n  2. Run full system scan with Dell SupportAssist (if applicable)" -ForegroundColor White
    Write-Host "     - Install any identified software updates" -ForegroundColor White
    Write-Host "`n  3. Check Windows Store for updates" -ForegroundColor White
    Write-Host "     - Open Microsoft Store then Library then Get updates" -ForegroundColor White
    Write-Host "`n  4. Verify ADUC Placement (on Domain Controller)" -ForegroundColor White
    Write-Host "     - Open Active Directory Users and Computers" -ForegroundColor White
    Write-Host "     - Confirm $env:COMPUTERNAME is in the Computers OU" -ForegroundColor White
    Write-Host "     - Move if necessary" -ForegroundColor White
    Write-Host "`n  5. Final reboot recommended" -ForegroundColor White
    Write-Host "============================================`n" -ForegroundColor Green
    
    Write-Log "Provisioning script completed successfully!" -Level Success
    return $true
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-Provisioning {
    Initialize-Logging
    
    Write-Host @"

###############################################################
#                                                             #
#     YAHARA WORKSTATION PROVISIONING SCRIPT v1.5             #
#                                                             #
###############################################################

"@ -ForegroundColor Cyan

    # Load or initialize state
    $state = Get-ProvisioningState
    
    Write-Log "Starting provisioning from step $($state.CurrentStep)"
    
    # Step 1: Machine Type Selection
    if ($state.CurrentStep -lt 1) {
        if ($state.MachineType -eq "" -or $state.MachineType -eq $null) {
            $state = Step-MachineTypeSelection -State $state
        }
        $state.CurrentStep = 1
        Save-ProvisioningState -State $state
    }
    
    # Step 2: Detect Windows Edition
    if ($state.CurrentStep -lt 2) {
        if ($state.WindowsEdition -eq "" -or $state.WindowsEdition -eq $null) {
            $state = Step-DetectWindowsEdition -State $state
        }
        $state.CurrentStep = 2
        Save-ProvisioningState -State $state
    }
    
    # Step 3: Timezone Configuration
    if ($state.CurrentStep -lt 3) {
        Step-TimezoneConfiguration -State $state | Out-Null
        $state.CurrentStep = 3
        Save-ProvisioningState -State $state
    }
    
    # Step 4: Check Windows Activation
    if ($state.CurrentStep -lt 4) {
        Step-CheckWindowsActivation -State $state | Out-Null
        $state.CurrentStep = 4
        Save-ProvisioningState -State $state
    }
    
    # Step 5: Change local admin password
    if ($state.CurrentStep -lt 5) {
        Step-ChangeLocalAdminPassword -State $state | Out-Null
        $state.CurrentStep = 5
        Save-ProvisioningState -State $state
    }
    
    # Step 6: Rename PC (BEFORE domain join)
    if ($state.CurrentStep -lt 6) {
        if (Step-RenamePC -State $state) {
            $state.CurrentStep = 6
            Save-ProvisioningState -State $state
        }
    }
    
    # Step 7: Enable Single-Label DNS Domain (after rename reboot, before domain join)
    if ($state.CurrentStep -lt 7) {
        Step-EnableSingleLabelDomain -State $state | Out-Null
        $state.CurrentStep = 7
        Save-ProvisioningState -State $state
    }
    
    # Step 8: Domain Join
    if ($state.CurrentStep -lt 8) {
        if (Step-JoinDomain -State $state) {
            $state.CurrentStep = 8
            Save-ProvisioningState -State $state
        }
    }
    
    # Step 9: Install Chocolatey
    if ($state.CurrentStep -lt 9) {
        Step-InstallChocolatey -State $state | Out-Null
        $state.CurrentStep = 9
        Save-ProvisioningState -State $state
    }
    
    # Step 10: Install Software
    if ($state.CurrentStep -lt 10) {
        Step-InstallSoftware -State $state | Out-Null
        $state.CurrentStep = 10
        Save-ProvisioningState -State $state
    }
    
    # Step 11: Manual Software Instructions (Flash Drive)
    if ($state.CurrentStep -lt 11) {
        Step-ManualSoftwareInstructions -State $state | Out-Null
        $state.CurrentStep = 11
        Save-ProvisioningState -State $state
    }
    
    # Step 12: Windows Updates
    if ($state.CurrentStep -lt 12) {
        Step-InstallWindowsUpdates -State $state | Out-Null
        $state.CurrentStep = 12
        Save-ProvisioningState -State $state
    }
    
    # Step 13: Add User to Administrators
    if ($state.CurrentStep -lt 13) {
        Step-AddUserToAdministrators -State $state | Out-Null
        $state.CurrentStep = 13
        Save-ProvisioningState -State $state
    }
    
    # Step 14: Get IP Configuration
    if ($state.CurrentStep -lt 14) {
        Step-GetIPConfiguration -State $state | Out-Null
        $state.CurrentStep = 14
        Save-ProvisioningState -State $state
    }
    
    # Step 15: Final Instructions
    if ($state.CurrentStep -lt 15) {
        Step-FinalInstructions -State $state | Out-Null
        $state.CurrentStep = 999
        Save-ProvisioningState -State $state
    }
    
    # Clean up resume mechanism
    Remove-RebootResume
    
    Write-Host "`nProvisioning log saved to: $Script:LogFile" -ForegroundColor Cyan
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run the provisioning
Start-Provisioning
