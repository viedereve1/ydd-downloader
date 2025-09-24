# force_clean_and_push.ps1
param (
    [string]$RepoUrl = "https://github.com/viedereve1/ydd-downloader.git",
    [string]$Token   = "ghp_sp6u0091H2nrFmsV3GoCO5fho00YF93qMCTy"
)

Write-Host "[1] Nettoyage des gros fichiers..."
# Création d’un .gitignore pour éviter les fichiers lourds
@"
*.exe
*.dll
*.bin
*.mp4
*.zip
tools/
downloads/
__pycache__/
*.log
.DS_Store
"@ | Out-File -Encoding utf8 .gitignore

git rm -r --cached . > $null 2>&1
git add .gitignore
git add .
git commit -m "Nettoyage des fichiers lourds et ajout .gitignore" --allow-empty

Write-Host "[2] Purge de l’historique Git..."
git filter-branch --force --index-filter "git rm -r --cached --ignore-unmatch tools/ffmpeg/bin/*" --prune-empty --tag-name-filter cat -- --all

Write-Host "[3] Configuration du remote avec token..."
$remoteWithToken = $RepoUrl.Replace("https://", "https://$Token@")
git remote remove origin > $null 2>&1
git remote add origin $remoteWithToken

Write-Host "[4] Push forcé vers main..."
git branch -M main
git push -u origin main --force

if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] ECHEC DU PUSH. Vérifie ton token et tes droits." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Push terminé avec succès !" -ForegroundColor Green

Write-Host "[5] Nettoyage du remote (retrait du token)..."
git remote remove origin
git remote add origin $RepoUrl

Write-Host "[FIN] Dépôt propre, token retiré."
