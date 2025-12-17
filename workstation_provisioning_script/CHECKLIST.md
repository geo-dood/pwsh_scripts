# Workstation Provisioning - Quick Reference Checklist

## Pre-Script Setup
- [ ] Fresh Windows 11 installed
- [ ] Connected to Ethernet
- [ ] Signed in as local administrator
- [ ] Script copied to machine (e.g., `C:\Temp`)
- [ ] Flash drive with installers connected
- [ ] Domain credentials ready (Pro/Enterprise only)

## Running the Script
- [ ] Run PowerShell as Administrator
- [ ] Execute: `.\WorkstationProvisioning.ps1`
- [ ] Select Machine Type:
  - [ ] `D` = Developer
  - [ ] `N` = Non-Dev
  - [ ] `S` = Stock

## Information You'll Need During Script Execution

### Windows Edition (Step 2)
Script auto-detects:
- [ ] Windows Home → Domain features skipped
- [ ] Windows Pro/Enterprise → Full provisioning

### PC Rename (Step 6)
**For User Machines:**
- [ ] Username: `___________________`
- [ ] Generated Name: `YS-___________-__`
- [ ] Format: YS-username-YY (two-digit year)
- [ ] Example: YS-jdoe-25

**For Stock Machines:**
- [ ] New PC Name: `YS-STOCK-__`
- [ ] Example: YS-STOCK-01

### Domain Join (Step 8) - Pro/Enterprise Only
- [ ] Domain: `yahara`
- [ ] Username: `___________________`
- [ ] Password: `___________________`

### User to Add as Admin (Step 13) - Dev/Non-Dev Only
- [ ] Username: `___________________`

## Automated Software Installation

### Step 10: Chocolatey Packages
Script installs with retry logic:
- [ ] Zoom
- [ ] Slack
- [ ] Google Chrome
- [ ] Firefox
- [ ] Microsoft 365 (via Office Deployment Tool)

**Developer Only:**
- [ ] Git
- [ ] Visual Studio Code
- [ ] Visual Studio 2022 Professional
- [ ] SQL Server Management Studio

### Step 11: Flash Drive Software
Auto-detected and installed:
- [ ] RingCentral (auto-removed from startup)
- [ ] Checkpoint VPN (manual config required)
- [ ] Dell SupportAssist

## Domain Controller Tasks (Step 14) - Pro/Enterprise Only

### DNS Configuration
- [ ] IP Address: `___________________`
- [ ] Computer Name: `___________________`
- [ ] Host (A) record created in DNS

### ADUC Verification
- [ ] Computer found in ADUC
- [ ] Located in correct OU
- [ ] Moved if necessary

## Final Manual Steps

### Checkpoint VPN Configuration
- [ ] Server: `69.129.61.46`
- [ ] Port: `4433`
- [ ] Connection tested

### Dell SupportAssist (if Dell hardware)
- [ ] Full system scan completed
- [ ] All updates installed

### Windows Store
- [ ] Opened Microsoft Store
- [ ] Checked for updates
- [ ] All updates installed

### Final Reboot
- [ ] Performed final reboot
- [ ] Verified all services start correctly

## Post-Provisioning Verification

### Software Checklist - All Machines
- [ ] Zoom
- [ ] Slack
- [ ] Google Chrome
- [ ] Firefox
- [ ] Microsoft 365
- [ ] RingCentral (NOT in startup)
- [ ] Checkpoint VPN (configured)
- [ ] Dell SupportAssist (if Dell)

### Additional Software - Developer Only
- [ ] Git
- [ ] SQL Server Management Studio
- [ ] Visual Studio Code
- [ ] Visual Studio 2022 Professional

### System Verification
- [ ] PC name correct: `___________________`
- [ ] Domain joined: yahara (or N/A for Home)
- [ ] User is local administrator (Dev/Non-Dev)
- [ ] Timezone: Central Standard Time
- [ ] Windows activated
- [ ] All updates installed
- [ ] DNS record created (Pro/Enterprise)
- [ ] Computer in ADUC (Pro/Enterprise)

## Log File Location
`C:\ProvisioningLogs\Provisioning_YYYYMMDD_HHMMSS.log`

## State File Location
`C:\ProvisioningLogs\ProvisioningState.json`

## If Script Doesn't Resume After Reboot
Just run the script again - it will pick up where it left off!

## To Reset and Start Over
```powershell
Remove-Item "C:\ProvisioningLogs\ProvisioningState.json" -Force
```

## Notes / Issues Encountered
```
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
```

## Provisioning Summary
| Item | Value |
|------|-------|
| Provisioned By | |
| Date | |
| Time Started | |
| Time Completed | |
| Machine Type | Dev / Non-Dev / Stock |
| Windows Edition | Home / Pro / Enterprise |
| PC Name | |
| Domain Joined | Yes / No / N/A |

---
*Version 1.5 - December 2025*
*Keep this checklist for your records*
