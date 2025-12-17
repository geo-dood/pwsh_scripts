$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$username = $env:USERNAME
$logFile = "$env:USERPROFILE\Desktop\network_diagnostics_${username}_$timestamp.txt"

Write-Host "Starting network diagnostics for user: $username" -ForegroundColor Cyan
Write-Host "Output will be saved to: $logFile`n"

function Run-And-Log {
    param(
        [string]$Label,
        [scriptblock]$Command
    )
    Write-Host "Running $Label..." -ForegroundColor Yellow
    Add-Content -Path $logFile -Value "`n================== $Label ==================`n"
    try {
        $output = & $Command 2>&1
        $output | Out-File -FilePath $logFile -Append -Encoding utf8
    }
    catch {
        "Error running ${Label}: $_" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}

Add-Content -Path $logFile -Value "Network Diagnostic Log"
Add-Content -Path $logFile -Value "Run by: $username"
Add-Content -Path $logFile -Value "Timestamp: $timestamp`n"

Run-And-Log "IPCONFIG /ALL" { ipconfig /all }
Run-And-Log "NSLOOKUP slack.com" { nslookup slack.com }
Run-And-Log "NSLOOKUP zoom.us" { nslookup zoom.us }
Run-And-Log "NSLOOKUP jira.com" { nslookup jira.com }

Run-And-Log "PING slack.com" { ping slack.com }
Run-And-Log "PING zoom.us" { ping zoom.us }
Run-And-Log "PING jira.com" { ping jira.com }

Run-And-Log "TRACERT slack.com (max 10 hops, 1 sec timeout)" { tracert -h 10 -w 1000 slack.com }
Run-And-Log "TRACERT zoom.us (max 10 hops, 1 sec timeout)" { tracert -h 10 -w 1000 zoom.us }
Run-And-Log "TRACERT jira.com (max 10 hops, 1 sec timeout)" { tracert -h 10 -w 1000 jira.com }

Write-Host "`nDiagnostics complete!" -ForegroundColor Green
Write-Host "Log file created: $logFile" -ForegroundColor Cyan
Write-Host "Please send this file to your IT contact." -ForegroundColor Gray

Invoke-Item -Path (Split-Path $logFile)
