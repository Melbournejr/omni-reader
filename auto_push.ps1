param([string]$msg = "update: OmniReader")
git add -A
git commit -m "$msg"
git push origin main
