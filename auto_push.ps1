param([string]$Message = "chore: auto update omni-reader")
$ErrorActionPreference = "Stop"
git add .
if ([string]::IsNullOrWhiteSpace((git status --porcelain))) {
  Write-Host "Khong co thay doi moi." -ForegroundColor Yellow
  exit 0
}
git commit -m $Message
git push -u origin main
Write-Host "Da up len https://github.com/Melbournejr/omni-reader thanh cong!" -ForegroundColor Green
