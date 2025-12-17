# Quick Start Guide
## Workstation Provisioning in 5 Minutes

### Before You Start
- Fresh Windows 11 installed
- Connected to Ethernet
- Flash drive with installers connected
- Domain credentials ready (Pro/Enterprise only)

### Step 1: Copy Script (30 seconds)
1. Copy `WorkstationProvisioning.ps1` to `C:\Temp\`
2. Keep flash drive connected

### Step 2: Run Script (30 seconds)
1. Right-click `WorkstationProvisioning.ps1`
2. Select **"Run with PowerShell"**
3. If prompted, allow administrator access

### Step 3: Answer Prompts (2 minutes)
| Prompt | What to Enter | Example |
|--------|--------------|---------|
| Machine type | `D`, `N`, or `S` | `N` for Non-Dev |
| Domain credentials | Username & Password | `admin` / `********` |
| New PC name | See naming below | `YS-jdoe-25` |
| User to add as admin | Domain username | `jdoe` |

**Machine Types:**
- `D` = Developer (full dev tools)
- `N` = Non-Dev (business tools)
- `S` = Stock (minimal setup)

**PC Naming:**
- User machines: `YS-username-YY` (e.g., `YS-jdoe-25`)
- Stock machines: `YS-STOCK-XX` (e.g., `YS-STOCK-01`)

### Step 4: Wait for Automation (15-30 minutes)
The script will:
- Configure system settings
- Rename PC (auto-reboot)
- Enable single-label DNS
- Join domain (auto-reboot) - *skipped for Windows Home*
- Install Chocolatey
- Install software packages (with retry logic)
- Install Microsoft 365 via ODT
- Install from flash drive (RingCentral, VPN, SupportAssist)
- Remove RingCentral from startup
- Install Windows updates

**Don't close PowerShell!** It will resume after reboots automatically.

### Step 5: Complete DNS (2 minutes)
*Skip this step for Windows Home or Stock machines*

When script displays IP address:
1. Log into Domain Controller
2. Open DNS Manager
3. Create Host (A) record
   - Name: `YS-jdoe-25` (from script)
   - IP: `192.168.x.x` (from script)
4. Verify computer in ADUC Computers OU

### Step 6: Final Tasks (5 minutes)
- [ ] Run Dell SupportAssist scan (if Dell)
- [ ] Check Microsoft Store for updates
- [ ] Configure Checkpoint VPN: `69.129.61.46:4433`
- [ ] Final reboot

## Done!

---

## Software Installed

### Stock & Non-Dev Get:
- Zoom, Slack, Chrome, Firefox, Microsoft 365
- RingCentral, Checkpoint VPN
- Dell SupportAssist (Dell only)

### Developers Also Get:
- Git, VS Code, Visual Studio 2022 Pro
- SQL Server Management Studio

---

## Common Issues

**"Execution Policy" error:**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

**Script won't resume after reboot:**
Just run it again - it remembers where it left off!

**PC rename fails with "Access Denied":**
Script will prompt for domain credentials - enter them when asked.

**Chrome installation fails:**
Script will automatically try multiple methods including direct download from Google.

**Flash drive installers not detected:**
Check drive is connected and files match patterns:
- `*RingCentral*.exe`
- `*Checkpoint*.exe` or `*VPN*.exe`
- `*SupportAssist*.exe`

**Windows Home detected:**
This is normal! Script will skip domain join automatically.

**Need help?**
Check `C:\ProvisioningLogs\Provisioning_*.log`

---

## That's It!
Total time: ~30-45 minutes (mostly automated)
Log location: `C:\ProvisioningLogs\`
Detailed docs: See `README.md`

---
*Version 1.5 - December 2025*
