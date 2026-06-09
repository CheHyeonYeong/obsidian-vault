robocopy "..\cohe\기술노트" ".\content" /MIR /XD .obsidian /XF .DS_Store | Out-Null

git add -A
$msg = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
git commit -m $msg
git push origin main
Write-Host "배포 완료: $msg"
