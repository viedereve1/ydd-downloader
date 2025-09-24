Param(
  [string]$RepoUrl = "https://github.com/viedereve1/ydd-downloader.git",
  [string]$Token   = "PASTE_NEW_TOKEN_HERE",
  [int]$MaxSizeMB  = 100
)

function Ok($m){ Write-Host "OK  $m" -ForegroundColor Green }
function Info($m){ Write-Host "i   $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "!   $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "X   $m" -ForegroundColor Red }

# 0) Pré-checks ---------------------------------------------------------------
$ErrorActionPreference = 'Stop'
try { git --version | Out-Null } catch { Err "Git introuvable."; exit 1 }
try {
  git rev-parse --is-inside-work-tree | Out-Null
} catch {
  Err "Ce dossier n'est pas un dépôt Git. Lance le script depuis la racine du projet."; exit 1
}

# 1) Installer git-filter-repo si nécessaire ---------------------------------
Info "Vérification de git-filter-repo..."
$hasGFR = $false
try {
  python - << 'PY'
import importlib, sys
sys.exit(0 if importlib.util.find_spec("git_filter_repo") else 1)
PY
  if ($LASTEXITCODE -eq 0) { $hasGFR = $true }
} catch {}

if (-not $hasGFR) {
  Info "Installation de git-filter-repo (pip)..."
  pip install --upgrade git-filter-repo | Out-Null
  python - << 'PY'
import importlib, sys
sys.exit(0 if importlib.util.find_spec("git_filter_repo") else 1)
PY
  if ($LASTEXITCODE -ne 0) { Err "Impossible d’installer git-filter-repo."; exit 1 }
}
Ok "git-filter-repo prêt."

# 2) Construire la liste des chemins à retirer de l’historique ---------------
$pathsFile = Join-Path $PWD ".paths_to_remove.txt"
if (Test-Path $pathsFile) { Remove-Item $pathsFile -Force }
New-Item $pathsFile -ItemType File | Out-Null

# Dossiers/fichiers « bruyants » connus
$knownPaths = @(
  "tools/ffmpeg/bin/", "tools/ffmpeg/", "downloads/", "__pycache__/",
  "*.log", "*.tmp", "*.bak", ".DS_Store", "Thumbs.db",
  "push_with_token.ps1", "push_with_token.ps", "push_auto.ps1"
)

# Ajoute les chemins connus présents dans l’historique
foreach($p in $knownPaths){
  $hits = git ls-files -z $p 2>$null | ForEach-Object { $_ }
  if ($LASTEXITCODE -eq 0 -and $hits) { Add-Content $pathsFile $p }
}

# Fichiers contenant des secrets (on retire entièrement ces fichiers)
$secretPatterns = @("ghp_", "x-access-token", "AWS_SECRET_ACCESS_KEY", "Authorization: Bearer ", "TOKEN=", "PASSWORD=")
foreach($pat in $secretPatterns){
  $files = git grep -Il "$pat" -- ':!*.png' ':!*.jpg' ':!*.jpeg' ':!*.gif' ':!*.mp4' 2>$null
  foreach($f in ($files | Sort-Object -Unique)){
    Add-Content $pathsFile $f
  }
}

# 3) Détection des blobs > $MaxSizeMB dans l’historique ----------------------
Info "Scan des fichiers > $MaxSizeMB MB dans l’historique (peut prendre un peu de temps)..."
$big = @()
# liste (sha + path)
$all = & git rev-list --objects --all
foreach($line in $all){
  if ($line.Trim() -eq "") { continue }
  $parts = $line -split " ",2
  if ($parts.Count -lt 2) { continue }
  $sha = $parts[0]; $path = $parts[1]
  # taille du blob
  $size = (& git cat-file -s $sha) 2>$null
  if ($size -and [int64]$size -gt ($MaxSizeMB*1MB)) {
    $big += $path
  }
}
foreach($p in ($big | Sort-Object -Unique)){
  Add-Content $pathsFile $p
}
Ok "Liste de purge préparée."

# 4) Purge avec git-filter-repo ----------------------------------------------
$hasPaths = (Get-Content $pathsFile | Where-Object { $_.Trim() -ne "" } | Measure-Object).Count -gt 0

Info "Purge de l’historique (secrets + gros fichiers)..."
if ($hasPaths) {
  & git filter-repo --force `
      --paths-from-file $pathsFile --invert-paths `
      --strip-blobs-bigger-than "${MaxSizeMB}M"
} else {
  & git filter-repo --force --strip-blobs-bigger-than "${MaxSizeMB}M"
}

# 5) Repack & GC --------------------------------------------------------------
Info "Repack/GC..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive
Ok "Nettoyage local terminé."

# 6) Push forcé (avec token puis remote propre) ------------------------------
$remoteClean = $RepoUrl
$remoteWithToken = $RepoUrl.Replace("https://", "https://$Token@")

Info "Reconfiguration temporaire du remote avec token..."
git remote remove origin 2>$null
git remote add origin $remoteWithToken

Info "Push forcé (branches + tags)..."
git push origin --force --all
if ($LASTEXITCODE -ne 0) {
  Err "Échec du push (vérifie le token et les règles du dépôt)."; exit 1
}
git push origin --force --tags

Ok "Push réussi vers $RepoUrl"

Info "Nettoyage du remote (sans token)..."
git remote remove origin
git remote add origin $remoteClean
Ok "Remote rétabli proprement."

# 7) Conseils finaux ----------------------------------------------------------
Warn "Si tu as déjà poussé un token, va sur le lien Secret Scanning de GitHub pour 'unblock' si nécessaire, ou vérifie que plus AUCUN secret n’est présent."
Ok "Terminé."

