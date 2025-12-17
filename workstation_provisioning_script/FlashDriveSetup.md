# Flash Drive Setup Guide

## Purpose
This guide explains how to organize your flash drive so the provisioning script can automatically detect and install software.

## Flash Drive Structure

You can organize your flash drive in any way you prefer. The script will search up to 2 levels deep. Here are some recommended structures:

### Option 1: Simple (Recommended)
```
USB Drive (D:, E:, F:, etc.)
+-- RingCentral.exe
+-- CheckpointVPN.exe
+-- SupportAssist.exe
```

### Option 2: Organized by Software
```
USB Drive (D:, E:, F:, etc.)
+-- RingCentral/
|   +-- RingCentral-Installer.exe
+-- Checkpoint/
|   +-- CheckpointVPN-Setup.exe
+-- Dell/
    +-- SupportAssistInstaller.exe
```

### Option 3: Complete Provisioning Kit
```
USB Drive (D:, E:, F:, etc.)
+-- Scripts/
|   +-- WorkstationProvisioning.ps1
|   +-- README.md
|   +-- QuickStart.md
|   +-- CHECKLIST.md
|   +-- FlashDriveSetup.md
+-- Installers/
|   +-- RingCentral.exe
|   +-- CheckpointVPN.msi
|   +-- DellSupportAssist.exe
+-- Documentation/
    +-- [Any additional IT documentation]
```

## Installer Detection Patterns

The script looks for files matching these patterns:

### RingCentral
- `*RingCentral*.exe`
- `*RingCentral*.msi`

**Examples that will be detected:**
- `RingCentral.exe`
- `RingCentralSetup.exe`
- `RingCentral-v23.4.0.exe`
- `RingCentral_V=20139914060036100.exe`
- `RingCentral_Installer.msi`

**Note:** The script automatically removes RingCentral from startup applications after installation!

### Checkpoint VPN
- `*Checkpoint*.exe`
- `*Checkpoint*.msi`
- `*VPN*.exe`

**Examples that will be detected:**
- `CheckpointVPN.exe`
- `Checkpoint-Setup.exe`
- `E84.20_CheckPointVPN.msi`
- `VPN-Client.exe`
- `CheckpointVPNInstaller.msi`

### Dell SupportAssist
- `*SupportAssist*.exe`
- `*Dell*Support*.exe`
- `*SupportAssist*.msi`

**Examples that will be detected:**
- `SupportAssist.exe`
- `SupportAssistinstaller.exe`
- `DellSupportAssist.exe`
- `Dell_SupportAssist_Setup.exe`
- `SupportAssistInstaller.msi`

## Important Notes

### File Types
- Both `.exe` and `.msi` installers are supported
- The script will attempt silent installation first
- If silent installation fails, it will try multiple silent switches
- If all silent attempts fail, it will prompt for manual installation

### Search Depth
- The script searches up to 2 folder levels deep
- Don't nest installers deeper than 2 folders
- Root level or 1 subfolder is recommended

### Multiple Matches
- If multiple matching files are found, the first one discovered will be used
- Keep only one version of each installer to avoid confusion

### Removal After Use
- Installers are NOT deleted from the flash drive
- You can reuse the same flash drive for multiple machines
- Consider keeping a backup of installers in case files become corrupted

## Verification

To verify your flash drive is set up correctly:

1. Insert the flash drive into the target computer
2. Open PowerShell as Administrator
3. Run these commands to see what the script will find:

```powershell
# Find removable drives
Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter }

# Search for installers (replace D: with your drive letter)
Get-ChildItem -Path "D:\" -Filter "*RingCentral*.exe" -Recurse -Depth 2
Get-ChildItem -Path "D:\" -Filter "*Checkpoint*.exe" -Recurse -Depth 2
Get-ChildItem -Path "D:\" -Filter "*SupportAssist*.exe" -Recurse -Depth 2
```

## Troubleshooting

### Script doesn't detect flash drive
- Ensure flash drive is properly connected
- Check that it appears in File Explorer
- Verify it's detected as a "Removable" drive (not Fixed)
- Try a different USB port

### Installer not detected
- Check filename matches patterns above
- Ensure installer is not nested too deep (max 2 folders)
- Verify file extension is `.exe` or `.msi`
- Check for typos in filename

### Installation fails
- Verify installer file is not corrupted
- Ensure you have administrator privileges
- Check Windows Defender isn't blocking the installer
- Look at provisioning log for specific error messages
- Try running installer manually to test

### Wrong installer detected
- Remove other versions/copies from flash drive
- Rename files to be more specific if needed
- Keep only one installer per software package

### RingCentral keeps appearing in startup
- The script automatically removes RingCentral from startup
- If it still appears, check manually:
  - Task Manager -> Startup tab
  - Settings -> Apps -> Startup
  - Registry: `HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`

## Best Practices

1. **Keep it simple**: Flat structure or one subfolder works best
2. **Use clear names**: Avoid overly generic names like "Setup.exe"
3. **One version only**: Don't keep multiple versions of the same software
4. **Test first**: Verify installers work manually before relying on automation
5. **Stay organized**: Keep provisioning scripts and installers together
6. **Label drive**: Physically label drive as "IT Provisioning Kit"
7. **Regular updates**: Keep installers current with latest versions
8. **Backup**: Maintain a backup copy of your provisioning flash drive

## Complete Provisioning Kit Contents

A well-prepared flash drive should contain:

```
IT Provisioning Flash Drive (8GB+ recommended)
|
+-- Scripts/
|   +-- WorkstationProvisioning.ps1  (v1.5)
|   +-- README.md
|   +-- QuickStart.md
|   +-- CHECKLIST.md
|   +-- FlashDriveSetup.md (this file)
|
+-- Installers/
|   +-- RingCentral_V=XXXXXXXXX.exe
|   +-- E84.XX_CheckPointVPN.msi
|   +-- SupportAssistinstaller.exe
|
+-- Documentation/
    +-- [Any additional IT documentation]
```

## Quick Reference

**Drive Requirements:**
- USB flash drive (8GB+ recommended)
- Formatted as NTFS or FAT32
- Detected as "Removable" drive type

**Required Installers:**
1. RingCentral (any version)
2. Checkpoint VPN Client
3. Dell SupportAssist (optional, only for Dell hardware)

**Optional Additions:**
- Provisioning script and documentation
- Network drivers (for machines without ethernet)
- Additional troubleshooting tools
- IT contact information

## What the Script Does with Each Installer

| Software | Silent Install | Post-Install Action |
|----------|---------------|---------------------|
| RingCentral | `/S` switch | Removes from startup apps |
| Checkpoint VPN | MSI `/qn` | Displays config reminder |
| Dell SupportAssist | `/S` switch | None (may run in background) |

---

*Version 1.5 - December 2025*
*Maintained by: IT Department*
