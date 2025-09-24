# ===========================
# finalize_push.ps1
# Nettoyage + purge historique (gros fichiers) + push
# ===========================

$ErrorActionPreference = "Stop"

function Ok($m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Info($m){ Write-Host "[i]  $m" -ForegroundColor Cyan }
function Warn($m){ Write-Host "[!]  $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "[X]  $m" -ForegroundColor Red }

# 0) Contexte
$root = Get-Location
Info "Dossier projet : $root"

# 1) Demander repo cible
if (-not $RepoUser) { $RepoUser = Read-Host "Ton user GitHub (ex: videoreve1)" }
if (-not $RepoName) { $RepoName = Read-Host "Nom du repo (ex: ydd-downloader)" }

$remoteUrl = "https://github.com/$RepoUser/$RepoName.git"
Info "Remote cible : $remoteUrl"

# 2) S'assurer qu'on est bien un repo git
if (-not (Test-Path ".git")) {
  Info "Initialisation Git…"
  git init | Out-Null
} else {
  Info "Repo Git déjà initialisé."
}

# 3) Nettoyage du working tree (supprime les lourds/local-only)
$pathsToRemove = @(
  ".tools/ffmpeg",      # binaires ffmpeg (>100MB)
  "downloads",          # fichiers téléchargés
  "__pycache__",        # caches python
  ".log",               # logs éventuels
  ".DS_Store"           # fichiers macOS, au cas où
)

foreach ($p in $pathsToRemove) {
  if (Test-Path $p) {
    Info "Suppression locale: $p"
    Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# 4) .gitignore à jour
$gi = @"
# --- YDD-Downloader ignore ---
downloads/
__pycache__/
*.log
.DS_Store
.tools/ffmpeg/
# --------------------------------
"@
Set-Content -Path ".gitignore" -Value $gi -Encoding UTF8
Ok ".gitignore mis à jour"

# 5) Stage & commit (si changements)
git add -A
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
  Info "Aucun changement à committer (working tree clean)."
} else {
  $msg = "chore: prepare clean repo before history purge"
  git commit -m $msg | Out-Null
  Ok "Commit: $msg"
}

# 6) Installer git-filter-repo si absent
function Ensure-FilterRepo {
  try {
    git filter-repo --help | Out-Null
    return $true
  } catch {
    Warn "git filter-repo introuvable. Installation via pip…"
    # Essayer python/pip utilisateur
    try {
      python -m pip install --user git-filter-repo
    } catch {
      Warn "Tentative avec 'pip' direct…"
      pip install --user git-filter-repo
    }
    # Ajouter le chemin Scripts utilisateur au PATH de la session si besoin
    $userScripts = Join-Path $env:USERPROFILE "AppData\Roaming\Python\Python39\Scripts"
    $altScripts1 = Join-Path $env:USERPROFILE "AppData\Roaming\Python\Python310\Scripts"
    $altScripts2 = Join-Path $env:USERPROFILE "AppData\Roaming\Python\Python311\Scripts"
    $altScripts3 = Join-Path $env:USERPROFILE "AppData\Roaming\Python\Python312\Scripts"
    foreach ($d in @($userScripts,$altScripts1,$altScripts2,$altScripts3)) {
      if (Test-Path $d -and ($env:PATH -notlike "*$d*")) { $env:PATH="$d;$env:PATH" }
    }
    try {
      git filter-repo --help | Out-Null
      return $true
    } catch {
      return $false
    }
  }
}
if (-not (Ensure-FilterRepo)) {
  Err "Impossible d’installer/charger git-filter-repo. Installe Python puis relance."
  exit 1
}
Ok "git-filter-repo prêt"

# 7) PURGE de l’historique (retire définitivement les chemins lourds)
Warn "Purge de l’historique Git (cela réécrit tout l’historique)…"
$removePaths = @(
  ".tools/ffmpeg",
  "downloads",
  "__pycache__",
  ".log",
  ".DS_Store"
)

# Construction des arguments: --path <p> répété + --invert-paths
$pathArgs = @()
foreach ($p in $removePaths) { $pathArgs += @("--path", $p) }

# --force évite les prompts; --replace-refs remplace les refs propres
git filter-repo @pathArgs --invert-paths --force --replace-refs delete-no-add | Out-Null
Ok "Historique purgé des gros fichiers"

# 8) Reconfigurer la remote sur le bon repo
$hasOrigin = (git remote) -split "`n" | Where-Object { $_ -eq "origin" }
if ($hasOrigin) {
  git remote set-url origin $remoteUrl | Out-Null
  Info "Remote 'origin' mise à jour."
} else {
  git remote add origin $remoteUrl | Out-Null
  Info "Remote 'origin' ajoutée."
}

# 9) S’assurer d’être sur 'main'
git branch -M main | Out-Null

# 10) PUSH (force-with-lease pour préserver la sécu)
Warn "Push force-with-lease vers 'origin/main'…"
Warn "Si Windows demande un login, mets ton user GitHub et le TOKEN comme mot de passe."
git config --global credential.helper manager-core | Out-Null
git push --force-with-lease -u origin main
if ($LASTEXITCODE -ne 0) {
  Err "Échec du push. Vérifie les droits sur le repo & le token (scopes: repo)."
  exit 1
} else {
  Ok "Push réussi vers $remoteUrl"
}
