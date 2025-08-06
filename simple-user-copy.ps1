# Prompt for username and destination IP
$userName = Read-Host -Prompt "Enter the username"
$destinationIP = Read-Host -Prompt "Enter the destination IP address"

# Construct source and destination paths
$sourcePath = "C:\Users\$userName"
$destinationPath = "\\$destinationIP\g\Users\$userName"

# Check if source path exists
if (-Not (Test-Path -Path $sourcePath)) {
    Write-Error "Source path '$sourcePath' does not exist. Please check the username and try again."
    exit
}

# Attempt to copy the directory recursively with force
try {
    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    Write-Host "Successfully copied '$sourcePath' to '$destinationPath'." -ForegroundColor Green
}
catch {
    Write-Error "Failed to copy files: $_"
}

