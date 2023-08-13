# Simple powershell script to aid in pushing to GitLab
echo "`n`r----------------------------------------------------"
read-host -prompt "Hello! `nPlease press any key to continue"
echo "****************************************************"
git status
echo '****************************************************'
read-host -prompt "Please review `nPress any key to continue"
git add .
echo "----------------------------------------------------"
$commit_comment = read-host -prompt "Please provide comment for commit"
echo '----------------------------------------------------'
read-host -prompt "Please confirm comment: `n`r$echo $commit_comment `nPress any key to continue"
echo '****************************************************'
git commit -m "$commit_comment"
echo '****************************************************'
echo '----------------------------------------------------'
read-host -prompt "Triple check before proceeding! `nPress any key to continue, or ctrl+c to quit"
echo '****************************************************'
git push origin main
echo "****************************************************"