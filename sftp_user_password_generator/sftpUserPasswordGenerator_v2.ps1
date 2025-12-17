function New-StrongPassword {
    param (
        [int]$length = 12
    )

    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}|;:,.<>?'
    $password = -join ((1..$length) | ForEach-Object { $charSet | Get-Random })
    return $password
}

# Example usage
$users = Import-Csv -Path "C:\sftp_stuff\exportUsers_2024-12-18.csv"

foreach ($user in $users) {
    $password = New-StrongPassword
    $user | Add-Member -MemberType NoteProperty -Name "Password" -Value $password
}

$users | Export-Csv -Path "C:\sftp_stuff\AzureADUsersWithPasswords.csv" -NoTypeInformation