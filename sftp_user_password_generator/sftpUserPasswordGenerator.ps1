$users = Import-Csv -Path "C:\sftp_stuff\exportUsers_2024-12-18.csv"

foreach ($user in $users) {
    $password = [System.Web.Security.Membership]::GeneratePassword(12, 2)
    $user | Add-Member -MemberType NoteProperty -Name "Password" -Value $password
}

$users | Export-Csv -Path "C:\sftp_stuff\AzureADUsersWithPasswords.csv" -NoTypeInformation