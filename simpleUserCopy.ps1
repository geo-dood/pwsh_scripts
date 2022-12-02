$user = read-host "Username"
$recvIP = read-host "Destination IP"
Copy-Item -force -recurse -path "C:\Users\$user" -Destination \\$recvIP\g\Users\$user
