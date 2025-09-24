# sanitize_and_force_push.ps1
# Nettoie le repo (présent & historique) puis push force vers main avec token

param(
  [string]$RemoteClean = "https://github.com/viedereve1/ydd-downloader.git"
)

# ---------- helpers ----------
function Ok($m){ Write-Host "[$(Get-Date -f HH:mm:ss)] $m" -ForegroundColor Green }
function Info($m){ Write-Host "[$(Get-Date -f HH:mm:ss)] $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[$(Get-Date -f HH:mm:ss)] $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[$(Get-Date -f HH:mm:ss)] $m" -ForegroundColor Red }

function Read-TokenPlain([string]$prompt){
  $sec = Read-Host $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

# ---------- prérequis ----------
# 1) Être à la racine du projet (où il y a .git)
$here = Get-Location
if (-not (Test-Path ".git")){ Err "Pas de dossier .git ici: $here"; exit 1 }

# 2) git présent ?
if (-not (Get-Command git -ErrorAction SilentlyContinue)){
  Err "git introuvable dans le PATH."; exit 1
}

# 3) git-filter-repo présent ? Si non, tenter installation via pip
$hasFilter = $false
try { git filter-repo --help *> $null; $hasFilter = $true } catch {}
if (-not $hasFilter){
  Warn "git-filter-repo non détecté. Tentative d'installation via 'pip install git-filter-repo'..."
  try {
    pip --version *> $null
    pip install --user git-filter-repo
    # après install, retester
    git filter-repo --help *> $null
    $hasFilter = $true
  } catch {
    Err "Impossible d'installer/charger git-filter-repo. Installe-le manuellement puis relance."
    exit 1
  }
}

# ---------- liste des gros éléments à purger ----------
$pathsToRemove = @(
  ".tools/ffmpeg",
  "downloads",
  "__pycache__",
  ".log",
  ".DS_Store"
)

# ---------- 0) Sécurité : enlever éventuels identifiants GitHub déjà enregistrés ----------
Info "Nettoyage éventuel d'identifiants GitHub dans le Credential Manager..."
try {
  git credential-manager erase <<EOF
protocol=https
host=github.com
EOF
} catch {}

# ---------- 1) Ignorer dès maintenant ces chemins ----------
Info "Mise à jour .gitignore et retrait de l'index courant..."
$gi = ".gitignore"
$existing = @{}
if (Test-Path $gi){ (Get-Content $gi) | ForEach-Object { $existing[$_] = $true } }

$added = 0
$pathsToRemove | ForEach-Object {
  if (-not $existing.ContainsKey($_)){
    Add-Content -Path $gi -Value $_
    $added++
  }
}

git rm -r --cached --ignore-unmatch @pathsToRemove 2>$null | Out-Null
git add .gitignore
git add -A
git commit -m "chore: stop tracking large paths & update .gitignore" | Out-Null
Ok "Index courant nettoyé."

# ---------- 2) Purge de l'historique (réécrit TOUT l'historique) ----------
Warn "ATTENTION: Réécriture de l'historique en cours (git filter-repo)..."
# Construire les options --path pour filter-repo (avec --invert-paths pour retirer)
$opts = @()
$pathsToRemove | ForEach-Object { $opts += @("--path", $_) }
# Sauvegarde de secours
if (-not (Test-Path ".git\backup_before_filterrepo")){
  git branch backup_before_filterrepo | Out-Null
}
git filter-repo @opts --invert-paths --force

Ok "Historique purgé."

# ---------- 3) Vérifier/poser le remote origin propre ----------
Info "Configuration du remote 'origin'..."
$origin = git remote 2>$null
if (-not ($origin -match "origin")){
  git remote add origin $RemoteClean | Out-Null
} else {
  git remote set-url origin $RemoteClean | Out-Null
}
Ok "Remote 'origin' -> $RemoteClean"

# ---------- 4) Pousser en force avec TOKEN (sans le stocker) ----------
$token = Read-TokenPlain "Colle ton PAT GitHub (il ne sera pas stocké) :"
if ([string]::IsNullOrWhiteSpace($token)){
  Err "Token vide."; exit 1
}

# Construire une URL temporaire avec auth 'x-access-token:TOKEN'
$remoteWithToken = $RemoteClean -replace '^https://','https://x-access-token:' + $token + '@'

Info "Push force vers 'origin/main' (URL temporaire avec token)..."
git remote set-url origin $remoteWithToken | Out-Null
git branch -M main | Out-Null
git push -u origin main --force
if ($LASTEXITCODE -ne 0){
  Err "Échec du push. Vérifie droits du token (repo: full control) & que tu es bien propriétaire du dépôt."
  # remettre l'URL propre avant de quitter
  git remote set-url origin $RemoteClean | Out-Null
  exit 1
}

Ok "Push réussi."

# ---------- 5) Revenir sur l'URL propre ----------
git remote set-url origin $RemoteClean | Out-Null
Ok "Remote nettoyé (sans token)."
Ok "Terminé."
