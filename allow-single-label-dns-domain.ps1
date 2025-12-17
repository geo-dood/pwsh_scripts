$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
$valueName = "AllowSingleLabelDnsDomain"
$valueData = 1

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You must run this script as Administrator."
    exit 1
}

if (-not (Test-Path $regPath)) {
    Write-Error "Registry path not found: $regPath"
    exit 1
}

try {
    New-ItemProperty -Path $regPath -Name $valueName -PropertyType DWord -Value $valueData -Force | Out-Null
    Write-Host "Successfully set '$valueName' to '$valueData' in '$regPath'"
} catch {
    Write-Error "Failed to set registry value: $_"
    exit 1
}
