# Workstation Provisioning Script - Usage Guide

## Overview
This PowerShell script automates the provisioning of Yahara domain workstations after a fresh Windows 11 installation. It handles software installation, domain joining, system configuration, and much more.

## Version
**Current Version: 1.5** (December 2025)

## Features
- **Machine Type Selection**: Dev/Non-Dev/Stock options with appropriate software
- **Windows Edition Detection**: Automatically detects Home vs Pro and skips domain features for Home
- **Automatic Reboot Handling**: Resumes automatically after required reboots via RunOnce registry
- **Comprehensive Logging**: All actions logged to `C:\ProvisioningLogs`
- **State Management**: Can be interrupted and resumed safely
- **Error Handling**: Graceful handling of failures with retry logic
- **Step Progress Display**: Clear step numbers shown during execution
- **Chrome Fallback**: Multiple installation methods including direct download from Google

## Prerequisites
1. Fresh Windows 11 installation
2. Connected to Ethernet
3. Administrator access
4. Domain credentials ready (for Pro/Enterprise editions)

## What Gets Automated

### Fully Automated Steps:
| Step | Description | Notes |
|------|-------------|-------|
| 1 | Machine type selection | Dev/Non-Dev/Stock |
| 2 | Windows edition detection | Auto-detects Home vs Pro |
| 3 | Timezone configuration | Central Standard Time |
| 4 | Windows activation check | |
| 5 | Local admin password change | |
| 6 | PC rename | Reboot after |
| 7 | Single-label DNS registry | With Dnscache service restart |
| 8 | Domain join | Skipped for Windows Home, reboot after |
| 9 | Chocolatey installation | |
| 10 | Software installation | Chrome uses --ignore-checksums |
| 11 | Flash drive software | RingCentral, VPN, SupportAssist |
| 12 | Windows Updates | NuGet auto-installed |
| 13 | Add user to Administrators | Skipped for Stock/Home |
| 14 | IP configuration display | |
| 15 | Final instructions | |

### Manual Steps Remaining:
- BIOS configuration and Windows installation
- Initial ethernet connection
- Checkpoint VPN configuration (server/port settings)
- Dell SupportAssist system scan
- Microsoft Store updates
- DNS record creation on Domain Controller
- ADUC verification on Domain Controller

### Flash Drive Auto-Detection
The script will automatically detect and install software from a connected USB flash drive:
- **RingCentral** - Automatically removed from startup after installation
- **Checkpoint VPN** - Prompts for manual configuration after installation
- **Dell SupportAssist** - For Dell hardware

Simply ensure your flash drive is connected before running the script!

## Software Installed

### Stock Machines:
- Zoom
- Slack
- Google Chrome
- Firefox
- Microsoft 365 Business (via Office Deployment Tool)

### Non-Developer Workstations:
- Same as Stock, plus user added to Administrators

### Developer Workstations (includes above plus):
- Git
- SQL Server Management Studio
- Visual Studio Code
- Visual Studio 2022 Professional

## Usage Instructions

### Step 1: Prepare the Script
1. After Windows installation, sign in with local admin account
2. Copy `WorkstationProvisioning.ps1` to the machine (USB drive, network share, etc.)
3. Place it in an accessible location (e.g., `C:\Temp`)
4. **Connect your flash drive** with the installers (RingCentral, Checkpoint VPN, Dell SupportAssist)

