# deep_clean.ps1
Write-Host "[1] Suppression des gros fichiers + secrets de l’historique..."

# Supprimer ffmpeg et les fichiers lourds
git filter-branch --force --index-filter `
  "git rm -rf --cached --ignore-unmatch tools/ffmpeg/bin/* *.exe *.dll *.bin *.mp4 *.zip" `
  --prune-empty --tag-name-filter cat -- --all

# Supprimer tout fichier sensible (comme push_with_token.ps1)
git filter-branch --force --index-filter `
  "git rm -rf --cached --ignore-unmatch push_with_token.ps1" `
  --prune-empty --tag-name-filter cat -- --all

Write-Host "[2] Nettoyage terminé. Repack du dépôt..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

Write-Host "[3] Reconfigurer le remote avec ton token..."
$RepoUrl = "https://github.com/viedereve1/ydd-downloader.git"
$Token   = "ghp_sp6u0091H2nrFmsV3GoCO5fho00YF93qMCTy"
$remoteWithToken = $RepoUrl.Replace("https://", "https://$Token@")

git remote remove origin 2>$null
git remote add origin $remoteWithToken

Write-Host "[4] Push forcé..."
git push origin --force --all
git push origin --force --tags

Write-Host "[OK] Push terminé. Nettoyage du remote..."
git remote remove origin
git remote add origin $RepoUrl

Write-Host "[FINI] Dépôt nettoyé et pushé avec succès."
