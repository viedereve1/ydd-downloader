param(
  [string]$RepoUrl = "https://ghp_276c8HLScQTvbH1eDM1Ccg8ijYPLX2vk2uX@github.com/viedereve1/ydd-downloader.git",
  [string]$Branch = "main"
)

# === Fonctions utilitaires ===
function OK ($m)  { Write-Host "✔ $m" -ForegroundColor Green }
function INF($m)  { Write-Host "• $m" -ForegroundColor Cyan }
function ERR($m)  { Write-Host "✖ $m" -ForegroundColor Red }

# === Étape 1 : Nettoyage local ===
INF "Suppression des fichiers lourds..."
$patterns = @("*.exe","*.dll","*.bin","*.zip","*.mp4","tools","downloads","__pycache__")
foreach ($p in $patterns) {
    Get-ChildItem -Path . -Recurse -Include $p -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
OK "Nettoyage terminé."

# === Étape 2 : Réécriture de l’historique ===
INF "Purge de l’historique Git..."
git filter-repo --path-glob "*.exe" --invert-paths --force
git filter-repo --path-glob "*.dll" --invert-paths --force
git filter-repo --path-glob "*.bin" --invert-paths --force
git filter-repo --path-glob "*.zip" --invert-paths --force
git filter-repo --path-glob "*.mp4" --invert-paths --force
git filter-repo --path tools --invert-paths --force
git filter-repo --path downloads --invert-paths --force
git filter-repo --path __pycache__ --invert-paths --force
OK "Historique purgé."

# === Étape 3 : Repack Git ===
INF "Compression..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive
OK "Compression terminée."

# === Étape 4 : Push forcé ===
INF "Configuration du remote..."
git remote remove origin 2>$null
git remote add origin $RepoUrl

INF "Push forcé vers $Branch..."
git checkout -B $Branch | Out-Null
git push -u origin $Branch --force

if ($LASTEXITCODE -ne 0) {
    ERR "Échec du push. Vérifie ton token et tes droits."
    exit 1
}
OK "Push réussi."

# === Étape 5 : Nettoyage remote (enlever le token) ===
$remoteClean = $RepoUrl -replace "https://ghp_[^@]+@", "https://"
INF "Nettoyage de l’URL remote..."
git remote set-url origin $remoteClean
OK "Remote nettoyé."

OK "✅ Dépôt minimal repoussé proprement sur $RepoUrl"
