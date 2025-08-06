Import-Module BitsTransfer

$errorActionPreference = 'SilentlyContinue'

# Prompt user for input
$userName = Read-Host "Enter username"
$destinationIP = Read-Host "Enter destination IP"

# Define source and destination paths
$sourcePath = "C:\Users\$userName"
$destinationPath = "\\$destinationIP\g\Users\$userName"

# Create destination directory if it does not exist
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
}

# Get all directories (including hidden) recursively from source path
$directories = Get-ChildItem -Path $sourcePath -Directory -Force -Recurse

# Transfer all files from source root to destination root
$job = Start-BitsTransfer -Source "$sourcePath\*.*" -Destination $destinationPath

# Wait for the job to complete
while ($job.JobState.ToString() -eq 'Transferring' -or $job.JobState.ToString() -eq 'Connecting') {
    Start-Sleep -Seconds 1
}
Complete-BitsTransfer -BitsJob $job

# Transfer files for each subdirectory
foreach ($dir in $directories) {
    $targetDir = Join-Path -Path $destinationPath -ChildPath $dir.Name

    # Create target subdirectory if it does not exist
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory | Out-Null
    }

    # Start BITS transfer for files in the subdirectory
    $job = Start-BitsTransfer -Source "$($dir.FullName)\*.*" -Destination $targetDir

    # Wait for the job to complete
    while ($job.JobState.ToString() -eq 'Transferring' -or $job.JobState.ToString() -eq 'Connecting') {
        Start-Sleep -Seconds 1
    }
    Complete-BitsTransfer -BitsJob $job
}

