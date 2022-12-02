import-module bitsTransfer
$errorActionPreference='silentlyContinue'
$u= read-host "User"
$4= read-host "IP"
$s= "C:\Users\$u\"
$p= "\\$4\g\Users\$u"
if(-not(test-path $p)){$null= new-item -p $p -i d}$d= get-childItem -n -pa $s -di -r
$j= start-bitsTransfer -so $s\*.* -dest $p
while(($j.JobState.ToString() -eq 'Transferring') -or ($j.JobState.ToString() -eq 'Connecting')){sleep 1}complete-bitsTransfer -bitsJob $j
foreach($i in $d){$e= test-path $p\$i
if($e -eq $false){new-item $p\$i -i d}$j=start-bitsTransfer -so $s\$i\*.* -dest $p\$i
while(($j.JobState.ToString() -eq 'Transferring') -or ($j.JobState.ToString() -eq 'Connecting')){sleep 1}complete-bitsTransfer -bitsJob $j}
