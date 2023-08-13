#pwsh script to start workday
start-process -filePath Chrome -argumentList 'https://outlook.office365.com/mail/ https://outlook.office365.com/calendar/view/day https://outlook.office365.com/bookings/calendar https://wigov.sharepoint.com/sites/doa-desktopkb https://eiam.wisconsin.gov/CayosoftWebAdmin/QuickSearch/Login https://falcon.us-2.crowdstrike.com/dashboards-v2/dashboard/9D5413A9-50CB-4242-8DE4-F32C23534A3B https://myapps.microsoft.com/signin/e94dd0cf-b102-4089-a2e3-514335342788?tenantId=f4e2d11c-fae4-453b-b6c0-2964663779aa'
start-process -filePath Firefox -argumentList 'https://sundialsc.com/SCOffice/Pages/logon.aspx https://ess.wi.gov/psp/ess/EXTERNAL/HRMS/?cmd=login https://mail.proton.me/u/0/inbox'
start-process -filePath "C:\Program Files\Notepad++\notepad++.exe"
start-process -filePath "C:\Program Files (x86)\Cherwell Software\Cherwell Service Management\Trebuchet.App.exe"
start-process -verb runas -filePath "C:\Program Files (x86)\ConfigMgrConsole\bin\Microsoft.ConfigurationManagement.exe"