### Step 2: Run the Script
1. Right-click on `WorkstationProvisioning.ps1`
2. Select **"Run with PowerShell"** (as Administrator)
   - OR open PowerShell as Administrator and run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   cd C:\Temp
   .\WorkstationProvisioning.ps1
   ```

### Step 3: Follow the Prompts
1. **Machine Type**: Choose installation type:
   - `D` = Developer workstation (full development tools)
   - `N` = Non-Dev workstation (business tools only)
   - `S` = Stock machine (minimal configuration)
2. **Domain Join**: Enter domain credentials when prompted (Pro/Enterprise only)
3. **PC Rename**: Enter new PC name following the format:
   - User machines: `YS-username-YY` (e.g., `YS-jdoe-25`)
   - Stock machines: `YS-STOCK-XX` (e.g., `YS-STOCK-01`)
4. **User to Add**: Enter the domain username to add to local Administrators group (Dev/Non-Dev only)

### Step 4: Automatic Reboots
The script will automatically reboot when needed (after domain join and PC rename). It will resume automatically after each reboot using the Windows RunOnce registry key.

### Step 5: Additional Software Installation
The script will automatically scan your flash drive for installers:
- **RingCentral** - Auto-installs and removes from startup
- **Checkpoint VPN** - Auto-installs (manual config still required)
- **Dell SupportAssist** - Auto-installs on Dell hardware

If installers aren't found or installation fails:
1. Install manually from flash drive or download from official sites
2. For RingCentral: Remove from startup apps after installation
3. For Checkpoint VPN: Configure with server `69.129.61.46:4433`

The script will show you which applications were successfully installed.

### Step 6: Domain Controller Tasks (Pro/Enterprise only)
When the script displays the IP address and computer name:
1. Log into the Domain Controller
2. Open DNS Manager
3. Create a Host (A) record with the displayed IP and computer name
4. Open Active Directory Users and Computers (ADUC)
5. Verify the computer appears in the Computers OU

### Step 7: Final Manual Steps
1. Run full system scan with Dell SupportAssist (if applicable)
2. Check Microsoft Store for updates
3. Configure Checkpoint VPN with server `69.129.61.46:4433`
4. Perform final reboot

## Configuration Variables
You can modify these at the top of the script if needed:

```powershell
$Script:DomainName = "yahara"
$Script:LocalAdminUser = "yahara"
$Script:NewLocalAdminPassword = "Coast-Repetition-Pan-Excellence-4"
$Script:CheckpointVPN_Server = "69.129.61.46"
$Script:CheckpointVPN_Port = "4433"
```

## Logging
All actions are logged to: `C:\ProvisioningLogs\Provisioning_YYYYMMDD_HHMMSS.log`

The log includes:
- Timestamp for each action
- Success/failure status
- Error messages
- Configuration changes

## State Management
The script saves its progress to: `C:\ProvisioningLogs\ProvisioningState.json`

This allows it to:
- Resume after reboots
- Skip completed steps if re-run
- Remember machine type selection
- Track PC rename status
- Remember which user to add as admin

## Troubleshooting

### Script won't run - "Execution Policy" error
Run this first:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

### Domain join fails
- Verify ethernet connection
- Check domain credentials
- Ensure DNS is properly configured
- Verify firewall isn't blocking domain communication
- **Note**: Windows Home cannot join domains - script will skip automatically

### PC rename fails with "Access Denied"
- For domain-joined machines, you'll be prompted for domain credentials
- Ensure you have appropriate permissions

### Chocolatey installation fails
- Check internet connection
- Verify access to chocolatey.org
- Check firewall/proxy settings

### Software installation errors
- Script has retry logic - will attempt up to 3 times
- Check the log file for specific package failures
- Some packages may require manual installation
- Verify sufficient disk space

### Microsoft 365 installation fails
- Script uses Office Deployment Tool (not Chocolatey)
- Check internet connection
- Verify no existing Office installation conflicts
- May need manual installation from office.com

### Script doesn't resume after reboot
- Check RunOnce registry: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`
- Verify state file exists: `C:\ProvisioningLogs\ProvisioningState.json`
- Run the script manually if needed - it will resume from last step

### Reset and start over
If you need to start from scratch:
```powershell
# Remove state file
Remove-Item -Path "C:\ProvisioningLogs\ProvisioningState.json" -Force

# Remove RunOnce entry (if exists)
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WorkstationProvisioning" -ErrorAction SilentlyContinue

# Remove scheduled task (legacy, if exists)
Unregister-ScheduledTask -TaskName "WorkstationProvisioning_Resume" -Confirm:$false -ErrorAction SilentlyContinue
```

## Advanced Usage

### Skip specific steps
You can manually edit the state file to skip steps:
```powershell
$state = Get-Content "C:\ProvisioningLogs\ProvisioningState.json" | ConvertFrom-Json
$state.CurrentStep = 10  # Skip to step 10
$state | ConvertTo-Json | Set-Content "C:\ProvisioningLogs\ProvisioningState.json"
```

### Check current state
```powershell
Get-Content "C:\ProvisioningLogs\ProvisioningState.json" | ConvertFrom-Json
```

## Security Notes
- The script requires Administrator privileges
- Domain credentials are never logged or stored
- Local admin password is stored in the script - ensure proper file permissions
- Review the script before running in production environments

## Version History
- **v1.5** (2025-12): Step order and Windows Update fixes
  - Fixed: PC rename now happens BEFORE domain join (correct hostname joins domain)
  - Fixed: Single-label DNS now restarts Dnscache service after registry edit
  - Fixed: NuGet installs without Enter prompt (direct download fallback)
  - Fixed: Removed unsupported -AcceptLicense parameter
  - Changed: Chrome uses --ignore-checksums as primary method

- **v1.4** (2025-12): Chrome and Windows Update fixes
  - Fixed: Chrome install now uses --ignore-checksums fallback, then direct Google download
  - Fixed: NuGet/PSGallery no longer prompts for Enter key (sets PSGallery as trusted)
  - Fixed: Windows Updates now properly install without manual intervention
  
- **v1.3** (2025-12): Major bug fixes and improvements
  - Fixed: Auto-resume after reboot (now uses RunOnce registry)
  - Fixed: Domain join/PC rename no longer re-prompts after reboot
  - Fixed: O365 now uses Office Deployment Tool
  - Fixed: RingCentral removed from startup apps
  - Added: Step numbers display during execution
  - Changed: Machine type selection now D/N/S (Dev/Non-Dev/Stock)
  
- **v1.2** (2025-12): Windows Home support
  - Auto-detect Windows Home vs Pro edition
  - Skip domain join and single-label DNS for Windows Home
  - Fixed domain join success reporting
  - Fixed PC rename asking twice after reboot
  
- **v1.1** (2025-11): Stock machine support
  - Updated naming convention to YS-username-YY format
  - Added stock machine naming option (YS-STOCK-XX)
  - Added minimal "stock" install type

- **v1.0** (2025-11): Initial release
  - Dev/Non-dev selection
  - Automatic reboot handling
  - Comprehensive logging
  - State management

## Support
For issues or questions:
1. Check the log file: `C:\ProvisioningLogs\Provisioning_*.log`
2. Review this README
3. Contact IT Department

## License
Internal use only - Yahara IT Department
