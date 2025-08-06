# Simple PowerShell script to aid pushing to GitLab

Write-Host "`n----------------------------------------------------" -ForegroundColor Cyan

Read-Host -Prompt "Hello! Press Enter to continue"

Write-Host "****************************************************" -ForegroundColor Green

git status

Write-Host "****************************************************" -ForegroundColor Green

Read-Host -Prompt "Please review above status. Press Enter to continue"

git add .

Write-Host "----------------------------------------------------" -ForegroundColor Cyan

$commit_comment = Read-Host -Prompt "Please provide a commit comment"

Write-Host "----------------------------------------------------" -ForegroundColor Cyan

# Confirm the commit comment
$confirmation = Read-Host -Prompt "Please confirm your comment:`n'$commit_comment'`nType Y to confirm, N to cancel"

if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Commit cancelled by user." -ForegroundColor Red
    exit
}

Write-Host "****************************************************" -ForegroundColor Green

git commit -m "$commit_comment"

Write-Host "****************************************************" -ForegroundColor Green

Write-Host "----------------------------------------------------" -ForegroundColor Cyan

$final_confirm = Read-Host -Prompt "Ready to push to 'main'? Type Y to push, any other key to cancel"

if ($final_confirm -eq 'Y' -or $final_confirm -eq 'y') {
    git push origin main
    Write-Host "Push complete!" -ForegroundColor Green
} else {
    Write-Host "Push cancelled by user." -ForegroundColor Yellow
}

Write-Host "****************************************************" -ForegroundColor Cyan

